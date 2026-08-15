#!/usr/bin/env bash
set -euo pipefail

OS_ID=""
OS_ID_LIKE=""
IS_ATOMIC=false
PKG_MANAGER=""

log_info() { printf '[INFO] %s\n' "$*" >&2; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }
die() { log_error "$*"; exit 1; }

array_contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

detect_os() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_ID_LIKE="${ID_LIKE:-}"
  else
    OS_ID="unknown"
  fi

  if [[ -f /run/ostree-booted ]] || command -v rpm-ostree >/dev/null 2>&1; then
    IS_ATOMIC=true
  fi
}

detect_package_manager() {
  if [[ "$IS_ATOMIC" == true ]]; then
    PKG_MANAGER="rpm-ostree"
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt-get"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
  elif command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"
  elif command -v zypper >/dev/null 2>&1; then
    PKG_MANAGER="zypper"
  elif command -v apk >/dev/null 2>&1; then
    PKG_MANAGER="apk"
  else
    die "No supported package manager found (checked apt-get, dnf, rpm-ostree, pacman, zypper, apk) for distro '${OS_ID}' (ID_LIKE='${OS_ID_LIKE}'). Install git, curl, and an SSH client manually, then re-run this script; chezmoi itself installs independently of the package manager."
  fi
}

package_name_for_binary() {
  local bin="$1"
  case "$bin" in
    git) echo "git" ;;
    curl) echo "curl" ;;
    ssh | ssh-keygen)
      case "$PKG_MANAGER" in
        apt-get) echo "openssh-client" ;;
        dnf | rpm-ostree) echo "openssh-clients" ;;
        pacman | zypper) echo "openssh" ;;
        apk) echo "openssh-client" ;;
        *) echo "openssh" ;;
      esac
      ;;
    *) echo "" ;;
  esac
}

install_packages() {
  local -a pkgs=("$@")
  if [[ ${#pkgs[@]} -eq 0 ]]; then
    return 0
  fi

  local -a sudo_prefix=()
  if [[ "${EUID}" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo_prefix=(sudo)
    else
      die "Missing packages (${pkgs[*]}) require root privileges to install, but sudo is not available and this script is not running as root."
    fi
  fi

  case "$PKG_MANAGER" in
    apt-get)
      log_info "Installing via apt-get: ${pkgs[*]}"
      "${sudo_prefix[@]}" apt-get update
      "${sudo_prefix[@]}" apt-get install -y "${pkgs[@]}"
      ;;
    dnf)
      log_info "Installing via dnf: ${pkgs[*]}"
      "${sudo_prefix[@]}" dnf install -y "${pkgs[@]}"
      ;;
    pacman)
      log_info "Installing via pacman: ${pkgs[*]}"
      "${sudo_prefix[@]}" pacman -Sy --noconfirm "${pkgs[@]}"
      ;;
    zypper)
      log_info "Installing via zypper: ${pkgs[*]}"
      "${sudo_prefix[@]}" zypper install -y "${pkgs[@]}"
      ;;
    apk)
      log_info "Installing via apk: ${pkgs[*]}"
      "${sudo_prefix[@]}" apk add "${pkgs[@]}"
      ;;
    rpm-ostree)
      log_warn "Layering packages via rpm-ostree (immutable/atomic host): ${pkgs[*]}"
      log_warn "A reboot will be required before these packages are usable."
      "${sudo_prefix[@]}" rpm-ostree install -y "${pkgs[@]}"
      ;;
    *)
      die "Unknown package manager: $PKG_MANAGER"
      ;;
  esac
}

check_prerequisites() {
  local -a missing_bins=()
  local bin
  for bin in git curl ssh ssh-keygen; do
    if ! command -v "$bin" >/dev/null 2>&1; then
      missing_bins+=("$bin")
    fi
  done

  if [[ ${#missing_bins[@]} -eq 0 ]]; then
    log_info "Prerequisites already present: git, curl, ssh, ssh-keygen."
    return 0
  fi

  log_info "Missing prerequisites: ${missing_bins[*]}"

  local -a pkgs=()
  for bin in "${missing_bins[@]}"; do
    local pkg
    pkg="$(package_name_for_binary "$bin")"
    if [[ -n "$pkg" ]] && ! array_contains "$pkg" "${pkgs[@]}"; then
      pkgs+=("$pkg")
    fi
  done

  install_packages "${pkgs[@]}"

  for bin in "${missing_bins[@]}"; do
    if ! command -v "$bin" >/dev/null 2>&1; then
      die "'$bin' is still not available after attempting installation. Install it manually and re-run this script."
    fi
  done
}

install_chezmoi() {
  if command -v chezmoi >/dev/null 2>&1; then
    log_info "chezmoi already installed at $(command -v chezmoi)."
    return 0
  fi

  log_info "Installing chezmoi into \$HOME/.local/bin ..."
  mkdir -p "$HOME/.local/bin"
  if ! sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"; then
    die "chezmoi installation script failed."
  fi

  if ! command -v chezmoi >/dev/null 2>&1; then
    die "chezmoi was installed but is still not on PATH. Ensure \$HOME/.local/bin is in PATH and re-run this script."
  fi

  log_info "chezmoi installed at $(command -v chezmoi)."
}

check_path_persistence() {
  local -a rc_files=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.zshrc")
  local rc
  local found=false
  for rc in "${rc_files[@]}"; do
    if [[ -f "$rc" ]] && grep -Fq ".local/bin" "$rc"; then
      found=true
      break
    fi
  done

  if [[ "$found" == false ]]; then
    log_warn "\$HOME/.local/bin was not found in any shell startup file (.bashrc, .bash_profile, .profile, .zshrc)."
    log_warn "Add this to your shell rc file so chezmoi stays on PATH in new shells:"
    # shellcheck disable=SC2016
    log_warn '  export PATH="$HOME/.local/bin:$PATH"'
  fi
}

is_valid_ssh_origin() {
  local origin="$1"
  if [[ "$origin" =~ ^ssh://[[:alnum:]_.-]+@[[:alnum:]_.-]+(:[0-9]+)?/[^[:space:]]+$ ]]; then
    return 0
  fi
  if [[ "$origin" =~ ^[[:alnum:]_.-]+@[[:alnum:]_.-]+:[^[:space:]]+$ ]]; then
    return 0
  fi
  return 1
}

prompt_git_origin() {
  local origin=""
  local answer
  while true; do
    read -r -p "Git SSH origin for your dotfiles repo (e.g. git@github.com:user/dotfiles.git), or leave blank to skip: " origin
    if [[ -z "$origin" ]]; then
      printf '%s\n' ""
      return 0
    fi
    if is_valid_ssh_origin "$origin"; then
      printf '%s\n' "$origin"
      return 0
    fi
    log_warn "\"$origin\" doesn't look like a valid SSH remote (expected user@host:path or ssh://user@host/path)."
    read -r -p "Try entering it again? [Y/n] " answer
    if [[ "$answer" =~ ^[Nn] ]]; then
      printf '%s\n' ""
      return 0
    fi
  done
}

find_existing_key() {
  local key
  for key in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
    if [[ -f "$key" ]]; then
      printf '%s\n' "$key"
      return 0
    fi
  done
  return 1
}

setup_ssh_key() {
  local key_path=""
  local pub_path

  if key_path="$(find_existing_key)"; then
    log_info "Found existing SSH key: $key_path"
  elif ssh-add -l >/dev/null 2>&1; then
    log_info "ssh-agent already has at least one identity loaded; assuming it is usable for git."
  else
    log_info "No existing SSH key found. Generating a new ed25519 key pair."
    key_path="$HOME/.ssh/id_ed25519"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$(id -un)@$(hostname 2>/dev/null || uname -n)" -f "$key_path"
  fi

  if [[ -n "$key_path" ]]; then
    pub_path="${key_path}.pub"
    if [[ -f "$pub_path" ]]; then
      echo
      echo "Your SSH public key:"
      cat "$pub_path"
      echo
    fi
  fi

  cat <<'EOF'
Add this SSH key to your git hosting provider before continuing, e.g.:
  GitHub:    Settings -> SSH and GPG keys -> New SSH key
  GitLab:    Preferences -> SSH Keys
  Bitbucket: Personal settings -> SSH keys
  Other/self-hosted: consult your git host's account or profile settings
EOF

  read -r -p "Press Enter once the key has been added to your git host (or Ctrl+C to abort): " _
}

is_chezmoi_initialized() {
  chezmoi source-path >/dev/null 2>&1
}

print_summary() {
  local git_origin="$1"
  local applied="$2"

  echo
  log_info "Setup complete."
  log_info "chezmoi binary: $(command -v chezmoi)"

  if [[ -n "$git_origin" ]]; then
    log_info "chezmoi source repo: $git_origin"
  else
    log_info "chezmoi initialized without a git origin (empty source repo)."
  fi

  echo
  if [[ "$applied" == true ]]; then
    echo "Dotfiles have been applied to \$HOME."
    echo "Next: review changes with 'chezmoi diff', then re-run 'chezmoi apply' after future edits."
  else
    echo "Next steps:"
    echo "  chezmoi diff     # preview what would change"
    echo "  chezmoi apply    # apply the dotfiles to \$HOME"
    echo "  chezmoi cd       # open a shell in the chezmoi source directory"
  fi
}

main() {
  detect_os
  detect_package_manager

  export PATH="$HOME/.local/bin:$PATH"

  check_prerequisites
  install_chezmoi
  check_path_persistence

  local git_origin
  git_origin="$(prompt_git_origin)"

  if [[ -n "$git_origin" ]]; then
    setup_ssh_key
  fi

  if is_chezmoi_initialized; then
    log_warn "chezmoi already appears to be initialized (source directory exists)."
    local reinit_answer
    read -r -p "Run chezmoi init again anyway? [y/N] " reinit_answer
    if [[ ! "$reinit_answer" =~ ^[Yy] ]]; then
      log_info "Skipping chezmoi init."
      print_summary "$git_origin" false
      return 0
    fi
  fi

  local applied=false
  if [[ -n "$git_origin" ]]; then
    local apply_answer
    read -r -p "Run 'chezmoi init --apply $git_origin' now? This may overwrite existing files in \$HOME. [y/N] " apply_answer
    if [[ "$apply_answer" =~ ^[Yy] ]]; then
      chezmoi init --apply "$git_origin"
      applied=true
    else
      chezmoi init "$git_origin"
    fi
  else
    chezmoi init
  fi

  print_summary "$git_origin" "$applied"
}

main "$@"
