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
- **Initial commit** — commits the newly added dotfiles to your chezmoi source repo, and offers to push them to your origin.
- **Safe by default** — `chezmoi init` runs without `--apply` unless you explicitly confirm, dotfiles are only ever added (never overwritten) once chezmoi already manages them, and pushing requires explicit confirmation. The script is idempotent to re-run.

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
7. **Add common dotfiles** — checks each path in the [managed dotfiles list](#managed-dotfiles); any that exist on your machine and aren't already tracked by chezmoi are added to its source state.
8. **Commit and push** — if anything new was added, commits it to the chezmoi source repo (prompting for a git identity first if none is configured there). If the repo has an `origin` remote, asks for confirmation before pushing.

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
| `~/.curlrc` | Default options for curl |
| `~/.wgetrc` | Default options for wget |
| `~/.config/MangoHud/MangoHud.conf` | MangoHud performance/FPS overlay, common on gaming distros |
| `~/.config/lutris/lutris.conf` | Lutris game manager settings |
| `~/.config/starship.toml` | Starship cross-shell prompt |
| `~/.ssh/config` | SSH client host aliases and connection options — connection settings only, never key files |

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
