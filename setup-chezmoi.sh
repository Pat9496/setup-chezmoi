#!/usr/bin/env bash
set -euo pipefail

OS_ID=""
OS_ID_LIKE=""
IS_ATOMIC=false
IS_READONLY_ROOT=false
PKG_MANAGER=""

DOTFILE_CANDIDATES=(
  "$HOME/.bashrc"
  "$HOME/.bash_profile"
  "$HOME/.bash_login"
  "$HOME/.profile"
  "$HOME/.zshrc"
  "$HOME/.zprofile"
  "$HOME/.zshenv"
  "$HOME/.config/fish/config.fish"
  "$HOME/.inputrc"
  "$HOME/.gitconfig"
  "$HOME/.gitignore_global"
  "$HOME/.vimrc"
  "$HOME/.config/nvim"
  "$HOME/.tmux.conf"
  "$HOME/.config/tmux/tmux.conf"
  "$HOME/.config/alacritty/alacritty.toml"
  "$HOME/.config/kitty/kitty.conf"
  "$HOME/.config/wezterm/wezterm.lua"
  "$HOME/.config/foot/foot.ini"
  "$HOME/.Xresources"
  "$HOME/.screenrc"
  "$HOME/.config/sway/config"
  "$HOME/.config/i3/config"
  "$HOME/.i3/config"
  "$HOME/.curlrc"
  "$HOME/.wgetrc"
  "$HOME/.config/MangoHud/MangoHud.conf"
  "$HOME/.config/lutris/lutris.conf"
  "$HOME/.config/starship.toml"
  "$HOME/.ssh/config"
)

ADDED_DOTFILES=()
DOTFILES_COMMITTED=false
DOTFILES_PUSHED=false

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

detect_readonly_root() {
  if [[ "$IS_ATOMIC" == true ]]; then
    return 0
  fi

  if command -v steamos-readonly >/dev/null 2>&1; then
    IS_READONLY_ROOT=true
    return 0
  fi

  local mount_opts
  mount_opts="$(findmnt -no OPTIONS / 2>/dev/null || true)"
  if [[ -n "$mount_opts" ]]; then
    local -a opts
    IFS=',' read -r -a opts <<< "$mount_opts"
    local opt
    for opt in "${opts[@]}"; do
      if [[ "$opt" == "ro" ]]; then
        IS_READONLY_ROOT=true
        return 0
      fi
    done
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
      if [[ "$IS_READONLY_ROOT" == true ]]; then
        if command -v steamos-readonly >/dev/null 2>&1; then
          log_warn "Read-only root filesystem detected (SteamOS-style); temporarily disabling it to install: ${pkgs[*]}"
          "${sudo_prefix[@]}" steamos-readonly disable
          "${sudo_prefix[@]}" pacman -Sy --noconfirm "${pkgs[@]}"
          "${sudo_prefix[@]}" steamos-readonly enable
          log_warn "A reboot may be required before these packages are fully usable."
        else
          die "Detected a read-only root filesystem (checked for 'steamos-readonly') with no known way to temporarily unlock it for distro '${OS_ID}' (ID_LIKE='${OS_ID_LIKE}'). Install ${pkgs[*]} manually, then re-run this script; chezmoi itself installs independently of the package manager."
        fi
      else
        log_info "Installing via pacman: ${pkgs[*]}"
        "${sudo_prefix[@]}" pacman -Sy --noconfirm "${pkgs[@]}"
      fi
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
  GitHub:       Settings -> SSH and GPG keys -> New SSH key
  GitLab:       Preferences -> SSH Keys
  Bitbucket:    Personal settings -> SSH keys
  Gitea:        Settings -> SSH / GPG Keys -> Add Key
  Azure DevOps: User settings -> SSH public keys -> New Key
  Other/self-hosted: consult your git host's account or profile settings
EOF

  read -r -p "Press Enter once the key has been added to your git host (or Ctrl+C to abort): " _
}

is_chezmoi_initialized() {
  chezmoi source-path >/dev/null 2>&1
}

add_common_dotfiles() {
  ADDED_DOTFILES=()

  local -a managed=()
  local managed_raw
  managed_raw="$(chezmoi managed --path-style=absolute 2>/dev/null || true)"
  if [[ -n "$managed_raw" ]]; then
    mapfile -t managed <<< "$managed_raw"
  fi

  local path
  for path in "${DOTFILE_CANDIDATES[@]}"; do
    if [[ ! -e "$path" ]]; then
      continue
    fi
    if array_contains "$path" "${managed[@]}"; then
      continue
    fi
    log_info "Adding to chezmoi source state: $path"
    chezmoi add "$path"
    ADDED_DOTFILES+=("$path")
  done

  if [[ ${#ADDED_DOTFILES[@]} -eq 0 ]]; then
    log_info "No new common dotfiles found to add."
  else
    log_info "Added ${#ADDED_DOTFILES[@]} dotfile path(s) to chezmoi."
  fi
}

ensure_git_identity() {
  local source_dir="$1"
  local name email

  name="$(git -C "$source_dir" config user.name 2>/dev/null || true)"
  email="$(git -C "$source_dir" config user.email 2>/dev/null || true)"

  if [[ -n "$name" && -n "$email" ]]; then
    return 0
  fi

  log_warn "No git identity (user.name/user.email) configured for the dotfiles repo."
  if [[ -z "$name" ]]; then
    read -r -p "Git user.name for this dotfiles repo: " name
    [[ -n "$name" ]] || die "A git user.name is required to commit the dotfiles repo."
    git -C "$source_dir" config user.name "$name"
  fi
  if [[ -z "$email" ]]; then
    read -r -p "Git user.email for this dotfiles repo: " email
    [[ -n "$email" ]] || die "A git user.email is required to commit the dotfiles repo."
    git -C "$source_dir" config user.email "$email"
  fi
}

commit_and_push_dotfiles() {
  DOTFILES_COMMITTED=false
  DOTFILES_PUSHED=false

  local source_dir
  source_dir="$(chezmoi source-path)"

  ensure_git_identity "$source_dir"

  git -C "$source_dir" add -A

  if [[ -z "$(git -C "$source_dir" status --porcelain)" ]]; then
    log_info "Nothing new to commit in the dotfiles repo."
    return 0
  fi

  git -C "$source_dir" commit -m "Add initial dotfiles"
  DOTFILES_COMMITTED=true
  log_info "Committed initial dotfiles."

  local remote_url
  if ! remote_url="$(git -C "$source_dir" remote get-url origin 2>/dev/null)"; then
    log_info "No 'origin' remote configured for the dotfiles repo; commit is local-only."
    return 0
  fi

  local push_answer
  read -r -p "Push the initial dotfiles commit to $remote_url now? [y/N] " push_answer
  if [[ ! "$push_answer" =~ ^[Yy] ]]; then
    log_info "Skipping push."
    return 0
  fi

  local branch
  branch="$(git -C "$source_dir" branch --show-current)"
  if [[ -z "$branch" ]]; then
    die "Could not determine the current branch in the dotfiles repo."
  fi

  if ! git -C "$source_dir" push -u origin "$branch"; then
    die "Dotfiles were committed locally, but the push to $remote_url failed. Resolve the error above, then push manually with: git -C \"$source_dir\" push"
  fi

  DOTFILES_PUSHED=true
  log_info "Pushed initial dotfiles commit to $remote_url."
}

run_chezmoi_init() {
  local git_origin="$1"
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

  printf '%s\n' "$applied"
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

  echo
  if [[ ${#ADDED_DOTFILES[@]} -gt 0 ]]; then
    echo "Added ${#ADDED_DOTFILES[@]} common dotfile path(s) to chezmoi:"
    local path
    for path in "${ADDED_DOTFILES[@]}"; do
      echo "  $path"
    done
  else
    echo "No new common dotfiles were added (none found on this machine, or all already managed)."
  fi

  if [[ "$DOTFILES_COMMITTED" == true ]]; then
    echo "Committed the initial dotfiles to the chezmoi source repo."
    if [[ "$DOTFILES_PUSHED" == true ]]; then
      echo "Pushed that commit to origin."
    else
      echo "That commit was not pushed (declined, or no origin remote configured)."
    fi
  else
    echo "No new commit was made in the dotfiles repo (nothing to commit)."
  fi
}

main() {
  detect_os
  detect_readonly_root
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

  local do_init=true
  if is_chezmoi_initialized; then
    log_warn "chezmoi already appears to be initialized (source directory exists)."
    local reinit_answer
    read -r -p "Run chezmoi init again anyway? [y/N] " reinit_answer
    if [[ ! "$reinit_answer" =~ ^[Yy] ]]; then
      log_info "Skipping chezmoi init."
      do_init=false
    fi
  fi

  local applied=false
  if [[ "$do_init" == true ]]; then
    applied="$(run_chezmoi_init "$git_origin")"
  fi

  add_common_dotfiles
  commit_and_push_dotfiles
  print_summary "$git_origin" "$applied"
}

main "$@"
