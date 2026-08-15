# setup-chezmoi

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)](setup-chezmoi.sh)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passing-brightgreen)](setup-chezmoi.sh)

A single bash script that bootstraps [chezmoi](https://www.chezmoi.io/) and its prerequisites on any Linux machine — including immutable/atomic distributions such as Fedora Silverblue, Fedora Kinoite, and Bazzite — and helps you connect it to your dotfiles repository over SSH.

It is desktop-environment-agnostic: everything happens at the CLI level, with no assumptions about GNOME, KDE, or any other DE.

## Features

- **Cross-distro detection** — identifies the host's package manager (`apt-get`, `dnf`, `rpm-ostree`, `pacman`, `zypper`, `apk`) via `/etc/os-release` and fails clearly instead of guessing on unsupported systems.
- **Atomic/immutable-aware** — detects Fedora Atomic variants (Bazzite, Silverblue, Kinoite) and avoids unnecessary `rpm-ostree` package layering (and the reboot it requires) wherever possible.
- **Minimal, targeted installs** — only installs prerequisites (`git`, `curl`, `ssh`, `ssh-keygen`) that are actually missing.
- **Official chezmoi installer** — installs chezmoi into `~/.local/bin` via its own install script, independent of distro packaging, so it stays current on every platform.
- **Guided git origin setup** — prompts for your dotfiles repository's SSH origin and validates the format before using it.
- **SSH key handling** — detects an existing usable key or generates a new passphrase-protected `ed25519` key, then walks you through adding the public key to your git host.
- **Safe by default** — `chezmoi init` runs without `--apply` unless you explicitly confirm, and the script is idempotent to re-run.

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
| `pacman` | Arch Linux and derivatives |
| `zypper` | openSUSE |
| `apk` | Alpine Linux |

## Usage

```bash
git clone git@github.com:Pat9496/setup-chezmoi.git
cd setup-chezmoi
./setup-chezmoi.sh
```

## How It Works

1. **Detect the OS** — reads `/etc/os-release` and checks for `/run/ostree-booted` or `rpm-ostree` to identify atomic Fedora variants, then selects the matching package manager.
2. **Check prerequisites** — verifies `git`, `curl`, `ssh`, and `ssh-keygen` are available, installing only what's missing.
3. **Install chezmoi** — skips if already installed; otherwise runs chezmoi's official installer into `~/.local/bin` and warns if that directory isn't persisted on your `PATH`.
4. **Prompt for a git origin** — asks for your dotfiles repository's SSH remote (e.g. `git@github.com:user/dotfiles.git`), validating the format; leave it blank to skip and start from an empty chezmoi source directory.
5. **Set up an SSH key** — reuses an existing key or generates a new `ed25519` key pair, then prints the public key with instructions for adding it to your git host.
6. **Initialize chezmoi** — runs `chezmoi init` against your origin. Applying the dotfiles (`--apply`, which can overwrite files in `$HOME`) requires explicit confirmation.

## License

Released under the [MIT License](LICENSE).

## Credits

- [chezmoi](https://www.chezmoi.io/) — the dotfiles manager this script bootstraps.
- Author: [Pat9496](https://github.com/Pat9496)
