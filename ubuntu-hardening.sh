#!/usr/bin/env bash
# =============================================================================
#  ubuntu-hardening.sh — Interaktives First-Install Security Script
#  Ziel: Ubuntu 24.04 LTS
#  Autor: Franky / 3NET GmbH
# =============================================================================

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# FARBEN & SYMBOLE
# ──────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

OK="${BOLD}${GREEN}[✔]${RESET}"
WARN="${BOLD}${YELLOW}[!]${RESET}"
ERR="${BOLD}${RED}[✘]${RESET}"
INFO="${BOLD}${CYAN}[→]${RESET}"
SKIP="${BOLD}${DIM}[−]${RESET}"
STEP="${BOLD}${BLUE}[▶]${RESET}"

LOG_FILE="/var/log/hardening-$(date +%Y%m%d-%H%M%S).log"

# ──────────────────────────────────────────────────────────────────────────────
# HILFSFUNKTIONEN
# ──────────────────────────────────────────────────────────────────────────────
log()    { echo -e "$1" | tee -a "$LOG_FILE"; }
ok()     { log "${OK}  $1"; }
warn()   { log "${WARN} $1"; }
err()    { log "${ERR} $1"; exit 1; }
info()   { log "${INFO} $1"; }
skip()   { log "${SKIP} Übersprungen: $1"; }
step()   { log "${STEP} $1"; }

section() {
  log ""
  log "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
  log "${BOLD}${CYAN}║  $1$(printf '%*s' $((52 - ${#1} - 2)) '')║${RESET}"
  log "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
}

run() {
  echo -e "  ${DIM}▸ $*${RESET}" | tee -a "$LOG_FILE"
  eval "$@" >> "$LOG_FILE" 2>&1 || warn "Befehl schlug fehl (non-fatal): $*"
}

divider() {
  echo -e "${DIM}  ──────────────────────────────────────────────────────${RESET}"
}

# Ja/Nein-Frage
ask_yn() {
  local prompt="$1"
  local default="${2:-n}"
  local options
  if [[ "$default" == "j" ]]; then
    options="${BOLD}[J/n]${RESET}"
  else
    options="${BOLD}[j/N]${RESET}"
  fi
  while true; do
    echo -en "${BOLD}${YELLOW}?${RESET}  $prompt $options: "
    read -r answer
    answer="${answer:-$default}"
    case "${answer,,}" in
      j|ja|y|yes) return 0 ;;
      n|nein|no)  return 1 ;;
      *) echo -e "   ${RED}Bitte 'j' oder 'n' eingeben.${RESET}" ;;
    esac
  done
}

# Texteingabe mit optionalem Standardwert
ask_input() {
  local prompt="$1"
  local default="${2:-}"
  local result
  if [[ -n "$default" ]]; then
    echo -en "${BOLD}${YELLOW}?${RESET}  $prompt ${DIM}[Standard: $default]${RESET}: "
  else
    echo -en "${BOLD}${YELLOW}?${RESET}  $prompt: "
  fi
  read -r result
  echo "${result:-$default}"
}

# Passworteingabe (kein Echo, mit Bestätigung)
ask_password() {
  local prompt="$1"
  local pass1 pass2
  while true; do
    echo -en "${BOLD}${YELLOW}?${RESET}  $prompt: "
    read -rs pass1
    echo ""
    echo -en "${BOLD}${YELLOW}?${RESET}  Passwort bestätigen: "
    read -rs pass2
    echo ""
    if [[ "$pass1" == "$pass2" ]]; then
      echo "$pass1"
      return 0
    else
      echo -e "   ${RED}Passwörter stimmen nicht überein. Erneut versuchen.${RESET}"
    fi
  done
}

# ──────────────────────────────────────────────────────────────────────────────
# ROOT-CHECK
# ──────────────────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && {
  echo -e "${ERR} Dieses Skript muss als root ausgeführt werden!"
  echo -e "   Nutze: ${CYAN}sudo ./ubuntu-hardening.sh${RESET}"
  exit 1
}

touch "$LOG_FILE"

# ──────────────────────────────────────────────────────────────────────────────
# BANNER
# ──────────────────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
cat << 'BANNER'
  ╔═══════════════════════════════════════════════════════════╗
  ║                                                           ║
  ║    █░█ █▄▄ █░█ █▄░█ ▀█▀ █░█   █░█ ▄▀█ █▀█ █▀▄ █▀▀ █▄░█  ║
  ║    █▄█ █▄█ █▄█ █░▀█ ░█░ █▄█   █▀█ █▀█ █▀▄ █▄▀ ██▄ █░▀█  ║
  ║                                                           ║
  ║         Ubuntu 24.04 — First Install Security             ║
  ║                     by 3NET GmbH                          ║
  ╚═══════════════════════════════════════════════════════════╝
BANNER
echo -e "${RESET}"
echo -e "  ${DIM}Interaktiver Konfigurationsassistent — alle Eingaben vor der Ausführung.${RESET}"
echo -e "  ${DIM}Log: ${LOG_FILE}${RESET}"
echo ""

# Ubuntu-Version prüfen
if ! grep -q "Ubuntu 24" /etc/os-release 2>/dev/null; then
  warn "Dieses Skript ist für Ubuntu 24.04 ausgelegt. Andere Versionen können abweichen."
  ask_yn "Trotzdem fortfahren?" || { echo -e "${INFO} Abgebrochen."; exit 0; }
fi

echo -e "${BOLD}  Drücke ENTER um den Assistenten zu starten...${RESET}"
read -r

# ══════════════════════════════════════════════════════════════════════════════
#
#   WIZARD — Alle Fragen VOR der Ausführung
#
# ══════════════════════════════════════════════════════════════════════════════
clear
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${BLUE}║              KONFIGURATIONSASSISTENT                 ║${RESET}"
echo -e "${BOLD}${BLUE}║  Beantworte alle Fragen — dann läuft alles durch.   ║${RESET}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""

# ── [1] SYSTEM-UPDATE ─────────────────────────────────────────────────────────
echo -e "${BOLD}  [1/10] System-Update${RESET}"
echo -e "  ${DIM}Führt apt update, upgrade und dist-upgrade durch.${RESET}"
if ask_yn "System jetzt aktualisieren?" "j"; then
  CFG_UPDATE=true
else
  CFG_UPDATE=false
fi
echo ""

# ── [2] HOSTNAME ──────────────────────────────────────────────────────────────
echo -e "${BOLD}  [2/10] Hostname${RESET}"
CURRENT_HOSTNAME=$(hostname)
echo -e "  ${DIM}Aktueller Hostname: ${CURRENT_HOSTNAME}${RESET}"
if ask_yn "Hostname ändern?"; then
  CFG_HOSTNAME=$(ask_input "Neuer Hostname")
else
  CFG_HOSTNAME=""
fi
echo ""

# ── [3] ADMIN-USER ────────────────────────────────────────────────────────────
echo -e "${BOLD}  [3/10] Admin-Nutzer${RESET}"
echo -e "  ${DIM}Empfohlen: nicht direkt als root arbeiten.${RESET}"
if ask_yn "Neuen sudo-Nutzer anlegen?" "j"; then
  CFG_ADMIN_USER=$(ask_input "Nutzername")
  while [[ -z "$CFG_ADMIN_USER" ]]; do
    echo -e "   ${RED}Nutzername darf nicht leer sein.${RESET}"
    CFG_ADMIN_USER=$(ask_input "Nutzername")
  done
  if id "$CFG_ADMIN_USER" &>/dev/null; then
    warn "Nutzer '$CFG_ADMIN_USER' existiert bereits — Passwort wird nicht geändert."
    CFG_ADMIN_PASS=""
  else
    CFG_ADMIN_PASS=$(ask_password "Passwort für '$CFG_ADMIN_USER'")
  fi
else
  CFG_ADMIN_USER=""
  CFG_ADMIN_PASS=""
fi
echo ""

# ── [4] SSH PUBLIC KEY ────────────────────────────────────────────────────────
echo -e "${BOLD}  [4/10] SSH Public Key${RESET}"
echo -e "  ${DIM}Passwort-Auth wird deaktiviert — du BRAUCHST einen Key!${RESET}"
echo -e "  ${DIM}Beispiel: ssh-ed25519 AAAA... user@host${RESET}"
if ask_yn "SSH Public Key jetzt hinterlegen?" "j"; then
  echo -en "${BOLD}${YELLOW}?${RESET}  Public Key (ganzen Key in eine Zeile einfügen): "
  read -r CFG_SSH_PUBKEY
  while [[ -z "$CFG_SSH_PUBKEY" ]]; do
    echo -e "   ${RED}Key darf nicht leer sein.${RESET}"
    echo -en "${BOLD}${YELLOW}?${RESET}  Public Key: "
    read -r CFG_SSH_PUBKEY
  done
  KEY_TYPE=$(echo "$CFG_SSH_PUBKEY" | awk '{print $1}')
  case "$KEY_TYPE" in
    ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp521)
      echo -e "   ${GREEN}Key-Typ erkannt: $KEY_TYPE${RESET}" ;;
    *)
      warn "Unbekannter Key-Typ '$KEY_TYPE' — bitte prüfen!" ;;
  esac
else
  CFG_SSH_PUBKEY=""
  warn "Kein SSH Key angegeben! Stelle sicher, dass authorized_keys bereits existiert."
  ask_yn "Wirklich ohne Key-Hinterlegung fortfahren?" || { echo "Abgebrochen."; exit 1; }
fi
echo ""

# ── [5] SSH PORT ──────────────────────────────────────────────────────────────
echo -e "${BOLD}  [5/10] SSH Port${RESET}"
echo -e "  ${DIM}Standard ist 22. Ein anderer Port reduziert automatisierte Scans.${RESET}"
CFG_SSH_PORT_RAW=$(ask_input "SSH Port" "22")
CFG_SSH_PORT="${CFG_SSH_PORT_RAW//[^0-9]/}"
if [[ -z "$CFG_SSH_PORT" || "$CFG_SSH_PORT" -lt 1 || "$CFG_SSH_PORT" -gt 65535 ]]; then
  warn "Ungültiger Port — verwende 22"
  CFG_SSH_PORT=22
fi
echo ""

# ── [6] FIREWALL ──────────────────────────────────────────────────────────────
echo -e "${BOLD}  [6/10] UFW Firewall — weitere Ports${RESET}"
echo -e "  ${DIM}SSH (Port $CFG_SSH_PORT) wird automatisch erlaubt.${RESET}"
CFG_EXTRA_PORTS=()
if ask_yn "Weitere Ports freigeben? (Web, VPN, Mail…)"; then
  echo -e "  ${DIM}Format: 80/tcp  443/tcp  51820/udp  8080  — leere Zeile zum Beenden${RESET}"
  while true; do
    echo -en "${BOLD}${YELLOW}?${RESET}  Port (leer = fertig): "
    read -r port_entry
    [[ -z "$port_entry" ]] && break
    CFG_EXTRA_PORTS+=("$port_entry")
    echo -e "   ${GREEN}+ $port_entry vorgemerkt${RESET}"
  done
fi
echo ""

# ── [7] FAIL2BAN ──────────────────────────────────────────────────────────────
echo -e "${BOLD}  [7/10] Fail2ban${RESET}"
echo -e "  ${DIM}Sperrt IPs bei zu vielen fehlgeschlagenen Login-Versuchen.${RESET}"
if ask_yn "Fail2ban installieren?" "j"; then
  CFG_FAIL2BAN=true
  CFG_F2B_MAXRETRY=$(ask_input "Max. Fehlversuche vor Ban" "3")
  CFG_F2B_BANTIME=$(ask_input "Ban-Dauer in Sekunden (86400 = 24h)" "86400")
else
  CFG_FAIL2BAN=false
  CFG_F2B_MAXRETRY=3
  CFG_F2B_BANTIME=86400
fi
echo ""

# ── [8] AUTO-UPDATES ──────────────────────────────────────────────────────────
echo -e "${BOLD}  [8/10] Automatische Sicherheitsupdates${RESET}"
echo -e "  ${DIM}Sicherheitspatches werden täglich automatisch eingespielt.${RESET}"
if ask_yn "Automatische Sicherheitsupdates aktivieren?" "j"; then
  CFG_AUTO_UPDATES=true
  if ask_yn "Bei Bedarf automatisch neu starten? (z.B. für Kernel-Updates)"; then
    CFG_AUTO_REBOOT=true
    CFG_AUTO_REBOOT_TIME=$(ask_input "Uhrzeit für Auto-Reboot (HH:MM)" "03:00")
  else
    CFG_AUTO_REBOOT=false
    CFG_AUTO_REBOOT_TIME="03:00"
  fi
else
  CFG_AUTO_UPDATES=false
  CFG_AUTO_REBOOT=false
  CFG_AUTO_REBOOT_TIME="03:00"
fi
echo ""

# ── [9] OPTIONALE TOOLS ───────────────────────────────────────────────────────
echo -e "${BOLD}  [9/10] Optionale Sicherheitstools${RESET}"

if ask_yn "auditd? (Vollständiges Audit-Logging aller System-Events)" "j"; then
  CFG_AUDITD=true
else
  CFG_AUDITD=false
fi

if ask_yn "rkhunter? (Täglicher Rootkit-Scan per Cron)" "j"; then
  CFG_RKHUNTER=true
else
  CFG_RKHUNTER=false
fi

if ask_yn "ClamAV? (Antivirus, benötigt mehr Ressourcen)"; then
  CFG_CLAMAV=true
else
  CFG_CLAMAV=false
fi

if ask_yn "USB-Speicher blockieren? (usb-storage Kernel-Blacklist)"; then
  CFG_BLOCK_USB=true
else
  CFG_BLOCK_USB=false
fi

if ask_yn "IPv6 komplett deaktivieren?"; then
  CFG_DISABLE_IPV6=true
else
  CFG_DISABLE_IPV6=false
fi
echo ""

# ── [10] MOTD ─────────────────────────────────────────────────────────────────
echo -e "${BOLD}  [10/10] Login-Banner (MOTD)${RESET}"
echo -e "  ${DIM}Zeigt beim SSH-Login eine rechtliche Warnmeldung an.${RESET}"
if ask_yn "MOTD mit Sicherheitshinweis setzen?" "j"; then
  CFG_MOTD=true
  CFG_MOTD_ORG=$(ask_input "Organisations-/Firmenname für MOTD (optional, leer lassen = kein Name)" "")
else
  CFG_MOTD=false
  CFG_MOTD_ORG=""
fi
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# ZUSAMMENFASSUNG & BESTÄTIGUNG
# ══════════════════════════════════════════════════════════════════════════════
clear
echo -e "${BOLD}${MAGENTA}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${MAGENTA}║            DEINE KONFIGURATION — ÜBERSICHT           ║${RESET}"
echo -e "${BOLD}${MAGENTA}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""

print_cfg() {
  local label="$1"
  local value="$2"
  local color="${3:-$CYAN}"
  printf "  ${BOLD}%-30s${RESET} ${color}%s${RESET}\n" "$label" "$value"
}

print_cfg "System-Update:"        "$($CFG_UPDATE && echo "ja" || echo "nein")"
print_cfg "Hostname:"             "${CFG_HOSTNAME:-unverändert ($CURRENT_HOSTNAME)}"
print_cfg "Admin-User:"           "${CFG_ADMIN_USER:-nein}"

if [[ -n "$CFG_SSH_PUBKEY" ]]; then
  print_cfg "SSH Public Key:" "$(echo "$CFG_SSH_PUBKEY" | cut -c1-45)…" "$GREEN"
else
  print_cfg "SSH Public Key:" "NICHT gesetzt — ⚠ Gefahr des Aussperrens!" "$RED"
fi

print_cfg "SSH Port:"             "$CFG_SSH_PORT"

if [[ ${#CFG_EXTRA_PORTS[@]} -gt 0 ]]; then
  print_cfg "Zusätzliche Ports:" "${CFG_EXTRA_PORTS[*]}"
else
  print_cfg "Zusätzliche Ports:" "keine"
fi

print_cfg "Fail2ban:" \
  "$($CFG_FAIL2BAN && echo "ja (${CFG_F2B_MAXRETRY} Versuche → ${CFG_F2B_BANTIME}s Ban)" || echo "nein")"
print_cfg "Auto-Updates:" \
  "$($CFG_AUTO_UPDATES && echo "ja" || echo "nein")"
print_cfg "Auto-Reboot:" \
  "$($CFG_AUTO_REBOOT && echo "ja (${CFG_AUTO_REBOOT_TIME})" || echo "nein")"
print_cfg "auditd:"               "$($CFG_AUDITD && echo "ja" || echo "nein")"
print_cfg "rkhunter:"             "$($CFG_RKHUNTER && echo "ja" || echo "nein")"
print_cfg "ClamAV:"               "$($CFG_CLAMAV && echo "ja" || echo "nein")"
print_cfg "USB blockieren:"       "$($CFG_BLOCK_USB && echo "ja" || echo "nein")"
print_cfg "IPv6 deaktivieren:"    "$($CFG_DISABLE_IPV6 && echo "ja" || echo "nein")"
print_cfg "MOTD:" \
  "$($CFG_MOTD && echo "ja${CFG_MOTD_ORG:+ ($CFG_MOTD_ORG)}" || echo "nein")"

echo ""
divider
echo ""

if ! ask_yn "Alles korrekt — Härtung jetzt starten?" "j"; then
  echo -e "${INFO} Abgebrochen. Keine Änderungen wurden vorgenommen."
  exit 0
fi

echo ""
echo -e "${BOLD}${GREEN}  Starte Härtung — $(date)${RESET}"
echo ""
sleep 1

# ══════════════════════════════════════════════════════════════════════════════
#
#   AUSFÜHRUNG
#
# ══════════════════════════════════════════════════════════════════════════════

APPLIED_STEPS=()
SKIPPED_STEPS=()
apply()   { APPLIED_STEPS+=("$1"); }
skipped() { SKIPPED_STEPS+=("$1"); }

# ── SCHRITT 1: SYSTEM-UPDATE ──────────────────────────────────────────────────
section "Schritt 1 · System-Update"
if $CFG_UPDATE; then
  step "apt update & upgrade — bitte warten..."
  run apt-get update -q
  run apt-get upgrade -y -q
  run apt-get dist-upgrade -y -q
  run apt-get autoremove -y -q
  run apt-get autoclean -q
  ok "System auf aktuellem Stand"
  apply "System-Update"
else
  skip "System-Update"
  skipped "System-Update"
fi

# ── SCHRITT 2: UNNÖTIGE PAKETE ────────────────────────────────────────────────
section "Schritt 2 · Unnötige Pakete entfernen"
UNNECESSARY_PKGS=(telnet rsh-client rsh-redone-client talk talkd xinetd nis cups avahi-daemon)
removed_count=0
for pkg in "${UNNECESSARY_PKGS[@]}"; do
  if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
    run apt-get remove -y -q "$pkg"
    ok "Entfernt: $pkg"
    removed_count=$((removed_count + 1))
  else
    info "Nicht installiert: $pkg"
  fi
done
ok "$removed_count Pakete entfernt"
apply "Unnötige Pakete ($removed_count entfernt)"

# ── SCHRITT 3: HOSTNAME ───────────────────────────────────────────────────────
section "Schritt 3 · Hostname"
if [[ -n "$CFG_HOSTNAME" ]]; then
  run hostnamectl set-hostname "$CFG_HOSTNAME"
  echo "$CFG_HOSTNAME" > /etc/hostname
  if grep -q "127.0.1.1" /etc/hosts; then
    sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$CFG_HOSTNAME/" /etc/hosts
  else
    echo "127.0.1.1	$CFG_HOSTNAME" >> /etc/hosts
  fi
  ok "Hostname gesetzt: $CFG_HOSTNAME"
  apply "Hostname → $CFG_HOSTNAME"
else
  skip "Hostname (unverändert: $CURRENT_HOSTNAME)"
  skipped "Hostname"
fi

# ── SCHRITT 4: ADMIN-USER ─────────────────────────────────────────────────────
section "Schritt 4 · Admin-Nutzer"
if [[ -n "$CFG_ADMIN_USER" ]]; then
  if id "$CFG_ADMIN_USER" &>/dev/null; then
    info "Nutzer '$CFG_ADMIN_USER' existiert bereits"
  else
    run useradd -m -s /bin/bash -G sudo "$CFG_ADMIN_USER"
    echo "$CFG_ADMIN_USER:$CFG_ADMIN_PASS" | chpasswd
    ok "Nutzer '$CFG_ADMIN_USER' angelegt (sudo-Gruppe)"
  fi
  apply "Admin-User: $CFG_ADMIN_USER"
else
  skip "Admin-User"
  skipped "Admin-User"
fi

# ── SCHRITT 5: SSH PUBLIC KEY ─────────────────────────────────────────────────
section "Schritt 5 · SSH Public Key"
if [[ -n "$CFG_SSH_PUBKEY" ]]; then
  if [[ -n "$CFG_ADMIN_USER" ]]; then
    TARGET_USER="$CFG_ADMIN_USER"
    TARGET_HOME="/home/$CFG_ADMIN_USER"
  else
    TARGET_USER="root"
    TARGET_HOME="/root"
  fi
  SSH_DIR="$TARGET_HOME/.ssh"
  run mkdir -p "$SSH_DIR"
  if ! grep -qF "$CFG_SSH_PUBKEY" "$SSH_DIR/authorized_keys" 2>/dev/null; then
    echo "$CFG_SSH_PUBKEY" >> "$SSH_DIR/authorized_keys"
    ok "Key hinzugefügt: $SSH_DIR/authorized_keys"
  else
    info "Key bereits vorhanden — kein Duplikat"
  fi
  run chmod 700 "$SSH_DIR"
  run chmod 600 "$SSH_DIR/authorized_keys"
  run chown -R "$TARGET_USER:$TARGET_USER" "$SSH_DIR"
  ok "SSH Key gesichert für '$TARGET_USER'"
  apply "SSH Key → $TARGET_USER"
else
  skip "SSH Key (keiner angegeben)"
  skipped "SSH Key"
fi

# ── SCHRITT 6: SSH ABSICHERN ──────────────────────────────────────────────────
section "Schritt 6 · SSH-Härtung"
SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_HARDENING="/etc/ssh/sshd_config.d/99-hardening.conf"
SSHD_BACKUP="${SSHD_CONFIG}.bak-$(date +%Y%m%d-%H%M%S)"
run cp "$SSHD_CONFIG" "$SSHD_BACKUP"
ok "Backup der Hauptdatei: $SSHD_BACKUP"

# Auf Ubuntu 24.04 haben Dateien in sshd_config.d/ Priorität über sshd_config.
# Wir schreiben alle Härtungseinstellungen in eine eigene Datei dort.
run mkdir -p /etc/ssh/sshd_config.d

# Sicherstellen dass Include-Direktive in sshd_config vorhanden ist
if ! grep -q "^Include /etc/ssh/sshd_config.d" "$SSHD_CONFIG"; then
  sed -i '1s|^|Include /etc/ssh/sshd_config.d/*.conf\n|' "$SSHD_CONFIG"
  ok "Include-Direktive in sshd_config ergänzt"
fi

cat > "$SSHD_HARDENING" <<EOF
# ubuntu-hardening.sh — $(date)
# Alle Einstellungen hier überschreiben sshd_config

Port                    $CFG_SSH_PORT
PermitRootLogin         no
PasswordAuthentication  no
PubkeyAuthentication    yes
AuthorizedKeysFile      .ssh/authorized_keys
PermitEmptyPasswords    no
X11Forwarding           no
AllowAgentForwarding    no
AllowTcpForwarding      no
MaxAuthTries            3
LoginGraceTime          30
ClientAliveInterval     300
ClientAliveCountMax     2
UsePAM                  yes
Banner                  /etc/ssh/banner

# Starke Kryptographie
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
EOF
ok "SSH-Konfiguration geschrieben: $SSHD_HARDENING"

cat > /etc/ssh/banner <<'EOF'
  ╔══════════════════════════════════════════════════════════╗
  ║  WARNUNG: Unbefugter Zugriff ist strafbar (§ 202a StGB)  ║
  ║  Alle Verbindungen werden protokolliert und überwacht.   ║
  ╚══════════════════════════════════════════════════════════╝
EOF
ok "SSH-Login-Banner gesetzt"

if sshd -t >> "$LOG_FILE" 2>&1; then
  run systemctl restart sshd
  ok "SSH neugestartet auf Port $CFG_SSH_PORT (Key-only)"
else
  warn "sshd Konfigurationstest fehlgeschlagen — Hardening-Datei wird entfernt!"
  run rm -f "$SSHD_HARDENING"
  run cp "$SSHD_BACKUP" "$SSHD_CONFIG"
  run systemctl restart sshd
fi
apply "SSH-Härtung (Port: $CFG_SSH_PORT, Key-only)"

# ── SCHRITT 7: UFW FIREWALL ───────────────────────────────────────────────────
section "Schritt 7 · UFW Firewall"
run apt-get install -y -q ufw
run ufw --force reset
run ufw default deny incoming
run ufw default allow outgoing
run ufw limit "$CFG_SSH_PORT/tcp" comment "SSH (rate-limited)"
ok "SSH Port $CFG_SSH_PORT erlaubt (rate-limited)"

for port in "${CFG_EXTRA_PORTS[@]:-}"; do
  [[ -z "$port" ]] && continue
  run ufw allow "$port" comment "Manuell"
  ok "UFW: $port geöffnet"
done

run ufw --force enable
ok "UFW aktiviert"
ufw status numbered | tee -a "$LOG_FILE"
apply "UFW Firewall"

# ── SCHRITT 8: FAIL2BAN ───────────────────────────────────────────────────────
section "Schritt 8 · Fail2ban"
if $CFG_FAIL2BAN; then
  run apt-get install -y -q fail2ban
  cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime  = $CFG_F2B_BANTIME
findtime = 600
maxretry = $CFG_F2B_MAXRETRY
backend  = systemd

[sshd]
enabled  = true
port     = $CFG_SSH_PORT
filter   = sshd
maxretry = $CFG_F2B_MAXRETRY
bantime  = $CFG_F2B_BANTIME
EOF
  run systemctl enable fail2ban
  run systemctl restart fail2ban
  ok "Fail2ban: ${CFG_F2B_MAXRETRY} Versuche → ${CFG_F2B_BANTIME}s Ban"
  apply "Fail2ban"
else
  skip "Fail2ban"
  skipped "Fail2ban"
fi

# ── SCHRITT 9: AUTO-UPDATES ───────────────────────────────────────────────────
section "Schritt 9 · Automatische Sicherheitsupdates"
if $CFG_AUTO_UPDATES; then
  run apt-get install -y -q unattended-upgrades apt-listchanges
  cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
  "\${distro_id}:\${distro_codename}";
  "\${distro_id}:\${distro_codename}-security";
  "\${distro_id}ESMApps:\${distro_codename}-apps-security";
  "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "$($CFG_AUTO_REBOOT && echo "true" || echo "false")";
Unattended-Upgrade::Automatic-Reboot-Time "${CFG_AUTO_REBOOT_TIME}";
Unattended-Upgrade::Mail "root";
EOF
  cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
  run systemctl enable unattended-upgrades
  run systemctl restart unattended-upgrades
  ok "Automatische Sicherheitsupdates aktiv"
  apply "Automatische Updates"
else
  skip "Automatische Updates"
  skipped "Automatische Updates"
fi

# ── SCHRITT 10: KERNEL-HÄRTUNG ────────────────────────────────────────────────
section "Schritt 10 · Kernel-Härtung (sysctl)"
cat > /etc/sysctl.d/99-hardening.conf <<EOF
# Netzwerk-Härtung
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_timestamps = 0

# IPv6
net.ipv6.conf.all.disable_ipv6 = $($CFG_DISABLE_IPV6 && echo "1" || echo "0")
net.ipv6.conf.default.disable_ipv6 = $($CFG_DISABLE_IPV6 && echo "1" || echo "0")

# Kernel-Schutz
kernel.randomize_va_space = 2
fs.suid_dumpable = 0
kernel.core_pattern = |/bin/false
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.perf_event_paranoid = 3
kernel.yama.ptrace_scope = 1
kernel.sysrq = 0

# Dateisystem
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
EOF
run sysctl --system
ok "sysctl-Härtung angewendet"
$CFG_DISABLE_IPV6 && ok "IPv6 deaktiviert" || true
apply "Kernel-Härtung (sysctl)"

# ── SCHRITT 11: AUDITD ────────────────────────────────────────────────────────
section "Schritt 11 · Audit-Logging (auditd)"
if $CFG_AUDITD; then
  run apt-get install -y -q auditd audispd-plugins
  cat > /etc/audit/rules.d/99-hardening.rules <<'EOF'
-D
-b 8192
-f 1
-w /var/log/faillog -p wa -k login
-w /var/log/lastlog -p wa -k login
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k identity
-w /etc/sudoers.d/ -p wa -k identity
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k network
-w /etc/hosts -p wa -k network
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
-w /usr/bin/sudo -p x -k sudo_usage
-w /etc/ssh/sshd_config -p wa -k ssh_config
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules
-e 2
EOF
  run systemctl enable auditd
  run systemctl restart auditd
  ok "auditd konfiguriert und aktiv"
  apply "auditd"
else
  skip "auditd"
  skipped "auditd"
fi

# ── SCHRITT 12: RKHUNTER ──────────────────────────────────────────────────────
section "Schritt 12 · Rkhunter"
if $CFG_RKHUNTER; then
  run apt-get install -y -q rkhunter
  rkhunter --update --nocolors >> "$LOG_FILE" 2>&1 || true
  rkhunter --propupd --nocolors >> "$LOG_FILE" 2>&1 || true
  cat > /etc/cron.daily/rkhunter-check <<'EOF'
#!/bin/bash
/usr/bin/rkhunter --check --nocolors --report-warnings-only --sk >> /var/log/rkhunter.log 2>&1
EOF
  chmod +x /etc/cron.daily/rkhunter-check
  ok "Rkhunter täglich per Cron aktiv"
  apply "Rkhunter"
else
  skip "Rkhunter"
  skipped "Rkhunter"
fi

# ── SCHRITT 13: CLAMAV ────────────────────────────────────────────────────────
section "Schritt 13 · ClamAV"
if $CFG_CLAMAV; then
  run apt-get install -y -q clamav clamav-daemon
  run systemctl stop clamav-freshclam
  step "Signaturen aktualisieren (kann einige Minuten dauern)..."
  run freshclam
  run systemctl enable clamav-daemon clamav-freshclam
  run systemctl start clamav-daemon clamav-freshclam
  ok "ClamAV installiert und aktiv"
  apply "ClamAV"
else
  skip "ClamAV"
  skipped "ClamAV"
fi

# ── SCHRITT 14: USB BLOCKIEREN ────────────────────────────────────────────────
section "Schritt 14 · USB-Speicher"
if $CFG_BLOCK_USB; then
  echo "blacklist usb-storage" > /etc/modprobe.d/usb-storage.conf
  run update-initramfs -u
  ok "USB-Speicher blacklisted (aktiv nach Reboot)"
  apply "USB-Speicher blockiert"
else
  skip "USB-Speicher"
  skipped "USB-Speicher"
fi

# ── SCHRITT 15: PASSWORT-POLICY & LIMITS ─────────────────────────────────────
section "Schritt 15 · Passwort-Policy & System-Limits"
run apt-get install -y -q libpam-pwquality

cat > /etc/security/pwquality.conf <<'EOF'
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
maxrepeat = 3
usercheck = 1
enforcing = 1
EOF
ok "Passwort-Policy: min. 14 Zeichen, Groß/Klein/Zahl/Sonderzeichen"

if ! grep -q "hard core" /etc/security/limits.conf; then
  echo "* hard core 0" >> /etc/security/limits.conf
  echo "* soft core 0" >> /etc/security/limits.conf
fi
ok "Core-Dumps deaktiviert"

# /proc mit hidepid absichern — Ubuntu 24.04 Methode via systemd
# (fstab-Methode ist auf systemd-basierten Systemen unzuverlässig)
if ! grep -q "hidepid" /etc/fstab; then
  mkdir -p /etc/systemd/system/
  cat > /etc/systemd/system/remount-proc.service <<'EOF'
[Unit]
Description=Remount /proc with hidepid=2
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/mount -o remount,hidepid=2,gid=0 /proc
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
  run systemctl daemon-reload
  run systemctl enable remount-proc.service
  warn "/proc hidepid=2 aktiv nach Reboot (via systemd-Service)"
fi
apply "Passwort-Policy & Limits"

# ── SCHRITT 16: MOTD ──────────────────────────────────────────────────────────
section "Schritt 16 · MOTD"
if $CFG_MOTD; then
  run chmod -x /etc/update-motd.d/* 2>/dev/null || true
  {
    echo ""
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║         GESICHERTES SYSTEM — ACHTUNG!            ║"
    echo "  ║  Unbefugter Zugriff ist strafbar (§ 202a StGB).  ║"
    echo "  ║  Alle Aktivitäten werden protokolliert.          ║"
    if [[ -n "$CFG_MOTD_ORG" ]]; then
      printf "  ║  %-48s║\n" "$CFG_MOTD_ORG"
    fi
    echo "  ╚══════════════════════════════════════════════════╝"
    echo ""
  } > /etc/motd
  ok "MOTD gesetzt"
  apply "MOTD"
else
  skip "MOTD"
  skipped "MOTD"
fi

# ══════════════════════════════════════════════════════════════════════════════
# ABSCHLUSSBERICHT
# ══════════════════════════════════════════════════════════════════════════════
clear
echo -e "${BOLD}${GREEN}"
cat << 'DONE'
  ╔══════════════════════════════════════════════════════╗
  ║          HÄRTUNG ERFOLGREICH ABGESCHLOSSEN           ║
  ╚══════════════════════════════════════════════════════╝
DONE
echo -e "${RESET}"

echo -e "${BOLD}  Angewendete Maßnahmen (${#APPLIED_STEPS[@]}):${RESET}"
for s in "${APPLIED_STEPS[@]}"; do
  echo -e "  ${OK}  $s"
done

if [[ ${#SKIPPED_STEPS[@]} -gt 0 ]]; then
  echo ""
  echo -e "${BOLD}  Übersprungen (${#SKIPPED_STEPS[@]}):${RESET}"
  for s in "${SKIPPED_STEPS[@]}"; do
    echo -e "  ${SKIP}  $s"
  done
fi

echo ""
divider
echo ""
echo -e "${BOLD}  Verbindungsdaten:${RESET}"
SERVER_IP=$(hostname -I | awk '{print $1}')
echo -e "  ${CYAN}ssh -p $CFG_SSH_PORT ${CFG_ADMIN_USER:-root}@${SERVER_IP}${RESET}"
echo ""
echo -e "${BOLD}  Log:${RESET} ${DIM}$LOG_FILE${RESET}"
echo ""
echo -e "${BOLD}${RED}  ⚠  JETZT UNBEDINGT:${RESET}"
echo -e "  ${RED}1.${RESET} Neue SSH-Session im obigen Befehl öffnen & testen!"
echo -e "  ${RED}2.${RESET} Erst dann diese Session schließen."
echo -e "  ${RED}3.${RESET} Nach Reboot: hidepid & USB-Blacklist werden aktiv."
echo ""
divider
echo ""

log ""
log "=== ABGESCHLOSSEN: $(date) ==="
log "Angewendet: ${APPLIED_STEPS[*]:-keine}"
log "Übersprungen: ${SKIPPED_STEPS[*]:-keine}"

read -rp "$(echo -e "${BOLD}System jetzt neu starten? [j/N]: ${RESET}")" REBOOT_CHOICE
if [[ "${REBOOT_CHOICE,,}" =~ ^(j|ja)$ ]]; then
  echo -e "${INFO} Reboot in 5 Sekunden — neue SSH-Session bereit?"
  sleep 5
  reboot
else
  echo -e "${INFO} Manueller Reboot: ${CYAN}sudo reboot${RESET}"
fi
