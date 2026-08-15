# setup-chezmoi

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)](setup-chezmoi.sh)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passing-brightgreen)](setup-chezmoi.sh)

A single bash script that bootstraps [chezmoi](https://www.chezmoi.io/) and its prerequisites on any Linux machine — including immutable/atomic distributions such as Fedora Silverblue, Fedora Kinoite, and Bazzite — and helps you connect it to your dotfiles repository over SSH.

It is desktop-environment-agnostic: everything happens at the CLI level, with no assumptions about GNOME, KDE, or any other DE.

## Features

- **Cross-distro detection** — identifies the host's package manager (`apt-get`, `dnf`, `rpm-ostree`, `pacman`, `zypper`, `apk`) via `/etc/os-release` and fails clearly instead of guessing on unsupported systems.
- **Atomic/immutable-aware** — detects Fedora Atomic variants (Bazzite, Silverblue, Kinoite) and avoids unnecessary `rpm-ostree` package layering (and the reboot it requires) wherever possible; also detects SteamOS-style read-only-root Arch systems and handles them separately.
- **Minimal, targeted installs** — only installs prerequisites (`git`, `curl`, `ssh`, `ssh-keygen`) that are actually missing.
- **Official chezmoi installer** — installs chezmoi into `~/.local/bin` via its own install script, independent of distro packaging, so it stays current on every platform.
- **Guided git origin setup** — prompts for your dotfiles repository's SSH origin and validates the format before using it.
- **SSH key handling** — detects an existing usable key or generates a new passphrase-protected `ed25519` key, then walks you through adding the public key to your git host.
- **Automatic dotfile discovery** — picks up a curated set of common dotfiles already on your machine (see [Managed Dotfiles](#managed-dotfiles)) and adds any not yet tracked to chezmoi.
- **Self-documenting dotfiles repo** — generates a `README.md` inside the chezmoi source repo itself (if one doesn't already exist) explaining what it is, how to use chezmoi day-to-day, and which dotfiles get picked up automatically.
- **Initial commit** — commits the newly added dotfiles (and the generated README) to your chezmoi source repo, and offers to push them to your origin.
- **Topgrade integration** — if [topgrade](https://github.com/topgrade-rs/topgrade) is installed and configured, offers to add a `Chezmoi Push` custom command to it (and disable its built-in `chezmoi` step in favor of that), so your dotfiles get committed and pushed as part of your regular topgrade run. See [Topgrade Integration](#topgrade-integration) below.
- **Safe by default** — `chezmoi init` runs without `--apply` unless you explicitly confirm, dotfiles are only ever added (never overwritten) once chezmoi already manages them, and pushing requires explicit confirmation. Config file edits (topgrade) are backed up first and applied all-or-nothing. The script is idempotent to re-run.

## Requirements

- A Bash shell.
- `sudo` access if any prerequisite (`git`, `curl`, `ssh`) is missing and needs to be installed (rarely needed — these are present on most base images).
- An interactive terminal (the script prompts for input).

## Supported Distributions

| Package manager | Distributions |
| --- | --- |
| `apt-get` | Debian, Ubuntu, and derivatives |
| `dnf` | Fedora (traditional/non-atomic) |
| `rpm-ostree` | Fedora Silverblue, Fedora Kinoite, Bazzite, and other atomic/immutable Fedora variants |
| `pacman` | Arch Linux and derivatives, including SteamOS-style read-only-root systems (temporarily unlocked via `steamos-readonly` when needed) |
| `zypper` | openSUSE |
| `apk` | Alpine Linux |

## Usage

```bash
git clone git@github.com:Pat9496/setup-chezmoi.git
cd setup-chezmoi
./setup-chezmoi.sh
```

## How It Works

1. **Detect the OS** — reads `/etc/os-release` and checks for `/run/ostree-booted` or `rpm-ostree` to identify atomic Fedora variants, and separately checks for a SteamOS-style read-only root filesystem on Arch-based systems, then selects the matching package manager.
2. **Check prerequisites** — verifies `git`, `curl`, `ssh`, and `ssh-keygen` are available, installing only what's missing.
3. **Install chezmoi** — skips if already installed; otherwise runs chezmoi's official installer into `~/.local/bin` and warns if that directory isn't persisted on your `PATH`.
4. **Prompt for a git origin** — asks for your dotfiles repository's SSH remote (e.g. `git@github.com:user/dotfiles.git`), validating the format; leave it blank to skip and start from an empty chezmoi source directory.
5. **Set up an SSH key** — reuses an existing key or generates a new `ed25519` key pair, then prints the public key with instructions for adding it to your git host.
6. **Initialize chezmoi** — runs `chezmoi init` against your origin. Applying the dotfiles (`--apply`, which can overwrite files in `$HOME`) requires explicit confirmation.
7. **Generate a dotfiles repo README** — creates a `README.md` at the root of the chezmoi source directory (if one doesn't already exist) documenting the repo for anyone who lands on it — chezmoi ignores this file when applying, so it never ends up in `$HOME`.
8. **Add common dotfiles** — checks each path in the [managed dotfiles list](#managed-dotfiles); any that exist on your machine and aren't already tracked by chezmoi are added to its source state.
9. **Commit and push** — if anything new was added, commits it to the chezmoi source repo (prompting for a git identity first if none is configured there). If the repo has an `origin` remote, asks for confirmation before pushing.
10. **Configure topgrade** — if `topgrade` is installed and `~/.config/topgrade.toml` exists, offers to wire up the `Chezmoi Push` command described in [Topgrade Integration](#topgrade-integration).

## Managed Dotfiles

If present on your machine and not already tracked by chezmoi, the script adds these files/directories automatically — nothing outside this list is ever touched, and nothing that can hold credentials (e.g. `.netrc`, cloud/API credential files, private SSH keys) is ever added:

| Path(s) | What it configures |
| --- | --- |
| `~/.bashrc`, `~/.bash_profile`, `~/.bash_login`, `~/.profile` | Bash shell startup and interactive behavior |
| `~/.zshrc`, `~/.zprofile`, `~/.zshenv` | Zsh shell startup and interactive behavior |
| `~/.config/fish/config.fish` | Fish shell configuration |
| `~/.inputrc` | Readline command-line editing behavior (used by bash and other readline-based tools) |
| `~/.gitconfig`, `~/.gitignore_global` | Git identity, aliases, and global ignore rules |
| `~/.vimrc` | Vim editor configuration |
| `~/.config/nvim` | Neovim configuration (whole directory) |
| `~/.tmux.conf`, `~/.config/tmux/tmux.conf` | tmux terminal multiplexer configuration |
| `~/.config/alacritty/alacritty.toml` | Alacritty terminal emulator |
| `~/.config/kitty/kitty.conf` | Kitty terminal emulator |
| `~/.config/wezterm/wezterm.lua` | WezTerm terminal emulator |
| `~/.config/foot/foot.ini` | Foot terminal emulator (Wayland-native) |
| `~/.Xresources` | X11 terminal/font/color resource settings |
| `~/.screenrc` | GNU Screen terminal multiplexer configuration |
| `~/.config/sway/config` | Sway (Wayland tiling compositor) configuration |
| `~/.config/i3/config`, `~/.i3/config` | i3 (X11 tiling window manager) configuration |
| `~/.config/gtk-3.0/settings.ini`, `~/.config/gtk-4.0/settings.ini` | GTK app theming (dark mode, font, icon theme) |
| `~/.config/mimeapps.list` | Default application associations |
| `~/.config/user-dirs.dirs` | XDG user directory paths (Desktop, Downloads, etc.) |
| `~/.curlrc` | Default options for curl |
| `~/.wgetrc` | Default options for wget |
| `~/.config/MangoHud/MangoHud.conf` | MangoHud performance/FPS overlay, common on gaming distros |
| `~/.config/lutris/lutris.conf` | Lutris game manager settings |
| `~/.config/vkBasalt/vkBasalt.conf` | vkBasalt Vulkan post-processing overlay |
| `~/.config/glow/glow.yml` | Glow terminal markdown renderer settings |
| `~/.config/scummvm/scummvm.ini`, `~/.scummvmrc` | ScummVM adventure-game engine settings |
| `~/.config/scummvm-nightly/scummvm.ini` | ScummVM nightly build settings (separate install, XDG config dir) |
| `~/.var/app/org.scummvm.ScummVM/config/scummvm/scummvm.ini` | ScummVM settings (Flatpak install) |
| `~/.config/retroarch/retroarch.cfg` | RetroArch emulator frontend settings — **check this file before pushing** if you've ever used the legacy RetroAchievements login: it can store `cheevos_username`/`cheevos_password` as plaintext |
| `~/.config/starship.toml` | Starship cross-shell prompt |
| `~/.config/topgrade.toml` | Topgrade (everything-updater) settings |
| `~/.ssh/config` | SSH client host aliases and connection options — connection settings only, never key files |

## Generated Dotfiles README

If your chezmoi source directory doesn't already have a `README.md`, the script creates one for you, containing:

- A short explanation of what the repo is and that it's managed by chezmoi.
- The same day-to-day usage command table as [Using chezmoi](#using-chezmoi) below.
- A list of every path in [Managed Dotfiles](#managed-dotfiles), generated directly from the script's own candidate list so it can't drift out of sync.

It's created only if no `README.md` already exists there — an existing one (yours or otherwise) is never overwritten — and gets committed and pushed alongside your dotfiles in the same run.

## Topgrade Integration

[Topgrade](https://github.com/topgrade-rs/topgrade) upgrades everything on your system (packages, tools, firmware, ...) in one run. If it's installed and `~/.config/topgrade.toml` already exists, this script offers (with a confirmation prompt) to add a custom command to it:

```toml
[commands]
"Chezmoi Push" = '''chezmoi re-add && chezmoi git -- add -A && (chezmoi git -- diff --cached --quiet || chezmoi git -- commit -m "$(date '+%Y-%m-%d %H:%M:%S')") && chezmoi git -- push'''

[misc]
disable = ["chezmoi"]
```

This re-adds any changed dotfiles, commits them (only if something actually changed), and pushes — running as one of your topgrade steps instead of relying on you to remember to push manually. Topgrade's own built-in `chezmoi` step (which just runs `chezmoi update`) is disabled via `[misc]` `disable`, since this command supersedes it.

The script only adds this if it's not already present (safe to re-run), always backs up `topgrade.toml` first (`topgrade.toml.bak.<timestamp>`), and only writes changes if it can confidently locate/edit the right spot — if your `disable` array spans multiple lines or has an unexpected shape, it leaves the file untouched and tells you to add the two entries by hand.

## Using chezmoi

A few commands you'll use after running the script:

| Command | What it does |
| --- | --- |
| `chezmoi edit ~/.bashrc` | Edit a dotfile through chezmoi (edits the source copy, not the live file) |
| `chezmoi diff` | Preview what `apply` would change in `$HOME` |
| `chezmoi apply` | Apply the source state to `$HOME` |
| `chezmoi add ~/.some-file` | Start tracking a new dotfile |
| `chezmoi cd` | Open a shell in the source directory (for git operations, etc.) |
| `chezmoi update` | Pull the latest changes from your origin and apply them |

Typical loop: edit a dotfile with `chezmoi edit` (or edit it live and re-run `chezmoi add`), check `chezmoi diff`, then `chezmoi apply`. Commit and push from `chezmoi cd` (or `git -C "$(chezmoi source-path)" ...`) whenever you're happy with a change. See the [chezmoi user guide](https://www.chezmoi.io/user-guide/command-overview/) for the full command set.

## License

Released under the [MIT License](LICENSE).

## Credits

- [chezmoi](https://www.chezmoi.io/) — the dotfiles manager this script bootstraps.
