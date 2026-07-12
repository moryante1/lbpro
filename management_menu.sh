#!/bin/bash

LOG_FILE="/var/log/shahsty.log"
HASH='$2a$12$/e7uq6qW4UOkVYYIY/LOje396Elb/k1fyzfxIA6JxlPu1h1GUStPa'

# ═══════════════════════════════════════════════
#   SHAHSTY PRO v2.0 — Netflix-Style Console
#   Professional IPTV & Licensing Platform
# ═══════════════════════════════════════════════

# ── Colors & Styles (tput) ──────────────────────
if tput colors &>/dev/null; then
    BOLD=$(tput bold)
    DIM=$(tput dim)
    RESET=$(tput sgr0)
    GREEN=$(tput setaf 2)
    RED=$(tput setaf 1)
    CYAN=$(tput setaf 6)
    YELLOW=$(tput setaf 3)
    WHITE=$(tput setaf 7)
    BG_BLACK=$(tput setab 0)
    BG_GREEN=$(tput setab 2)
    BG_RED=$(tput setab 1)
else
    BOLD="" DIM="" RESET="" GREEN="" RED="" CYAN="" YELLOW="" WHITE="" BG_BLACK="" BG_GREEN="" BG_RED=""
fi

# ── Logging ─────────────────────────────────────
log_action() {
    local level="${2:-INFO}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $1" >> "$LOG_FILE"
}

# ── Splash Screen ───────────────────────────────
show_splash() {
    clear
    echo ""
    echo "${BOLD}${GREEN}"
    echo "  ███████╗██╗  ██╗ █████╗ ██╗  ██╗███████╗████████╗██╗   ██╗"
    echo "  ██╔════╝██║  ██║██╔══██╗██║  ██║██╔════╝╚══██╔══╝╚██╗ ██╔╝"
    echo "  ███████╗███████║███████║███████║███████╗   ██║    ╚████╔╝ "
    echo "  ╚════██║██╔══██║██╔══██║██╔══██║╚════██║   ██║     ╚██╔╝  "
    echo "  ███████║██║  ██║██║  ██║██║  ██║███████║   ██║      ██║   "
    echo "  ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝      ╚═╝  "
    echo "${RESET}${CYAN}"
    echo "                  ██████╗ ██████╗  ██████╗ "
    echo "                  ██╔══██╗██╔══██╗██╔═══██╗"
    echo "                  ██████╔╝██████╔╝██║   ██║"
    echo "                  ██╔═══╝ ██╔══██╗██║   ██║"
    echo "                  ██║     ██║  ██║╚██████╔╝"
    echo "                  ╚═╝     ╚═╝  ╚═╝ ╚═════╝ "
    echo "${RESET}"
    echo "${DIM}${WHITE}              IPTV & Software Licensing Platform${RESET}"
    echo "${DIM}${GREEN}                       v2.0  •  $(date '+%Y')${RESET}"
    echo ""
    echo "${DIM}${WHITE}  ──────────────────────────────────────────────────${RESET}"
    printf  "  ${CYAN}Hostname:${RESET} %-20s ${CYAN}IP:${RESET} %s\n" \
        "$(hostname)" "$(ip -4 addr show scope global 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1 || echo 'N/A')"
    printf  "  ${CYAN}Timezone:${RESET} %-20s ${CYAN}Up:${RESET} %s\n" \
        "$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null)" \
        "$(uptime -p 2>/dev/null || uptime | awk '{print $3,$4}' | tr -d ',')"
    echo "${DIM}${WHITE}  ──────────────────────────────────────────────────${RESET}"
    echo ""
    sleep 1
}

# ── Password Check ──────────────────────────────
check_exit_password() {
    PASS=$(whiptail \
        --title "🔐 Authentication Required" \
        --passwordbox "\nThis action requires your exit password.\n\nEnter password:" \
        12 55 3>&1 1>&2 2>&3) || return 1

    if python3 -c "import crypt; print(crypt.crypt('$PASS', '$HASH') == '$HASH')" 2>/dev/null | grep -q True; then
        clear
        echo "${GREEN}${BOLD}✔ Authenticated. Goodbye.${RESET}"
        log_action "Console exited via authentication" "INFO"
        sleep 1
        exit 0
    else
        whiptail --title "✗ Access Denied" \
            --msgbox "\n  ✗  Incorrect password.\n\n  Access denied." \
            10 38
    fi
}

trap 'check_exit_password' SIGINT
trap '' SIGQUIT SIGTSTP

# ── Interface Selector ──────────────────────────
select_interface() {
    local INTERFACES
    INTERFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)

    local MENU_ITEMS=()
    local idx=1
    for iface in $INTERFACES; do
        local STATUS
        STATUS=$(ip link show "$iface" | grep -oP '(?<=state )\w+')
        local IP
        IP=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1 || echo "no ip")
        MENU_ITEMS+=("$iface" "[$STATUS]  $IP")
        ((idx++))
    done

    whiptail --title "🌐 Select Interface" \
        --menu "\nChoose the network interface to configure:\n" \
        18 60 8 \
        "${MENU_ITEMS[@]}" \
        3>&1 1>&2 2>&3
}

# ── IP Validator ────────────────────────────────
validate_ip() {
    echo "$1" | grep -qE '^[0-9]{1,3}(\.[0-9]{1,3}){3}'
}

# ── Netplan Cleanup ─────────────────────────────
cleanup_netplan() {
    [ -d /etc/cloud ] && touch /etc/cloud/cloud-init.disabled
    rm -f /etc/netplan/*.yaml
    log_action "Netplan configs wiped, cloud-init disabled" "INFO"
}

# ── Progress Bar ────────────────────────────────
show_progress() {
    local title="$1"
    local msg="$2"
    {
        for i in 20 40 55 70 85 100; do
            echo "$i"
            sleep 0.2
        done
    } | whiptail --title "$title" --gauge "\n$msg\n" 10 55 0
}

# ── Static IP ───────────────────────────────────
apply_static_ip() {
    local IFACE
    IFACE=$(select_interface) || return
    [ -z "$IFACE" ] && return

    IP_ADDR=$(whiptail \
        --title "📌 Static IP — $IFACE" \
        --inputbox "\nEnter IP address with CIDR prefix:\n\n  Example:  192.168.1.100/24" \
        13 55 3>&1 1>&2 2>&3) || return

    GATEWAY=$(whiptail \
        --title "📌 Static IP — Gateway" \
        --inputbox "\nEnter default gateway IP:\n\n  Example:  192.168.1.1" \
        13 55 3>&1 1>&2 2>&3) || return

    DNS=$(whiptail \
        --title "📌 Static IP — DNS" \
        --inputbox "\nEnter DNS servers (space-separated):\n\n  Example:  8.8.8.8 1.1.1.1" \
        13 55 "8.8.8.8 1.1.1.1" 3>&1 1>&2 2>&3) || return

    validate_ip "$IP_ADDR" || { whiptail --title "✗ Error" --msgbox "\n  Invalid IP address format.\n\n  Please use CIDR notation: x.x.x.x/prefix" 11 50; return; }
    validate_ip "$GATEWAY" || { whiptail --title "✗ Error" --msgbox "\n  Invalid gateway IP format." 9 44; return; }

    DNS_FORMATTED=$(echo "$DNS" | sed 's/ /, /g')

    # Confirm
    whiptail --title "⚡ Confirm — Apply Static IP" \
        --yesno "\n  Interface : $IFACE\n  IP Address: $IP_ADDR\n  Gateway   : $GATEWAY\n  DNS       : $DNS\n\n  ⚠  Existing netplan configs will be removed.\n\n  Apply these settings?" \
        16 58 || return

    show_progress "Applying Static IP" "Configuring $IFACE..."

    cleanup_netplan

    local NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
    cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      dhcp4: no
      dhcp6: no
      addresses: [$IP_ADDR]
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$DNS_FORMATTED]
EOF

    chmod 600 "$NETPLAN_FILE"
    netplan generate 2>/dev/null
    netplan apply 2>/dev/null

    log_action "Static IP $IP_ADDR applied on $IFACE" "SUCCESS"

    whiptail --title "✔ Success" \
        --msgbox "\n  ✔  Static IP applied successfully!\n\n  Interface : $IFACE\n  IP Address: $IP_ADDR\n  Gateway   : $GATEWAY\n  DNS       : $DNS" \
        15 52
}

# ── DHCP ────────────────────────────────────────
apply_dhcp() {
    local IFACE
    IFACE=$(select_interface) || return
    [ -z "$IFACE" ] && return

    whiptail --title "🔄 Enable DHCP — $IFACE" \
        --yesno "\n  Switch $IFACE to DHCP mode?\n\n  ⚠  Existing netplan configs will be removed.\n  The interface will request a new IP automatically.\n\n  Continue?" \
        14 58 || return

    show_progress "Enabling DHCP" "Configuring $IFACE for DHCP..."

    cleanup_netplan

    local NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
    cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      dhcp4: yes
      dhcp6: yes
EOF

    chmod 600 "$NETPLAN_FILE"
    netplan generate 2>/dev/null
    netplan apply 2>/dev/null

    log_action "DHCP enabled on $IFACE" "SUCCESS"

    whiptail --title "✔ DHCP Enabled" \
        --msgbox "\n  ✔  DHCP enabled on $IFACE\n\n  The interface will request an IP from your\n  DHCP server automatically." \
        12 54
}

# ── Network Status ──────────────────────────────
show_status() {
    local INFO=""
    INFO+="  INTERFACES\n"
    INFO+="  ══════════════════════════════════════\n"

    while IFS= read -r iface; do
        local STATE IP MAC
        STATE=$(ip link show "$iface" | grep -oP '(?<=state )\w+')
        IP=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -1 || echo "—")
        MAC=$(ip link show "$iface" | grep -oP '(?<=link/ether )\S+' | head -1 || echo "—")
        INFO+="  $iface   [$STATE]\n"
        INFO+="    IPv4 : $IP\n"
        INFO+="    MAC  : $MAC\n\n"
    done < <(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)

    INFO+="  ROUTING TABLE\n"
    INFO+="  ══════════════════════════════════════\n"
    while IFS= read -r route; do
        INFO+="  $route\n"
    done < <(ip route 2>/dev/null)

    INFO+="\n  DNS SERVERS\n"
    INFO+="  ══════════════════════════════════════\n"
    if [ -f /etc/resolv.conf ]; then
        while IFS= read -r line; do
            [[ "$line" =~ ^nameserver ]] && INFO+="  $line\n"
        done < /etc/resolv.conf
    fi

    whiptail --title "📊 Network Status — $(hostname)" \
        --scrolltext \
        --msgbox "$(echo -e "$INFO")" \
        28 64
}

# ── Change Hostname ─────────────────────────────
change_hostname() {
    local CURRENT_HOSTNAME
    CURRENT_HOSTNAME=$(hostname)

    local NEW_HOSTNAME
    NEW_HOSTNAME=$(whiptail \
        --title "🏷  Change Hostname" \
        --inputbox "\n  Current hostname: ${CURRENT_HOSTNAME}\n\n  Enter new hostname:\n  (letters, numbers, hyphens only)" \
        14 58 "$CURRENT_HOSTNAME" 3>&1 1>&2 2>&3) || return

    [ -z "$NEW_HOSTNAME" ] && { whiptail --title "✗ Error" --msgbox "\n  Hostname cannot be empty." 9 40; return; }

    if ! echo "$NEW_HOSTNAME" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$|^[a-zA-Z0-9]$'; then
        whiptail --title "✗ Invalid Hostname" \
            --msgbox "\n  Invalid hostname format.\n\n  Rules:\n   • Letters, numbers, and hyphens only\n   • Must start and end with letter/number\n   • No spaces or special characters" \
            14 50
        return
    fi

    whiptail --title "⚡ Confirm Hostname Change" \
        --yesno "\n  Old hostname : $CURRENT_HOSTNAME\n  New hostname : $NEW_HOSTNAME\n\n  This will update:\n   • /etc/hostname\n   • /etc/hosts (127.0.1.1 entry)\n\n  Apply change?" \
        15 52 || return

    show_progress "Changing Hostname" "Updating system hostname..."

    hostnamectl set-hostname "$NEW_HOSTNAME"
    echo "$NEW_HOSTNAME" > /etc/hostname

    if grep -q "127.0.1.1" /etc/hosts; then
        sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
    else
        echo -e "127.0.1.1\t$NEW_HOSTNAME" >> /etc/hosts
    fi

    log_action "Hostname changed: '$CURRENT_HOSTNAME' → '$NEW_HOSTNAME'" "SUCCESS"

    whiptail --title "✔ Hostname Changed" \
        --msgbox "\n  ✔  Hostname changed successfully!\n\n  Old : $CURRENT_HOSTNAME\n  New : $NEW_HOSTNAME\n\n  Changes saved permanently." \
        13 50
}

# ── Change Timezone ─────────────────────────────
change_timezone() {
    local CURRENT_TZ
    CURRENT_TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "Unknown")

    local REGIONS
    REGIONS=$(timedatectl list-timezones 2>/dev/null | awk -F'/' '{print $1}' | sort -u)

    local REGION_ITEMS=()
    while IFS= read -r region; do
        local count
        count=$(timedatectl list-timezones 2>/dev/null | grep -c "^${region}/")
        REGION_ITEMS+=("$region" "($count zones)")
    done <<< "$REGIONS"

    local REGION
    REGION=$(whiptail \
        --title "🌍 Change Timezone — Step 1 of 2" \
        --menu "\n  Current timezone: $CURRENT_TZ\n\n  Select region:" \
        24 56 12 \
        "${REGION_ITEMS[@]}" \
        3>&1 1>&2 2>&3) || return

    [ -z "$REGION" ] && return

    local TZ_ITEMS=()
    while IFS= read -r tz; do
        local city="${tz#*/}"
        TZ_ITEMS+=("$tz" "$city")
    done < <(timedatectl list-timezones 2>/dev/null | grep "^${REGION}/")

    if [ ${#TZ_ITEMS[@]} -eq 0 ]; then
        whiptail --title "✗ Error" --msgbox "\n  No timezones found for: $REGION" 9 44
        return
    fi

    local SELECTED_TZ
    SELECTED_TZ=$(whiptail \
        --title "🌍 Change Timezone — Step 2 of 2" \
        --menu "\n  Region: $REGION\n\n  Select city / timezone:" \
        24 60 14 \
        "${TZ_ITEMS[@]}" \
        3>&1 1>&2 2>&3) || return

    [ -z "$SELECTED_TZ" ] && return

    show_progress "Setting Timezone" "Applying $SELECTED_TZ..."

    timedatectl set-timezone "$SELECTED_TZ"
    ln -sf "/usr/share/zoneinfo/$SELECTED_TZ" /etc/localtime
    echo "$SELECTED_TZ" > /etc/timezone

    local NEW_TIME
    NEW_TIME=$(date '+%A, %d %B %Y  %H:%M:%S')

    log_action "Timezone changed: '$CURRENT_TZ' → '$SELECTED_TZ'" "SUCCESS"

    whiptail --title "✔ Timezone Updated" \
        --msgbox "\n  ✔  Timezone changed successfully!\n\n  Old : $CURRENT_TZ\n  New : $SELECTED_TZ\n\n  Local time: $NEW_TIME" \
        13 60
}

# ── View Log ────────────────────────────────────
view_log() {
    local LOG_CONTENT
    if [ -f "$LOG_FILE" ]; then
        LOG_CONTENT=$(tail -50 "$LOG_FILE" | tac)
    else
        LOG_CONTENT="  No log entries yet."
    fi

    whiptail --title "📋 System Log — Last 50 Entries" \
        --scrolltext \
        --msgbox "$LOG_CONTENT" \
        28 72
}

# ── Reboot / Shutdown ───────────────────────────
confirm_reboot() {
    whiptail --title "⚡ Confirm Reboot" \
        --yesno "\n  Are you sure you want to REBOOT?\n\n  The server will restart immediately.\n  All active sessions will be terminated." \
        12 52 || return

    log_action "System reboot initiated by console" "WARNING"
    show_progress "Rebooting" "Saving state and rebooting..."
    reboot
}

confirm_shutdown() {
    whiptail --title "⚡ Confirm Shutdown" \
        --yesno "\n  Are you sure you want to SHUT DOWN?\n\n  The server will power off immediately.\n  This cannot be undone remotely." \
        12 52 || return

    log_action "System shutdown initiated by console" "WARNING"
    show_progress "Shutting Down" "Stopping services..."
    shutdown -h now
}

# ── Main Menu ───────────────────────────────────
main_menu() {
    local HOSTNAME_INFO
    HOSTNAME_INFO=$(hostname)
    local IP_INFO
    IP_INFO=$(ip -4 addr show scope global 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1 || echo "—")
    local TZ_INFO
    TZ_INFO=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "—")
    local TIME_INFO
    TIME_INFO=$(date '+%H:%M:%S')

    CHOICE=$(whiptail \
        --title "  SHAHSTY PRO  |  $HOSTNAME_INFO  |  $IP_INFO  |  $TIME_INFO" \
        --menu "\n  ┌─ System Info ────────────────────────────┐\n  │  Host: $HOSTNAME_INFO   •   TZ: $TZ_INFO\n  └──────────────────────────────────────────┘\n\n  Select an option:\n" \
        24 66 9 \
        "1" "  🌐  Set Static IP          (Clean Mode)" \
        "2" "  🔄  Enable DHCP            (Clean Mode)" \
        "3" "  📊  Show Network Status" \
        "4" "  🏷   Change Hostname" \
        "5" "  🌍  Change Timezone" \
        "6" "  📋  View System Log" \
        "7" "  ♻   Reboot System" \
        "8" "  ⏻   Shutdown System" \
        "9" "  🔐  Exit Console" \
        3>&1 1>&2 2>&3)

    [ $? -ne 0 ] && check_exit_password && return

    case $CHOICE in
        1) apply_static_ip ;;
        2) apply_dhcp ;;
        3) show_status ;;
        4) change_hostname ;;
        5) change_timezone ;;
        6) view_log ;;
        7) confirm_reboot ;;
        8) confirm_shutdown ;;
        9) check_exit_password ;;
    esac
}

# ── Entry Point ─────────────────────────────────
show_splash

log_action "Console session started on $(hostname)" "INFO"

while true; do
    main_menu
done
