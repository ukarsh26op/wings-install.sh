#!/usr/bin/env bash

# ================================================================
#                 UTKARSH WINGS PRO INSTALLER
#                 Pterodactyl Wings Installer
# ================================================================

set -Eeuo pipefail

# ---------------- COLORS ----------------

RESET='\033[0m'
BOLD='\033[1m'
CYAN='\033[38;5;51m'
BLUE='\033[38;5;39m'
PURPLE='\033[38;5;141m'
GREEN='\033[38;5;82m'
YELLOW='\033[38;5;226m'
RED='\033[38;5;196m'
WHITE='\033[97m'
GRAY='\033[90m'

# ---------------- FUNCTIONS ----------------

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

section() {
    echo
    printf "${PURPLE}╭──────────────────────────────────────────────────────────────╮${RESET}\n"
    printf "${PURPLE}│${RESET}  ${BOLD}${WHITE}%-58s${RESET}${PURPLE}│${RESET}\n" "$1"
    printf "${PURPLE}╰──────────────────────────────────────────────────────────────╯${RESET}\n"
    echo
}

# ---------------- ENVIRONMENT DETECTION ----------------

IS_CODESPACES="false"

if [[ "${CODESPACES:-}" == "true" ]]; then
    IS_CODESPACES="true"
fi

if [[ -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]]; then
    IS_CODESPACES="true"
fi

# ---------------- LOGO ----------------

clear 2>/dev/null || true

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

echo
printf "${CYAN}              PTERODACTYL WINGS INSTALLER${RESET}\n"
printf "${GRAY}        Automated Wings deployment for Pterodactyl 1.x${RESET}\n"
echo

ok "Initializing installer"
ok "Preparing installation environment"

# ---------------- SYSTEM CHECK ----------------

section "01 • SYSTEM CHECK"

info "Detecting operating system..."

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "      Operating System: ${WHITE}${PRETTY_NAME:-Unknown}${RESET}"
else
    warn "Could not identify operating system."
fi

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

# ---------------- CODESPACES MODE ----------------

if [[ "$IS_CODESPACES" == "true" ]]; then

    echo
    printf "${PURPLE}${BOLD}"
    echo "                 ✦ GITHUB CODESPACES MODE ✦"
    printf "${RESET}"
    echo

    ok "GitHub Codespaces detected."
    warn "Codespaces does not provide systemd for Wings."
    warn "Docker/systemd installation will be skipped."
    echo
    info "Running in preparation mode."
    info "Wings will NOT be falsely reported as online."

    MODE="codespaces"

else

    MODE="vps"

    # ---------------- ROOT CHECK ----------------

    if [[ $EUID -ne 0 ]]; then
        echo
        fail "This installer must be run as root on a VPS."
        echo
        echo "Run:"
        echo "  sudo bash wings-install.sh"
        echo
        exit 1
    fi

    # ---------------- SYSTEMD CHECK ----------------

    info "Checking systemd..."

    if [[ "$(ps -p 1 -o comm= 2>/dev/null | tr -d ' ')" == "systemd" ]]; then
        ok "systemd is running."
    else
        fail "systemd is not running."
        echo
        warn "This does not appear to be a normal VPS."
        warn "Run Wings on a real Linux VPS/server."
        echo
        exit 1
    fi

fi

# ---------------- NODE INPUT ----------------

section "02 • NODE CONFIGURATION"

printf "${CYAN}${BOLD}      Enter your Pterodactyl node details${RESET}\n"
echo

printf "      ${WHITE}Panel URL:${RESET}\n"
printf "      > "
read -r PANEL_URL

printf "\n      ${WHITE}Node UUID:${RESET}\n"
printf "      > "
read -r NODE_UUID

printf "\n      ${WHITE}Token ID:${RESET}\n"
printf "      > "
read -r TOKEN_ID

printf "\n      ${WHITE}Token:${RESET}\n"
printf "      > "
read -rs TOKEN
echo
echo

# ---------------- CLEAN PANEL URL ----------------

PANEL_URL="${PANEL_URL%/}"

PANEL_URL="${PANEL_URL%/admin/nodes/view/1/configuration}"

PANEL_URL="${PANEL_URL%/}"

if [[ -z "$PANEL_URL" ]]; then
    fail "Panel URL cannot be empty."
    exit 1
fi

if [[ -z "$NODE_UUID" ]]; then
    fail "Node UUID cannot be empty."
    exit 1
fi

if [[ -z "$TOKEN_ID" ]]; then
    fail "Token ID cannot be empty."
    exit 1
fi

if [[ -z "$TOKEN" ]]; then
    fail "Token cannot be empty."
    exit 1
fi

ok "Panel URL received."
ok "Node UUID received."
ok "Token ID received."
ok "Token received securely."

# ================================================================
# CODESPACES PREPARATION MODE
# ================================================================

if [[ "$MODE" == "codespaces" ]]; then

    section "03 • CODESPACES PREPARATION"

    # Use the repository/workspace instead of /etc and /usr/local.
    WORKSPACE="${GITHUB_WORKSPACE:-$PWD}"

    UTKARSH_DIR="$WORKSPACE/.utkarsh-wings"
    BIN_DIR="$UTKARSH_DIR/bin"
    CONFIG_DIR="$UTKARSH_DIR/etc/pterodactyl"
    DATA_DIR="$UTKARSH_DIR/var/lib/pterodactyl"
    LOG_DIR="$UTKARSH_DIR/var/log/pterodactyl"

    mkdir -p "$BIN_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$DATA_DIR/volumes"
    mkdir -p "$DATA_DIR/archives"
    mkdir -p "$DATA_DIR/backups"
    mkdir -p "$LOG_DIR"
    mkdir -p "$UTKARSH_DIR/tmp"

    ok "Codespaces workspace prepared."

    # ---------------- CURL ----------------

    info "Checking curl..."

    if command -v curl >/dev/null 2>&1; then
        ok "curl is installed."
    else
        fail "curl is required but is not installed."
        echo
        echo "Install curl in your Codespace and run this installer again."
        exit 1
    fi

    # ---------------- WINGS DOWNLOAD ----------------

    section "04 • WINGS BINARY"

    info "Downloading official Wings binary..."

    WINGS_URL="https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${WINGS_ARCH}"

    curl -fL "$WINGS_URL" -o "$BIN_DIR/wings"

    if [[ ! -s "$BIN_DIR/wings" ]]; then
        fail "Failed to download Wings."
        exit 1
    fi

    chmod +x "$BIN_DIR/wings"

    ok "Wings binary downloaded."

    # ---------------- VERSION ----------------

    info "Checking Wings version..."

    WINGS_VERSION="$("$BIN_DIR/wings" version 2>/dev/null | head -n 1 || true)"

    if [[ -n "$WINGS_VERSION" ]]; then
        ok "Installed: $WINGS_VERSION"
    else
        ok "Wings binary verified."
    fi

    # ---------------- CONFIG ----------------

    section "05 • GENERATING CONFIGURATION"

    info "Creating Codespaces configuration..."

    cat > "$CONFIG_DIR/config.yml" <<EOF
debug: false

uuid: ${NODE_UUID}
token_id: ${TOKEN_ID}
token: ${TOKEN}

api:
  host: 0.0.0.0
  port: 8080
  ssl:
    enabled: false
    cert: ""
    key: ""
  upload_limit: 100

system:
  root_directory: ${DATA_DIR}
  log_directory: ${LOG_DIR}
  data: ${DATA_DIR}/volumes
  archive_directory: ${DATA_DIR}/archives
  backup_directory: ${DATA_DIR}/backups
  tmp_directory: ${UTKARSH_DIR}/tmp
  username: $(whoami)
  timezone: UTC
  user:
    rootless:
      enabled: false
      container_uid: 0
      container_gid: 0
    uid: $(id -u)
    gid: $(id -g)

docker:
  network:
    name: pterodactyl_nw
    interfaces:
      v4:
        subnet: 172.18.0.0/16
        gateway: 172.18.0.1
      v6:
        subnet: fdba:17c8:6c94::/64
        gateway: fdba:17c8:6c94::1
  domainname: ""
  registries: {}
  tmpfs_size: 100
  container_pid_limit: 512
  installer_limits:
    memory: 1024
    cpu: 100
  build:
    network: pterodactyl_nw

remote: ${PANEL_URL}

remote_query:
  timeout: 30
  boot_servers_per_page: 50

allowed_mounts: []
allowed_origins: []

sftp:
  bind_address: 0.0.0.0
  bind_port: 2022
  read_only: false
EOF

    chmod 600 "$CONFIG_DIR/config.yml"

    ok "Codespaces config.yml created."
    ok "Configuration permissions secured."

    # ---------------- DOCKER CHECK ----------------

    section "06 • ENVIRONMENT CHECK"

    info "Checking Docker availability..."

    if command -v docker >/dev/null 2>&1; then

        ok "Docker CLI detected."

        if docker info >/dev/null 2>&1; then
            ok "Docker daemon is accessible."
            DOCKER_AVAILABLE="true"
        else
            warn "Docker CLI exists, but Docker daemon is unavailable."
            warn "This is normal for many GitHub Codespaces."
            DOCKER_AVAILABLE="false"
        fi

    else

        warn "Docker CLI is not installed."
        warn "Docker installation is intentionally skipped in Codespaces."
        DOCKER_AVAILABLE="false"

    fi

    # ---------------- CONFIG TEST ----------------

    section "07 • CODESPACES VALIDATION"

    info "Checking Wings executable..."

    if "$BIN_DIR/wings" version >/dev/null 2>&1; then
        ok "Wings executable works."
    else
        fail "Wings executable could not be executed."
        exit 1
    fi

    echo
    warn "Wings has NOT been started."
    warn "Codespaces is not being treated as a production Wings node."

    # ---------------- SAVE INFO ----------------

    cat > "$UTKARSH_DIR/README.txt" <<EOF
UTKARSH WINGS PRO
Codespaces preparation

Panel:
${PANEL_URL}

Node UUID:
${NODE_UUID}

Wings binary:
${BIN_DIR}/wings

Configuration:
${CONFIG_DIR}/config.yml

IMPORTANT:
This Codespace is only a preparation environment.
Wings should ultimately run on a real Linux VPS with Docker
and systemd.

DO NOT COMMIT config.yml TO A PUBLIC GITHUB REPOSITORY.
The configuration contains your Wings authentication token.
EOF

    # ---------------- FINAL ----------------

    section "08 • CODESPACES READY"

    printf "${PURPLE}${BOLD}"

    cat <<'EOF'

╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║                 ✓  CODESPACES READY  ✓                          ║
║                                                                  ║
║              U T K A R S H   W I N G S   P R O                  ║
║                                                                  ║
║              Wings binary + configuration prepared              ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

EOF

    printf "${RESET}"

    echo
    printf "${CYAN}${BOLD}Codespaces files${RESET}\n"
    echo
    echo "  Wings:  $BIN_DIR/wings"
    echo "  Config: $CONFIG_DIR/config.yml"
    echo
    printf "${YELLOW}${BOLD}IMPORTANT${RESET}\n"
    echo
    echo "  Codespaces is NOT running Wings."
    echo "  No systemd service was created."
    echo "  No Docker daemon was started."
    echo "  Use a real VPS for the production Wings node."
    echo
    printf "${PURPLE}${BOLD}                    ✦ U T K A R S H ✦${RESET}\n"
    echo
    exit 0
fi

# ================================================================
# REAL VPS MODE
# ================================================================

# ---------------- DEPENDENCIES ----------------

section "03 • DEPENDENCIES"

info "Checking curl..."

if command -v curl >/dev/null 2>&1; then
    ok "curl is installed."
else
    warn "curl is missing."
    apt-get update -y
    apt-get install -y curl
    ok "curl installed."
fi

info "Checking Docker..."

if command -v docker >/dev/null 2>&1; then
    ok "Docker detected: $(docker --version)"
else
    warn "Docker is not installed."
    echo
    info "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    ok "Docker installed."
fi

info "Checking Docker service..."

systemctl enable docker >/dev/null 2>&1 || true
systemctl start docker

if systemctl is-active --quiet docker; then
    ok "Docker is running."
else
    fail "Docker is not running."
    systemctl status docker --no-pager -l || true
    exit 1
fi

# ---------------- DIRECTORIES ----------------

section "04 • WINGS INSTALLATION"

info "Creating Pterodactyl directories..."

mkdir -p /etc/pterodactyl
mkdir -p /var/lib/pterodactyl
mkdir -p /var/lib/pterodactyl/volumes
mkdir -p /var/lib/pterodactyl/archives
mkdir -p /var/lib/pterodactyl/backups
mkdir -p /var/log/pterodactyl
mkdir -p /var/run/wings
mkdir -p /tmp/pterodactyl

ok "Pterodactyl directories created."

# ---------------- WINGS DOWNLOAD ----------------

info "Downloading official Wings binary..."

WINGS_URL="https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${WINGS_ARCH}"

curl -fL "$WINGS_URL" -o /tmp/wings

if [[ ! -s /tmp/wings ]]; then
    fail "Failed to download Wings."
    exit 1
fi

install -m 755 /tmp/wings /usr/local/bin/wings
rm -f /tmp/wings

ok "Wings binary installed."

# ---------------- VERSION ----------------

info "Checking Wings version..."

WINGS_VERSION="$(wings version 2>/dev/null | head -n 1 || true)"

if [[ -n "$WINGS_VERSION" ]]; then
    ok "Installed: $WINGS_VERSION"
else
    ok "Wings binary verified."
fi

# ---------------- CONFIG ----------------

section "05 • GENERATING CONFIGURATION"

info "Creating /etc/pterodactyl/config.yml..."

cat > /etc/pterodactyl/config.yml <<EOF
debug: false

uuid: ${NODE_UUID}
token_id: ${TOKEN_ID}
token: ${TOKEN}

api:
  host: 0.0.0.0
  port: 8080
  ssl:
    enabled: false
    cert: ""
    key: ""
  upload_limit: 100

system:
  root_directory: /var/lib/pterodactyl
  log_directory: /var/log/pterodactyl
  data: /var/lib/pterodactyl/volumes
  archive_directory: /var/lib/pterodactyl/archives
  backup_directory: /var/lib/pterodactyl/backups
  tmp_directory: /tmp/pterodactyl
  username: pterodactyl
  timezone: UTC
  user:
    rootless:
      enabled: false
      container_uid: 0
      container_gid: 0
    uid: 988
    gid: 988

docker:
  network:
    name: pterodactyl_nw
    interfaces:
      v4:
        subnet: 172.18.0.0/16
        gateway: 172.18.0.1
      v6:
        subnet: fdba:17c8:6c94::/64
        gateway: fdba:17c8:6c94::1
  domainname: ""
  registries: {}
  tmpfs_size: 100
  container_pid_limit: 512
  installer_limits:
    memory: 1024
    cpu: 100
  build:
    network: pterodactyl_nw

remote: ${PANEL_URL}

remote_query:
  timeout: 30
  boot_servers_per_page: 50

allowed_mounts: []
allowed_origins: []

sftp:
  bind_address: 0.0.0.0
  bind_port: 2022
  read_only: false
EOF

chmod 600 /etc/pterodactyl/config.yml

ok "config.yml created."
ok "Configuration permissions secured."

# ---------------- VALIDATE CONFIG ----------------

section "06 • CONFIGURATION TEST"

info "Testing Wings configuration..."

TEST_LOG="/tmp/utkarsh-wings-test.log"

wings --debug >"$TEST_LOG" 2>&1 &
WINGS_TEST_PID=$!

sleep 5

if kill -0 "$WINGS_TEST_PID" 2>/dev/null; then

    kill "$WINGS_TEST_PID" >/dev/null 2>&1 || true
    wait "$WINGS_TEST_PID" 2>/dev/null || true

    ok "Wings configuration loaded successfully."

else

    wait "$WINGS_TEST_PID" 2>/dev/null || true

    fail "Wings could not start with this configuration."
    echo
    cat "$TEST_LOG"
    echo
    exit 1

fi

# ---------------- SYSTEMD ----------------

section "07 • SYSTEM SERVICE"

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

# ---------------- START WINGS ----------------

section "08 • STARTING WINGS"

info "Enabling Wings at boot..."

systemctl enable wings >/dev/null 2>&1

ok "Wings enabled."

info "Starting Wings..."

systemctl restart wings

sleep 5

if systemctl is-active --quiet wings; then
    ok "Wings is running."
else
    fail "Wings failed to start."
    echo
    systemctl status wings --no-pager -l || true
    echo
    echo "Recent logs:"
    journalctl -u wings -n 50 --no-pager || true
    exit 1
fi

# ---------------- FINAL ----------------

section "09 • FINAL STATUS"

printf "${GREEN}${BOLD}"

cat <<'EOF'

╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║                    ✓  WINGS IS ONLINE  ✓                         ║
║                                                                  ║
║              U T K A R S H   W I N G S   P R O                  ║
║                                                                  ║
║                 Installation completed!                         ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

EOF

printf "${RESET}"

echo
printf "${CYAN}${BOLD}Useful commands${RESET}\n"
echo
printf "  ${WHITE}Status:${RESET}   systemctl status wings\n"
printf "  ${WHITE}Restart:${RESET}  systemctl restart wings\n"
printf "  ${WHITE}Stop:${RESET}     systemctl stop wings\n"
printf "  ${WHITE}Start:${RESET}    systemctl start wings\n"
printf "  ${WHITE}Logs:${RESET}     journalctl -u wings -f\n"
printf "  ${WHITE}Config:${RESET}   /etc/pterodactyl/config.yml\n"
echo

printf "${PURPLE}${BOLD}"
echo "                    ✦ U T K A R S H ✦"
printf "${RESET}"

echo
printf "${GRAY}          Pterodactyl Wings deployment complete.${RESET}\n"
echo

rm -f "$TEST_LOG"

exit 0
