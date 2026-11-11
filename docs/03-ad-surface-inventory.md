# 03 — Where ad slots and trackers actually live on MagicOS

Findings from a full inventory of one Honor Magic8 Pro (MagicOS 11 / Android 17):
378 installed packages, 225 flagged with network + sensitive permissions.

## The vendor advertises for itself

Ad slots are not (only) third-party SDKs. On MagicOS the system itself is the distributor:

```
OAID distribution : com.hihonor.id        → HnOaIdService / OaidSwitchesProvider
Ad slot hosts     : launcher · magazine lockscreen · hiboard (negative-one screen) · search
                    app market · browser · YOYO · intelligent message
                    → all carry com.hihonor.adsdk
Push-slot adverts : com.hihonor.android.pushagent → .ad.common / .data.* / .ipc
Reporting         : metrics-basecloud-drcn.dt.hihonorcloud.com
Push channel      : trs-drcn.push.hihonorcloud.com
```

## Component-level vs in-dex SDKs — an important split

Scanning all 380 package manifests (**44,615 components**, parsed from binary AXML so that
components *without* intent-filters are included) shows only **three** packages actually
declare `com.hihonor.adsdk.*` components:

| Package | adsdk components | Kind |
|---|---:|---|
| `com.hihonor.android.thememanager` | 23 | 5 adapter providers + 18 landing activities |
| `com.hihonor.quickengine` | 11 | landing activities — **not** in `a3`, the whole package is frozen by `a2` |
| `com.hihonor.quickgame` | 4 | landing activities — **not** in `a3`, the whole package is frozen by `a2` |

Everything else (launcher, search, browser, app market, push channel, YOYO) embeds the SDK
**in dex only** — there is nothing to disable at the component level.

> Consequence: `pm disable` removes **user-visible ad landing pages**, it does not stop the
> SDK's network reporting. Reporting happens inside the host process; only domain-level
> blocking reaches it.

The 11 landing activity classes are always the same:

```
RewardActivity  InterstitialActivity  WebCommonActivity  WebVideoActivity
WebPermissionsActivity  OpenMarketPageActivity  OpenTrialGamePageActivity
InstallNotifyActivity  DateFlowTipActivity  PermissionActivity  MessageAdsActivity
```

## Structural safety check before disabling anything

Disabling a component that other code expects can crash the host app. The check that made
this batch safe:

```
Do the target components have any intent-filter?
→ none of the 119 selected activities did
```

No intent-filter ⇒ only the SDK can start them ⇒ removing them cannot break an app entry point.

## What was frozen (`a2`) vs component-disabled (`a3`)

- **`a2` — whole packages** (ad-slot hosts / content surfaces):
  `com.hihonor.hiboard`, `com.hihonor.magazine`, `com.hihonor.livewallpaper.paradise`,
  `com.hihonor.hiviewpush`, `com.hihonor.hiviewtunnel`, `com.hihonor.quickengine`,
  `com.hihonor.quickgame`, `com.honor.yoyocards`, `com.android.adservices.api`
- **`a3` — 124 components** across 13 system packages (119 activities + the 5 thememanager
  adapter providers), e.g. messaging app, install wizard, wallet, calendar, browser,
  weather, search, cloud, dock bar, scenario manager, theme store, two IMEs.

Freezing the whole package is appropriate when the *feature* is unwanted (negative-one screen,
magazine lockscreen, quick apps). Component disabling is appropriate when the app itself is
kept but its ad landing pages are not wanted.

## Third-party SDKs are a separate problem

A dex scan found, among others: Pangle/穿山甲, GDT/优量汇, Kuaishou, Baidu Union, Google
Mobile Ads, Meta/Unity/AppLovin/Mintegral/ironSource/Tapjoy/Vungle/AdColony/Smaato/Amazon,
plus analytics (Umeng, Firebase, AppsFlyer, Adjust, Sensors, Bugly, Tingyun) and risk SDKs
(Tencent Turing, Shumei, Tongdun, Geetest). These live inside third-party apps — no system
setting disables them; domain-level blocking is the only practical lever.
