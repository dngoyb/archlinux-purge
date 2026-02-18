# arch-purge

A comprehensive Arch Linux utility to **completely uninstall an application** and wipe every trace it left behind — config, cache, logs, saved credentials, desktop entries, Flatpak/Snap installs, and orphaned dependencies.

**Now with interactive mode** — search for packages visually and select which one to remove!

---

## What it does

| Step | Action |
|------|--------|
| 1 | Uninstalls the package via `pacman -Rns` (also checks `yay`/`paru` for AUR packages) |
| 2 | Discovers and deletes all user-level data (`~/.config`, `~/.local/share`, `~/.cache`, `~/.local/state`, `~/snap`, `~/.var/app`, hidden `~/.*` dirs) |
| 3 | Wipes system-level leftovers under `/etc`, `/var/lib`, `/var/log`, `/var/cache`, `/opt` |
| 4 | Purges saved logins and credentials from GNOME Keyring (`secret-tool`) and KDE Wallet (`kwallet-query`) |
| 5 | Removes the matching Flatpak app and its data (`~/.var/app/<id>`) |
| 6 | Removes the matching Snap package with `--purge` |
| 7 | Deletes leftover `.desktop` entries and autostart files |
| 8 | Optionally removes orphaned dependencies (`pacman -Qdtq`) |
| 9 | Clears the pacman package cache for the removed package |

The script is smart about name matching: it derives search terms from the package name by splitting on hyphens and discarding generic AUR suffixes (`bin`, `git`, `launcher`, `nightly`, etc.), so `visual-studio-code-bin` correctly searches for "visual", "studio", and "code" without chasing false positives.

---

## Features

- **🔍 Interactive Mode** — Don't remember the exact package name? Run without arguments and search interactively
- **🛡️ Safety First** — Only shows installed packages, confirms before removal, dry-run support
- **📋 Package Listing** — View all installed packages with `--list`
- **🔮 Dry Run** — Preview what would be removed with `--dry-run` (no actual changes)
- **🧹 Complete Cleanup** — Removes package, config files, cache, credentials, and orphaned deps

---

## Requirements

- Arch Linux (or any Arch-based distro — Manjaro, EndeavourOS, CachyOS, etc.)
- `bash` 4.3+ (uses namerefs)
- `pacman` (core requirement)
- `sudo` privileges
- Optional but recommended: `libsecret` (`secret-tool`) for keyring cleanup

```bash
sudo pacman -S libsecret
```

---

## Usage

### Interactive Mode (Recommended)

Run without arguments to search for packages interactively:

```bash
arch-purge
```

Then type part of the package name and press Enter:
```
Search for app to remove: spotify
Found packages:
   1) spotify
   2) spotify-adblock-git
   0) Cancel

Select package to remove [0-2]: 1
```

### Direct Removal

Remove a specific package by name:

```bash
arch-purge firefox
arch-purge discord
arch-purge visual-studio-code-bin
```

### Command-Line Options

| Flag | Description |
|------|-------------|
| `-h, --help` | Show detailed help message |
| `-l, --list` | List all installed packages |
| `-d, --dry-run` | Preview what would be removed (no changes) |
| `-i, --interactive` | Force interactive mode |

### Examples

```bash
# Show help
arch-purge --help

# List all installed packages
arch-purge --list

# Preview what would be removed for firefox (safe)
arch-purge --dry-run firefox

# Interactive search mode
arch-purge --interactive

# Remove spotify directly
arch-purge spotify
```

---

## Adding to the system (install system-wide)

To run `arch-purge` from anywhere without specifying the full path:

### Option A — Copy to `/usr/local/bin` (recommended)

```bash
sudo cp arch-purge.sh /usr/local/bin/arch-purge
sudo chmod +x /usr/local/bin/arch-purge
```

Now you can call it from any terminal:

```bash
# Interactive mode
arch-purge

# Direct removal
arch-purge firefox
arch-purge discord

# Other options
arch-purge --list
arch-purge --dry-run spotify
```

To remove it:

```bash
sudo rm /usr/local/bin/arch-purge
```

### Option B — Add the script's directory to your `PATH`

If you prefer to keep the script in its current location, add the directory to your shell's `PATH`.

For **zsh** (edit `~/.zshrc`):

```bash
echo 'export PATH="$HOME/Music/archlinux-purge:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Then call it as:

```bash
arch-purge.sh discord
```

### Option C — Shell alias (quickest, no PATH changes)

```bash
echo "alias arch-purge='bash \"$HOME/Music/archlinux-purge/arch-purge.sh\"'" >> ~/.zshrc
source ~/.zshrc
```

---

## Safety Features

- ✅ **Package verification** — Checks that the package is actually installed before attempting removal
- ✅ **Confirmation prompt** — Asks for confirmation before removing anything
- ✅ **Dry-run mode** — Preview exactly what would be removed without making changes
- ✅ **Graceful errors** — If a package isn't found, suggests using `--list` or interactive mode
- ✅ **Installed-only search** — Interactive mode only shows packages you actually have installed

---

## Removing from the system (uninstall)

If you installed via **Option A**, remove the binary from `/usr/local/bin`:

```bash
sudo rm /usr/local/bin/arch-purge
```

If you added a **PATH entry** (Option B), remove the line from `~/.zshrc`:

```bash
# Open ~/.zshrc in your editor and delete the line:
# export PATH="$HOME/Music/archlinux-purge:$PATH"
source ~/.zshrc
```

If you added an **alias** (Option C), remove the alias from `~/.zshrc`:

```bash
# Open ~/.zshrc in your editor and delete the line:
# alias arch-purge='bash "$HOME/Music/archlinux-purge/arch-purge.sh"'
source ~/.zshrc
```

---

## Notes & caveats

- The script uses `rm -rf` on discovered directories. Double-check the discovered paths printed in **Step 2** before the deletions proceed if you are unsure.
- System-level deletions (Steps 3, 9) require `sudo`. You will be prompted for your password if your session has expired.
- Orphan removal in Step 8 is **interactive** — you are asked to confirm before any orphaned packages are removed.
- The script does **not** delete `~/.local/share/recently-used.xbel` entries or browser history inside a profile that is shared with other apps. Remove those manually if needed.
- If a package is installed as both a native package and a Flatpak, both will be removed in the same run.
