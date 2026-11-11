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
kernelsu-modules/          seven independent KernelSU modules (per-module table below)
docs/
  01-persistence-model.md          what survives reboot vs what does not
  02-kernelsu-modules.md           module structure, execution order, four gotchas
  03-ad-surface-inventory.md       where ad slots / trackers actually live on MagicOS
  04-proxy-detectability.md        can apps detect a transparent proxy? what leaks
  05-tailscale-coexistence.md      running Tailscale and a TPROXY proxy together
scripts/
  notif-channel-dex/        host-side channel CLI + the smali/Java source of ch.dex
  abox-lockdown.sh          standalone port lockdown (no module needed)
  degrade-watch.sh          daily snapshot of msc config / cpu caps / battery / volume
  rollback-ads-activities.sh generated rollback for a3
install.sh                  copy modules into /data/adb/modules (requires root)
```

## 模块一览

每行一句话说清「做什么 / 数据在哪 / 用什么手段 / 关掉会失去什么」。七个模块**不共享任何一行配置**，
但同一个 app 可能被三层同时覆盖（见下一节），这是分层，不是重复。

`a0` 与 `a0b` 手段相同（都是 `settings put`），拆开是因为**语义相反**：前者「少上报、少推荐」，
后者「不要检测我」。混在一个模块里，一次 restore 会把广告推荐和反诈提醒一起放回来——这正是
之前标题写成「广告/遥测/反诈 开关键」的原因，也是这次重排要解决的根源。

| id | 做什么 | 数据文件 | 手段 | 切到 restore 会失去什么 |
|---|---|---|---|---|
| `a0-privacy-settings` | 22 项系统开关：推荐 11 · 遥测与体验上报 8 · OAID/分享 ID 限制 2 · 云端网络推荐 1，外加 18 条 Deeplink 前缀拦截 | `keys.txt` `deeplink.json` | `settings put`，写后回读重试 | 个性化推荐、上报重新打开 |
| `a0b-safety-off` | **16 项全是关掉 Honor 的安全检测**：HiSafeManager 广告/病毒/手机扫描 3 · 反诈提醒与云端核查 4 · 支付风险提醒 1 · WiFi 云端安全检测 1 · AI 诈骗/换脸/会中伪造检测 7 | `keys.txt` | `settings put`（同一手段，独立开关） | **诈骗提醒、病毒扫描、换脸检测全部回来**（这也正是默认要有它们的原因） |
| `a1-privacy-ops` | 9 个系统/服务包不许读「你在用哪些 App」；百度网盘不要短信/通讯录/通话记录 | `usage.txt` `appops.conf` | `cmd appops` + `pm revoke` | 使用统计被读取，网盘恢复三项权限 |
| `a2-honor-ads-freeze` | 9 个广告位宿主整包冻结 | `pkgs.txt` | `pm disable-user` | 负一屏、杂志锁屏、快应用/快游戏、元服务、壁纸、遥测推送全部复活 |
| `a3-honor-ads-components` | 13 个系统包里的 124 个 `com.hihonor.adsdk.*` 组件禁用（119 落地 Activity + 5 适配器 Provider） | `targets.txt` | `pm disable`（组件级） | 广告落地页/激励视频能打开，包本身还在 |
| `a4-abox-lockdown` | 不让本机其他 App 扫到代理端口 | `lockdown.sh` 里的 `PORTS` | `iptables REJECT`（仅 `iif lo`） | 本机任意 App 可连 10810/65535，扫得出透明代理 |
| `a5-notif-channels` | 32 条营销/推荐通知渠道封死 | `channels.tsv` | `app_process` + `NotificationManager.updateNotificationChannel` | 营销通知恢复，功能通知自始至终不受影响 |

### 重叠与分层

只有一处**真重复**，已经删掉；其余是同一目标的不同层，互不替代：

- ~~`a1` 里的 `com.android.adservices.api`~~ → 与 `a2` 整包冻结重复，已从 `usage.txt` 移除。
- `a0` + `a2`：`a0` 写 `hiboard.recommend.status` / `hiboard.improve.status` /
  `show_hiboard_notification_state`，而 `a2` 把 `com.hihonor.hiboard` 整包冻结了 —— 冻结期间这三键空转，
  解冻后才有意义。保留（幂等、无副作用）。
- `a0` 与 `a0b`：同一个 `settings` 通道、两套 state，字母序 `a0` < `a0b` < `a1`，两个 settings 层
  都排在 `a2`/`a3` 的 pm 风暴之前（风暴期间 SettingsProvider 会短暂拒绝事务）。
- `a0` + `a3` + `a5`：`themememanager` / `hncloud` / `honor.browser` 三个包同时出现。
  三层各管一段：`a3` 砍广告落地页 → `a0` 关推荐开关 → `a5` 封通知渠道。任何一层单独都存在漏洞。
- `a0` 的 `deeplink.json` 前 4 条指向 `com.huawei.appmarket` / `com.huawei.gamebox`，
  **本机没装这两个包**（Honor 用 `com.hihonor.appmarket`），属于空配置；其余 14 条（淘宝/京东/拼多多…）有效。
- `a4` 与其他模块零交集：它管的是「代理可探测性」，和广告/隐私无关。

### 一个必须知道的取舍

`a0b-safety-off` 整包就是**关掉安全防护**，不是减少广告：
`hsm_ad_detect` `hsm_antivirus` `hsm_phonescan` `app_check_risk` `antifraud_remind`
`fraud_cloud_security_check` `anti_fraud_status` `ai_scam_detect_*`（5 项）
`hn_hsm_payment_risk_reminder_state` `meeting_live_fake_detect_state` `video_live_fake_detect_state`
`wifi_cloud_security_check`。

它确实减少了厂商上报，但代价是**诈骗提醒、病毒扫描、换脸/会中伪造检测**也没了。
所以它是独立模块、默认可以单独关掉：**只用广告相关需求的话，直接不要装 `a0b`**，
`a0` 不会连带影响任何安全能力。

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
