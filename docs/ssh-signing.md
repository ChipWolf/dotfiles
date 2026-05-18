# SSH commit signing (Windows + TPM)

This dotfiles repo enables SSH-format git commit signing on Windows with the key sealed in the TPM via `ssh-tpm-agent`. GPG-format signing is the standard on Unix machines in this repo, but is not viable on Windows: gpg4win has no path to the TPM (`scdaemon` speaks CCID; the TPM is exposed via Windows CNG; the bridge `gnupg-pkcs11-scd` + `tpm2-pkcs11` is unmaintained on Windows). SSH commit signing (`gpg.format = ssh`) plus `ssh-tpm-agent` is the modern Windows-native alternative.

## Requirements

- Windows 11 with TPM 2.0
- git >= 2.34 (already installed via Chocolatey)
- `gh` CLI authenticated
- `sshSigning.enabled: true` in `home/.chezmoidata/ssh-signing.yaml`

## First-time per-machine setup

After running `chezmoi apply` on a fresh Windows machine (so `ssh-tpm-agent.exe` is installed and the Windows ssh-agent service is disabled), run:

```powershell
# Generate a TPM-sealed signing key (ECDSA P-256, default).
# Outputs ~/.ssh/id_ecdsa.tpm (sealed) + ~/.ssh/id_ecdsa.tpm.pub (public).
ssh-tpm-keygen -t ecdsa -C "hello@chipwolf.uk"

# Upload public key to GitHub as a Signing Key (separate from auth).
gh ssh-key add ~/.ssh/id_ecdsa.tpm.pub --type signing --title "$env:COMPUTERNAME (TPM)"

# Print the YAML stanza to paste into home/.chezmoidata/ssh-signing.yaml.
$pub = (Get-Content ~/.ssh/id_ecdsa.tpm.pub).Trim()
@"
    - host: "$($env:COMPUTERNAME.ToLower())"
      type: "tpm"
      pubkey: "$pub"
"@
```

Then paste the stanza into the `keys:` list of `home/.chezmoidata/ssh-signing.yaml`, flip `enabled: true` if not already, commit the change, and run `chezmoi apply` again so `~/.ssh/allowed_signers` re-renders and gitconfig activates SSH signing.

Test with:

```powershell
git commit --allow-empty -m "test"
git log --show-signature -1
```

## Adding more Windows machines

Same flow. Each Windows host has its own TPM-sealed key (TPM blobs are not portable). Each host generates its own, uploads its own public key to GitHub, and adds its own entry to the `keys:` list. After the YAML change is committed, every machine (Windows, macOS, Linux, WSL) running `chezmoi apply` will pick up the new entry in `~/.ssh/allowed_signers` and can locally verify that machine's signed commits.

## Health-check commands

```powershell
# 1. Windows ssh-agent service disabled?
Get-Service ssh-agent | Select-Object Status, StartType
# Expect: Status=Stopped, StartType=Disabled

# 2. ssh-tpm-agent running?
Get-Process ssh-tpm-agent -ErrorAction SilentlyContinue

# 3. Named pipe up?
Test-Path \\.\pipe\openssh-ssh-agent
# Expect: True

# 4. Agent serving the TPM key?
ssh-add -L
# Expect: ecdsa-sha2-nistp256 AAAA... <comment>
```

## Troubleshooting

- `ssh-tpm-keygen: cannot find binary` -- the install script did not run, or the `REPLACE_WITH_RELEASE_SHA256` placeholder is still in `home/.chezmoidata/ssh-tpm-agent.yaml`. Set the real SHA256 from the GitHub release `SHA256SUMS` file and re-run `chezmoi apply`.
- `communication with agent failed` -- the Windows built-in `ssh-agent` service is still running and holding the named pipe. Check with `Get-Service ssh-agent`; if it shows Running or StartType=Manual, the disable script did not fire (verify `sshSigning.enabled: true`).
- `gpg failed to sign the data` -- gitconfig may not be using SSH format. Confirm with `git config --get gpg.format` (expect `ssh`) and `git config --get gpg.ssh.program` (expect the Windows OpenSSH path).
- `sign_and_send_pubkey: signing failed: agent refused operation` -- `ssh-tpm-agent.exe` is not running. Restart with `Start-Process ssh-tpm-agent.exe -WindowStyle Hidden`, or log out and back in to fire the Run-key autostart.
- First sign of a session is slow (1-2s) -- TPM init latency. Subsequent signs are ~200ms.
- TPM cleared (BIOS update, factory reset) -- the sealed key blob is now unusable. Regenerate, upload a new pubkey to GitHub, replace the YAML entry, and remove the old key from GitHub.

## Relationship to other identity

- **GPG:** superseded for Windows git signing. The legacy `0x4C90101E11349775` reference stays commented in `home/.chezmoidata/profile.yaml` as a recoverable breadcrumb.
- **YubiKey FIDO2 SSH auth** (`docs/yubikey.md`): unchanged. Different key (`~/.ssh/id_ed25519_sk`), different purpose (SSH transport for git push). The TPM key is only for signing.
- **Optional quieting:** ssh-tpm-agent loads the TPM key into the SSH agent, so `ssh` will offer it to remote hosts during auth, even though GitHub only accepts it as a signing key. This is harmless (auth falls through to the YubiKey) but produces "tried key X" lines on `git push`. Silence with this in `~/.ssh/config`:

  ```
  Host github.com
    IdentitiesOnly yes
    IdentityFile ~/.ssh/id_ed25519_sk
  ```
