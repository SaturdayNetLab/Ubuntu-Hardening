# ubuntu-hardening.sh

Interaktives Bash-Skript zur Grundhärtung eines frisch installierten Ubuntu 24.04 LTS Systems. Alle Einstellungen werden vor der Ausführung abgefragt — nichts wird stillschweigend verändert.

Entwickelt für den internen Einsatz bei 3NET GmbH, funktioniert aber auf jedem Standard-Ubuntu-24.04-Server.

---

*English version below.*

---

## Voraussetzungen

- Ubuntu 24.04 LTS (frische Installation)
- Root-Zugang (`sudo`)
- SSH Public Key vorhanden (wird im Wizard abgefragt)
- Internetverbindung für apt und optionale Tools

Das Skript ist ausdrücklich für Ubuntu 24.04 ausgelegt. Auf anderen Versionen kann es zu Abweichungen kommen.

---

## Nutzung

```bash
wget https://raw.githubusercontent.com/DEIN-USER/REPO/main/ubuntu-hardening.sh
chmod +x ubuntu-hardening.sh
sudo ./ubuntu-hardening.sh
```

Der Wizard fragt alle Einstellungen ab, zeigt danach eine Zusammenfassung und wartet auf eine letzte Bestätigung, bevor irgendetwas am System verändert wird.

---

## Was das Skript konfiguriert

**System**
- apt update, upgrade, dist-upgrade
- Hostname setzen
- Unnötige Pakete entfernen (telnet, rsh, cups, avahi u.a.)

**Nutzer & Zugang**
- Optionalen sudo-Nutzer anlegen
- SSH Public Key hinterlegen
- SSH-Port frei wählbar (Standard: 22)
- Passwort-Authentifizierung wird deaktiviert (Key-only)

**SSH-Härtung**
- Konfiguration landet in `/etc/ssh/sshd_config.d/99-hardening.conf`
- Root-Login deaktiviert
- MaxAuthTries 3, LoginGraceTime 30s
- Starke Algorithmen erzwungen: chacha20-poly1305, curve25519, AES-GCM
- Login-Banner (`/etc/ssh/banner`)

**Firewall**
- UFW mit `default deny incoming`
- SSH-Port rate-limited
- Weitere Ports können im Wizard eingetragen werden

**Weitere Maßnahmen (alle optional wählbar)**
- Fail2ban (Versuche und Ban-Dauer konfigurierbar)
- Automatische Sicherheitsupdates (unattended-upgrades)
- Kernel-Härtung via sysctl (ASLR, SYN-Cookies, kptr_restrict u.a.)
- auditd mit Regeln für Login, sudo, Identity-Dateien, Kernel-Module
- rkhunter (täglicher Cron-Job)
- ClamAV
- USB-Speicher-Blacklist
- IPv6 deaktivieren
- Passwort-Policy (libpam-pwquality, min. 14 Zeichen)
- /proc hidepid via systemd-Service
- MOTD mit rechtlichem Hinweis

Am Ende zeigt das Skript einen Verbindungsbefehl für eine neue SSH-Session an, die vor dem Schließen der aktuellen Session getestet werden sollte.

---

## Hinweise

**SSH vor dem Abmelden testen.** Das Skript deaktiviert Passwort-Authentifizierung. Wer seinen Public Key nicht korrekt hinterlegt hat, sperrt sich aus. Immer eine zweite Terminalsitzung öffnen und die Verbindung prüfen, bevor die laufende Session geschlossen wird.

Das Log landet unter `/var/log/hardening-DATUM-UHRZEIT.log`.

Einige Maßnahmen (hidepid, USB-Blacklist) werden erst nach einem Neustart aktiv.

---

## Getestete Umgebung

| Merkmal | Wert |
|---|---|
| OS | Ubuntu 24.04 LTS |
| Shell | bash 5.2 |
| Architektur | x86_64 |
| Zugang | SSH mit Ed25519-Key |

---

## Lizenz

Internes Werkzeug. Keine Garantie auf Vollständigkeit oder Fehlerfreiheit. Vor dem Einsatz auf Produktivsystemen testen.

---
---

# ubuntu-hardening.sh — English

An interactive Bash script for hardening a freshly installed Ubuntu 24.04 LTS system. Every setting is asked for upfront through a wizard — nothing is changed silently.

Built for internal use at 3NET GmbH, but works on any standard Ubuntu 24.04 server.

---

## Requirements

- Ubuntu 24.04 LTS (fresh installation)
- Root access (`sudo`)
- SSH public key ready (the wizard will ask for it)
- Internet connection for apt and optional tools

The script is written specifically for Ubuntu 24.04. Other versions may behave differently.

---

## Usage

```bash
wget https://raw.githubusercontent.com/YOUR-USER/REPO/main/ubuntu-hardening.sh
chmod +x ubuntu-hardening.sh
sudo ./ubuntu-hardening.sh
```

The wizard collects all configuration upfront, then shows a summary and waits for a final confirmation before making any changes to the system.

---

## What the script configures

**System**
- apt update, upgrade, dist-upgrade
- Set hostname
- Remove unnecessary packages (telnet, rsh, cups, avahi, etc.)

**Users & access**
- Create an optional sudo user
- Deploy SSH public key
- SSH port is freely configurable (default: 22)
- Password authentication is disabled (key-only)

**SSH hardening**
- Configuration is written to `/etc/ssh/sshd_config.d/99-hardening.conf`
- Root login disabled
- MaxAuthTries 3, LoginGraceTime 30s
- Strong algorithms enforced: chacha20-poly1305, curve25519, AES-GCM
- Login banner (`/etc/ssh/banner`)

**Firewall**
- UFW with `default deny incoming`
- SSH port rate-limited
- Additional ports can be added during the wizard

**Optional measures (all individually selectable)**
- Fail2ban (number of retries and ban duration configurable)
- Automatic security updates (unattended-upgrades)
- Kernel hardening via sysctl (ASLR, SYN cookies, kptr_restrict, etc.)
- auditd with rules covering login, sudo, identity files, kernel modules
- rkhunter (daily cron job)
- ClamAV
- USB storage blacklist
- Disable IPv6
- Password policy (libpam-pwquality, min. 14 characters)
- /proc hidepid via systemd service
- MOTD with legal notice

At the end, the script displays an SSH connection command for a new session that should be tested before closing the current one.

---

## Notes

**Test SSH before logging out.** The script disables password authentication. If the public key was not set up correctly, access to the server will be lost. Always open a second terminal session and verify the connection before closing the current one.

The log file is written to `/var/log/hardening-DATE-TIME.log`.

Some measures (hidepid, USB blacklist) only take effect after a reboot.

---

## Tested environment

| Property | Value |
|---|---|
| OS | Ubuntu 24.04 LTS |
| Shell | bash 5.2 |
| Architecture | x86_64 |
| Access | SSH with Ed25519 key |

---

## License

Internal tool. No warranty of completeness or correctness. Test before deploying to production systems.
