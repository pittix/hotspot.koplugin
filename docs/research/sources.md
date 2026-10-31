---
topic: sources
last_reviewed: 2026-10-31
---

# Source registry

Columns: **ID** · **URL** · **type** · **supports** (claim IDs) · **status** · **notes**.
Status: `verified` (fetched by the main agent on 2026-10-31 and content confirmed), `agent` (cited by a research subagent, not re-fetched), `snippet` (only seen via search snippets / page blocked), `dead` (URL failed; alternative given).
All accessed 2026-10-31 unless noted.

## Local (this repository)

| ID | URL / path | type | supports | status | notes |
|---|---|---|---|---|---|
| S-LOC-01 | `hostapd` (plugin root) | binary | BASE-C01 | verified | reproduce: `file hostapd; readelf -A hostapd; strings hostapd \| grep -E 'hostapd v\|^2\.10$\|GCC: \|GLIBC_ABI_DT_RELR'` |
| S-LOC-02 | `udhcpd` (plugin root) | binary | BASE-C02 | verified | reproduce: `file udhcpd; readelf -A udhcpd; strings udhcpd \| grep 'BusyBox v'` |
| S-LOC-03 | `main.lua` (plugin root) | source | BASE-C03 | verified | BACKENDS table, `Device:isKobo()` guard, `WIFI_MODULE`, enable/disable-wifi.sh |
| S-LOC-04 | `README.md` (plugin root) | doc | BASE-C03 | verified | MediaTek notes, koreader#13197/#16222 references |
| S-LOC-05 | https://github.com/thorondir/hotspot.koplugin | upstream repo | BASE-C03 | verified | original plugin (commits by Ying Stokes, GitHub `thorondir`), Clara 2E only; `pittix/hotspot.koplugin` is a fork. No licence file shown |
| S-FS-01 | https://github.com/abrahamnm/filesync.koplugin ; fork https://github.com/pittix/filesync.koplugin (branches `feat/eink-mode`, `fix/aborted-download-hang`) | companion repo | D3 | agent (from the filesync-eink session, 2026-10-31) | filesync.koplugin by abrahamnm, AGPLv3: HTTP file manager on the reader, port 80 (fallback 8080), `filesync.local` via mDNS. E-ink browser mode is on the fork, upstream PR not opened yet. Hotspot+filesync not yet tested end to end |

## KOReader (code and issues)

| ID | URL | type | supports | status | notes |
|---|---|---|---|---|---|
| S-KOR-01 | https://github.com/koreader/koreader/blob/master/frontend/device/kindle/device.lua | source | KIN-C02, KIN-C03, KIN-C11 | verified | look for `isMTK = yes`, `kindleEnableWifi`, `wirelessEnable`, `return "wlan0"` |
| S-KOR-02 | https://raw.githubusercontent.com/koreader/koreader/master/frontend/device/pocketbook/device.lua | source | PB-C03, PB-C04, PB-C06, PB-C07 | verified | look for `inkview.WiFiPower`, `/mnt/secure/su`, `isB288SoC`, `REQ_KEYLOCK`, `iv_sleepmode` |
| S-KOR-03 | https://raw.githubusercontent.com/koreader/koreader/master/platform/pocketbook/koreader.app | source | PB-C04 | verified | `/mnt/secure/su /bin/chmod 644 /dev/input/*` |
| S-KOR-04 | https://raw.githubusercontent.com/koreader/koreader/master/platform/remarkable/enable-wifi.sh | source | RM-C03 | verified | modprobe brcmfmac, stop wpa_supplicant unit, own wpa_supplicant |
| S-KOR-05 | https://github.com/koreader/koreader/pull/11287 | PR | RM-C09 | agent | rM1 shares the Wi-Fi script; no MODULE_UNLOAD on rM1 |
| S-KOR-06 | https://raw.githubusercontent.com/koreader/koreader/master/platform/cervantes/enable-wifi.sh | source | OTH-C01 | agent | PCB 22/23 → `dhd` nl80211; else `8189fs` wext; iface eth0 |
| S-KOR-07 | https://raw.githubusercontent.com/koreader/koreader/master/platform/bookeen/wlan.sh | source | OTH-C02 | agent | `8188eu.ko` for 3.0.8+, wext, wlan0 |
| S-KOR-08 | https://raw.githubusercontent.com/koreader/koreader/master/frontend/device/bookeen/device.lua | source | OTH-C02 | agent | Bookeen model list |
| S-KOR-09 | https://github.com/koreader/koreader/blob/master/plugins/SSH.koplugin/main.lua | source | KIN-C08, KIN-C10 | agent | runs iptables on Kindle (needs root) |
| S-KOR-10 | https://github.com/koreader/koreader/issues/16222 | issue | KIN-C13, BASE-C03 | agent | MediaTek wmt daemons fix (used by plugin) |
| S-KOR-11 | https://github.com/koreader/koreader/issues/13197 | issue | BASE-C03 | agent | MediaTek reboot when chip powered without daemons |
| S-KOR-12 | https://github.com/koreader/koreader/pull/12056 | PR | KIN-C03 | agent | NiLuJe: "We don't do *anything*, it's all wifid" |
| S-KOR-13 | https://github.com/koreader/koreader/blob/master/frontend/ui/network/manager.lua | source | KIN-C03 | agent | isConnected via operstate + getifaddrs |
| S-KOR-14 | https://github.com/koreader/koreader/blob/master/frontend/device/kindle/powerd.lua | source | KIN-C11 | agent | Kindle suspend via powerd |
| S-KOR-15 | https://github.com/koreader/koreader/issues/14537 | issue | KIN-C12 | agent | "all our target platforms will kill WiFi on suspend" |
| S-KOR-16 | https://github.com/koreader/koreader/blob/master/plugins/keepalive.koplugin/main.lua | source | KIN-C11 | agent | `preventScreenSaver` via lipc |
| S-KOR-17 | https://github.com/koreader/koreader/pull/13620 | PR | RM-C07 | agent | reMarkable Paper Pro support (XOVI, qtfb shim) |
| S-KOR-18 | https://github.com/koreader/koreader/tree/master/frontend/device | tree | OTH-C03 | agent | device dirs: android, bookeen, cervantes, dummy, generic, kindle, kobo, pocketbook, remarkable, sdl |
| S-KOR-19 | https://github.com/koreader/koreader/tree/master/platform | tree | OTH-C03 | agent | `platform/sony-prstux` still exists |

## Kindle

| ID | URL | type | supports | status | notes |
|---|---|---|---|---|---|
| S-KIN-01 | https://raw.githubusercontent.com/zampierilucas/kindle-ble-hid/master/kindle_system_info.md | device dump | KIN-C01 | verified | **use branch `master`**; `blob/main/...` returns 404. Look for `wlan_drv_gen4m`, `wmt_chrdev_wifi`, `wmt_drv`, `4.9.77-lab126`, `glibc 2.20` |
| S-KIN-02 | https://github.com/zampierilucas/kindle-ble-hid/blob/main/kindle_kernel_config.txt | kernel config dump | KIN-C04 | agent | raw `main` URL 404'd; try `.../master/kindle_kernel_config.txt` |
| S-KIN-03 | https://github.com/katadelos/linux-3.0.35-lab126 | GPL kernel mirror | KIN-C18, KIN-C20, KIN-C26 | agent | Kindle_src_5.10.1.1; covers wario/duet |
| S-KIN-04 | https://raw.githubusercontent.com/katadelos/linux-3.0.35-lab126/master/arch/arm/configs/imx60_wario_defconfig | kernel config | KIN-C18, ATH-C08 | verified | `CONFIG_CFG80211=m`, `CONFIG_ATH6KL=m`, `# CONFIG_AR6003_CFG80211 is not set`, `CONFIG_COMPAT_WIRELESS=y` |
| S-KIN-05 | https://github.com/katadelos/linux-3.0.35-lab126/blob/master/arch/arm/configs/imx60_duet_defconfig | kernel config | KIN-C26 | agent | `CFG80211=y`, `CFG80211_WEXT=y`, no in-tree Broadcom |
| S-KIN-06 | https://raw.githubusercontent.com/katadelos/linux-3.0.35-lab126/master/compat-wireless/compat_version | file | KIN-C20, ATH-C08 | verified | content: `3.3-OSR-2012-10-11-15-g2bd3ebf` |
| S-KIN-07 | https://raw.githubusercontent.com/katadelos/linux-3.0.35-lab126/master/compat-wireless/compat_base_tree_version | file | KIN-C20 | agent | `branching-rel-3.2.3-73-g263e071` |
| S-KIN-08 | https://raw.githubusercontent.com/katadelos/linux-3.0.35-lab126/master/compat-wireless/drivers/net/wireless/ath/ath6kl/init.c | source | KIN-C21, ATH-C08 | verified | `WIPHY_FLAG_HAVE_AP_SME`, `WIPHY_FLAG_AP_PROBE_RESP_OFFLOAD`, `module_param_string(board_data_file` under `CONFIG_LAB126` |
| S-KIN-09 | https://raw.githubusercontent.com/katadelos/linux-3.0.35-lab126/master/compat-wireless/drivers/net/wireless/ath/ath6kl/cfg80211.c | source | KIN-C22 | agent | AP callbacks add/set/del_beacon, WPA-PSK |
| S-KIN-10 | https://raw.githubusercontent.com/katadelos/linux-3.0.35-lab126/master/compat-wireless/Kconfig (and `/Makefile`) | source | KIN-C20 | agent | "Compat wireless support for Eink devices" |
| S-KIN-11 | https://gist.github.com/gdamjan/13fc8c75a2f8bb34541da0948739baed | device dump | KIN-C19 | agent | PW2 lsmod shows `ar6003`; config says CFG80211 not set (contradicts S-KIN-04) |
| S-KIN-12 | https://www.mobileread.com/forums/showthread.php?p=3726053 | forum (serial log) | KIN-C23, BRCM-C05 | verified | Heisenberg/KT3, `3.10.53-lab126`, `Dongle Host Driver, version 1.201.59`, `fw_bcmdhd_sr.bin`, `CFG80211-ERROR) wl_event_handler`. Long page: use WebFetch offset |
| S-KIN-13 | https://www.mobileread.com/forums/showthread.php?p=4133943 | forum (serial log) | KIN-C23 | agent | second KT3 log, same driver |
| S-KIN-14 | https://www.mobileread.com/forums/showthread.php?p=4103442 | forum | KIN-C24, ATH-C02 | verified | PW3 mainline: AR6803G ≈ AR6003 QFN, ath6kl, `bdata.SD32.bin`; partial results, station only |
| S-KIN-15 | https://www.mobileread.com/forums/showthread.php?p=4221618 | forum | KIN-C25, ATH-C02 | agent | Kindle Touch `/opt/ar6k/target/AR6003/hw2.1.1/bin/`, `/usr/libexec/firmware.sh` |
| S-KIN-16 | https://www.mobileread.com/forums/showthread.php?p=4110907 | forum | KIN-C06 | verified (mismatch) | post p=4110907 is NiMa's serial-wiring reply; the SD32 board-data info on that page is bdm310's post p=4103442, i.e. **duplicate of S-KIN-14**. Cite S-KIN-14 instead |
| S-KIN-17 | https://barebox.org/doc/2019.06.0/_sources/boards/imx/amazon-kindle-4-5.rst.txt | doc | KIN-C06 | agent | K4/K5 i.MX50 |
| S-KIN-18 | https://www.mobileread.com/forums/showthread.php?page=2&t=246657 | forum | KIN-C06 | verified (mismatch) | thread "PaperWhite 1 Kernel Build Walkthrough"; page 2 does **not** contain `2.6.31-rt11-lab126` (only `linux-2.6.31.tar.gz` by bulsa). Kernel string for K4/Touch/PW1 still needs another source |
| S-KIN-19 | https://techinfodepot.shoutwiki.com/wiki/Amazon_Kindle_7_Gen_(WP63GW) | hw database | KIN-C06 | agent | AR6003G |
| S-KIN-20 | https://techinfodepot.shoutwiki.com/wiki/Amazon_Kindle_Paperwhite_2_Wi-Fi_6_Gen_(DP75SDI) | hw database | KIN-C06 | agent | PW2 chip |
| S-KIN-21 | https://www.ifixit.com/Teardown/Kindle+Voyage+Teardown/32278 | teardown | KIN-C06 | agent | Voyage chip |
| S-KIN-22 | https://electronics360.globalspec.com/article/7407/teardown-amazon-s-kindle-oasis | teardown | KIN-C06 | agent | Oasis 1 i.MX6SL, Broadcom |
| S-KIN-23 | https://github.com/zampierilucas/kindle-hid-passthrough/issues/60 | issue | KIN-C06 | agent | kernels per model (3.10.53, 4.1.15), BCM4343 |
| S-KIN-24 | https://github.com/zampierilucas/kindle-hid-passthrough/blob/main/docs/compatibility.md | doc | KIN-C06 | agent | chip vendor per model |
| S-KIN-25 | https://github.com/zampierilucas/kindle-hid-passthrough (also /issues/167) | repo | KIN-C06 | agent | rex (PW4) i.MX6SLL 4.1.15 |
| S-KIN-26 | https://itc.ua/articles/obzor-amazon-kindle-oasis-2017/amp/ | review | KIN-C06 | agent | Oasis 2 i.MX7D (medium) |
| S-KIN-27 | https://gist.github.com/liquidguru/1e9c77f9389cdf23f94d2a94b220c90a | notes | KIN-C08, KIN-C13 | agent | PW6 root shell; upstart `wmt` job; `lipc-send-event` broken on 5.18.5 |
| S-KIN-28 | https://github.com/abhaymettu/omarchy-kindle | repo | KIN-C04 | agent | MTK modules unsigned; 4.9.77 |
| S-KIN-29 | https://github.com/SolAstrius/kexec-kindle-mt8512 | repo | KIN-C14 | agent | connsys doesn't fully power down on unload |
| S-KIN-30 | https://github.com/NiLuJe/KindleTool | repo | KIN-C06 | agent | platform codenames (bellatrix3/4, platpa6, platcs8) |
| S-KIN-31 | https://www.engadget.com/mobile/tablets/amazon-adds-the-kindle-scribe-colorsoft-and-scribe-3-to-its-writing-tablet-lineup-145031938.html | news | KIN-C06 | agent | Scribe 3 / Scribe Colorsoft |
| S-KIN-32 | https://kindlemodding.org/jailbreaking/post-jailbreak/koreader.html | doc | KIN-C07 | agent | kindlehf for FW ≥ 5.16.3 |
| S-KIN-33 | https://github.com/Niluje/koxtoolchain | repo | BASE-C01 | agent | toolchains for older-kernel builds |
| S-KIN-34 | https://kindlemodding.org/jailbreaking/WinterBreak/ ; https://github.com/KindleModding ; https://github.com/KindleModding/SpringBreak ; https://terminalbytes.com/sanctuary-kindle-jailbreak-koreader-2026/ ; https://blog.the-ebook-reader.com/2026/09/01/new-spidercat-kindle-jailbreak-is-the-easiest-method-yet/ ; https://github.com/archit15singh/kindle-jailbreak/blob/main/README.md | docs/news | KIN-C17 | agent | **fast-moving**: jailbreak coverage by firmware |
| S-KIN-35 | https://www.mobileread.com/forums/showthread.php?t=262385 | forum | KIN-C09 | agent | `restart wifid`, `/etc/upstart/wifid.conf` |
| S-KIN-36 | https://homecircuits.eu/blog/repurposing-kindle-paperwhite-dashboard/ | blog | KIN-C09 | agent | `wpa_cli` present |
| S-KIN-37 | https://www.mobileread.com/forums/showthread.php?p=2413909 | forum | KIN-C10 | agent | stock iptables INPUT DROP (FW 5.3.3 era) |
| S-KIN-38 | https://developer.amazon.com/docs/frustration-free-setup/understand-wi-fi-simple-setup.html | vendor doc | KIN-C15 | agent | Kindle is provisionee |
| S-KIN-39 | https://www.mobileread.com/forums/showthread.php?p=1361281 ; https://www.mobileread.com/forums/showthread.php?p=1399814 | forum | KIN-C16 | verified (mismatch) | thread "Kindle 3 wifi mode monitor \| sniffing"; the two cited posts (kranu 2011-01-27, m0ngr31 2011-02-16) do **not** mention AP/ad-hoc or `--mode=ap`. Does not support KIN-C16 |
| S-KIN-40 | https://www.mobileread.com/forums/showthread.php?p=4604552 | forum | KIN-C27, KIN-C28 | verified | "Quick Share/Nearby Share Plugin for KoReader", unrealJune, 2026-08-17: SoftAP on Kindle Voyage FW 5.13.6 with "cross-compiled hostapd plus busybox udhcpd", stock `ath6kl_sdio`; check with `iw phy phy0 info` for `* AP` |
| S-KIN-41 | https://github.com/unrealJune/kindshare ; .../blob/main/docs/COMPATIBILITY.md ; .../blob/main/docs/PORTING.md ; https://raw.githubusercontent.com/unrealJune/kindshare/main/device/kindle-ap.sh | repo (MIT) | KIN-C27, KIN-C28 | verified | kindshare by unrealJune. Voyage (Icewine, i.MX6SL), 3.0.35-lab126, AR6003 hw2.1.1, "upstream `ath6kl_sdio` (compat-wireless backport), v3.4.0.158". hostapd 2.11 static armv7 (Docker/QEMU). `kindle-ap.sh`: `stop wifid`, `killall wpa_supplicant`, `modprobe ath6kl_sdio`, hostapd on `wlan0`, `192.168.55.1/24`, udhcpd, iptables INPUT/OUTPUT rules, 600 s no-client revert, `start wifid` on stop |

## PocketBook

| ID | URL | type | supports | status | notes |
|---|---|---|---|---|---|
| S-PB-01 | https://raw.githubusercontent.com/pocketbook/kernel-b288/master/B288.config | kernel config | PB-C01 | verified | `Linux/arm 3.10.65`, `CONFIG_CFG80211=y`, `CONFIG_MAC80211=y`, `CONFIG_XRADIO=m`, `CONFIG_XRADIO_SUSPEND_POWER_OFF=y` |
| S-PB-02 | https://github.com/pocketbook/kernel-b288 | GPL kernel | PB-C01 | verified | one commit, Sep 2020 |
| S-PB-03 | https://github.com/pocketbook/kernel-b300/tree/master/drivers/net/wireless | GPL kernel tree | PB-C08 | verified | dirs incl. `xradio`, `bcmdhd`, `rtl8723bs_vq0`, `rtl8723cs`; no defconfig at root |
| S-PB-04 | https://github.com/pocketbook?tab=repositories | org listing | PB-C08 | verified | kernel-b300 / uboot-b300 updated Mar 2026; Platform_A13, Platform_MX6, SDK_6.3.0 |
| S-PB-05 | https://github.com/pocketbook/Platform_A13 | GPL kernel | PB-C11 | agent | 3.0.8, RTL8188EUS build flags |
| S-PB-06 | https://github.com/pocketbook/Platform_MX6 | GPL kernel | PB-C12 | agent | 3.0.35, CFG80211 not set (PB631) |
| S-PB-07 | https://www.mobileread.com/forums/showthread.php?p=4583437 (and p=4522396, p=4429705 from the same search) | forum | PB-C09 | snippet (mismatch) | claim "SDK 6.8 for B300 uses kernel 4.9.56"; post p=4583437 (nhedgehog, 2026-05-02, PB62x/740 thread) does **not** mention B300 or 4.9.56. p=4522396/p=4429705 not checked |
| S-PB-08 | https://github.com/karabek/xradio/ | repo | PB-C02 | agent | generic XR819 driver (not PocketBook-specific) |

## reMarkable

| ID | URL | type | supports | status | notes |
|---|---|---|---|---|---|
| S-RM-01 | https://raw.githubusercontent.com/torvalds/linux/master/arch/arm/boot/dts/nxp/imx/imx7d-remarkable2.dts | DTS | RM-C01 | agent | `brcm,bcm4329-fmac` on usdhc2 |
| S-RM-02 | https://git.zx2c4.com/linux-dev/commit/?id=d8075e9490309d8f0d50869987a9e1d9426e9e4f | commit | RM-C01 | agent | rM2 Wi-Fi DT commit |
| S-RM-03 | https://github.com/reMarkable/brcmfmac-firmware | firmware repo | RM-C02 | agent | "Concurrent APSTA", "SoftAP association fix" |
| S-RM-04 | https://remarkable.guide/guide/access/ssh.html | community doc | RM-C04 | agent | root SSH, Developer Mode, `rm-ssh-over-wlan` |
| S-RM-05 | https://github.com/reMarkable/linux-imx-rm | GPL kernel | RM-C05 | agent | ferrari/chiappa/tatsu defconfigs |
| S-RM-06 | https://github.com/gitman-101111/chiappa | community | RM-C06 | agent | Move: i.MX93 + NXP IW611 mwifiex |
| S-RM-07 | https://newreleases.io/project/github/koreader/koreader/release/v2025.08 | release notes | RM-C07 | agent | KOReader v2025.08 Paper Pro |
| S-RM-08 | https://www.mobileread.com/forums/showthread.php?p=4578364 | forum | RM-C07 | agent | Move via AppLoad |
| S-RM-09 | https://www.github.com/toltec-dev/toltec/releases | releases | RM-C07 | agent | toltec ≤ OS 3.3.x |
| S-RM-10 | https://github.com/rM-self-serve/webinterface-wifi | repo | RM-C08 | agent | only exposes web UI over Wi-Fi (not an AP) |

## Other platforms (incl. out of scope)

| ID | URL | type | supports | status | notes |
|---|---|---|---|---|---|
| S-OTH-01 | https://wiki.mobileread.com/wiki/PRST2 | wiki | OTH-C04 | agent | Sony PRS-T2 AR6003 |
| S-OTH-02 | https://www.mobileread.com/forums/showthread.php?p=4558337 | forum | OTH-C01 | agent | Cervantes unlock server down |
| S-OTH-03 | https://www.mobileread.com/forums/showthread.php?p=4615824 | forum | OTH-C05 | agent | Tolino Shine 5 "Kobo mode" (wipes) |
| S-OTH-04 | https://www.mobileread.com/forums/showthread.php?p=4421729 | forum | OTH-C05 | agent (partial mismatch) | thread "Can I convert a Tolino into a kobo?"; post p=4421729 itself (Terisa de morgan, 2024-05-07) is empty. "FW 5.x ignores KoboRoot.tgz" must be elsewhere in the thread (not pinned) |
| S-OTH-05 | https://www.mobileread.com/forums/showthread.php?p=4267969 ; https://liliputing.com/tolinos-new-ereaders-look-familiar-if-kobo-devices-ran-android/ ; https://www.mobileread.com/forums/showthread.php?p=4541118 ; https://www.github.com/koreader/android-luajit-launcher/pull/457 | forum/news | OTH-C06 | agent | Android Tolinos = Kobo hardware (out of scope, D2) |
| S-OTH-06 | https://developer.android.com/develop/connectivity/wifi/localonlyhotspot | vendor doc | OTH-C07 | agent | out of scope (D2), kept for traceability |
| S-OTH-07 | https://raw.githubusercontent.com/koreader/android-luajit-launcher/master/assets/android.lua ; https://raw.githubusercontent.com/koreader/android-luajit-launcher/master/app/src/main/AndroidManifest.xml | source | OTH-C07 | agent | out of scope (D2) |
| S-OTH-08 | https://www.mobileread.com/forums/showthread.php?p=4119531 | forum | OTH-C07 | agent | Boox hidden tethering UI (out of scope) |

## Wi-Fi chips: general

| ID | URL | type | supports | status | notes |
|---|---|---|---|---|---|
| S-CHIP-01 | https://wireless.docs.kernel.org/en/latest/en/users/drivers.html | kernel doc | CHIP-C01 | agent | driver feature table (AP column) |
| S-CHIP-02 | https://lists.infradead.org/pipermail/lede-dev/2018-March/011517.html | mailing list | CHIP-C01 | agent | Realtek `cfg80211_rtw_add_virtual_intf` monitor-only |
| S-CHIP-03 | https://github.com/pritambaral/hostapd-rtl871xdrv/ | repo | CHIP-C01, OTH-C02 | agent | Realtek rtl871xdrv hostapd patch |
| S-CHIP-04 | https://lkml.iu.edu/2511.2/01116.html | mailing list | CHIP-C01 | agent | upstream `nxpwifi` in progress |

## Atheros AR6003 / ath6kl

| ID | URL | type | supports | status | notes |
|---|---|---|---|---|---|
| S-ATH-01 | https://raw.githubusercontent.com/torvalds/linux/master/drivers/net/wireless/ath/ath6kl/wmi.h | source | ATH-C04 | verified | `#define AP_MAX_NUM_STA 10` (warning: change needs driver+firmware rebuild) |
| S-ATH-02 | https://wireless.wiki.kernel.org/en/users/Drivers/ath6kl | wiki | ATH-C01 | agent | out of staging in 3.2 |
| S-ATH-03 | https://wireless.docs.kernel.org/en/latest/en/users/drivers/ath6kl.html | kernel doc | ATH-C01 | agent | "AP mode (requires hostapd 1.0 or newer)", WPA/WPA2, no monitor |
| S-ATH-04 | https://github.molgen.mpg.de/git-mirror/linux/commit/6a7c9badab158086b6162c661a47c4f1a4a68e92 | commit | ATH-C01 | agent | "Add functionality for starting AP mode" |
| S-ATH-05 | https://github.molgen.mpg.de/git-mirror/linux/commit/6e4604c8b91743c5a797fc2674544618854ed0f2 | commit | ATH-C01 | agent | "Allow AP mode to be configured" |
| S-ATH-06 | https://lore.kernel.org/all/1314730691-12089-1-git-send-email-jouni@qca.qualcomm.com/T/ | mailing list | ATH-C01 | snippet | AP patches "require a new firmware build" |
| S-ATH-07 | https://android-kvm.googlesource.com/linux/+/30295c8936f3a426985e99bebb17d72bd7847910 | commit | ATH-C03 | agent | staging ath6kl: STA+AP; AP b/g only |
| S-ATH-08 | https://gitlab.com/kernel-firmware/linux-firmware/-/raw/main/WHENCE | licence index | ATH-C05, BRCM-C02 | agent | AR6003 hw2.1.1 files + LICENCE.atheros_firmware; Cypress 43430 files |
| S-ATH-09 | https://lab.nexedi.cn/kirr/linux/-/commit/65a8b4cc511b68712799e91137324f2abece7d3e | commit | ATH-C05 | agent | fw-3.bin (API 3) |
| S-ATH-10 | https://lists.infradead.org/pipermail/hostap/2013-November/028998.html | mailing list | ATH-C03 | agent | 11n AP: `nl80211: Failed to set channel … -22` |
| S-ATH-11 | https://lore.kernel.org/all/CAEk6gTAR5O8SAK9-tcr9nXujGpZN9HciYXg5y4CBQYVFWnKHYA@mail.gmail.com/T/ | mailing list | ATH-C03 | agent | AR6004 AP only without 11n |
| S-ATH-12 | https://kiwix.lema.org/stackoverflow.com_en_all_2023-11/questions/18109920/ath6kl-interface-is-not-up-for-ap-mode | Q&A mirror | ATH-C06 | agent | Android 4.2.2 AR6003 hostapd works manually |
| S-ATH-13 | https://github.com/torvalds/linux/commit/270df8f80d67 ; https://patchwork.kernel.org/project/linux-wireless/patch/20160704110719.7694-2-plemagourou@aldebaran.com/ | commit/patch | ATH-C07 | agent | 2016 tethering fixes (AR9374) |
| S-ATH-14 | https://docs.digi.com/resources/documentation/digidocs/embedded/dey/2.6/cc6/bsp_r_wifi-overview_ar6233 | vendor doc | ATH-C06 | agent | ConnectCore 6 i.MX6 ath6kl softAP ≤5 clients, AP-STA |
| S-ATH-15 | https://docs.yoctoproject.org/pipermail/meta-freescale/2014-February/007368.html | mailing list | ATH-C06 | agent | i.MX6 Sabre AR6103 ath6kl (bdata, STA issues) |
| S-ATH-16 | https://community.nxp.com/t5/i-MX-Processors/Problems-running-ath6kl-driver-for-AR6103-Wifi-on-i-mx6q-Sabre/m-p/304362 | forum | ATH-C06 | snippet | 403; proprietary driver STA-only, moved to ath6kl |
| S-ATH-17 | https://raw.githubusercontent.com/psyke83/AR6kSDK.3.0/master/AR6kSDK.3.0/host/tools/wmiconfig/wmiconfig.c ; https://github.com/dalingrin/android_system_wlan_atheros ; https://raw.githubusercontent.com/tjstyle/AR6kSDK-CAF/master/AR6kSDK.2.2.1.151/host/tools/wlan_tool/wlan_tool | source | ATH-C09 | agent | vendor AR6kSDK softAP via wmiconfig; no AP security option |
| S-ATH-18 | https://techinfodepot.shoutwiki.com/wiki/Seagate_GoFlex_Satellite_(500GB) | hw database | ATH-C06 | agent | negative: not Atheros |
| S-ATH-19 | https://cdn.kernel.org/pub/linux/kernel/projects/backports/stable/ ; https://lore.kernel.org/backports/20171013094226.10021-11-johannes@sipsolutions.net/ ; https://lkml.iu.edu/hypermail/linux/kernel/1404.1/01176.html | release index / ML | ATH-C10 | agent | backports v4.4.2 last with 3.0 support |
| S-ATH-20 | https://github.molgen.mpg.de/git-mirror/linux/commit/562a74803f4881772ba2375ec4e5aa0ad90f4caa | commit | ATH-C08 | agent | upstream added HAVE_AP_SME to ath6kl (Nov 2011) |

## Broadcom BCM4343W / bcmdhd / brcmfmac

| ID | URL | type | supports | status | notes |
|---|---|---|---|---|---|
| S-BRCM-01 | https://git.raptorcs.com/git/talos-op-linux/log/drivers/net/wireless/brcm80211/brcmfmac/bcmsdh.c?h=v4.4.4 | git log | BRCM-C01 | agent | BCM43430 added to brcmfmac (Mar 2015 → 4.1) |
| S-BRCM-02 | https://docs.raspap.com/features-experimental/ap-sta/ | doc | BRCM-C03 | agent | AP+STA via `uap0`, same channel |
| S-BRCM-03 | https://github.com/RaspAP/raspap-webgui/issues/462 | issue | BRCM-C04 | agent | ~8–10 clients |
| S-BRCM-04 | https://github.com/raspberrypi/firmware/issues/1403 | issue | BRCM-C04 | agent | 43455 fw crash at 8th client |
| S-BRCM-05 | https://www.github.com/CyanogenMod/android_device_htc_msm8660-common/blob/cm-10.1/bcmdhd.mk | build file | BRCM-C06 | agent | `WIFI_DRIVER_FW_PATH_AP`, `BOARD_HOSTAPD_DRIVER := NL80211` |
| S-BRCM-06 | https://android.googlesource.com/platform/hardware/broadcom/wlan/+/android-6.0.0_r3/bcmdhd/firmware/bcm4343 ; .../firmware/LICENSE.TXT | firmware + licence | BRCM-C08 | agent | `fw_bcm4343[_a1][_apsta].bin`; redistributable unmodified for Broadcom products |
| S-BRCM-07 | https://docs.yoctoproject.org/pipermail/meta-freescale/2017-June/020588.html | mailing list | BRCM-C05 | agent | NXP 4.1.15 BSP `CONFIG_BCMDHD=y` |
| S-BRCM-08 | https://raw.githubusercontent.com/nxp-imx/linux-imx/imx_4.1.15_2.0.0_ga/drivers/net/wireless/bcmdhd/Kconfig | source | BRCM-C05 | agent | default fw/nvram paths; WEXT only if no CFG80211 |
| S-BRCM-09 | https://community.nxp.com/thread/462224 ; https://community.nxp.com/thread/443700 | forum | BRCM-C07 | snippet | 403; Murata 1DX AP-ENABLED but not visible |
| S-BRCM-10 | https://wiki.somlabs.com/index.php/How_to_use_Murata_WiFi_on_VisionSOM-6ULL | vendor wiki | BRCM-C06 | agent | bcmdhd `op_mode=2` + stock hostapd + udhcpd recipe |
| S-BRCM-11 | https://git.depau.eu/mochabin/imx-firmware/commits/tag/android-10.0.0_2.5.0 | git log mirror | BRCM-C07 | snippet | host didn't resolve; "fw_bcmdhd.bin supports STA, Soft AP, STA+Soft AP" since bcmdhd 1.141.100.6 |
| S-BRCM-12 | https://coral.googlesource.com/imx-firmware/+/refs/heads/release-day/bcm/1DX_BCM4343W | firmware mirror | BRCM-C08 | agent | NXP 1DX `fw_bcmdhd.bin` (NXP licence) |
| S-BRCM-13 | https://lists.openwall.net/netdev/2017/05/21/34 | mailing list | BRCM-C08 | agent | DHD firmware under brcmfmac |

## Attribution (authors of forum posts and repos)

Checked 2026-10-31 for crediting in public posts (e.g. a MobileRead call for testers). Fetched with `showpost.php?p=<id>` (single post) or `showthread.php?p=<id>` (page). "match" = whether the post itself supports the claim it is cited for.

| Source | Author | Date | Thread / repo | match |
|---|---|---|---|---|
| S-LOC-05 | Ying Stokes (`thorondir`) | 2026-07-22 | thorondir/hotspot.koplugin | yes |
| S-FS-01 | abrahamnm (+ contributors) | — | abrahamnm/filesync.koplugin | yes |
| S-KOR-10 | winterwurzel | 2026-10-12 | koreader#16222 "Kobo FW 5.x (MTK): Wi-Fi can't come up when KOReader starts without Nickel" (WMT-daemon fix, tested on a Tolino Vision Color) | yes |
| S-KOR-11 | shuvashish76 (diagnosis: shuvashish76, NiLuJe) | 2025-02-02 | koreader#13197 "Clara BW: Device reboots when turning on wifi 1st time…" | yes |
| S-KIN-01, S-KIN-02, S-KIN-23..25 | zampierilucas | — | kindle-ble-hid, kindle-hid-passthrough | yes |
| S-KIN-03..10 | katadelos | — | linux-3.0.35-lab126 (mirror of Amazon's GPL release) | yes |
| S-KIN-11 | gdamjan | — | PW2 gist | yes |
| S-KIN-12 | Bergfux, post #392 | 2018-07-09 | "Serial Jailbreaking your fw >= 5.6.x Kindle for Dummies" (KT3 boot log). The `p=3726053` link lands on that page but p=3726053 itself is dsjstc's #393 | yes (page) |
| S-KIN-13 | rahuldhebri | 2021-06-27 | same thread, second KT3 boot log | yes |
| S-KIN-14 | bdm310, post #3 | 2021-03-17 | "PW3 Kindle Paperwhite 3 Schematics and Mainline u-boot/Linux" | yes |
| S-KIN-15 | katadelos | 2022-05-12 | "K5 Can't get self-compiled ar6003 module to work" (`firmware.sh` absent from non-Amazon builds; the `/opt/ar6k` path is elsewhere in the thread) | partial |
| S-KIN-27 | liquidguru | — | PW6 notes gist | yes |
| S-KIN-28 | abhaymettu | — | omarchy-kindle | yes |
| S-KIN-29 | SolAstrius | — | kexec-kindle-mt8512 | yes |
| S-KIN-30, S-KIN-33 | NiLuJe | — | KindleTool, koxtoolchain | yes |
| S-KIN-35 | morinew, post #3 | 2015-07-01 | "Disable connectivity check / connect to "island" WiFi" | yes |
| S-KIN-37 | knc1 | 2013-02-06 | "Managing the Kindle firewall" | yes |
| S-KIN-40, S-KIN-41 | unrealJune | 2026-08-17 | "Quick Share/Nearby Share Plugin for KoReader" / kindshare (MIT) | yes |
| S-PB-08 | karabek | — | xradio | yes |
| S-RM-08 | dkyates79 | 2026-04-08 | "KOReader on rM Paper Pro Move – installation & configuration" (FW 3.27.0.87, AppLoad not appearing) | yes |
| S-OTH-02 | iluuuk | 2026-01-05 | "KOReader running on BQ/Fnac devices" | partial (thread-level) |
| S-OTH-03 | bosa | 2026-10-13 | "NickelTiles: an app tile grid for the Kobo home screen (testers wanted)": Tolino Shine 5 (Clara BW hardware) running Kobo Clara BW FW 4.45.23697 | partial (no mention of the wipe) |
| S-KIN-16, S-KIN-18, S-KIN-39, S-PB-07 | — | — | see rows above | **no** |
