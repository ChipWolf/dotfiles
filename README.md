etc
===

Configuration files for backup/sync between systems.

## Usage

 1. Clone: `git clone --recursive git@github.com:ChipWolf/etc.git ~/.etc`
 2. Backup: `~/.etc/link.sh/link.sh -u ~/.etc/.link.conf -b`
 3. Link: `~/.etc/link.sh/link.sh -u ~/.etc/.link.conf -wf`

### Remove PS
_~/.etc/zsh/zsh-os-conf/local-pre/00-bullettrain.zsh_
```
BULLETTRAIN_CONTEXT_DEFAULT_USER=Chip
DEFAULT_USER=Chip
```
