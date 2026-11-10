# 01 — Persistence model: what survives a reboot?

A frequent misconception: *"if root is temporary, everything I configured is temporary too."*
That is not how Android stores state. Split every change into **policy data** and **runtime state**.

## Policy data — lives in `/data`, never lost

| Change | Stored in | Survives reboot | Needs root again |
|---|---|:---:|:---:|
| Package freeze (`pm disable-user`) | `/data/system/users/0/package-restrictions.xml` | ✅ | – |
| Component disable (`pm disable pkg/cmp`) | same file | ✅ | – |
| `appops` overrides | `/data/system/appops/`, `hnappops.xml` | ✅ | – |
| Runtime permission revoke | package-restrictions + appops | ✅ | – |
| `settings put` keys | `settings_global.xml` / `settings_secure.xml` | ✅ | – |
| App-own routing rules (Room DB) | `/data/data/<pkg>/databases/*.db` | ✅ | – |
| KernelSU modules | `/data/adb/modules/<id>/` | ✅ | – |

Root was needed to *write* them once. Reading/enforcing them afterwards is the system's job.

## Runtime state — rebuilt after every boot

| Runtime | Survives reboot | Rebuilt by |
|---|:---:|---|
| Temporary root itself (exploit + `insmod kernelsu.ko`) | ❌ | manual deploy |
| `iptables` rules (TPROXY, port lockdown) | ❌ | proxy app on start / KernelSU module |
| Proxy daemons (`asteriskd`, `sing-box`) | ❌ | proxy app on start |
| Shizuku server | ❌ | adb / root script |
| VPN tunnels (Tailscale etc.) | ❌ (auto reconnect) | the app itself |

## Consequence

After a reboot with temporary root the manual work is exactly two steps:

1. Deploy root → KernelSU `late-load` runs every module's `service.sh` → policy re-applied,
   port lockdown re-installed.
2. Start the proxy app → it rebuilds its `iptables` rules from its own DB.

Everything else (freezes, component disables, appops, settings) is already in place.

## Why not patch `/system`?

On modern Honor/Qualcomm devices `/system` is delivered as **erofs** images bind-mounted
per file, the root mount `/` is read-only, and `dm-verity` is `enforcing` with a locked
bootloader:

```
$ mount -o rw,remount /system
mount: '/system' not in /proc/mounts
$ getprop ro.boot.veritymode
enforcing
$ getprop ro.boot.flash.locked
1
```

Editing an APK under `/system/priv-app` would also break its v2/v3 signature, so the package
manager would refuse to load it at next boot. `/data` is the only sane place to persist changes.
