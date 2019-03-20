Dotfiles
===

Configuration files for backup/sync between systems.

![](https://i.cwlf.uk/rlPOb)

## Usage

 1. Clone: `git clone --recursive git@github.com:ChipWolf/etc.git ~/.etc`
 2. Backup: `~/.etc/link.sh/link.sh -u ~/.etc/.link.conf -b`
 3. Link: `~/.etc/link.sh/link.sh -u ~/.etc/.link.conf -wf`

### Remove user@hostname from prompt
_~/.etc/zsh/zsh-os-conf/local-pre/00-bullettrain.zsh_
```
BULLETTRAIN_CONTEXT_DEFAULT_USER=$USER
DEFAULT_USER=$USER
```

#### Screnshot Workflow (Automator)
```
screencapture -c -s && export PATH=/usr/local/bin:$PATH && pngpaste - | curl -X POST --data-binary @- https://i.cwlf.uk/ | pbcopy && afplay /System/Library/Sounds/Glass.aiff
```

#### iTerm config
- Tomorrow Night (included; tomorrow-night.itermcolor)
- Operator Mono 14pt (ASCII)
- monofur for Powerline 14pt (non-ASCII)
