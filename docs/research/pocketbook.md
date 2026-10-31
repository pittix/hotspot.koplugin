---
topic: pocketbook
last_reviewed: 2026-10-31
families: [b288, b300, a13, imx6]
caveat: research subagent was cut off by an API safeguard mid-report; claims with status `agent` here come from its surviving per-model table only
---

# PocketBook (running KOReader)

## Summary verdicts (2026-10-31)

| Family | Verdict | Key claims |
|---|---|---|
| B288, rooted (setuid `/mnt/secure/su`) | **Likely / moderate work** | PB-C01, PB-C02, PB-C04 |
| B288, not rooted | Impossible (KOReader unprivileged) | PB-C04, PB-C05 |
| B300 | Unknown | PB-C08, PB-C09, PB-C10 |
| A13 (Touch Lux 3 and older) | Possible with significant work | PB-C11 |
| i.MX6 (631, 650) | Unlikely | PB-C12 |

## Claims

### PB-C01: B288 kernel has a mac80211 XRadio driver and cfg80211
- claim: PocketBook's published `B288.config` is `Linux/arm 3.10.65` with `CONFIG_CFG80211=y`, `CONFIG_NL80211_TESTMODE=y`, `CONFIG_MAC80211=y`, `CONFIG_XRADIO=m`, `CONFIG_XRADIO_SDIO=y`, `# CONFIG_XRADIO_5GHZ_SUPPORT is not set`, `CONFIG_XRADIO_SUSPEND_POWER_OFF=y`, `CONFIG_NETFILTER=y`, `CONFIG_IP_NF_IPTABLES=y`, `CONFIG_IP_NF_TARGET_MASQUERADE=y`, `# CONFIG_BRIDGE is not set`, `CONFIG_MODULES=y`.
- confidence: high
- status: verified
- sources: S-PB-01, S-PB-02
- recheck: grep those lines in S-PB-01
- notes: XRadio (XR819, likely) is soft-MAC, so AP comes from mac80211 and works with hostapd nl80211. Kernel 3.10.65 ≥ 3.2 and Cortex-A7 NEON, so the current binaries should run (BASE-C01). 2.4 GHz only.

### PB-C02: XRadio supports AP and STA+AP concurrency
- claim: the B288 XRadio driver advertises AP, P2P-GO, ad-hoc and mesh, with interface combinations up to 2 STA + 1 AP, max 3 interfaces, 1 channel (`P2P_MULTIVIF` defined).
- confidence: medium
- status: agent (subagent read driver source; not re-checked)
- sources: S-PB-02 (driver source in kernel-b288 tree; exact file not recorded), S-PB-08 (generic XR819 driver for comparison)
- recheck: browse `drivers/net/wireless/xradio/` in kernel-b288 for `iface_combinations` / `NL80211_IFTYPE_AP`. On device: `iw list` (Q-PB-01)

### PB-C03: KOReader drives PocketBook Wi-Fi through inkview
- claim: Wi-Fi on is `inkview.WiFiPower(1)` then `inkview.NetConnect(nil)`; off is `inkview.NetDisconnect()`; state is `inkview.QueryNetwork()`; keep-alive is `inkview.NetMgrPing()`. KOReader has no network interface name and no shell scripts on PocketBook.
- confidence: high
- status: verified
- sources: S-KOR-02

### PB-C04: KOReader uses /mnt/secure/su when present
- claim: `device.lua` does `local su = "/mnt/secure/su"; su = util.pathExists(su) and (su .. " ") or ""` and uses it for `/sbin/hwclock -u -w`. `koreader.app` runs `/mnt/secure/su /bin/chmod 644 /dev/input/*` for raw input.
- confidence: high
- status: verified
- sources: S-KOR-02, S-KOR-03
- notes: the plugin can reuse this pattern: prefix privileged commands with `/mnt/secure/su ` if present, otherwise report "needs root"

### PB-C05: KOReader runs unprivileged on PocketBook
- claim: KOReader runs as user `reader` (uid 101), not root.
- confidence: medium
- status: agent
- sources: (subagent; no URL recorded)
- recheck: on device, from KOReader's terminal: `id` (Q-PB-02)

### PB-C06: KOReader PocketBook model classes
- claim: KOReader defines PocketBook515, 606, 611, 613, 614W, 615, 616, 617, 618, 619, 622, 623, 624, 625, 626, 627, 628, 629, 630, 631, 632, 633, 634, 634K3, 640, 641, 650, 700, 700K3, 710, 740, 740_2, 741, 743C, 743K3, 743G, 1030, 1040 and ColorLux (801). It has an `isB288SoC` flag set at init, and **no B300 references**.
- confidence: high
- status: verified
- sources: S-KOR-02

### PB-C07: PocketBook suspend/standby in KOReader
- claim: on suspend KOReader only sends `inkview.SendGlobalRequest(C.REQ_KEYLOCK)`. `setAutoStandby` calls `inkview.iv_sleepmode(0|1)`. The kernel's `XRADIO_SUSPEND_POWER_OFF=y` means the radio powers off on suspend.
- confidence: high
- status: verified
- sources: S-KOR-02, S-PB-01
- notes: plugin should disable auto-standby while the AP is up

### PB-C08: B300 kernel source and candidate Wi-Fi drivers
- claim: PocketBook publishes `kernel-b300` (updated Mar 2026). Its `drivers/net/wireless` contains `xradio`, `bcmdhd`, `rtl8723bs_vq0`, `rtl8723cs`, plus generic vendor dirs. No defconfig is visible at the repo root, so which driver B300 devices use is unknown.
- confidence: high (listing); unknown (actual driver)
- status: verified
- sources: S-PB-03, S-PB-04
- recheck: look for configs under `linaro/configs`, `arch/arm*/configs`, `sys_config/` in kernel-b300

### PB-C09: B300 kernel version
- claim: SDK 6.8 for B300 uses Linux 4.9.56.
- confidence: low
- status: snippet
- sources: S-PB-07
- recheck: kernel-b300 Makefile `VERSION/PATCHLEVEL/SUBLEVEL`

### PB-C10: AIC8800 on B300
- claim: the subagent suggested B300 devices use an AIC8800 chip. This was **not confirmed**: no `aic*` dir appears in the kernel-b300 wireless listing (which may be incomplete).
- confidence: low
- status: contradicted / unconfirmed
- sources: S-PB-03
- recheck: on device `lsmod` (Q-PB-04)

### PB-C11: A13 devices
- claim: PB515, 614, 624/625, 626 (Touch Lux 3) and 840 (InkPad 1) use Allwinner A13 (Cortex-A8), kernel 3.0.8. PB626 has an RTL8188EUS on internal USB with vendor `8188eu` built with `CONFIG_IOCTL_CFG80211` and `CONFIG_AP_MODE`/`NATIVEAP_MLME`, but `CONFIG_CONCURRENT_MODE` off. AP works via nl80211 only if the kernel has cfg80211 (unknown); otherwise it needs an `rtl871xdrv` hostapd.
- confidence: medium
- status: agent
- sources: S-PB-05, S-CHIP-03

### PB-C12: i.MX6 PocketBooks
- claim: PB631 (Touch HD / HD 2) is i.MX6 SoloLite, kernel 3.0.35, `CFG80211` not set (WEXT only), with an unknown out-of-tree driver. PB650 (Ultra) is i.MX6SL, 3.0.35, out-of-tree full-MAC (`CFG80211=y`, no mac80211).
- confidence: medium (631); low (650)
- status: agent
- sources: S-PB-06

### PB-C13: root availability (existence only, per D4)
- claim: a community jailbreak installs a setuid `/mnt/secure/su` on B288-era and older devices. B300 devices are reported to be much harder to root.
- confidence: medium
- status: agent
- sources: (subagent; deliberately not detailed)

### PB-C14: no prior art and no native AP feature
- claim: no hostapd, soft AP or ad-hoc use on any PocketBook was found (MobileRead, GitHub, Russian-language forums). PocketBook firmware has no AP or Wi-Fi Direct feature.
- confidence: medium (negative result)
- status: agent

### PB-C15: firmware network manager owns Wi-Fi
- claim: PocketBook's firmware network stack (`netagent` and friends, behind inkview) manages Wi-Fi power and wpa_supplicant. Whether `NetDisconnect()` leaves the radio powered is unknown.
- confidence: medium
- status: agent / inference
- recheck: on device `ps | grep -Ei 'netagent|wpa_'` (Q-PB-03)

## Porting sketch: B288 (inference, needs Q-PB-01..03)

1. Detection: `Device:isPocketBook()` and `Device.isB288SoC`, `/mnt/secure/su` exists, `/sys/module/xradio_wlan` present.
2. Privilege wrapper: prefix privileged commands with `/mnt/secure/su `.
3. Bring-up:
   - **Concurrent first**: `iw dev wlan0 interface add ap0 type __ap`, then hostapd on `ap0`. This avoids fighting netagent.
   - **Fallback, exclusive**: `NetDisconnect()`, keep the radio powered, hostapd on `wlan0`.
4. IP, udhcpd, iptables rule if needed, disable auto-standby (`iv_sleepmode`).
