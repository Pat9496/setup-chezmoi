# setup-chezmoi

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)](setup-chezmoi.sh)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passing-brightgreen)](setup-chezmoi.sh)

Ein einzelnes Bash-Skript, das [chezmoi](https://www.chezmoi.io/) und dessen Voraussetzungen auf einer beliebigen Linux-Maschine — einschließlich unveränderlicher/atomarer Distributionen wie Fedora Silverblue, Fedora Kinoite und Bazzite — bootstrapped und hilft, es über SSH mit dem Dotfiles-Repository zu verbinden.

Das Skript ist Desktop-Umgebung-agnostisch: Alles verläuft auf CLI-Ebene, ohne Annahmen über GNOME, KDE oder eine andere DE.

[English version](README.md)

## Inhaltsverzeichnis

- [Eigenschaften](#eigenschaften)
- [Anforderungen](#anforderungen)
- [Unterstützte Distributionen](#unterstützte-distributionen)
- [Verwendung](#verwendung)
- [Funktionsweise](#funktionsweise)
- [Verwaltete Dotfiles](#verwaltete-dotfiles)
- [Generierte Dotfiles-README](#generierte-dotfiles-readme)
- [Topgrade-Integration](#topgrade-integration)
- [chezmoi verwenden](#chezmoi-verwenden)
- [Lizenz](#lizenz)
- [Credits](#credits)

## Eigenschaften

- **Distro-übergreifende Erkennung** — identifiziert den Paketmanager des Hosts (`apt-get`, `dnf`, `rpm-ostree`, `pacman`, `zypper`, `apk`) über `/etc/os-release` und schlägt eindeutig fehl, statt auf nicht unterstützten Systemen zu raten.
- **Atomic/Immutable-aware** — erkennt Fedora Atomic-Varianten (Bazzite, Silverblue, Kinoite) und vermeidet unnötiges `rpm-ostree`-Paketlayering (und den damit verbundenen Neustart), wo immer möglich; erkennt auch Arch-Systeme im SteamOS-Stil mit schreibgeschütztem Root-Dateisystem und behandelt diese separat.
- **Minimale, gezielte Installationen** — installiert nur Voraussetzungen (`git`, `curl`, `ssh`, `ssh-keygen`), die wirklich fehlen.
- **Offizieller chezmoi-Installer** — installiert chezmoi über sein eigenes Installationsskript in `~/.local/bin`, unabhängig von Distro-Paketierung, sodass es auf jeder Plattform aktuell bleibt.
- **Geführtes Git-Origin-Setup** — fordert den SSH-Origin des Dotfiles-Repositories an und validiert das Format vor der Verwendung.
- **SSH-Schlüsselverwaltung** — erkennt einen vorhandenen verwendbaren Schlüssel oder generiert einen neuen passwortgeschützten `ed25519`-Schlüssel, dann wird durch das Hinzufügen des öffentlichen Schlüssels zum Git-Host geführt.
- **Automatische Dotfile-Erkennung** — wählt einen kuratiert gepflegten Satz von häufigen Dotfiles auf dem System aus (siehe [Verwaltete Dotfiles](#verwaltete-dotfiles)) und fügt solche, die nicht bereits nachverfolgt werden, zu chezmoi hinzu.
- **Selbstdokumentierendes Dotfiles-Repository** — generiert eine `README.md` im chezmoi-Source-Repository (falls noch nicht vorhanden), die erklärt, was es ist, wie chezmoi im Alltag verwendet wird, und welche Dotfiles automatisch aufgegriffen werden.
- **Initial Commit** — committed die neu hinzugefügten Dotfiles (und die generierte README) im chezmoi-Source-Repository und bietet an, diese zur Origin zu pushen.
- **Topgrade-Integration** — falls [topgrade](https://github.com/topgrade-rs/topgrade) installiert und konfiguriert ist, wird angeboten (mit einer Bestätigungsaufforderung), einen benutzerdefinierten Befehl hinzuzufügen (und seinen integrierten `chezmoi`-Schritt zugunsten dieses zu deaktivieren), sodass Dotfiles als Teil eines regulären topgrade-Laufs committed und gepushed werden. Siehe [Topgrade-Integration](#topgrade-integration) unten.
- **Sicher standardmäßig** — `chezmoi init` wird ohne `--apply` ausgeführt, es sei denn, eine explizite Bestätigung erfolgt; Dotfiles werden nur hinzugefügt (nie überschrieben), sobald chezmoi diese bereits verwaltet; Pushen erfordert explizite Bestätigung. Konfigurationsdatei-Bearbeitungen (topgrade) werden zuerst gesichert und alles-oder-nichts angewendet. Das Skript ist idempotent, um erneut ausgeführt zu werden.

## Anforderungen

- Eine Bash-Shell.
- `sudo`-Zugriff, falls eine Voraussetzung (`git`, `curl`, `ssh`) fehlt und installiert werden muss (selten erforderlich — diese sind auf den meisten Base-Images vorhanden).
- Ein interaktives Terminal (das Skript fordert Eingaben an).

## Unterstützte Distributionen

| Paketmanager | Distributionen |
| --- | --- |
| `apt-get` | Debian, Ubuntu und Derivate |
| `dnf` | Fedora (traditionell/nicht-atomar) |
| `rpm-ostree` | Fedora Silverblue, Fedora Kinoite, Bazzite und andere atomare/unveränderliche Fedora-Varianten |
| `pacman` | Arch Linux und Derivate, einschließlich Systeme mit SteamOS-artigen schreibgeschützten Root-Dateisystemen (temporär über `steamos-readonly` entsperrt, wenn nötig) |
| `zypper` | openSUSE |
| `apk` | Alpine Linux |

## Verwendung

```bash
git clone git@github.com:Pat9496/setup-chezmoi.git
cd setup-chezmoi
./setup-chezmoi.sh
```

## Funktionsweise

1. **OS erkennen** — liest `/etc/os-release` und prüft auf `/run/ostree-booted` oder `rpm-ostree`, um atomare Fedora-Varianten zu identifizieren, und prüft separat auf ein Arch-basiertes Dateisystem im SteamOS-Stil mit schreibgeschütztem Root, dann wird der entsprechende Paketmanager ausgewählt.
2. **Voraussetzungen prüfen** — verifiziert, dass `git`, `curl`, `ssh` und `ssh-keygen` vorhanden sind, installiert nur das, was fehlt.
3. **chezmoi installieren** — übersprungen, falls bereits installiert; ansonsten wird chezmoi's offizieller Installer in `~/.local/bin` ausgeführt und gewarnt, falls dieses Verzeichnis nicht auf `PATH` persistiert wird.
4. **Nach Git-Origin fragen** — fordert den SSH-Remote des Dotfiles-Repositories an (z.B. `git@github.com:user/dotfiles.git`), validiert das Format; leer lassen zum Überspringen und Start aus einem leeren chezmoi-Source-Verzeichnis.
5. **SSH-Schlüssel einrichten** — verwendet einen vorhandenen Schlüssel oder generiert ein neues `ed25519`-Schlüsselpaar, dann wird der öffentliche Schlüssel mit Anweisungen für das Hinzufügen zum Git-Host angezeigt.
6. **chezmoi initialisieren** — führt `chezmoi init` gegen die Origin aus. Das Anwenden der Dotfiles (`--apply`, was Dateien in `$HOME` überschreiben kann) erfordert explizite Bestätigung.
7. **Dotfiles-Repository README generieren** — erstellt eine `README.md` im Root des chezmoi-Source-Verzeichnisses (falls noch nicht vorhanden), die das Repository für alle dokumentiert, die darauf landen — chezmoi ignoriert diese Datei beim Anwenden, sodass sie nie in `$HOME` endet.
8. **Häufige Dotfiles hinzufügen** — prüft jeden Pfad in der [Liste verwalteter Dotfiles](#verwaltete-dotfiles); alle, die auf dem System vorhanden sind und nicht bereits von chezmoi nachverfolgt werden, werden zum Source-Status hinzugefügt.
9. **Commit und Push** — falls etwas Neues hinzugefügt wurde, wird es im chezmoi-Source-Repository committed (Aufforderung zur Eingabe einer Git-Identität zuerst, falls dort keine konfiguriert ist). Falls das Repository ein `origin`-Remote hat, wird vor dem Pushen um Bestätigung gefragt.
10. **Topgrade konfigurieren** — falls `topgrade` installiert ist und `~/.config/topgrade.toml` existiert, wird angeboten, den `Chezmoi Push`-Befehl aus der [Topgrade-Integration](#topgrade-integration) einzurichten.

## Verwaltete Dotfiles

Falls auf dem System vorhanden und nicht bereits von chezmoi nachverfolgt, fügt das Skript diese Dateien/Verzeichnisse automatisch hinzu — nichts außerhalb dieser Liste wird jemals berührt, und nichts, was Zugangsdaten enthalten kann (z.B. `.netrc`, Cloud-/API-Credentials-Dateien, private SSH-Schlüssel), wird jemals hinzugefügt:

| Pfad(e) | Was es konfiguriert |
| --- | --- |
| `~/.bashrc`, `~/.bash_profile`, `~/.bash_login`, `~/.profile` | Bash-Shell-Startup und interaktives Verhalten |
| `~/.zshrc`, `~/.zprofile`, `~/.zshenv` | Zsh-Shell-Startup und interaktives Verhalten |
| `~/.config/fish/config.fish` | Fish-Shell-Konfiguration |
| `~/.inputrc` | Readline-Bearbeitungsverhalten der Befehlszeile (verwendet von bash und anderen Readline-basierten Tools) |
| `~/.gitconfig`, `~/.gitignore_global` | Git-Identität, Aliase und globale Ignorierungsregeln |
| `~/.config/git/config`, `~/.config/git/ignore` | Git-Identität, Aliase und globale Ignorierungsregeln (XDG-Konfigurationsort, Alternative zu `~/.gitconfig`) |
| `~/.vimrc` | Vim-Editor-Konfiguration |
| `~/.config/nvim` | Neovim-Konfiguration (ganzes Verzeichnis) |
| `~/.config/helix/config.toml` | Helix-Editor-Konfiguration |
| `~/.tmux.conf`, `~/.config/tmux/tmux.conf` | tmux-Terminal-Multiplexer-Konfiguration |
| `~/.config/zellij/config.kdl` | Zellij-Terminal-Multiplexer-Konfiguration |
| `~/.config/alacritty/alacritty.toml` | Alacritty-Terminal-Emulator |
| `~/.config/kitty/kitty.conf` | Kitty-Terminal-Emulator |
| `~/.config/wezterm/wezterm.lua` | WezTerm-Terminal-Emulator |
| `~/.config/foot/foot.ini` | Foot-Terminal-Emulator (Wayland-nativ) |
| `~/.Xresources` | X11-Terminal-/Font-/Farbressourcen-Einstellungen |
| `~/.xinitrc`, `~/.xprofile` | X11-Session-Startup-Befehle (startx / Display-Manager-Login) |
| `~/.screenrc` | GNU Screen-Terminal-Multiplexer-Konfiguration |
| `~/.config/sway/config` | Sway (Wayland-Tiling-Compositor)-Konfiguration |
| `~/.config/i3/config`, `~/.i3/config` | i3 (X11-Tiling-Fenster-Manager)-Konfiguration |
| `~/.config/hypr/hyprland.conf` | Hyprland (Wayland-Tiling-Compositor)-Konfiguration |
| `~/.config/waybar/config`, `~/.config/waybar/config.jsonc` | Waybar (Wayland-Statusleiste)-Konfiguration |
| `~/.config/rofi/config.rasi` | Rofi-Anwendungs-Launcher-Konfiguration |
| `~/.config/dunst/dunstrc` | Dunst-Benachrichtigungs-Daemon-Konfiguration |
| `~/.config/picom/picom.conf` | Picom (X11-Compositor)-Konfiguration |
| `~/.config/gtk-3.0/settings.ini`, `~/.config/gtk-4.0/settings.ini` | GTK-App-Design (Dark Mode, Schriftart, Icon-Design) |
| `~/.config/mimeapps.list` | Standardanwendungszuordnungen |
| `~/.config/user-dirs.dirs` | XDG-Benutzerverzeichnis-Pfade (Desktop, Downloads, usw.) |
| `~/.local/share/flatpak/overrides` | Flatpak-Pro-App-Berechtigungsüberschreibungen (Dateisystemzugriff, Gerätezugriff, D-Bus-Richtlinie) — ganzes Verzeichnis; einige Einträge können sich auf Disk-Mount-Labels beziehen, die spezifisch für die Maschine sind, auf der sie erstellt wurden |
| `~/.curlrc` | Standardoptionen für curl |
| `~/.wgetrc` | Standardoptionen für wget |
| `~/.config/htop/htoprc` | htop-Prozessviewer-Konfiguration |
| `~/.config/btop/btop.conf` | btop-Ressourcen-Monitor-Konfiguration |
| `~/.config/MangoHud/MangoHud.conf` | MangoHud-Leistungs-/FPS-Overlay, häufig auf Gaming-Distros |
| `~/.config/lutris/lutris.conf` | Lutris-Spielmanager-Einstellungen |
| `~/.config/vkBasalt/vkBasalt.conf` | vkBasalt-Vulkan-Nachbearbeitungs-Overlay |
| `~/.config/gamemode.ini` | GameMode-Leistungs-Daemon-Einstellungen |
| `~/.config/glow/glow.yml` | Glow-Terminal-Markdown-Renderer-Einstellungen |
| `~/.config/lazygit/config.yml` | Lazygit-Terminal-UI-für-Git-Konfiguration |
| `~/.tigrc` | tig (Git-TUI)-Konfiguration |
| `~/.config/bat/config` | bat (`cat`-Replacement)-Konfiguration |
| `~/.dircolors` | Benutzerdefiniertes `ls`/`dircolors`-Farbschema |
| `~/.config/direnv/direnvrc` | direnv-Globale-Konfiguration |
| `~/.config/scummvm/scummvm.ini`, `~/.scummvmrc` | ScummVM-Adventure-Game-Engine-Einstellungen |
| `~/.config/scummvm-nightly/scummvm.ini` | ScummVM-Nightly-Build-Einstellungen (separate Installation, XDG-Konfigurationsverzeichnis) |
| `~/.var/app/org.scummvm.ScummVM/config/scummvm/scummvm.ini` | ScummVM-Einstellungen (Flatpak-Installation) |
| `~/.config/retroarch/retroarch.cfg` | RetroArch-Emulator-Frontend-Einstellungen — **diese Datei überprüfen, bevor gepushed wird**, falls die alte RetroAchievements-Anmeldung je verwendet wurde: sie kann `cheevos_username`/`cheevos_password` als Klartext speichern |
| `~/.var/app/io.freetubeapp.FreeTube/config/FreeTube/settings.db` | FreeTube (Flatpak)-App-Einstellungen — Design, Wiedergabestandardwerte, UI-Toggle; umfasst Fenster `bounds` (Position/Größe), die möglicherweise nicht auf das Synchronisieren zwischen Maschinen mit unterschiedlichen Displays passen |
| `~/.var/app/io.freetubeapp.FreeTube/config/FreeTube/profiles.db` | FreeTube (Flatpak)-Abonnementliste (Profile und abonnierte Kanäle) |
| `~/.var/app/tv.kodi.Kodi/data/userdata/guisettings.xml` | Kodi (Flatpak)-Medienzentrum-Einstellungen — Skin, Wiedergabe, Untertitel, Region, Netzwerk-Einstellungen |
| `~/.var/app/tv.kodi.Kodi/data/userdata/keymaps` | Kodi (Flatpak)-benutzerdefinierte Tastenkombinationen (ganzes Verzeichnis) |
| `~/.var/app/tv.kodi.Kodi/data/userdata/profiles.xml` | Kodi (Flatpak)-Benutzerprofile — **diese Datei überprüfen, bevor gepushed wird**, falls je ein Master-Sperr-Code gesetzt wurde: sie kann den Sperr-Code-Hash speichern |
| `~/.config/starship.toml` | Starship-Cross-Shell-Prompt |
| `~/.config/yazi/yazi.toml` | Yazi-Terminal-Dateimanager-Einstellungen |
| `~/.config/lf/lfrc` | lf-Terminal-Dateimanager-Konfiguration |
| `~/.config/topgrade.toml` | Topgrade (alles-Updater)-Einstellungen |
| `~/.ssh/config` | SSH-Client-Host-Aliase und Verbindungsoptionen — nur Verbindungseinstellungen, nie Schlüsseldateien |

## Generierte Dotfiles-README

Falls das chezmoi-Source-Verzeichnis noch keine `README.md` hat, erstellt das Skript automatisch eine, die enthält:

- Eine kurze Erklärung, was das Repository ist und dass es von chezmoi verwaltet wird.
- Die gleiche Alltags-Verwendungs-Befehlstabelle wie [chezmoi verwenden](#chezmoi-verwenden) unten.
- Eine Liste von jedem Pfad in [Verwaltete Dotfiles](#verwaltete-dotfiles), direkt aus der eigenen Kandidaten-Liste des Skripts generiert, damit sie nicht ausfallen kann.

Diese wird nur erstellt, wenn keine `README.md` bereits dort vorhanden ist — eine vorhandene (eigene oder andere) wird nie überschrieben — und wird zusammen mit den Dotfiles im gleichen Lauf committed und gepushed.

## Topgrade-Integration

[Topgrade](https://github.com/topgrade-rs/topgrade) upgradet alles auf dem System (Pakete, Tools, Firmware, ...) in einem Lauf. Falls es installiert ist und `~/.config/topgrade.toml` bereits existiert, bietet dieses Skript (mit einer Bestätigungsaufforderung) an, einen benutzerdefinierten Befehl hinzuzufügen:

```toml
[commands]
"Chezmoi Push" = '''chezmoi re-add && chezmoi git -- add -A && (chezmoi git -- diff --cached --quiet || chezmoi git -- commit -m "$(date '+%Y-%m-%d %H:%M:%S')") && chezmoi git -- push'''

[misc]
disable = ["chezmoi"]
```

Dies fügt geänderte Dotfiles erneut auf, committed sie (nur wenn etwas tatsächlich geändert hat), und pushed — läuft als einer der topgrade-Schritte statt sich darauf zu verlassen, dass manuell gepushed wird. Der topgrade-Built-in `chezmoi`-Schritt führt nur `chezmoi update` aus (pullt und wendet Remote-Änderungen an, committed und pushed aber nicht die lokalen Bearbeitungen). Ohne diesen benutzerdefinierten Befehl müssten die Änderungen manuell committed und gepushed werden. Der Built-in-Schritt wird über `[misc]` `disable` deaktiviert, um Redundanz zu vermeiden und sicherzustellen, dass nur der benutzerdefinierte Befehl den vollständigen Workflow verarbeitet: erneut hinzufügen, bei Bedarf committen und pushen.

Das Skript fügt dies nur hinzu, falls es noch nicht vorhanden ist (sicher zur Erneuerung), legt immer zuerst ein Backup von `topgrade.toml` an (`topgrade.toml.bak.<timestamp>`), und schreibt Änderungen nur, falls es sicher die richtige Stelle finden/bearbeiten kann — falls das `disable`-Array mehrere Zeilen umfasst oder eine unerwartete Form hat, läßt das Skript die Datei unverändert und teilt mit, die zwei Einträge manuell hinzuzufügen.

## chezmoi verwenden

Ein paar Befehle, die nach dem Ausführen des Skripts verwendet werden:

| Befehl | Was es tut |
| --- | --- |
| `chezmoi edit ~/.bashrc` | Eine Dotfile durch chezmoi bearbeiten (bearbeitet die Quellkopie, nicht die Live-Datei) |
| `chezmoi diff` | Vorschau, was `apply` in `$HOME` ändern würde |
| `chezmoi apply` | Anwenden des Source-Zustands auf `$HOME` |
| `chezmoi add ~/.some-file` | Tracking einer neuen Dotfile starten |
| `chezmoi cd` | Eine Shell im Source-Verzeichnis öffnen (für Git-Operationen, usw.) |
| `chezmoi update` | Pullen der neuesten Änderungen von der Origin und anwenden |

Typische Schleife: Bearbeiten einer Dotfile mit `chezmoi edit` (oder Live-Bearbeitung und erneutes Ausführen von `chezmoi add`), Check mit `chezmoi diff`, dann `chezmoi apply`. Committen und pushen von `chezmoi cd` aus (oder `git -C "$(chezmoi source-path)" ...`), wann immer eine Änderung zufriedenstellend ist. Siehe die [chezmoi-Benutzeranleitung](https://www.chezmoi.io/user-guide/command-overview/) für den vollständigen Befehlssatz.

## Lizenz

Veröffentlicht unter der [MIT-Lizenz](LICENSE).

## Credits

- [chezmoi](https://www.chezmoi.io/) — der Dotfiles-Manager, den dieses Skript bootstrapped.
