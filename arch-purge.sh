#!/usr/bin/env bash
# =============================================================================
# arch-purge — Completely uninstall an app on Arch Linux and wipe all data
# including config, cache, logs, and saved credentials/logins.
#
# Usage:
#   chmod +x arch-purge.sh
#   ./arch-purge.sh <package-name>
#
# Examples:
#   ./arch-purge.sh firefox
#   ./arch-purge.sh discord
#   ./arch-purge.sh spotify-launcher
#   ./arch-purge.sh code
#   ./arch-purge.sh visual-studio-code-bin
# =============================================================================

set -uo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[DONE]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}"; }

# ── Argument check ────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
    echo -e "${BOLD}Usage:${RESET} $0 <package-name>"
    echo -e "  Example: $0 firefox"
    exit 1
fi

PKG="$1"

# =============================================================================
# build_search_terms <pkg> <nameref-array>
#
# Derives meaningful search terms from a package name by splitting on hyphens
# and discarding generic AUR suffixes ("bin", "git", "launcher", etc.).
#
# "visual-studio-code-bin" → ["visual-studio-code-bin", "visual", "studio", "code"]
# "spotify-launcher"       → ["spotify-launcher", "spotify"]
# =============================================================================
build_search_terms() {
    local pkg="$1"
    local -n _bst_out=$2

    local -a _noise=(bin git stable nightly beta dev launcher
                     desktop app appimage x86 x64 amd64)
    local -A _seen=()

    _seen["$pkg"]=1
    _bst_out+=("$pkg")

    IFS='-' read -ra _parts <<< "$pkg"
    for _part in "${_parts[@]}"; do
        local _skip=false
        for _n in "${_noise[@]}"; do
            [[ "${_part,,}" == "$_n" ]] && _skip=true && break
        done
        if [[ "$_skip" == false && ${#_part} -gt 2 && -z "${_seen[$_part]+_}" ]]; then
            _seen["$_part"]=1
            _bst_out+=("$_part")
        fi
    done
}

# =============================================================================
# discover_paths <nameref-terms> <nameref-results>
#
# Walks known XDG base dirs and $HOME (hidden dirs) looking for any entry
# whose name contains one of the search terms (case-insensitive). Results are
# de-duplicated and only direct children of each base are returned so we never
# queue both a parent and its child for deletion.
# =============================================================================
discover_paths() {
    local -n _dp_terms=$1
    local -n _dp_out=$2

    local -a _bases=(
        "$HOME/.config"
        "$HOME/.local/share"
        "$HOME/.local/state"
        "$HOME/.cache"
        "$HOME/.mozilla"        # Firefox stores data here, not under .config
        "$HOME/snap"
        "$HOME/.var/app"        # Flatpak per-user data
    )

    local -A _seen_paths=()

    for _term in "${_dp_terms[@]}"; do
        # XDG bases — only direct children (maxdepth 1) to avoid queuing both
        # parent and child
        for _base in "${_bases[@]}"; do
            [[ -d "$_base" ]] || continue
            while IFS= read -r -d '' _p; do
                if [[ -z "${_seen_paths[$_p]+_}" ]]; then
                    _seen_paths["$_p"]=1
                    _dp_out+=("$_p")
                fi
            done < <(find "$_base" -maxdepth 1 -mindepth 1 \
                          -iname "*${_term}*" -print0 2>/dev/null || true)
        done

        # Hidden dirs in $HOME (e.g. ~/.vscode, ~/.spotify, ~/.mozilla)
        while IFS= read -r -d '' _p; do
            if [[ -z "${_seen_paths[$_p]+_}" ]]; then
                _seen_paths["$_p"]=1
                _dp_out+=("$_p")
            fi
        done < <(find "$HOME" -maxdepth 1 -mindepth 1 \
                      -iname "*${_term}*" -print0 2>/dev/null || true)
    done
}

# ── Build search terms ────────────────────────────────────────────────────────
SEARCH_TERMS=()
build_search_terms "$PKG" SEARCH_TERMS

header "Purging: $PKG"
info "Search terms derived: ${SEARCH_TERMS[*]}"

# ── 1. Uninstall via pacman ───────────────────────────────────────────────────
header "Step 1: Uninstall package"

if pacman -Qi "$PKG" &>/dev/null; then
    info "Removing package (pacman -Rns) …"
    sudo pacman -Rns --noconfirm "$PKG"
    success "Package '$PKG' uninstalled."
else
    warn "Package '$PKG' is not installed via pacman — skipping pacman removal."
fi

for aur_helper in yay paru; do
    if command -v "$aur_helper" &>/dev/null; then
        if "$aur_helper" -Qi "$PKG" &>/dev/null 2>&1; then
            info "Found via $aur_helper — removing …"
            "$aur_helper" -Rns --noconfirm "$PKG" 2>/dev/null || true
        fi
    fi
done

# ── 2. Discover and wipe user-level data ──────────────────────────────────────
header "Step 2: Discover and wipe user data, config, cache, and credentials"

DISCOVERED=()
discover_paths SEARCH_TERMS DISCOVERED

if [[ ${#DISCOVERED[@]} -gt 0 ]]; then
    info "Discovered ${#DISCOVERED[@]} path(s) to remove:"
    for p in "${DISCOVERED[@]}"; do
        echo "    $p"
    done
    for p in "${DISCOVERED[@]}"; do
        rm -rf -- "$p"
        success "Removed: $p"
    done
else
    info "No user-level data directories found for '${SEARCH_TERMS[*]}'."
fi

# ── 3. Wipe system-level data ─────────────────────────────────────────────────
header "Step 3: Wipe system-level data (requires sudo)"

for term in "${SEARCH_TERMS[@]}"; do
    for prefix in /etc /var/lib /var/log /var/cache /opt; do
        # One level deep so we don't accidentally nuke /etc itself
        while IFS= read -r -d '' p; do
            sudo rm -rf -- "$p"
            success "Removed (system): $p"
        done < <(find "$prefix" -maxdepth 1 -mindepth 1 \
                      -iname "*${term}*" -print0 2>/dev/null || true)
    done
done

# ── 4. Purge saved logins and credentials ─────────────────────────────────────
header "Step 4: Purge saved logins and credentials"

# Collect the basenames of every discovered path as extra keyring search terms
# (e.g. a dir named "Code" discovered for the package "code" gives us "Code"
# as a service/application name to search the keyring with).
declare -A _kring_seen=()
KEYRING_TERMS=("${SEARCH_TERMS[@]}")
for p in "${DISCOVERED[@]}"; do
    bn=$(basename "$p")
    if [[ -z "${_kring_seen[$bn]+_}" ]]; then
        _kring_seen["$bn"]=1
        KEYRING_TERMS+=("$bn")
    fi
done

# 4a. GNOME Keyring / libsecret ───────────────────────────────────────────────
if command -v secret-tool &>/dev/null; then
    info "Sweeping GNOME Keyring for: ${KEYRING_TERMS[*]} …"
    for term in "${KEYRING_TERMS[@]}"; do
        # secret-tool clear <attribute> <value> removes all items with that pair
        secret-tool clear service     "$term" 2>/dev/null || true
        secret-tool clear application "$term" 2>/dev/null || true
        secret-tool clear label       "$term" 2>/dev/null || true
    done
    success "Keyring sweep complete."
else
    warn "secret-tool not found — skipping GNOME Keyring cleanup."
    warn "Install with: sudo pacman -S libsecret"
fi

# 4b. KDE Wallet ──────────────────────────────────────────────────────────────
if command -v kwallet-query &>/dev/null; then
    info "Searching KDE Wallet …"
    for term in "${KEYRING_TERMS[@]}"; do
        kwallet-query kdewallet -l 2>/dev/null | grep -i "$term" | while read -r entry; do
            kwallet-query kdewallet -d "$entry" 2>/dev/null || true
            success "Removed KWallet entry: $entry"
        done
    done
fi

# ── 5. Flatpak cleanup ────────────────────────────────────────────────────────
header "Step 5: Flatpak cleanup"

if command -v flatpak &>/dev/null; then
    for term in "${SEARCH_TERMS[@]}"; do
        mapfile -t FLATPAK_IDS < <(flatpak list --columns=application 2>/dev/null \
            | grep -i "$term" || true)
        for fid in "${FLATPAK_IDS[@]}"; do
            [[ -z "$fid" ]] && continue
            info "Removing Flatpak app: $fid"
            flatpak uninstall --delete-data -y "$fid" 2>/dev/null || true
            [[ -d "$HOME/.var/app/$fid" ]] && rm -rf -- "$HOME/.var/app/$fid" \
                && success "Removed Flatpak data: $HOME/.var/app/$fid"
        done
    done
    info "Flatpak sweep complete."
else
    info "Flatpak not installed — skipping."
fi

# ── 6. Snap cleanup ───────────────────────────────────────────────────────────
header "Step 6: Snap cleanup"

if command -v snap &>/dev/null; then
    if snap list "$PKG" &>/dev/null 2>&1; then
        info "Removing snap package: $PKG"
        sudo snap remove --purge "$PKG" 2>/dev/null || true
        success "Snap '$PKG' removed."
    else
        info "No snap installation found for '$PKG'."
    fi
else
    info "Snap not installed — skipping."
fi

# ── 7. Remove leftover desktop & autostart entries ────────────────────────────
header "Step 7: Remove desktop entries and autostart files"

DESKTOP_DIRS=(
    "$HOME/.local/share/applications"
    "/usr/local/share/applications"
    "/usr/share/applications"
)

for dir in "${DESKTOP_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    for term in "${SEARCH_TERMS[@]}"; do
        while IFS= read -r f; do
            sudo rm -f -- "$f" 2>/dev/null || rm -f -- "$f" 2>/dev/null || true
            success "Removed desktop entry: $f"
        done < <(find "$dir" -iname "*${term}*.desktop" 2>/dev/null || true)
    done
done

for term in "${SEARCH_TERMS[@]}"; do
    autostart="$HOME/.config/autostart/${term}.desktop"
    [[ -f "$autostart" ]] && rm -f -- "$autostart" && success "Removed autostart: $autostart"
done

# ── 8. Remove orphaned dependencies ──────────────────────────────────────────
header "Step 8: Remove orphaned dependencies"

mapfile -t ORPHANS < <(pacman -Qdtq 2>/dev/null || true)
if [[ ${#ORPHANS[@]} -gt 0 ]]; then
    info "Found orphaned packages:"
    printf '  %s\n' "${ORPHANS[@]}"
    read -rp "$(echo -e "${YELLOW}Remove all orphaned packages? [y/N]:${RESET} ")" confirm
    if [[ "${confirm,,}" == "y" ]]; then
        sudo pacman -Rns --noconfirm "${ORPHANS[@]}"
        success "Orphans removed."
    else
        info "Skipped orphan removal."
    fi
else
    info "No orphaned packages found."
fi

# ── 9. Clear pacman cache for this package ────────────────────────────────────
header "Step 9: Clear pacman package cache"

sudo find /var/cache/pacman/pkg/ -iname "${PKG}-*.pkg.tar.*" -delete 2>/dev/null || true
success "Pacman cache cleared for '$PKG'."

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗"
printf  "${GREEN}${BOLD}║  ✔  %-48s║\n${RESET}" "'$PKG' has been completely purged."
echo -e "${GREEN}${BOLD}║     Reinstall fresh: sudo pacman -S $PKG"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
