#!/usr/bin/env bash
# @file Cloudflared Configuration
# @brief Applies cloudflared configuration, connects to Argo tunnel with managed configuration, and enables it on system start
# @description
#     1. Skips the deletion of a tunnel when it is currently in use

set -Eeuo pipefail
trap "gum log -sl error 'Script encountered an error!'" ERR

if command -v cloudflared > /dev/null; then
  # Show warning message about ~/.cloudflared already existing
  if [ -d "$HOME/.cloudflared" ]; then
    gum log -sl warn '~/.cloudflared is already in the home directory - to ensure proper deployment, remove previous tunnel configuration folders'
  fi

  # Copy over configuration files
  gum log -sl info 'Ensuring /usr/local/etc/cloudflared exists' && sudo mkdir -p /usr/local/etc/cloudflared
  gum log -sl info 'Copying over configuration files from ~/.local/etc/cloudflared to /usr/local/etc/cloudflared'
  sudo cp -f "$HOME/.local/etc/cloudflared/cert.pem" /usr/local/etc/cloudflared/cert.pem
  sudo cp -f "$HOME/.local/etc/cloudflared/config.yml" /usr/local/etc/cloudflared/config.yml

  HOSTNAME_LOWER="host-$(hostname -s | tr '[:upper:]' '[:lower:]')"

  ### Remove previous tunnels connected to host
  while read TUNNEL_ID; do
    gum log -sl info "Deleteing CloudFlared tunnel ID $TUNNEL_ID"
    unset TUNNEL_EXIT_CODE
    sudo cloudflared tunnel delete "$TUNNEL_ID" || TUNNEL_EXIT_CODE=$?
    if [ -z "${TUNNEL_EXIT_CODE:-}" ]; then
      gum log -sl info "Removing credentials for $TUNNEL_ID which is not in use"
      sudo rm -f "/usr/local/etc/cloudflared/${TUNNEL_ID}.json"
    else
      logg success "Skipping deletion of $TUNNEL_ID credentials since it is in use"
    fi
  done< <(sudo cloudflared tunnel list | grep "$HOSTNAME_LOWER" | sed 's/ .*//')

  ### Register tunnel (if not already registered)
  gum log -sl info "Creating CloudFlared tunnel named "$HOSTNAME_LOWER""
  sudo cloudflared tunnel create "$HOSTNAME_LOWER" || EXIT_CODE=$?
  if [ -n "${EXIT_CODE:-}" ]; then
    gum log -sl info 'Failed to create tunnel - it probably already exists'
  fi

  ### Acquire TUNNEL_ID and symlink credentials.json
  TUNNEL_ID="$(sudo cloudflared tunnel list | grep "$HOSTNAME_LOWER" | sed 's/ .*//')"
  gum log -sl info "Tunnel ID: $TUNNEL_ID"
  gum log -sl info "Symlinking /usr/local/etc/cloudflared/$TUNNEL_ID.json to /usr/local/etc/cloudflared/credentials.json"
  sudo rm -f /usr/local/etc/cloudflared/credentials.json
  sudo ln -s /usr/local/etc/cloudflared/$TUNNEL_ID.json /usr/local/etc/cloudflared/credentials.json

  ### Symlink /usr/local/etc/cloudflared to /etc/cloudflared
  if [ ! -d /etc/cloudflared ]; then
    gum log -sl info 'Symlinking /usr/local/etc/cloudflared to /etc/cloudflared'
    sudo ln -s /usr/local/etc/cloudflared /etc/cloudflared
  else
    if [ ! -L /etc/cloudflared ]; then
      gum log -sl warn '/etc/cloudflared is present as a regular directory (not symlinked) but files are being modified in /usr/local/etc/cloudflared'
    fi
  fi

  ### Configure DNS
  # Must be deleted manually if no longer used
  gum log -sl info 'Setting up DNS records for CloudFlare Argo tunnels'
  while read DOMAIN; do
    if [ "$DOMAIN" != 'null' ]; then
      gum log -sl info "Setting up $DOMAIN for access through cloudflared (Tunnel ID: $TUNNEL_ID)"
      gum log -sl info "Running sudo cloudflared tunnel route dns -f "$TUNNEL_ID" "$DOMAIN""
      sudo cloudflared tunnel route dns -f "$TUNNEL_ID" "$DOMAIN" && logg success "Successfully routed $DOMAIN to this machine's cloudflared Argo tunnel"
    fi
  done< <(yq '.ingress[].hostname' /usr/local/etc/cloudflared/config.yml)

  ### Update /usr/local/etc/cloudflared/config.yml
  gum log -sl info 'Updating /usr/local/etc/cloudflared/config.yml to reference tunnel ID'
  sudo yq eval -i ".tunnel = \"$HOSTNAME_LOWER\"" /usr/local/etc/cloudflared/config.yml

  ### Set up service
  if [ -d /Applications ] && [ -d /System ]; then
    ### macOS
    if [ -f /Library/LaunchDaemons/com.cloudflare.cloudflared.plist ]; then
      gum log -sl info 'cloudflared service is already installed'
    else
      gum log -sl info 'Running sudo cloudflared service install'
      sudo cloudflared service install
    fi
    sudo cp -f "$HOME/Library/LaunchDaemons/com.cloudflare.cloudflared.plist" /Library/LaunchDaemons/com.cloudflare.cloudflared.plist
    gum log -sl info 'Ensuring cloudflared service is started'
    if sudo launchctl list | grep 'com.cloudflare.cloudflared' > /dev/null; then
      gum log -sl info 'Unloading previous com.cloudflare.cloudflared configuration'
      sudo launchctl unload /Library/LaunchDaemons/com.cloudflare.cloudflared.plist
    fi
    gum log -sl info 'Starting up com.cloudflare.cloudflared configuration'
    sudo launchctl load -w /Library/LaunchDaemons/com.cloudflare.cloudflared.plist
  elif [ -f /etc/os-release ]; then
    ### Linux
    if systemctl --all --type service | grep -q "cloudflared" > /dev/null; then
      gum log -sl info 'cloudflared service is already available as a service'
    else
      gum log -sl info 'Running sudo cloudflared service install'
      sudo cloudflared service install
    fi
    gum log -sl info 'Ensuring cloudflared service is started'
    sudo systemctl start cloudflared
    gum log -sl info 'Enabling cloudflared as a boot systemctl service'
    sudo systemctl enable cloudflared
  else
    # System is Windows
    cloudflared service install
    mkdir C:\Windows\System32\config\systemprofile\.cloudflared
    # Copy same cert.pem as being used above
    # copy C:\Users\%USERNAME%\.cloudflared\cert.pem C:\Windows\System32\config\systemprofile\.cloudflared\cert.pem
    # https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/local/as-a-service/windows/
  fi
else
  gum log -sl info 'cloudflared was not installed so CloudFlare Tunnels cannot be enabled'
fi
