# Slow restart diagnosis (2026-11-18)

**Solved: the ~30s login stall.** One boot with all three Surfshark system
extensions disabled collapsed boot→desktop from ~45s to ~17s. Surfshark's
extensions were gating loginwindow's authorization chain.

**Still open: the post-login load storm** - ~495K log lines in the 2 minutes
after Finder even without Surfshark (568–620K with it, ~680K before the
app-restore fix). Load ~76 at +1min, settled by +5min.

## Final timeline comparison (password ~+12s in every boot)

| Boot | Surfshark sysexts | `/nix` mount | Finder | Stall |
|---|---|---|---|---|
| 15:31, 21:44, 21:47, 22:07 | active | +43s (daemon) / +5s (fstab) | +45–47s | **~30s** |
| 22:35 | disabled | +5s (fstab) | **+17.4s** | ~2s |

## Root cause: Surfshark system extensions

loginwindow runs its login-authorization mechanism chain after FileVault
unlock. With Surfshark's extensions active, a `ctkd` (CryptoTokenKit) request
in that chain hangs ~18s mid-stall - ctkd is spawned by an `accessoryd`
token-client request and joined by `mobileactivationd` (device-activation
traffic, i.e. network) - and login proceeds the instant coreauthd cancels it.
Three extensions were installed (team `YHUG37CKN8`): PacketTunnel-Dausos,
PacketTunnel-WireGuard (network), and the Antivirus endpoint-security
extension. A second A/B boot (22:44, network extensions + app autostart
re-enabled, **Antivirus left disabled**) stayed fast at +16.1s with the tunnel
running - so the **Antivirus endpoint-security extension** is the specific
gating component, not the VPN tunnels. Endpoint-security clients observe (and
can delay) authorization events via `endpointsecurityd`; Surfshark's AV module
- also the worst CPU-wake offender measured that morning at 1317 wakes/sec -
does not answer promptly during early boot, and loginwindow's auth chain waits
out a ~30s timeout before proceeding.

### How Surfshark was disabled for the test

Killing processes doesn't stick (`sysextd` relaunches them) and
`systemextensionsctl uninstall` is blocked by SIP. What works:
**System Settings → General → Login Items & Extensions →** toggle Surfshark
off under both **Network Extensions** and **Endpoint Security Extensions**.
Extensions then show `[activated disabled]` in `systemextensionsctl list` and
do not load at boot. Re-enable the toggles to restore.

### Final Surfshark config (resolved 2026-11-18)

- App: stays in Login Items, auto-starts - normal usage.
- Network Extensions (Dausos + WireGuard toggles): **enabled** - VPN works.
- Endpoint Security Extensions (Antivirus toggle): **leave OFF**. It gates
  login by ~30s and burns CPU wakes; macOS's built-in XProtect/Gatekeeper
  cover the malware-defense role.
- If boots get slow again after a Surfshark update, check first whether the
  Antivirus toggle re-enabled itself (updates can re-prompt for the ES
  extension).
- Worth reporting Surfshark v4.30.2 as regressing login on macOS 27.2 - the
  30s timeout signature is visible in every gated boot's unified log.

## The pre-Finder stall anatomy (with Surfshark active - for reference)

| Offset | Event |
|---|---|
| +0s | kernel boot |
| +5s | login window up |
| +12s | password verified; FileVault keybag unlocks; Data mounts |
| +14s | full loginwindow spawned |
| +14–43s | **stall**: silent except background daemons |
| +25s | `ctkd` spawned (accessoryd token-client request; mobileactivationd follows) |
| +25–43s | ctkd's LocalAuthentication request hangs |
| +42.7s | coreauthd cancels → authd completes → SecurityAgent[636] → `gui/501` domain |
| +45s | Finder |

determinate-nixd was exonerated by A/B test (2026-11-18 22:07 boot: daemon
disabled + fstab `noauto` removed → `/nix` up at +5s, Finder unchanged).
That setup is **kept**: simpler boot path, one less daemon, nix-daemon and
nix-hook still enabled. Trade-off: determinate no longer syncs Nix trusted
certs from the Keychain per boot (only matters for corporate CAs). Rollback:

```bash
sudo launchctl enable system/systems.determinate.nix-store
# re-add "noauto" to the /nix line in /etc/fstab
```

## Post-login load storm (still open, mostly not Surfshark)

2 minutes after Finder: 495K lines without Surfshark / 568–620K with /
~680K before the `TALLogoutSavesState` fix. App restore was a small share;
Surfshark ~15%; the rest is macOS 27.2 session bring-up.

Top emitters in the 55s around Finder (lines / errors):

| Process | Lines | Errors | Notes |
|---|---|---|---|
| audiomxd | 73K | 8.3K | TCC XPC retry loop ("No user logged in") during session bring-up |
| runningboardd | 42K | 1K | state-update verbosity |
| Siri AI | 31K | 0.2K | Spotlight apps reindex |
| trustd | 31K | 0 | cert evaluation for every newly launched process |
| cfprefsd | 17K | 16.3K | sandbox rejections (contextstored mediaremote reads) |
| suggestd | 17K | 0 | |

All system daemons without a clean config lever; the storm self-resolves by
+5min. Treat as low priority unless the machine feels unusable during it.

Measurement caveat: `uptime` run *after* `log show` scans reports load partly
caused by those scans. Run `uptime` first, or sample
`top -l 1 -o cpu -n 10` at +60s.

## Verified fixed (do not re-chase)

- Login stall: Surfshark extensions (see root cause above).
- determinate-nixd: not on the login path (A/B tested; setup kept).
- Kernel CPU-wake violations: zero hits on the 21:44/21:47 boots.
- App restore on restart: `TALLogoutSavesState = 0` live; no ~10-app relaunch.
- `/nix` decryption + Spotlight: `FileVault: No`, `mdutil -s /nix` →
  `Indexing disabled.`. (storagekitd logging `Encrypted: Yes` early in boot is
  stale cache; `diskutil info` is authoritative.)
- Shutdown: teardown ends ~17s before the next kernel boot - fast.

## Re-measuring a slow boot

```bash
uptime                                                        # BEFORE log scans inflate it
sysctl kern.boottime
/usr/bin/log show -l boot --style compact | grep -m1 'Finder\['   # desktop time
/usr/bin/log show -l boot --style compact | grep 'caught waking the CPU'
/usr/bin/log show --start '<boot+45s>' --end '<boot+2min>' --style compact | wc -l  # storm size
top -l 1 -o cpu -n 10 -stats pid,command,cpu,time
```

Note: a `log` shell function shadows the binary in some shells here; use
`/usr/bin/log` when scripting.
