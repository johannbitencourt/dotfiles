# Omarchy top bar snapshot

This directory snapshots the active Omarchy shell layout and every user plugin
referenced by that layout:

- `johann.bar`
- `johann.menu`
- `johann.audio`
- `johann.cpu`

It intentionally lives outside `config/`. The repository's generic installer
links each top-level directory under `config/` into `~/.config`; putting this
snapshot there could replace Omarchy's package-managed user configuration.

The shell layout uses built-in Omarchy widgets alongside the four cloned user
plugins, so restoring it requires an installed Omarchy shell.

## Install on another device

Review differences before replacing an existing configuration. These plugins
use Omarchy's shell APIs, which can change between releases.

### 1. Prepare Omarchy

Install Omarchy and finish its initial setup. Use a reasonably current Omarchy
release, then confirm its stock shell starts successfully before applying this
snapshot.

### 2. Clone this branch

```bash
git clone --branch feat/omarchy-top-bar \
  https://github.com/johannbitencourt/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

If `~/dotfiles` already exists, fetch and switch instead:

```bash
cd ~/dotfiles
git fetch origin
git switch feat/omarchy-top-bar
git pull --ff-only
```

### 3. Back up the device's Omarchy configuration

Do not skip this step. Keep the printed path for the rollback procedure.

```bash
backup="$HOME/.config/omarchy.backup.$(date +%Y%m%d-%H%M%S)"
cp -a ~/.config/omarchy "$backup"
printf 'Backup: %s\n' "$backup"
```

### 4. Install the cloned plugins

```bash
mkdir -p ~/.config/omarchy/plugins
cp -a omarchy/plugins/johann.bar ~/.config/omarchy/plugins/
cp -a omarchy/plugins/johann.menu ~/.config/omarchy/plugins/
cp -a omarchy/plugins/johann.audio ~/.config/omarchy/plugins/
cp -a omarchy/plugins/johann.cpu ~/.config/omarchy/plugins/
```

### 5. Install the shell layout

This replaces the device's current bar layout, idle timers, and plugin enablement
stored in `shell.json`. The backup from step 3 preserves the previous values.

```bash
cp omarchy/shell.json ~/.config/omarchy/shell.json
```

### 6. Rescan and restart the shell

```bash
omarchy-shell shell rescanPlugins
omarchy restart shell
```

The top bar should now use `johann.bar`, with `johann.menu`, `johann.audio`, and
`johann.cpu` in the layout.

### 7. Verify the installation

```bash
omarchy plugin list
qs log -p /usr/share/omarchy/shell --tail 100
```

Confirm that all four `johann.*` plugins are listed and that the end of the shell
log contains `Configuration Loaded` without a plugin loading error. Portal and
stale MPRIS warnings are unrelated to this bar snapshot.

## Update an installed snapshot

Fetch the branch, make a new backup as in step 3, repeat steps 4 through 6, and
verify again. Do not run the repository's generic `install.sh` for this snapshot;
the `omarchy/` directory is intentionally installed manually.

## Roll back

Replace the example value of `backup` with the path printed in step 3. Moving
the failed configuration aside instead of deleting it keeps both versions
recoverable.

```bash
backup="$HOME/.config/omarchy.backup.YYYYMMDD-HHMMSS"
mv ~/.config/omarchy \
  "$HOME/.config/omarchy.failed.$(date +%Y%m%d-%H%M%S)"
cp -a "$backup" ~/.config/omarchy
omarchy restart shell
```
