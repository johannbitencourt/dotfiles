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

## Restore

Review differences before replacing an existing configuration. Omarchy may
change its plugin API between releases.

```bash
mkdir -p ~/.config/omarchy/plugins
cp -a omarchy/plugins/johann.bar ~/.config/omarchy/plugins/
cp -a omarchy/plugins/johann.menu ~/.config/omarchy/plugins/
cp -a omarchy/plugins/johann.audio ~/.config/omarchy/plugins/
cp -a omarchy/plugins/johann.cpu ~/.config/omarchy/plugins/
cp omarchy/shell.json ~/.config/omarchy/shell.json
omarchy restart shell
```

The shell layout uses built-in Omarchy widgets alongside the four cloned user
plugins, so restoring it requires an installed Omarchy shell.
