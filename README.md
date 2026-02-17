# arch-purge

A comprehensive Arch Linux utility to **completely uninstall an application** and wipe every trace it left behind — config, cache, logs, saved credentials, desktop entries, Flatpak/Snap installs, and orphaned dependencies.

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

```bash
./arch-purge.sh <package-name>
```

### Examples

```bash
./arch-purge.sh firefox
./arch-purge.sh discord
./arch-purge.sh spotify-launcher
./arch-purge.sh code
./arch-purge.sh visual-studio-code-bin
./arch-purge.sh steam
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
arch-purge firefox
arch-purge discord
```

To remove it:

```bash
sudo rm /usr/local/bin/arch-purge
```

### Option B — Add the script's directory to your `PATH`

If you prefer to keep the script in its current location, add the directory to your shell's `PATH`.

For **zsh** (edit `~/.zshrc`):

```bash
echo 'export PATH="$HOME/Music/purge apps:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Then call it as:

```bash
arch-purge.sh discord
```

### Option C — Shell alias (quickest, no PATH changes)

```bash
echo "alias arch-purge='bash \"$HOME/Music/purge apps/arch-purge.sh\"'" >> ~/.zshrc
source ~/.zshrc
```

---

## Removing from the system (uninstall)

If you installed via **Option A**, remove the binary from `/usr/local/bin`:

```bash
sudo rm /usr/local/bin/arch-purge
```

If you added a **PATH entry** (Option B), remove the line from `~/.zshrc`:

```bash
# Open ~/.zshrc in your editor and delete the line:
# export PATH="$HOME/Music/purge apps:$PATH"
source ~/.zshrc
```

If you added an **alias** (Option C), remove the alias from `~/.zshrc`:

```bash
# Open ~/.zshrc in your editor and delete the line:
# alias arch-purge='bash "$HOME/Music/purge apps/arch-purge.sh"'
source ~/.zshrc
```

---

## Notes & caveats

- The script uses `rm -rf` on discovered directories. Double-check the discovered paths printed in **Step 2** before the deletions proceed if you are unsure.
- System-level deletions (Steps 3, 9) require `sudo`. You will be prompted for your password if your session has expired.
- Orphan removal in Step 8 is **interactive** — you are asked to confirm before any orphaned packages are removed.
- The script does **not** delete `~/.local/share/recently-used.xbel` entries or browser history inside a profile that is shared with other apps. Remove those manually if needed.
- If a package is installed as both a native package and a Flatpak, both will be removed in the same run.
