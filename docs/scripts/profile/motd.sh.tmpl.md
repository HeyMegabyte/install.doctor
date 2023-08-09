---
title: MOTD
description: Incorporates the MOTD functionality that is leveraged by the `~/.bashrc` and `~/.zshrc` files
sidebar_label: MOTD
slug: /scripts/profile/motd.sh.tmpl
githubLocation: https://github.com/megabyte-labs/install.doctor/blob/master/home/dot_config/shell/motd.sh.tmpl
scriptLocation: https://github.com/megabyte-labs/install.doctor/raw/master/home/dot_config/shell/motd.sh.tmpl
repoLocation: home/dot_config/shell/motd.sh.tmpl
---

# MOTD

Incorporates the MOTD functionality that is leveraged by the `~/.bashrc` and `~/.zshrc` files

## Overview

This script is included by `~/.bashrc` and `~/.zshrc` to print a MOTD whenever a terminal session
is invoked.

## Source Code

```
#!/usr/bin/env sh
# @file MOTD
# @brief Incorporates the MOTD functionality that is leveraged by the `~/.bashrc` and `~/.zshrc` files
# @description
#     This script is included by `~/.bashrc` and `~/.zshrc` to print a MOTD whenever a terminal session
#     is invoked.

### MOTD
# Add file named .hushlogin in the user's home directory to disable the MOTD
if [ "$BASH_SUPPORT" = 'true' ] && [ ! -f ~/.hushlogin ] && [ "$SHLVL" -eq 1 ]; then
  if [ -f "${XDG_CONFIG_HOME:-$HOME/.config/shell/bash/motd.bash" ] && { [ -n "$SSH_CONNECTION" ] && [[ $- == *i* ]]; } || command -v qubes-vmexec > /dev/null || command -v qubes-dom0-update > /dev/null || { [ -d /Applications ] && [ -d /System ]; }; then
    if { [ -z "$MOTD" ] || [ "$MOTD" -ne 0 ]; } && [[ "$(hostname)" != *'-minimal' ]]; then
      . "${XDG_CONFIG_HOME:-$HOME/.config/shell/bash/motd.bash"
      # TODO - -- services
      if [ -n "$SSH_CONNECTION" ]; then
        # SSH
        bash_motd --banner --processor --memory --diskspace --docker --updates --letsencrypt --login
      elif command -v qubes-vmexec > /dev/null; then
        # Qubes AppVM
        bash_motd --banner --memory --diskspace --docker --updates
      elif command -v qubes-dom0-update > /dev/null; then
        # Qubes dom0
        bash_motd --banner --updates
      elif [ -d /Applications ] && [ -d /System ]; then
        # macOS
        bash_motd --banner
      else
        bash_motd --banner --processor --memory --diskspace --docker --updates --letsencrypt --login
      fi
    fi
  fi
fi
```
