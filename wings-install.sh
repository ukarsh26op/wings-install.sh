#!/usr/bin/env bash

# ================================================================
#                 UTKARSH WINGS PRO INSTALLER
#                 Pterodactyl Wings Installer
# ================================================================

set -Eeuo pipefail

# ------------------------------------------------
# COLORS
# ------------------------------------------------
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

CYAN='\033[38;5;51m'
BLUE='\033[38;5;39m'
PURPLE='\033[38;5;141m'
GREEN='\033[38;5;82m'
YELLOW='\033[38;5;226m'
RED='\033[38;5;196m'
WHITE='\033[97m'
GRAY='\033[90m'

# ------------------------------------------------
# TERMINAL HELPERS
# ------------------------------------------------

clear_screen() {
    printf '\033c'
}

line() {
    printf "${CYAN}════════════════════════════════════════════════════════════════════${RESET}\n"
}

section() {
    echo
    printf "${PURPLE}╭──────────────────────────────────────────────────────────────╮${RESET}\n"
    printf "${PURPLE}│${RESET}  ${BOLD}${WHITE}%-58s${RESET}${PURPLE}│${RESET}\n" "$1"
    printf "${PURPLE}╰──────────────────────────────────────────────────────────────╯${RESET}\n"
    echo
}

ok() {
    printf "      ${GREEN}✔${RESET} %s\n" "$1"
}

info() {
    printf "      ${CYAN}➜${RESET} %s\n" "$1"
}

warn() {
    printf "      ${YELLOW}⚠${RESET} %s\n" "$1"
}

fail() {
    printf "      ${RED}✖${RESET} %s\n" "$1"
}

sleep_small() {
    sleep 0.4
}

spinner() {
    local pid="$1"
    local text="$2"
    local spin='|/-\'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % 4 ))
        printf "\r      ${CYAN}%s${RESET} %s" "${spin:$i:1}" "$text"
        sleep 0.15
    done

    printf "\r\033[K"
}

run_step() {
    local text="$1"
    shift

    "$@" >/tmp/utkarsh_wings_step.log 2>&1 &
    local pid=$!

    spinner "$pid" "$text"

    if wait "$pid"; then
        ok "$text"
    else
        fail "$text"
        echo
        cat /tmp/utkarsh_wings_step.log
        echo
        exit 1
    fi
}

# ------------------------------------------------
# ERROR HANDLER
# ------------------------------------------------

error_handler() {
    local exit_code=$?
    echo
    printf "${RED}╔══════════════════════════════════════════════════════════════════╗${RESET}\n"
    printf "${RED}║${RESET}  ${BOLD}UTKARSH WINGS INSTALLER ENCOUNTERED AN ERROR${RESET}             ${RED}║${RESET}\n"
    printf "${RED}╚══════════════════════════════════════════════════════════════════╝${RESET}\n"
    echo
    printf "      ${RED}Exit code:${RESET} %s\n" "$exit_code"
    printf "      ${YELLOW}Check the output above for the exact problem.${RESET}\n"
    echo
    exit "$exit_code"
}

trap error_handler ERR

# ------------------------------------------------
# ROOT CHECK
# ------------------------------------------------

if [[ "${EUID}" -ne 0 ]]; then
    echo
    printf "${RED}✖ This installer must be run as root.${RESET}\n"
    echo
    printf "Try:\n"
    printf "  ${CYAN}sudo bash wings-install.sh${RESET}\n"
    echo
    exit 1
fi

# ------------------------------------------------
# LOGO
# ------------------------------------------------

clear_screen

printf "${CYAN}${BOLD}"
cat <<'EOF'

╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║  ██╗   ██╗████████╗██╗  ██╗ █████╗ ██████╗ ███████╗██╗  ██╗   ║
║  ██║   ██║╚══██╔══╝██║ ██╔╝██╔══██╗██╔══██╗██╔════╝██║  ██║   ║
║  ██║   ██║   ██║   █████╔╝ ███████║██████╔╝███████╗███████║   ║
║  ██║   ██║   ██║   ██╔═██╗ ██╔══██║██╔══██╗╚════██║██╔══██║   ║
║  ╚██████╔╝   ██║   ██║  ██╗██║  ██║██║  ██║███████║██║  ██║   ║
║   ╚═════╝    ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ║
║                                                                  ║
║                    W I N G S   P R O                             ║
║                      I N S T A L L E R                           ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

EOF
printf "${RESET}"

printf "${PURPLE}${BOLD}"
echo "                    ✦ U T K A R S H ✦"
printf "${RESET}"

printf "${CYAN}"
echo
echo "              PTERODACTYL WINGS INSTALLER"
echo
printf "${GRAY}        Automated Wings deployment for Pterodactyl 1.x${RESET}"
echo
echo

printf "${GREEN}      ✔${RESET} Initializing installer\n"
sleep_small
printf "${GREEN}      ✔${RESET} Preparing installation environment\n"

# ------------------------------------------------
# SYSTEM CHECK
# ------------------------------------------------

section "01 • SYSTEM CHECK"

info "Detecting operating system..."

if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS_NAME="${PRETTY_NAME:-Unknown}"
else
    OS_NAME="Unknown"
fi

echo "      Operating System: ${WHITE}${OS_NAME}${RESET}"

case "${ID:-}" in
    ubuntu|debian)
        ok "Supported Linux distribution detected."
        ;;
    *)
        warn "This OS is not one of the officially documented targets."
        warn "The installer will continue, but compatibility is not guaranteed."
        ;;
esac

info "Checking CPU architecture..."

ARCH="$(uname -m)"

case "$ARCH" in
    x86_64)
        WINGS_ARCH="amd64"
        ok "Architecture: x86_64 / amd64"
        ;;
    aarch64|arm64)
        WINGS_ARCH="arm64"
        ok "Architecture: ARM64"
        ;;
    *)
        fail "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

info "Checking systemd..."

if command -v systemctl >/dev/null 2>&1; then
    ok "systemd detected."
else
    fail "systemd is required for this installer."
    exit 1
fi

info "Checking virtualization..."

if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT="$(systemd-detect-virt || true)"

    if [[ "$VIRT" == "openvz" || "$VIRT" == "lxc" ]]; then
        warn "Detected virtualization: $VIRT"
        warn "Docker/Wings may not work correctly on this host."
    else
        ok "Virtualization: ${VIRT:-none}"
    fi
fi

# ------------------------------------------------
# NODE CONFIGURATION
# ------------------------------------------------

section "02 • NODE CONFIGURATION"

printf "${YELLOW}"
echo "      IMPORTANT"
printf "${RESET}"
echo
echo "      Create your node in:"
echo
printf "      ${CYAN}Admin Panel → Nodes → Your Node → Configuration${RESET}"
echo
echo "      Then use the Panel's:"
echo
printf "      ${GREEN}Generate Token${RESET}"
echo
echo "      Copy the complete command shown by your Panel."
echo
printf "${GRAY}      This is safer than manually guessing the Wings config.${RESET}"
echo

printf "${CYAN}      ➜ Paste the Generate Token command below:${RESET}\n"
printf "${GRAY}      (The command should contain 'wings configure'.)${RESET}\n\n"

printf "      ${WHITE}> ${RESET}"
read -r WINGS_COMMAND

if [[ -z "${WINGS_COMMAND}" ]]; then
    fail "No command was entered."
    exit 1
fi

if [[ "$WINGS_COMMAND" != *"wings configure"* ]]; then
    echo
    warn "The command does not appear to contain 'wings configure'."
    echo
    printf "      You should normally paste the command generated by:\n"
    printf "      ${CYAN}Admin Panel → Nodes → Configuration → Generate Token${RESET}\n"
    echo
    printf "      Continue anyway? [y/N]: "
    read -r CONTINUE

    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        echo
        info "Installation cancelled."
        exit 0
    fi
fi

# ------------------------------------------------
# DEPENDENCIES
# ------------------------------------------------

section "03 • DEPENDENCIES"

info "Checking curl..."

if command -v curl >/dev/null 2>&1; then
    ok "curl is already installed."
else
    warn "curl is missing."
    run_step "Installing curl..." apt-get update -y
    run_step "Installing curl package..." apt-get install -y curl
fi

info "Checking Docker..."

if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION="$(docker --version 2>/dev/null || true)"
    ok "Docker detected: ${DOCKER_VERSION}"
else
    warn "Docker is not installed."
    echo
    info "Installing Docker CE..."
    echo

    curl -fsSL https://get.docker.com | CHANNEL=stable bash

    ok "Docker installation completed."
fi

info "Starting Docker..."

systemctl enable --now docker

if systemctl is-active --quiet docker; then
    ok "Docker is running."
else
    fail "Docker failed to start."
    systemctl status docker --no-pager || true
    exit 1
fi

# ------------------------------------------------
# WINGS DIRECTORIES
# ------------------------------------------------

section "04 • WINGS INSTALLATION"

info "Creating Pterodactyl directories..."

mkdir -p /etc/pterodactyl
mkdir -p /var/lib/pterodactyl
mkdir -p /var/log/pterodactyl
mkdir -p /var/run/wings

ok "/etc/pterodactyl created."
ok "/var/lib/pterodactyl created."
ok "/var/log/pterodactyl created."

# ------------------------------------------------
# DOWNLOAD WINGS
# ------------------------------------------------

info "Downloading official Pterodactyl Wings binary..."

WINGS_URL="https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${WINGS_ARCH}"

TMP_WINGS="/tmp/wings"

curl -fL "$WINGS_URL" -o "$TMP_WINGS"

if [[ ! -s "$TMP_WINGS" ]]; then
    fail "Wings binary download failed."
    exit 1
fi

install -m 755 "$TMP_WINGS" /usr/local/bin/wings

rm -f "$TMP_WINGS"

ok "Wings binary installed."

# ------------------------------------------------
# VERIFY WINGS
# ------------------------------------------------

info "Verifying Wings binary..."

if /usr/local/bin/wings version >/tmp/wings-version.txt 2>&1; then
    WINGS_VERSION="$(head -n 1 /tmp/wings-version.txt || true)"
    ok "Wings binary is working."
    [[ -n "$WINGS_VERSION" ]] && echo "      ${GRAY}${WINGS_VERSION}${RESET}"
else
    warn "Could not display Wings version, but the binary was installed."
fi

# ------------------------------------------------
# APPLY PANEL CONFIGURATION
# ------------------------------------------------

section "05 • NODE CONFIGURATION"

echo
printf "${CYAN}      Executing the Panel-generated configuration command...${RESET}\n"
echo

# ------------------------------------------------
# SAFELY NORMALIZE COMMAND
# ------------------------------------------------

# The expected command is generated by Pterodactyl and normally resembles:
#
# cd /etc/pterodactyl && sudo wings configure --panel-url ... --token ...
#
# We remove "sudo" because the installer is already running as root.

WINGS_COMMAND="${WINGS_COMMAND//sudo /}"

# Remove common "cd /etc/pterodactyl &&" prefix.
WINGS_COMMAND="${WINGS_COMMAND#cd /etc/pterodactyl && }"

# Some panels may include:
# ./wings configure
# Replace it with the installed binary.
WINGS_COMMAND="${WINGS_COMMAND//\.\/wings /usr/local/bin/wings }"

# If the command starts with "wings configure", use installed binary.
WINGS_COMMAND="${WINGS_COMMAND/#wings /\/usr\/local\/bin\/wings }"

cd /etc/pterodactyl

printf "      ${GRAY}Running configuration command...${RESET}\n"

if ! bash -c "$WINGS_COMMAND"; then
    echo
    fail "Wings configuration command failed."
    echo
    printf "${YELLOW}The command must come directly from your Panel's${RESET}\n"
    printf "${YELLOW}Node → Configuration → Generate Token section.${RESET}\n"
    echo
    exit 1
fi

echo
ok "Wings configuration generated successfully."

# ------------------------------------------------
# CONFIG CHECK
# ------------------------------------------------

if [[ ! -f /etc/pterodactyl/config.yml ]]; then
    echo
    fail "/etc/pterodactyl/config.yml was not created."
    echo
    warn "The Panel-generated command may not have completed correctly."
    exit 1
fi

ok "config.yml detected."

# ------------------------------------------------
# SYSTEMD SERVICE
# ------------------------------------------------

section "06 • SYSTEM SERVICE"

info "Creating Wings systemd service..."

cat > /etc/systemd/system/wings.service <<'EOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

ok "wings.service created."

info "Reloading systemd..."

systemctl daemon-reload

ok "systemd reloaded."

# ------------------------------------------------
# TEST CONFIGURATION
# ------------------------------------------------

section "07 • CONFIGURATION TEST"

info "Testing Wings configuration..."

if /usr/local/bin/wings --help >/dev/null 2>&1; then
    ok "Wings executable test passed."
else
    warn "Wings executable test returned an unexpected result."
fi

info "Checking generated configuration..."

if [[ -s /etc/pterodactyl/config.yml ]]; then
    ok "config.yml is present and not empty."
else
    fail "config.yml is empty."
    exit 1
fi

# ------------------------------------------------
# START WINGS
# ------------------------------------------------

section "08 • STARTING WINGS"

info "Enabling Wings at boot..."

systemctl enable wings

ok "Wings enabled at boot."

info "Starting Wings..."

if systemctl restart wings; then
    sleep 3
    ok "Wings start command completed."
else
    fail "Wings failed to start."
    echo
    systemctl status wings --no-pager -l || true
    echo
    exit 1
fi

# ------------------------------------------------
# STATUS
# ------------------------------------------------

section "09 • FINAL STATUS"

if systemctl is-active --quiet wings; then

    printf "${GREEN}${BOLD}"
    cat <<'EOF'

╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║                    ✓  WINGS IS ONLINE  ✓                         ║
║                                                                  ║
║              UTKARSH WINGS PRO INSTALLER                        ║
║                                                                  ║
║                Installation completed!                          ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

EOF
    printf "${RESET}"

    echo
    printf "${CYAN}${BOLD}Useful commands${RESET}\n"
    echo
    printf "  ${WHITE}Status:${RESET}       systemctl status wings\n"
    printf "  ${WHITE}Restart:${RESET}      systemctl restart wings\n"
    printf "  ${WHITE}Stop:${RESET}         systemctl stop wings\n"
    printf "  ${WHITE}Start:${RESET}        systemctl start wings\n"
    printf "  ${WHITE}Logs:${RESET}         journalctl -u wings -f\n"
    printf "  ${WHITE}Debug:${RESET}        wings --debug\n"
    printf "  ${WHITE}Config:${RESET}       /etc/pterodactyl/config.yml\n"
    echo

    line

    printf "${GREEN}${BOLD}"
    echo "                 ✦ U T K A R S H ✦"
    printf "${RESET}"

    echo
    printf "${GRAY}          Pterodactyl Wings deployment complete.${RESET}\n"
    echo

else

    printf "${RED}${BOLD}"
    cat <<'EOF'

╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║                    ✖  WINGS FAILED  ✖                            ║
║                                                                  ║
║              The service did not stay online.                   ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

EOF
    printf "${RESET}"

    echo
    printf "${YELLOW}Run this command to see the exact error:${RESET}\n"
    echo
    printf "    ${CYAN}journalctl -u wings -n 100 --no-pager${RESET}\n"
    echo

    systemctl status wings --no-pager -l || true

    exit 1
fi

rm -f /tmp/utkarsh_wings_step.log
rm -f /tmp/wings-version.txt

exit 0
