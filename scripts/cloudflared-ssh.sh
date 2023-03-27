#!/usr/bin/env bash
# @file local/cloudflared.sh
# @brief Installs and configures cloudflared for short-lived SSH certificates authenticated via SSO
# @description
#     This script ensures Homebrew is installed and then uses Homebrew to ensure `cloudflared` is installed.
#     After that, it connects `cloudflared` to CloudFlare Teams and sets up short-lived SSH certificates so
#     that you do not have to manage SSH keys and instead use SSO (Single Sign-On) via CloudFlare Teams.
#
#     **Note**: `https://install.doctor/cloudflared` points to this file.
#
#     ## Variables
#
#     The `SSH_DOMAIN` variable should be set to the endpoint you want to be able to SSH into. The SSH endpoint(s)
#     that are created depend on what type of system is being configured. Some device types include multiple
#     properties that need multiple unique SSH endpoints. The `SSH_DOMAIN` must be passed to this script or else
#     it will default to `ssh.megabyte.space`.
#
#     * For most installations, the configured domain will be `$(hostname).${SSH_DOMAIN}`
#     * If Qubes is being configured, then the configured domain will be `$(hostname)-qube.${SSH_DOMAIN}`
#     * If [EasyEngine](https://easyengine.io/) is installed, then each domain setup with EasyEngine is configured to have an `ssh` subdomain (i.e. `ssh.example.com` for `example.com`)
#
#     There are other optional variables that can be customized as well:
#
#     * `CF_TUNNEL_NAME` - The ID to assign to the tunnel that `cloudflared` creates (`default-ssh-tunnel` by default)
#
#     ## Notes
#
#     Since the certificates are "short-lived", you will have to periodically re-authenticate against the
#     SSO authentication endpoint that is hosted by CloudFlare Teams (or an identity provider of your choosing).
#     This script will likely only work on AMD x64 devices.
#
#     Some of the commands are conditionally run based on whether or not the `CRONTAB_JOB` environment variable is set.
#     This is to accomodate EasyEngine installations where the list of SSH endpoints is variable. Both the initial
#     setup and updates are applied using this script (via a cronjob that does not need to run initialization tasks during
#     the cronjobs).
#
#     ## Links
#
#     [SSH with short-lived certificates](https://developers.cloudflare.com/cloudflare-one/tutorials/ssh-cert-bastion/)

# @description Ensures Homebrew is installed and loaded into the `PATH` variable if it is not already available
if ! command -v brew > /dev/null; then
    bash <(curl -sSL https://install.doctor/brew)
    
fi

# @description Ensures `cloudflared` is installed via Homebrew
if ! command -v cloudflared > /dev/null; then
    brew install cloudflared
fi

# @description Detect the SSH port being used
SSH_PORT="22"
if sudo cat /etc/ssh/sshd_config | grep '^Port ' > /dev/null; then
  SSH_PORT="$(sudo cat /etc/ssh/sshd_config | grep '^Port ' | sed 's/Port //')"
fi

# @description Login to the CloudFlare network (if running outside a cronjob) and acquire the tunnel ID
if [ -z "$CRONTAB_JOB" ]; then
    sudo cloudflared tunnel login
    sudo cloudflared tunnel create "${CF_TUNNEL_NAME:=default-ssh-tunnel}"
fi
TUNNEL_ID="$(sudo cloudflared tunnel list | grep " ${CF_TUNNEL_NAME} " | sed 's/^\([^ ]*\).*$/\1/')"

# @description Ensure CloudFlare tunnel ID was acquired, then add tunnel route, and create
# tunnel configuration based on what type of machine is being configured (i.e. regular, Qubes, or EasyEngine)
if [ -n "$TUNNEL_ID" ]; then
  if [ -z "$CRONTAB_JOB" ]; then
    sudo cloudflared tunnel route ip add 100.64.0.0/10 "${TUNNEL_ID}"
  fi

  # @description Create the `/root/.cloudflared/config.yml`
  CONFIG_TMP="$(mktemp)"
  echo "tunnel: ${TUNNEL_ID}" > "$CONFIG_TMP"
  echo "credentials-file: /root/.cloudflared/${TUNNEL_ID}.json" >> "$CONFIG_TMP"
  echo "" >> "$CONFIG_TMP"
  echo "ingress:" >> "$CONFIG_TMP"
  if [ -d '/opt/easyengine/sites' ]; then
    DOMAINS_HOSTED="$(find /opt/easyengine/sites -maxdepth 1 -mindepth 1 -type d | sed 's/.*sites\///' | xargs)"
  else
    if [ -d /etc/qubes ]; then
      DOMAINS_HOSTED="$(hostname)-qube.${SSH_DOMAIN:-ssh.megabyte.spaccec}"
    else
      DOMAINS_HOSTED="$(hostname).${SSH_DOMAIN:-ssh.megabyte.spaccec}"
    fi
  fi
  for DOMAIN in $DOMAINS_HOSTED; do
    echo "  - hostname: ${DOMAIN}" >> "$CONFIG_TMP"
    echo "    service: ssh://localhost:$SSH_PORT" >> "$CONFIG_TMP"
  done
  echo "  - service: http_status:404" >> "$CONFIG_TMP"
  echo "" >> "$CONFIG_TMP"
  sudo mkdir -p /root/.cloudflared
  sudo mv "$CONFIG_TMP" /root/.cloudflared/config.yml

  # @description Install the `cloudflared` system service (if it is not a cronjob)
  if [ -z "$CRONTAB_JOB" ]; then
    sudo cloudflared service install
  fi
else
  echo "ERROR: Unable to acquire CloudFlare tunnel ID" && exit 1
fi

# @description Restart if the config file changed
if [ ! -f /root/.cloudflared/config-previous.yml ] || [ "$(cat /root/.cloudflared/config-previous.yml)" != "$(cat /root/.cloudflared/config.yml)" ]; then
  # @todo Add restart command for non-systemctl devices (i.e. macOS)
  if command -v systemctl > /dev/null; then
    sudo systemctl restart cloudflared
  fi
  sudo cp /root/.cloudflared/config.yml /root/.cloudflared/config-previous.yml
fi
