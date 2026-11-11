# 06 — Notification channels: why ADB can't, and how to force it anyway

> **Requires root.** Everything below needs uid 0. `cmd notification` — the tool you would
> reach for first — has no channel-level subcommand at all.

## The problem

"Kill marketing notifications but keep DMs" is a **channel**-level request, not an
app-level one. Per-app blocking is trivial (`pm revoke <pkg> android.permission.POST_NOTIFICATIONS`,
or `cmd appops set --uid <uid> POST_NOTIFICATION ignore`), but it takes the useful
channels down with the marketing ones.

The state lives in `/data/system/notification_policy.xml`. Since Android 16/17 that file is
**ABX (Android Binary XML)**, not text:

```
$ su -c 'file /data/system/notification_policy.xml'
/data/system/notification_policy.xml: Android Binary XML v0
```

So `sed` patching is out, and the file is rewritten by `NotificationManagerService`
from memory anyway.

`cmd notification` subcommands on this device:

```
allow_listener / disallow_listener / allow_assistant / remove_assistant
set_dnd / allow_dnd / disallow_dnd / reset_assistant_user_set / get_approved_assistant
post / set_bubbles / set_bubbles_channel / list / get / snooze / unsnooze
set_exempt_th_force_grouping / redact_otp_from_untrusted_listeners
```

No `get_channel` / `update_channel`. Confirmed, not a version quirk.

## The route that works: `app_process` + real NotificationManager API

Root can start a throwaway JVM-like process with `app_process` and call framework APIs
directly:

1. `ActivityThread.systemMain()` — builds an `ActivityThread` in this process
   (needs `Looper.prepareMainLooper()` first, otherwise `Can't create handler inside thread
   that has not called Looper.prepare()`).
2. `ActivityThread.currentSystemContext()` — a `Context` that works without SystemUI.
   *Not* `getSystemContext()` (gone in API 37 — `NoSuchMethodError`) and *not*
   `getSystemUiContext()` (`IllegalStateException: ApplicationSharedMemory not initialized`).
3. `context.getSystemService("notification")` → `NotificationManager`.
4. `NotificationManager.updateNotificationChannel(pkg, uid, channel)` — NMS sees uid 0 as
   *system*, treats the write as a **user** modification, so it lands `importance=0` **and**
   sets `mUserLockedFields`. The app can no longer raise it back via
   `createNotificationChannel`.

Result in `dumpsys`:

```
NotificationChannel{mId='com.hihonor.android.pushagent.LOW.927503pnc', mName=营销通知,
  mImportance=0, ..., mUserLockedFields=24}
NotificationChannel{mId='DM', mName=私信, mImportance=3, mUserLockedFields=0}   ← untouched
```

`mUserLockedFields=24` is the part that makes it stick (a re-block of an already blocked
channel shows `24`; a fresh one shows `4`).

## Building the payload without the Android SDK

The machine doing this had no `d8`/`r8`/build-tools — but `apktool` ships the shaded
`dexlib2` and a smali assembler:

```java
// Build.java — java -cp apktool.jar:. Build <smaliDir> <api> <out.dex>
DexBuilder db = new DexBuilder(new Opcodes(api));
SmaliBuilder sb = new SmaliBuilder(api);
walk(new File(smaliDir), sb, db);            // buildFile() takes ONE file, not a dir
db.writeTo(new FileDataStore(new File(out)));
```

`apktool b` itself is useless here (its bundled `aapt2` fails on a minimal manifest:
`attribute android:minSdkVersion not found`), but `--no-apk` still emits
`build/apk/classes.dex` — *once resources succeed*, so it can silently leave a stale dex.

**Gotcha: dex version.** `api=35` emits `dex 041`, which this ART rejects with a bare
`ClassNotFoundException: Ch`. Use `api<=34` → `dex 039`/`040`. Universal, and nothing in the
payload needs newer opcodes.

## Gotcha: `pm list packages <filter>` is a substring match

```
$ cmd package list packages -U --user 0 com.unionpay
package:com.unionpay.tsmservice uid:10242     ← wrong package, wrong uid
package:com.unionpay uid:10333
```

Passing `10242` yields `IllegalArgumentException: Channel does not exist` from NMS (the
channel belongs to `10333`). Build an exact `pkg → uid` map once:

```sh
cmd package list packages -U --user 0 </dev/null \
  | sed 's/^package:\([^ ]*\) uid:\(.*\)$/\1\t\2/' > /data/local/tmp/.a5-pmap
uid_of(){ awk -v p="$1" -F'\t' '$1==p{print $2; exit}' /data/local/tmp/.a5-pmap; }
```

Also: `dumpsys notification` `AppSettings:` uids can be **stale leftovers** from old
installs (e.g. `com.zhihu.android` appeared under both `10032` and `10336`; only `10336`
was live). Never trust the uid in the dump — resolve it from PackageManager.

## Gotcha: channels that don't exist yet

`updateNotificationChannel` throws `Channel does not exist` for a package whose channel
cache NMS hasn't loaded yet. Reposting is harmless and the module re-applies on every root
acquisition; a channel that doesn't exist also can't notify.

## What this does *not* do

It doesn't stop an app from *calling* the notification API, and it doesn't touch the Honor
push pipeline — `a2`/`a3` handle the vendor ad surface, and `a0` handles the
recommendation switches. Channel blocking is the last mile: the marketing pushes that still
made it through every other layer.
