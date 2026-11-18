# Nix Store volume decryption (2026-11-18)

Machine ran the Determinate Nix Installer, which creates the `/nix` store as an
**APFS-encrypted** volume. On some boots the automatic unlock failed and macOS
showed a passphrase dialog for `/nix` at startup.

## How `/nix` actually mounts (no chicken-and-egg)

Mounting the store never requires the `nix` binary inside it:

- `/etc/synthetic.conf` creates the `/nix` mountpoint
- `/etc/fstab` maps the volume UUID to `/nix` (`noauto`, so boot never blocks on it)
- `/Library/LaunchDaemons/systems.determinate.nix-store.plist` runs
  `/usr/local/bin/determinate-nixd init` at boot — a binary on the Data volume,
  outside the store — which unlocks and mounts the volume
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
this, boots mount `/nix` silently — no dialog, no `init` needed.

Notes:

- The disk identifier (`disk3s7` here) can differ; find it with
  `diskutil apfs list`.
- The keychain entry is vestigial afterwards. Optional cleanup:
  `sudo security delete-generic-password -a 'Nix Store' -s 'Nix Store' /Library/Keychains/System.keychain`
- Tradeoff: the store is no longer encrypted at rest. It is a rebuildable
  package cache, so this was accepted.
