# Honor Magic8 Pro — Privacy & Ad-Surface Hardening

A reproducible, **reversible** set of KernelSU modules + scripts that reduce ad surfaces,
telemetry and tracker exposure on an Honor Magic8 Pro (MagicOS 11 / Android 17).

---

> ## ⚠️ This project requires root
>
> **Every module here needs root (KernelSU) to do anything.** Without root,
> `pm disable` on another package's component fails with
> `SecurityException: Shell cannot change component state`, and `/data/adb/modules/`
> is never executed.
>
> **How root is obtained on this device:** it is a *device-specific kernel exploit*
> (CVE-2026-98260 class, delivered by a third-party temporary-root tool) that loads
> `kernelsu.ko` at runtime. Details are deliberately omitted here.
>
> Consequences you must accept before using this repo:
>
> - **Root does not survive a reboot.** The bootloader is locked
>   (`ro.boot.flash.locked=1`), `/system` is read-only erofs under
>   `dm-verity=enforcing`, so there is no supported way to persist a patched kernel.
>   Root must be re-acquired after every boot.
> - **Exploit-based root carries real risk**, including kernel panics and data loss.
>   Nothing in this repository is a substitute for the exploit's own safety notes.
> - The modules here only automate the *cleanup* after root is obtained — they do not
>   obtain root, and they do not make root persistent.
>
> If your device is not rooted, or you are not willing to run an exploit on it,
> **this repository is not for you.** Nothing here is needed to read the documentation.

---

> Tested on one device (Honor Magic8 Pro, MagicOS 11.0.0, Android 17, arm64).
> Everything here is **opt-in, idempotent and reversible**. Nothing touches `/system`
> or any verified partition.

## Requirements

| Requirement | Notes |
|---|---|
| **Root (KernelSU)** | mandatory; `ksud` must be at `/data/adb/ksud` |
| KernelSU ≥ 3.x | for `ksud module action`, and `late-load` stage script execution |
| Honor Magic8 Pro / MagicOS 11 | package names and `settings` keys are MagicOS-specific |
| `adb` (optional) | for installation and verification |

## What this is

| Layer | Where it lives | Survives reboot | Needs root |
|---|---|---|---|
| `pm disable-user` (app freeze) | `/data/system/users/0/package-restrictions.xml` | ✅ | once |
| `pm disable pkg/component` (component-level) | same | ✅ | once |
| `appops` / permission revoke | `/data/system/appops/` | ✅ | once |
| `settings put` keys | `settings_global.xml` / `settings_secure.xml` | ✅ | once |
| Proxy route rules (AsteriskBOX / sing-box) | app's own Room DB | ✅ | once |
| KernelSU modules (this repo) | `/data/adb/modules/` | ✅ | at apply time |
| iptables rules (TPROXY, port lockdown) | kernel memory | ❌ rebuilt | at runtime |

**Key idea:** root is only needed as a *one-shot scalpel*. The effects live in `/data`,
so they persist even after root is gone. Only runtime state (iptables, daemons) is rebuilt —
and the KernelSU modules in this repo do that automatically the moment root appears.

## Layout

```
kernelsu-modules/          six independent KernelSU modules (enable/disable separately)
  a0-privacy-settings/     38 settings keys + deeplink interception
  a1-privacy-ops/          appops + sensitive-permission revoke
  a2-honor-ads-freeze/     9 packages frozen (pm disable-user)
  a3-honor-ads-components/ 124 com.hihonor.adsdk.* components
  a4-abox-lockdown/        loopback port lockdown for the proxy app
  a5-notif-channels/       32 marketing notification channels blocked at channel level
docs/
  01-persistence-model.md          what survives reboot vs what does not
  02-kernelsu-modules.md           module structure, execution order, four gotchas
  03-ad-surface-inventory.md       where ad slots / trackers actually live on MagicOS
  04-proxy-detectability.md        can apps detect a transparent proxy? what leaks
  05-tailscale-coexistence.md      running Tailscale and a TPROXY proxy together
scripts/
  notif-channel-dex/        host-side channel CLI + the smali/Java source of ch.dex
  abox-lockdown.sh          standalone port lockdown (no module needed)
  rollback-ads-activities.sh generated rollback for a3
install.sh                  copy modules into /data/adb/modules (requires root)
```

## Install

```bash
# 1. push this repo to the device
adb push kernelsu-modules /data/local/tmp/kmods
adb push install.sh /data/local/tmp/

# 2. install (root required)
adb shell su -c 'sh /data/local/tmp/install.sh /data/local/tmp/kmods'
```

`install.sh` copies each module into `/data/adb/modules/<id>/`, fixes permissions and
runs every `service.sh` once so the state is applied immediately.

Then each module appears in the KernelSU manager with an **Action** button
(`action.sh`) that toggles its group and reports the result.

## Toggle

```bash
su -c 'ksud module action a2-honor-ads-freeze'    # toggle one group
su -c 'ksud module disable a3-honor-ads-components'  # stop auto-applying
su -c 'ksud module enable  a3-honor-ads-components'
su -c 'ksud module uninstall a4-abox-lockdown'
su -c 'ksud module action a5-notif-channels'      # 营销通知渠道：封禁 <-> 还原
```

Execution order is alphabetical by module id, which is why the ids are `a0`…`a5`:
the fragile `settings` writes run first, the heavy 124× `pm disable` runs later.

## Safety notes

- **Nothing here modifies `/system`.** No OTA/verity/brick risk.
- Component disabling is **root-only** for other packages
  (`shell` gets `SecurityException: Shell cannot change component state`).
- Disabling `com.hihonor.adsdk.*` *activities* only removes ad landing pages — it does
  **not** stop the ad SDK's network reporting, which runs inside the host app process.
  For that you need domain-level blocking.
- Uninstalling `a2` does **not** un-freeze the packages (deliberate). Use its Action button.
- `a5` blocks individual notification **channels** (`importance=0` + `userLockedFields`),
  not whole apps: DMs, order updates and push still work. Restore uses the original
  importance recorded in `channels.tsv`.
- Some `settings` keys are rewritten by Honor system services on boot
  (`network_recommendations_enabled` is hardcoded). The module replays them on every root
  acquisition and logs a `REBOUND` line when one survives.

## Not a malware scanner, not a firewall

This is a personal hardening collection. It freezes ad-slot hosts, disables the vendor ad
SDK's landing pages, cuts analytics/recommendation switches, and reduces the local
fingerprint of a transparent proxy. It does not root the device and does not defeat
security controls.

## License

MIT — see [LICENSE](LICENSE).
