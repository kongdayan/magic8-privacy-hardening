# 02 — KernelSU modules: structure, order, and four gotchas

> **Requires root.** These modules are meaningless without KernelSU: `pm disable` on another
> package's component is refused for `shell` (`SecurityException: Shell cannot change
> component state`), and nothing under `/data/adb/modules/` runs. On this device root comes
> from a temporary kernel exploit and is lost on every reboot — see the warning in the
> top-level README.

## Why modules can run automatically

`ksud` exposes lifecycle triggers:

```
$ ksud --help
  post-fs-data    Trigger `post-fs-data` event
  services        Trigger `service` event
  boot-completed  Trigger `boot-complete` event
  late-load       Load kernelsu.ko and execute late-load stage scripts
```

With **exploit-based temporary root** the kernel module is loaded after boot, which is exactly
the `late-load` path — and KernelSU executes module scripts there. So "run something every time
root is acquired" needs no extra machinery.

## Module anatomy

```
/data/adb/modules/<id>/
├── module.prop     id / name / version / versionCode / author / description
├── service.sh      runs on root acquisition (apply the group's policy)
├── action.sh       exposed as the "Action" button in the KernelSU manager
├── uninstall.sh    cleanup on removal
└── state           lock|apply|restore|unlock — the only source of truth
```

`state` makes the module idempotent and toggleable: `service.sh` reads it, `action.sh`
flips it and applies immediately.

## Module id rules

```
$ ksud module action 20-honor-ads-freeze
Error: Invalid module ID: '20-honor-ads-freeze'. Must match /^[a-zA-Z][a-zA-Z0-9._-]+$/
```

Numeric prefixes show up in `module list` but are rejected by `module action`.
Use `a0-… a5-…` if you also want deterministic ordering.

## Execution order

Alphabetical by id:

```
a0-privacy-settings     ← fragile: binder to SettingsProvider
a1-privacy-ops          ← binder to AppOpsService
a2-honor-ads-freeze     ← pm, light
a3-honor-ads-components ← pm × 124, heaviest
a4-abox-lockdown        ← iptables, independent
a5-notif-channels       ← app_process + binder to NotificationManagerService
```

Do the fragile binder work **before** the heavy `pm` storm. Disabling 124 components can make
`settings` temporarily refuse transactions; running it first avoids that window.

## Gotcha 1 — `cmd` eats stdin inside `while read … < file`

```sh
while read -r ns k v; do
  settings put "$ns" "$k" "$v"
done < keys.txt
# → cmd: Failure calling service settings: Failed transaction (2147483646)
```

`cmd` passes stdin (here: the file) to the service as a request body → transaction failure.
The loop **looks like it ran**, exits 0, and silently changes nothing. Same trap for
`pm`, `cmd appops`, `settings get|put`.

```sh
# fix: detach stdin from every command inside the loop
settings put "$ns" "$k" "$v" </dev/null
```

Or iterate with `for x in $(cat file)`, which leaves the script's own stdin untouched.

## Gotcha 2 — module id must start with a letter

See above. `^[a-zA-Z][a-zA-Z0-9._-]+$`.

## Gotcha 3 — verify after writing, retry

`settings`/`appops` may transiently fail. Write → read back → retry, and only then report.
The `a0` module also skips keys that already hold the target value, so re-running is cheap.

## Gotcha 4 — some keys are unwinnable

`global/network_recommendations_enabled` is rewritten by Honor services immediately; the module
logs `REBOUND` for it and moves on. Expect `rebound=1` on this device — not a bug.

## Debugging

```bash
su -c 'ksud module list'
su -c 'ksud module action a0-privacy-settings'
su -c 'sh /data/adb/modules/a3-honor-ads-components/service.sh; echo rc=$?'
tail -5 /data/local/tmp/a3-honor-ads-components.log
su -c 'sh -x /data/adb/modules/a0-privacy-settings/service.sh'   # trace
```

`a5` is the one module that needs a helper process (`app_process` + `ch.dex`) rather than
plain shell tools — see [06-notification-channels.md](06-notification-channels.md) for why,
plus the dex-version and `pm list packages` substring traps.

Note: `ksud services` is **not** a reliable manual re-trigger (it expects module context and
de-duplicates). To test a `service.sh`, invoke it by absolute path.
