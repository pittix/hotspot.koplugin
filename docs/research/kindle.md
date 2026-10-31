---
topic: kindle
last_reviewed: 2026-10-31
families: [mediatek, broadcom, atheros, legacy]
---

# Kindle (jailbroken, running KOReader)

## Summary verdicts (2026-10-31)

| Family | Models | Verdict | Key claims |
|---|---|---|---|
| MediaTek | PW5/PW5 SE, Basic 2022 (11th), Basic 2024, PW6, Scribe 1/2, Colorsoft | **Likely, best next target** | KIN-C01, KIN-C02, KIN-C03, KIN-C10 |
| Broadcom BCM4343W | Basic 8th gen | **Likely** (driver verified) | KIN-C23, BRCM-C06, BRCM-C07 |
| Broadcom BCM4343W | PW4, Basic 10th, Oasis 2/3 | Probably likely (driver inferred) | KIN-C06, BRCM-C05 |
| Broadcom | Oasis 1 | Possible with more work | KIN-C26 |
| Atheros AR6003 | PW2, Basic 7th, Voyage, PW3 | Possible with work, path known | KIN-C18, KIN-C20, KIN-C21, ATH-C* |
| Atheros AR6003 | K4, Touch, PW1 | Unlikely (kernel 2.6.31) | KIN-C06 |
| unknown | Scribe 3, Scribe Colorsoft (2025) | Unknown | KIN-C06 |
| legacy ARMv6 | K2, DX, K3 | Out of scope | KIN-C06 |

## Claims

### KIN-C01: MediaTek Kindles use the same Wi-Fi stack as Kobo Libra Colour
- claim: A bellatrix Kindle (MT8110 = MT8512 die, kernel `4.9.77-lab126`, glibc 2.20, `/lib/ld-linux.so.3`, system software `juno_16020101_cava_bellatrix`) has `wlan_drv_gen4m`, `wmt_chrdev_wifi`, `wmt_drv` and `wmt_cdev_bt` loaded. These are the same modules as the plugin's `wlan_drv_gen4m` backend. `wmt_chrdev_wifi` is the module that provides `/dev/wmtWifi` in MediaTek's stack.
- confidence: high (modules); medium (that `/dev/wmtWifi` accepts `A` → `ap0` as on Kobo)
- status: verified (modules); inference (`A` → `ap0`)
- sources: S-KIN-01
- recheck: fetch S-KIN-01 (branch `master`), find the lsmod table rows `wlan_drv_gen4m`, `wmt_chrdev_wifi`, `wmt_drv`. On device: `echo A > /dev/wmtWifi; ls /sys/class/net` (Q-KIN-01)

### KIN-C02: KOReader's MTK flag
- claim: KOReader sets `isMTK = yes` for KindlePaperWhite5, KindlePaperWhite5SE, KindlePaperWhite6, KindleBasic4, KindleBasic5, KindleScribe, KindleScribe3, KindleColorSoft and KindleScribeColorSoft.
- confidence: high
- status: verified
- sources: S-KOR-01
- recheck: grep `isMTK = yes` in S-KOR-01
- notes: usable for backend detection: `Device:isKindle() and Device:isMTK()` plus check `/dev/wmtWifi`

### KIN-C03: KOReader does not drive Kindle Wi-Fi hardware; Amazon's wifid does
- claim: KOReader toggles Wi-Fi via LIPC: `com.lab126.cmd wirelessEnable` and `com.lab126.wifid enable`, with fallback `lipc-set-prop -i com.lab126.wifid enable <0|1>`. The interface name is hardcoded (`return "wlan0" -- so far, all Kindles appear to use wlan0`). Kindle has no enable/disable-wifi.sh and no `WIFI_MODULE`.
- confidence: high
- status: verified
- sources: S-KOR-01, S-KOR-12, S-KOR-13
- recheck: grep `kindleEnableWifi`, `wirelessEnable`, `wlan0` in S-KOR-01

### KIN-C04: MTK Kindle kernel config
- claim: `CONFIG_CFG80211=y`, `CONFIG_NL80211_TESTMODE=y`, `CONFIG_MTK_COMBO_WIFI=y`, `CONFIG_MTK_COMBO_CHIP_CONSYS_8512=y`, `CONFIG_MTK_WIFI_MCC_SUPPORT=y`; `CONFIG_CFG80211_WEXT` not set (so use `iw`, not `iwconfig`); `CONFIG_BRIDGE=y`, iptables NAT/MASQUERADE; modules unsigned.
- confidence: medium
- status: agent
- sources: S-KIN-02, S-KIN-28
- recheck: fetch S-KIN-02 (try branch `master`), grep those symbols. On device: `zcat /proc/config.gz | grep -E 'CFG80211|MTK_WIFI|MCC'`
- notes: MCC = multi-channel concurrency, a hint that STA+AP might work (Q-KIN-04)

### KIN-C05: no Marvell/NXP Wi-Fi in any Kindle
- claim: No Kindle uses Marvell/NXP, so there's no `uap0`/`moal` path on Kindle.
- confidence: medium
- status: agent (from per-model research)
- sources: S-KIN-02, S-KIN-04, S-KIN-05

### KIN-C06: per-model hardware table
- claim:

| Model | Platform | SoC / CPU | Kernel | Wi-Fi chip / driver |
|---|---|---|---|---|
| K4 NT, Touch, PW1 | yoshi/yoshime | i.MX50 Cortex-A8 | 2.6.31-rt11-lab126 | AR6003 (inferred), vendor `ar6003` |
| PW2, Basic 7th, Voyage, PW3 | wario | i.MX6 SoloLite Cortex-A9 | 3.0.35-lab126 | AR6003G/AR6803G, vendor `ar6003` (wext) |
| Oasis 1 | duet | i.MX6SL | 3.0.35 | Broadcom, driver unknown |
| Basic 8th gen (KT3) | heisenberg | i.MX6 SoloLite | 3.10.53-lab126 | BCM4343W, `bcmdhd` 1.201.59 (see KIN-C23) |
| Oasis 2, Oasis 3 | zelda | i.MX7D Cortex-A7 | 4.1.15-lab126 | BCM4343 |
| PW4, Basic 10th | rex | i.MX6SLL Cortex-A9 | 4.1.15-lab126 | BCM4343 |
| PW5/SE, Basic 2022, Scribe | bellatrix | MT8110 (MT8512) Cortex-A53 AArch32 | 4.9.77-lab126 | MediaTek CONSYS gen4m |
| Basic 2024, PW6, Scribe 2, Colorsoft | bellatrix3/4 | MT8110/MT8113(S) | 4.9.77 (Basic 2024, Scribe 2024) | MediaTek, assumed same |
| Scribe 3, Scribe Colorsoft (2025) | platpa6 / platcs8 | new quad-core | ? | ? (KOReader flags isMTK) |
| K2, DX, K3 | legacy | i.MX31/35 ARM11 (ARMv6) | 2.6.2x | AR6002 (K3) |

- confidence: medium overall (high for wario defconfig/PW2 lsmod, bellatrix, KT3)
- status: agent (mixed; KT3 row verified via KIN-C23, bellatrix via KIN-C01)
- sources: S-KIN-04, S-KIN-11, S-KIN-16, S-KIN-17, S-KIN-18, S-KIN-19, S-KIN-20, S-KIN-21, S-KIN-22, S-KIN-23, S-KIN-24, S-KIN-25, S-KIN-26, S-KIN-29, S-KIN-30, S-KIN-31, S-KOR-01
- recheck: each source; on device `uname -r; lsmod; readlink -f /sys/class/net/wlan0/device/driver`
- notes: vs BASE-C01, kernels 3.10, 4.1 and 4.9 run the current hostapd; **3.0.35 and 2.6.31 need a rebuilt hostapd** (musl)

### KIN-C07: userland ABI
- claim: firmware ≥ 5.16.3 is armhf (KOReader `kindlehf` build); `kindlepw2` (softfp) covers up to 5.16.2.1.1. KOReader detects it via `/lib/ld-linux-armhf.so.3`.
- confidence: high
- status: agent
- sources: S-KIN-32, S-KOR-01
- notes: irrelevant for static binaries (BASE-C01)

### KIN-C08: KOReader runs as root on Kindle
- claim: KOReader runs as root on jailbroken Kindles. Its SSH plugin calls `iptables` directly; users get a root shell through KOReader's dropbear.
- confidence: high
- status: agent
- sources: S-KOR-09, S-KIN-27

### KIN-C09: wifid is an upstart job
- claim: `wifid` is managed by upstart (`/etc/upstart/wifid.conf`; `restart wifid` documented on a PW2), so `stop wifid` / `start wifid` should work. `wpa_cli` is present.
- confidence: medium
- status: agent
- sources: S-KIN-35, S-KIN-36
- recheck: on device `status wifid; cat /etc/upstart/wifid.conf` (Q-KIN-02)

### KIN-C10: stock Kindle firewall blocks inbound on new interfaces
- claim: stock iptables has `INPUT` policy `DROP`, accepts `usb0`, and accepts only ESTABLISHED/RELATED on `wlan0`. On `ap0`, DHCP DISCOVER (UDP 67) and service ports would be dropped. The plugin must `iptables -I INPUT -i ap0 -j ACCEPT` (and OUTPUT), then delete those rules on stop.
- confidence: high for the old firmware; medium for current firmware
- status: agent
- sources: S-KIN-37 (FW 5.3.3 era), S-KOR-09
- recheck: on device `iptables-save` (Q-KIN-03)

### KIN-C11: suspend and standby on Kindle
- claim: Kindle suspend is handled by Amazon's `powerd`; `Kindle:readyToSuspend` just delegates to powerd (verified). `lipc-set-prop com.lab126.powerd preventScreenSaver 1` (used by KOReader's KeepAlive) prevents timeout sleep; a power-button press still suspends.
- confidence: high (delegation); medium (preventScreenSaver behaviour)
- status: verified (delegation); agent (preventScreenSaver)
- sources: S-KOR-01, S-KOR-14, S-KOR-16

### KIN-C12: Wi-Fi dies on suspend
- claim: NiLuJe: "all our target platforms will kill WiFi on suspend". One Basic 2024 user reports Wi-Fi staying up while asleep.
- confidence: medium
- status: agent
- sources: S-KOR-15

### KIN-C13: WMT firmware daemons on Kindle are started at boot
- claim: on MTK Kindles the WMT daemons appear to be started by an upstart `wmt` job and keep running (third-party jobs use `start on started wmt`). On Kobo, KOReader has to start them (koreader#16222). The reboot risk from writing `/dev/wmtWifi` is probably lower, but the plugin should check the daemons and abort rather than start them.
- confidence: medium
- status: agent / inference
- sources: S-KIN-27, S-KOR-10
- recheck: on device `status wmt; ps | grep -i wmt` (Q-KIN-01)

### KIN-C14: never rmmod the MTK Wi-Fi driver
- claim: Amazon's connsys driver does not fully power the hardware down on unload. Don't `rmmod wlan_drv_gen4m`.
- confidence: medium
- status: agent
- sources: S-KIN-29

### KIN-C15: no hidden AP/tethering feature
- claim: Kindle firmware has no AP/tethering feature. In Amazon's Wi-Fi Simple Setup the Kindle is the client (provisionee).
- confidence: medium
- status: agent
- sources: S-KIN-38

### KIN-C16: no prior art for hostapd on Kindle
- claim: no report of hostapd or a soft AP on any Kindle was found. The closest is a 2011 K3 thread about `/etc/init.d/wifi --mode=ap`, never shown working.
- confidence: medium (negative result)
- status: agent
- sources: S-KIN-39

### KIN-C17: jailbreak availability (existence only, per D4)
- claim: as of Oct 2026, public jailbreaks exist for most firmware up to 5.19.x, including PW6, Colorsoft and Scribe 2. Status for 5.20.x is unknown.
- confidence: medium
- status: agent, **fast-moving**
- sources: S-KIN-34
- recheck: kindlemodding.org and KindleModding GitHub

### KIN-C18: Atheros Kindles: stock driver is wext-only, but cfg80211/ath6kl are in Amazon's build
- claim: `imx60_wario_defconfig` has `CONFIG_AR6003=m`, `# CONFIG_AR6003_CFG80211 is not set`, `CONFIG_CFG80211=m`, `CONFIG_NL80211_TESTMODE=y`, `CONFIG_COMPAT_WIRELESS=y`, `CONFIG_COMPAT_WIRELESS_MODULES=m`, `CONFIG_ATH_COMMON=m`, `CONFIG_ATH6KL=m`, `CONFIG_ATH6KL_SDIO=m`, `CONFIG_WIRELESS_EXT=y`.
- confidence: high
- status: verified (contradicted for the shipped kernel by KIN-C19)
- sources: S-KIN-04
- recheck: grep those lines in S-KIN-04

### KIN-C19: PW2 shipped kernel config differs from the GPL defconfig
- claim: a PW2 stock dump shows `ar6003` loaded, `CONFIG_CFG80211 is not set` and `WIRELESS_EXT=y`.
- confidence: medium
- status: contradicted (vs KIN-C18)
- sources: S-KIN-11
- recheck: on device `zcat /proc/config.gz | grep CFG80211; find /lib/modules -name 'cfg80211.ko' -o -name '*ath6kl*'` (Q-KIN-06)
- notes: if the shipped kernel lacks cfg80211, the compat-wireless `cfg80211.ko` provides it. If it were built in (`=y`), it couldn't be swapped.

### KIN-C20: Amazon's tree carries Qualcomm's ath6kl compat package
- claim: `compat-wireless/compat_version` = `3.3-OSR-2012-10-11-15-g2bd3ebf`; base tree `branching-rel-3.2.3-73-g263e071`. It is wired into Kbuild ("Compat wireless support for Eink devices"), and contains `ath6kl/` with `cfg80211.c`, `wmiconfig.c`, `softmac.c`, `recovery.c` plus `.orig` files (Amazon patches).
- confidence: high
- status: verified (compat_version); agent (rest)
- sources: S-KIN-06, S-KIN-07, S-KIN-10, S-KIN-03

### KIN-C21: Amazon's ath6kl is ready for hostapd and has a calibration-file param
- claim: `init.c` sets `WIPHY_FLAG_HAVE_AP_SME | WIPHY_FLAG_AP_PROBE_RESP_OFFLOAD`, so hostapd uses device AP SME and no monitor interface is needed. Under `#ifdef CONFIG_LAB126` it defines `module_param_string(board_data_file, …)` (default `AR6003_REV3_BOARD_DATA_FILE`).
- confidence: high
- status: verified
- sources: S-KIN-08, S-ATH-20

### KIN-C22: Amazon's ath6kl implements AP callbacks
- claim: `cfg80211.c` registers AP operation via 3.0-era `add_beacon`/`set_beacon`/`del_beacon`/`set_channel` and handles WPA-PSK ciphers in `ath6kl_ap_beacon`.
- confidence: medium
- status: agent
- sources: S-KIN-09
- notes: the main agent's fetch of `init.c` did not show `NL80211_IFTYPE_AP`; it is expected in `cfg80211.c` (not re-checked)

### KIN-C23: Kindle Basic 8th gen uses bcmdhd (cfg80211 build), BCM4343W
- claim: serial boot log of Heisenberg (KT3, `3.10.53-lab126`) shows `dhd_module_init in`, `found wifi platform device bcmdhd_wlan`, `CFG80211-ERROR) wl_event_handler`, `download firmware '/opt/brcm_4343w/wifi/firmware/fw_bcmdhd_sr.bin'`, `Dongle Host Driver, version 1.201.59 (r506368)` and `Register interface [wlan0]`. The `wl_cfg80211` path means hostapd nl80211 is usable. `dhd_module_init` at ~30 s suggests the driver is a module loaded by userspace.
- confidence: high
- status: verified
- sources: S-KIN-12, S-KIN-13
- recheck: fetch S-KIN-12 and search for `Dongle Host Driver`, `fw_bcmdhd_sr.bin`, `wl_event_handler`

### KIN-C24: a PW3 ran upstream ath6kl (station mode, partial)
- claim: a PW3 on mainline Linux (Fedora ARM) uses upstream ath6kl with `/lib/firmware/ath6k/AR6003/hw2.1.1/`. The AR6803G "seems to be an AR6003 in a QFN package". `bdata.SD32.bin` is identical to the stock board data. Before linking it to `bdata.bin`, Wi-Fi associated and got an IP but "didn't seem to work well"; the fix was expected to work but not reported tested. No AP test.
- confidence: high (what was said)
- status: verified
- sources: S-KIN-14

### KIN-C25: Kindle Touch vendor-driver firmware path
- claim: the Kindle Touch vendor driver loads firmware from `/opt/ar6k/target/AR6003/hw2.1.1/bin/` (calibration `AR6103_CCK16dbm_QCA_08032011.bin`). Firmware loading goes through the `/sbin/hotplug` helper and `/usr/libexec/firmware.sh`.
- confidence: medium
- status: agent
- sources: S-KIN-15

### KIN-C26: Oasis 1 (duet) Wi-Fi is unclear
- claim: `imx60_duet_defconfig` has `CONFIG_CFG80211=y`, `CONFIG_CFG80211_WEXT=y`, all Atheros drivers disabled, and no Broadcom driver in-tree. It is probably an out-of-tree bcmdhd.
- confidence: low
- status: agent / inference
- sources: S-KIN-05

## Porting sketch: MTK Kindles (inference, needs Q-KIN-01..05)

1. Detection: `Device:isKindle() and Device:isMTK()`, `/dev/wmtWifi` exists, `/sys/module/wlan_drv_gen4m` present.
2. Start:
   1. Remember whether `/sys/class/net/wlan0` existed.
   2. `NetworkMgr:turnOffWifi()` (LIPC `wirelessEnable 0`).
   3. `stop wifid`.
   4. Verify WMT daemons are running; abort if not.
   5. `echo A > /dev/wmtWifi`, wait for `ap0`.
   6. hostapd (nl80211), then `ip addr add 192.168.42.1/24 dev ap0` and `iptables -I INPUT -i ap0 -j ACCEPT; iptables -I OUTPUT -o ap0 -j ACCEPT`, then udhcpd.
   7. `lipc-set-prop com.lab126.powerd preventScreenSaver 1`.
3. Stop: delete the iptables rules, `echo 0 > /dev/wmtWifi`, `start wifid`, `preventScreenSaver 0`, offer to re-enable Wi-Fi.
4. Binaries: current static armhf hostapd/udhcpd (kernel 4.9 ≥ 3.2).

## Porting sketch: Broadcom Kindles (inference, needs Q-KIN-07)

1. Find Amazon's `insmod` line and params (`/etc/upstart`, `/sys/module/*dhd*/parameters/`).
2. `stop wifid`, `rmmod` the driver, re-`insmod` it with **`op_mode=2`** plus Amazon's `firmware_path`/`nvram_path`.
3. hostapd nl80211 on `wlan0` (look for `device_ap_sme=1`, `AP-ENABLED`), plus IP, firewall, udhcpd.
4. If no beacon, try a fallback firmware (BRCM-C08). Basic 8th gen (3.10) runs the current binary; Oasis 1 (3.0.35) needs musl.

## Porting sketch: Atheros Kindles (inference, needs Q-KIN-06)

1. Check whether `/lib/modules` already has ath6kl/cfg80211. If not, build them from the 3.0.35-lab126 tree with `imx60_wario_defconfig` (vermagic match). Fallback: backports-4.4.2.
2. Bundle linux-firmware `ath6k/AR6003/hw2.1.1`; pass `board_data_file=` (device calibration or `bdata.SD32.bin`).
3. `stop wifid`, `rmmod ar6003`, `insmod` compat/cfg80211/ath6kl modules, then hostapd (`hw_mode=g`, `ieee80211n=0`), IP, firewall, udhcpd. Reverse on stop.
4. Rebuild hostapd/udhcpd with musl (kernel 3.0.35 < 3.2).
