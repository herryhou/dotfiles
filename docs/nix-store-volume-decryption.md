# Nix Store volume decryption (2026-11-18)

Machine ran the Determinate Nix Installer, which creates the `/nix` store as an
**APFS-encrypted** volume. On some boots the automatic unlock failed and macOS
showed a passphrase dialog for `/nix` at startup.

## How `/nix` actually mounts (no chicken-and-egg)

Mounting the store never requires the `nix` binary inside it:

- `/etc/synthetic.conf` creates the `/nix` mountpoint
- `/etc/fstab` maps the volume UUID to `/nix` (`noauto`, so boot never blocks on it)
- `/Library/LaunchDaemons/systems.determinate.nix-store.plist` runs
  `/usr/local/bin/determinate-nixd init` at boot - a binary on the Data volume,
  outside the store - which unlocks and mounts the volume
- Store-resident daemons wait for the mount first (the hook runs
  `/bin/wait4path /nix/nix-installer && /nix/nix-installer repair`)

## Recovery when `/nix` fails to mount

Cancel the boot dialog, log in, then:

```bash
sudo /usr/local/bin/determinate-nixd init   # unlock + mount
mount | grep /nix                            # verify
tail /var/log/determinate-nix-init.log       # debug
```

## Permanent fix: decrypt the volume (applied)

The passphrase is the random string the installer generated, not the login
password. It is stored in the System Keychain (service/account `"Nix Store"`).
Pull it from there instead of typing it:

```bash
sudo diskutil apfs decryptVolume disk3s7 \
  -passphrase "$(security find-generic-password -a 'Nix Store' -s 'Nix Store' -w)"
```

Verify: `diskutil info disk3s7` shows `FileVault: No` and
`diskutil apfs listCryptoUsers disk3s7` reports no cryptographic users. After
this, boots mount `/nix` silently - no dialog, no typed passphrase.

Notes:

- The disk identifier (`disk3s7` here) can differ; find it with
  `diskutil apfs list`.
- The `"Nix Store"` System Keychain entry is unused now that the volume is
  decrypted, and since 2026-11-18 `determinate-nixd init` is disabled anyway -
  fstab auto-mounts `/nix` (`noauto` removed; see `docs/slow-restart.md`).
  Still, do not delete the entry: if you ever roll back to the daemon-managed
  setup, `determinate-nixd init` looks it up on every boot and fails outright
  (`Keychain error: Not found`) when it is missing. If the entry was already
  deleted, recreate it with a placeholder value - the value is never tried
  against the now-unencrypted volume:

  ```bash
  sudo security add-generic-password -a 'Nix Store' -s 'Nix Store' \
    -l 'Nix Store' -w 'unused-decrypted' /Library/Keychains/System.keychain
  ```
- Tradeoff: the store is no longer encrypted at rest. It is a rebuildable
  package cache, so this was accepted.
- After decryption the boot log turns noisy but harmless:
  `/var/log/determinate-nix-init.log` shows an ERROR every boot
  (`The given APFS Volume is not locked (-69589)`); determinate-nixd falls back
  to mounting the unlocked volume directly and succeeds. Do not chase it.

## Keep Spotlight off `/nix` (slow post-login boots)

Once `/nix` mounts at every boot, Spotlight crawls it - tens of thousands of
store-path files - and pins `mds_stores` at ~100% CPU for minutes after login.
Measured on 2026-11-18: 14s to the login window, then load average 33 by +3
min with `mds_stores` at 117% CPU. Store paths are content hashes, so indexing
the volume is pure waste.

```bash
mdutil -s /nix             # want: Indexing disabled.
sudo mdutil -i off /nix    # one-time; persists across reboots
```

If boots get slow again after a nix uninstall/reinstall, re-check
`mdutil -s /nix` first.
