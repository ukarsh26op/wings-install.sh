#!/usr/bin/env bash
# ================================================================
#        UTKARSH WINGS - GITHUB CODESPACES INSTALLER
#        Pterodactyl Wings | NO systemd dependency
# ================================================================

set -Eeuo pipefail

RESET='\033[0m'
BOLD='\033[1m'
CYAN='\033[38;5;51m'
PURPLE='\033[38;5;141m'
GREEN='\033[38;5;82m'
YELLOW='\033[38;5;226m'
RED='\033[38;5;196m'
WHITE='\033[97m'
GRAY='\033[90m'

ok()   { printf "      ${GREEN}✔${RESET} %s\n" "$1"; }
info() { printf "      ${CYAN}➜${RESET} %s\n" "$1"; }
warn() { printf "      ${YELLOW}⚠${RESET} %s\n" "$1"; }
fail() { printf "      ${RED}✖${RESET} %s\n" "$1"; }
section() {
    echo
    printf "${PURPLE}╭──────────────────────────────────────────────────────────────╮${RESET}\n"
    printf "${PURPLE}│${RESET}  ${BOLD}${WHITE}%-58s${RESET}${PURPLE}│${RESET}\n" "$1"
    printf "${PURPLE}╰──────────────────────────────────────────────────────────────╯${RESET}\n"
    echo
}

# ---------------- CODESPACES CHECK ----------------

if [[ "${CODESPACES:-}" != "true" && -z "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]]; then
    fail "This installer is intended for GitHub Codespaces."
    echo "      Open a GitHub Codespace and run it there."
    exit 1
fi

MODE="codespaces"

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
║                 W I N G S   C O D E S P A C E S                 ║
║                         I N S T A L L E R                       ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

EOF
printf "${RESET}"
printf "${PURPLE}${BOLD}                    ✦ U T K A R S H ✦${RESET}\n\n"
printf "${CYAN}             PTERODACTYL WINGS • NO SYSTEMD${RESET}\n"
printf "${GRAY}       Designed for the default GitHub Codespaces environment${RESET}\n\n"

# ---------------- SYSTEM CHECK ----------------

section "01 • ENVIRONMENT"

ok "GitHub Codespaces detected."

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) WINGS_ARCH="amd64"; ok "Architecture: x86_64 / amd64" ;;
    aarch64|arm64) WINGS_ARCH="arm64"; ok "Architecture: ARM64" ;;
    *) fail "Unsupported architecture: $ARCH"; exit 1 ;;
esac

WORKSPACE="${GITHUB_WORKSPACE:-$PWD}"
UTKARSH_DIR="$WORKSPACE/.utkarsh-wings"
BIN_DIR="$UTKARSH_DIR/bin"
CONFIG_DIR="$UTKARSH_DIR/etc/pterodactyl"
DATA_DIR="$UTKARSH_DIR/var/lib/pterodactyl"
LOG_DIR="$UTKARSH_DIR/var/log/pterodactyl"
RUN_DIR="$UTKARSH_DIR/run"
TMP_DIR="$UTKARSH_DIR/tmp"

mkdir -p \
    "$BIN_DIR" \
    "$CONFIG_DIR" \
    "$DATA_DIR/volumes" \
    "$DATA_DIR/archives" \
    "$DATA_DIR/backups" \
    "$LOG_DIR" \
    "$RUN_DIR" \
    "$TMP_DIR"

ok "Codespaces-local directories prepared."

# ---------------- DEPENDENCIES ----------------

section "02 • DEPENDENCIES"

if command -v curl >/dev/null 2>&1; then
    ok "curl is installed."
else
    fail "curl is required."
    echo "      Install curl in the Codespace, then run this script again."
    exit 1
fi

if command -v docker >/dev/null 2>&1; then
    ok "Docker CLI detected: $(docker --version)"
else
    warn "Docker CLI is not installed."
    warn "Wings requires Docker to create/manage Minecraft containers."
    warn "No Docker/systemd installation will be attempted."
fi

DOCKER_AVAILABLE="false"
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    DOCKER_AVAILABLE="true"
    ok "Docker daemon is accessible."
else
    warn "Docker daemon is not accessible."
    warn "Wings can be installed, but Minecraft server containers cannot run"
    warn "until a Docker daemon is available to this Codespace."
fi

# ---------------- NODE INPUT ----------------

section "03 • NODE CONFIGURATION"

printf "${CYAN}${BOLD}      Enter your Pterodactyl node details${RESET}\n\n"

printf "      ${WHITE}Panel URL:${RESET}\n      > "
read -r PANEL_URL

printf "\n      ${WHITE}Node UUID:${RESET}\n      > "
read -r NODE_UUID

printf "\n      ${WHITE}Token ID:${RESET}\n      > "
read -r TOKEN_ID

printf "\n      ${WHITE}Token:${RESET}\n      > "
read -rs TOKEN
echo
echo

PANEL_URL="${PANEL_URL%/}"
PANEL_URL="${PANEL_URL%/admin/nodes/view/1/configuration}"
PANEL_URL="${PANEL_URL%/}"

[[ -n "$PANEL_URL" ]] || { fail "Panel URL cannot be empty."; exit 1; }
[[ -n "$NODE_UUID" ]] || { fail "Node UUID cannot be empty."; exit 1; }
[[ -n "$TOKEN_ID" ]] || { fail "Token ID cannot be empty."; exit 1; }
[[ -n "$TOKEN" ]] || { fail "Token cannot be empty."; exit 1; }

ok "Panel URL received."
ok "Node UUID received."
ok "Token ID received."
ok "Token received securely."

# ---------------- DOWNLOAD WINGS ----------------

section "04 • WINGS BINARY"

WINGS_URL="https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${WINGS_ARCH}"

info "Downloading official Wings binary..."
curl -fL --retry 3 "$WINGS_URL" -o "$BIN_DIR/wings"

[[ -s "$BIN_DIR/wings" ]] || {
    fail "Failed to download Wings."
    exit 1
}

chmod +x "$BIN_DIR/wings"
ok "Wings binary downloaded."

WINGS_VERSION="$("$BIN_DIR/wings" version 2>/dev/null | head -n 1 || true)"
if [[ -n "$WINGS_VERSION" ]]; then
    ok "Installed: $WINGS_VERSION"
else
    ok "Wings executable verified."
fi

# ---------------- CONFIG ----------------

section "05 • GENERATING CONFIGURATION"

# NOTE:
# - Everything lives inside the Codespace workspace.
# - No /etc, /usr/local, /var/lib, systemctl, or journalctl is required.
# - Port 8080 is the Wings HTTP/API port.
# - Port 2022 is the SFTP port.
# - TLS is disabled here; use the Codespace forwarded HTTPS URL for access.

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
  tmp_directory: ${TMP_DIR}
  username: $(whoami)
  timezone: UTC
  user:
    rootless:
      enabled: false
      container_uid: $(id -u)
      container_gid: $(id -g)
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
ok "config.yml created."
ok "Configuration permissions secured."

# ---------------- DOCKER NETWORK ----------------

section "06 • DOCKER CHECK"

if [[ "$DOCKER_AVAILABLE" == "true" ]]; then
    info "Checking Pterodactyl Docker network..."

    if docker network inspect pterodactyl_nw >/dev/null 2>&1; then
        ok "pterodactyl_nw already exists."
    else
        if docker network create \
            --driver bridge \
            --subnet 172.18.0.0/16 \
            --gateway 172.18.0.1 \
            pterodactyl_nw >/dev/null 2>&1; then
            ok "pterodactyl_nw created."
        else
            warn "Could not create pterodactyl_nw."
            warn "Wings may create/manage it when Docker permissions allow."
        fi
    fi
else
    warn "Skipping Docker network creation because Docker is unavailable."
fi

# ---------------- CONFIG VALIDATION ----------------

section "07 • CONFIGURATION TEST"

info "Testing Wings configuration without systemd..."

TEST_LOG="$LOG_DIR/wings-test.log"

set +e
"$BIN_DIR/wings" --config "$CONFIG_DIR/config.yml" --debug >"$TEST_LOG" 2>&1 &
TEST_PID=$!
set -e

sleep 5

if kill -0 "$TEST_PID" 2>/dev/null; then
    kill "$TEST_PID" >/dev/null 2>&1 || true
    wait "$TEST_PID" 2>/dev/null || true
    ok "Wings configuration loaded successfully."
else
    wait "$TEST_PID" 2>/dev/null || true
    fail "Wings stopped during the configuration test."
    echo
    echo "      Last Wings output:"
    tail -n 80 "$TEST_LOG" || true
    echo
    exit 1
fi

# ---------------- START / STOP HELPERS ----------------

section "08 • PROCESS CONTROL"

START_SCRIPT="$UTKARSH_DIR/start-wings.sh"
STOP_SCRIPT="$UTKARSH_DIR/stop-wings.sh"
STATUS_SCRIPT="$UTKARSH_DIR/status-wings.sh"

cat > "$START_SCRIPT" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail

BASE="$UTKARSH_DIR"
WINGS="\$BASE/bin/wings"
CONFIG="\$BASE/etc/pterodactyl/config.yml"
LOG="\$BASE/var/log/pterodactyl/wings.log"
PIDFILE="\$BASE/run/wings.pid"

if [[ -f "\$PIDFILE" ]] && kill -0 "\$(cat "\$PIDFILE")" 2>/dev/null; then
    echo "Wings is already running (PID \$(cat "\$PIDFILE"))."
    exit 0
fi

mkdir -p "\$(dirname "\$LOG")" "\$(dirname "\$PIDFILE")"

nohup "\$WINGS" --config "\$CONFIG" >>"\$LOG" 2>&1 &
PID=\$!
echo "\$PID" > "\$PIDFILE"

sleep 3

if kill -0 "\$PID" 2>/dev/null; then
    echo "Wings started (PID \$PID)."
    echo "Log: \$LOG"
else
    echo "Wings failed to start."
    rm -f "\$PIDFILE"
    tail -n 80 "\$LOG" 2>/dev/null || true
    exit 1
fi
EOF

cat > "$STOP_SCRIPT" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail

PIDFILE="$RUN_DIR/wings.pid"

if [[ ! -f "\$PIDFILE" ]]; then
    echo "Wings is not running."
    exit 0
fi

PID="\$(cat "\$PIDFILE")"

if kill -0 "\$PID" 2>/dev/null; then
    kill "\$PID"
    for _ in {1..20}; do
        kill -0 "\$PID" 2>/dev/null || break
        sleep 0.25
    done
    kill -9 "\$PID" 2>/dev/null || true
    echo "Wings stopped."
else
    echo "Wings process is not running."
fi

rm -f "\$PIDFILE"
EOF

cat > "$STATUS_SCRIPT" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail

PIDFILE="$RUN_DIR/wings.pid"

if [[ -f "\$PIDFILE" ]] && kill -0 "\$(cat "\$PIDFILE")" 2>/dev/null; then
    echo "Wings: RUNNING"
    echo "PID: \$(cat "\$PIDFILE")"
else
    echo "Wings: STOPPED"
fi

echo "Log: $LOG_DIR/wings.log"
EOF

chmod +x "$START_SCRIPT" "$STOP_SCRIPT" "$STATUS_SCRIPT"

ok "start-wings.sh created."
ok "stop-wings.sh created."
ok "status-wings.sh created."

# ---------------- START WINGS ----------------

section "09 • STARTING WINGS"

if [[ "$DOCKER_AVAILABLE" == "true" ]]; then
    info "Starting Wings in the background (no systemd)..."

    "$START_SCRIPT"

    echo
    "$STATUS_SCRIPT"
    echo
    ok "Wings is running as a normal Codespace process."
else
    warn "Wings was NOT started because Docker is unavailable."
    warn "This avoids falsely reporting a working Pterodactyl node."
fi

# ---------------- FINAL ----------------

section "10 • CODESPACES READY"

printf "${GREEN}${BOLD}"
cat <<'EOF'

╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║                 ✓  CODESPACES READY  ✓                         ║
║                                                                  ║
║              U T K A R S H   W I N G S                          ║
║                                                                  ║
║             NO SYSTEMD • NO SYSTEM SERVICE                     ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

EOF
printf "${RESET}"

echo
printf "${CYAN}${BOLD}Files${RESET}\n"
echo "  Wings:   $BIN_DIR/wings"
echo "  Config:  $CONFIG_DIR/config.yml"
echo "  Logs:    $LOG_DIR/wings.log"
echo "  Start:   $START_SCRIPT"
echo "  Stop:    $STOP_SCRIPT"
echo "  Status:  $STATUS_SCRIPT"
echo

printf "${YELLOW}${BOLD}Codespaces notes${RESET}\n"
echo "  • No systemd is used."
echo "  • No systemctl/journalctl is used."
echo "  • No Docker installation is attempted."
echo "  • Wings runs directly as a normal process."
echo "  • Forward Codespace port 8080 for the Wings API."
echo "  • Forward Codespace port 2022 if SFTP is required."
echo "  • A Codespace can stop/restart, so this is not production hosting."
echo

if [[ "$DOCKER_AVAILABLE" != "true" ]]; then
    printf "${RED}${BOLD}IMPORTANT${RESET}\n"
    echo "  Docker daemon is currently unavailable."
    echo "  Wings alone cannot start Minecraft containers."
    echo "  Fix Docker access in the Codespace before expecting the"
    echo "  Pterodactyl Panel node to become fully operational."
    echo
fi

printf "${PURPLE}${BOLD}                    ✦ U T K A R S H ✦${RESET}\n\n"

exit 0
