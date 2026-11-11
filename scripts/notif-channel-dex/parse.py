#!/usr/bin/env python3
"""解析 dumpsys notification --noredact，输出渠道信息 TSV。
用法: parse.py list [marketing|all] [pkg]
输出列: pkg, uid, importance, userLocked, deleted, channelId, channelName
"""
import re, sys

MARKETING = re.compile(
    r"营销|推广|活动公告|促销|优惠|广告|抽奖|福利|商城|签到|直播活动|推荐"
    r"|market|promo|advert|campaign|upsell|offer|deal", re.I)
SKIP_PKG = re.compile(
    r"^(android|com\.android\.systemui|com\.hihonor\.android\.launcher"
    r"|com\.android\.settings|com\.hihonor\.android\.pushagent)$")

def parse(text):
    cur = None
    apps = {}
    for line in text.splitlines():
        m = re.match(r"^      AppSettings: (\S+) \((\d+)\)(.*)$", line)
        if m:
            cur = m.group(1)
            e = apps.setdefault(cur, {"uid": int(m.group(2)), "hdr": m.group(3), "ch": []})
            uid = int(m.group(2))
            if uid < 100000 and e["uid"] >= 100000:      # 优先 user 0 的 uid
                e["uid"] = uid
            if "importance=NONE" in m.group(3):
                e["hdr"] = m.group(3)
            continue
        m = re.match(r"^\s+NotificationChannel\{mId='(.*?)', mName=(.*?), mDescription", line)
        if m and cur:
            g = lambda p, d="-99": (re.search(p, line).group(1) if re.search(p, line) else d)
            apps[cur]["ch"].append({
                "cid": m.group(1), "name": m.group(2),
                "imp": int(g(r"mImportance=(-?\d+)")),
                "locked": int(g(r"mUserLockedFields=(\d+)", "0")),
                "deleted": "mDeleted=true" in line,
            })
    return apps

def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "list"
    want = sys.argv[2] if len(sys.argv) > 2 else "marketing"
    pkg_filter = sys.argv[3] if len(sys.argv) > 3 else None
    apps = parse(sys.stdin.read())
    rows = []
    for pkg, a in sorted(apps.items()):
        if pkg_filter and pkg != pkg_filter:
            continue
        if SKIP_PKG.match(pkg):
            continue
        app_blocked = "importance=NONE" in a["hdr"]
        for c in a["ch"]:
            if c["deleted"]:
                continue
            if want == "marketing" and not (MARKETING.search(c["cid"]) or MARKETING.search(c["name"])):
                continue
            if want == "active" and c["imp"] < 2:
                continue
            rows.append((pkg, a["uid"], c["imp"], c["locked"], c["cid"], c["name"],
                         "appblocked" if app_blocked else ""))
    for r in rows:
        print("\t".join(str(x) for x in r))

if __name__ == "__main__":
    main()
