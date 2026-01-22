#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.plex.tv/

APP="Plex"
var_tags="${var_tags:-media}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-ubuntu}"
var_version="${var_version:-24.04}"
var_unprivileged="${var_unprivileged:-1}"
var_gpu="${var_gpu:-yes}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -f /etc/apt/sources.list.d/plexmediaserver.list ]] &&
    [[ ! -f /etc/apt/sources.list.d/plexmediaserver.sources ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  UPD=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "SUPPORT" --radiolist --cancel-button Exit-Script "Spacebar = Select \nplexupdate info >> https://github.com/mrworf/plexupdate" 10 59 3 \
    "1" "Update LXC" ON \
    "2" "Install plexupdate" OFF \
    "3" "Update Plugins (Hama + ASS)" OFF \
    3>&1 1>&2 2>&3)
  if [ "$UPD" == "1" ]; then
    msg_info "Updating ${APP} LXC"
    $STD apt update
    $STD apt -y upgrade
    msg_ok "Updated ${APP} LXC"
    msg_ok "Updated successfully!"
    exit
  fi
  if [ "$UPD" == "2" ]; then
    set +e
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/mrworf/plexupdate/master/extras/installer.sh)"
    msg_ok "Updated successfully!"
    exit
  fi
  if [ "$UPD" == "3" ]; then
    msg_info "Updating Plex Plugin (Hama) and Scanner (Absolute Series Scanner)"
    if ! command -v git &> /dev/null; then
      $STD apt update
      $STD apt install -y git
    fi

    # Install libxslt if not already installed
    if ! dpkg -l | grep -q libxslt1.1; then
      $STD apt update
      $STD apt install -y libxslt1.1 python3-lxml
    fi

    # Update Hama.bundle plugin
    PLUGINS_DIR="/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Plug-ins"
    mkdir -p "$PLUGINS_DIR"

    if [ ! -d "$PLUGINS_DIR/Hama.bundle" ]; then
      git clone https://github.com/memearchivarius/Hama.bundle.git "$PLUGINS_DIR/Hama.bundle"
    else
      git config --global --add safe.directory "$PLUGINS_DIR/Hama.bundle" 2>/dev/null || true
      git -C "$PLUGINS_DIR/Hama.bundle" pull || {
        rm -rf "$PLUGINS_DIR/Hama.bundle"
        git clone https://github.com/memearchivarius/Hama.bundle.git "$PLUGINS_DIR/Hama.bundle"
      }
    fi

    chown -R plex:plex "$PLUGINS_DIR"

    # Update Absolute Series Scanner (scanner, not a plugin)
    SCANNERS_DIR="/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Scanners/Series"
    mkdir -p "$SCANNERS_DIR"
    SCANNER_FILE="$SCANNERS_DIR/Absolute Series Scanner.py"

    curl -fsSL "https://raw.githubusercontent.com/ZeroQI/Absolute-Series-Scanner/master/Scanners/Series/Absolute%20Series%20Scanner.py" -o "$SCANNER_FILE"
    chmod +x "$SCANNER_FILE"
    chown -R plex:plex "/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Scanners"

    systemctl restart plexmediaserver
    msg_ok "Updated Plex Plugin and Scanner successfully!"
    exit
  fi
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:32400/web${CL}"
