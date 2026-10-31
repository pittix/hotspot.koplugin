# Porting hotspot.koplugin to other e-readers (Kindle, PocketBook, …)

> Research report, 2026-10-31. Sources: web research (three parallel research agents) plus my own checks of key primary sources and of the plugin code and binaries. Nothing here has been tested on a device yet. Each target has an "on-device checks" list.

## Executive summary

| Target | Verdict | One-line reason |
|---|---|---|
| **Kindle PW5/SE, Basic 2022/2024, PW6, Scribe 1/2, Colorsoft (MediaTek)** | **Likely, best next target** | Same `wmt_drv` / `wmt_chrdev_wifi` / `wlan_drv_gen4m` stack as the Kobo Libra Colour (verified), kernel 4.9, KOReader runs as root. Needs: stop `wifid`, open the iptables firewall, block the screensaver |
| **PocketBook B288 devices (Touch Lux 4/5, InkPad 3, Touch HD 3, Color, InkPad X, …)** | **Likely if rooted** | mac80211 XRadio driver + cfg80211 in kernel 3.10.65 (verified), AP and probably STA+AP concurrency. Blocker: root (KOReader is unprivileged, but already uses `/mnt/secure/su` when present) |
| reMarkable 1 / 2 | Likely (not an e-reader per se, but a KOReader target) | brcmfmac (AP via nl80211), root by default, KOReader already takes Wi-Fi over from xochitl |
| Kindle PW4, Basic 8th/10th, Oasis 2/3 (Broadcom BCM4343) | Possible with work | Driver and AP firmware unverified |
| Kindle PW2/PW3/Voyage/Basic 7th, Oasis 1 | Possible with significant work | Vendor wext `ar6003` driver / kernel 3.0.35 → rebuilt hostapd or rebuilt `ath6kl` modules |
| PocketBook B300 (newest) | Unknown | Wi-Fi driver unverified, root much harder |
| Cervantes, Bookeen | Possible with work | Realtek vendor drivers → `rtl871xdrv` hostapd, old kernels |
| Older Kindles (K4/Touch/PW1), PocketBook A13 / i.MX6, Sony PRS-T | Unlikely | Very old kernels, vendor wext drivers |
| **Android readers (Boox, etc.)** | **Out of scope** | System tethering already exists: no reinventing the wheel |

**Cross-cutting conclusions:**

1. **The MediaTek backend already written for the Libra Colour is the most reusable asset.** It should port to MTK Kindles with only platform glue: Wi-Fi off via LIPC instead of Kobo scripts, `stop wifid`, firewall rules, screensaver inhibit.
2. **The bundled binaries are fine for all "Likely" targets.** All of them run kernel ≥ 3.2 on ARMv7+NEON. Rebuilds (musl or older-kernel glibc, `rtl871xdrv` backend) are only needed for the "with work" targets.
3. **The plugin's hardest Kobo-isms to remove:**
   - the `Device:isKobo()` guard
   - `WIFI_MODULE` (Kobo-only)
   - `./enable-wifi.sh` / `./disable-wifi.sh` (Kobo/reMarkable/Cervantes only; Kindle and PocketBook have no such scripts)
   - the assumption that the plugin already runs as root
4. **New concerns that don't exist on Kobo:**
   - a vendor network daemon that must be stopped or coexisted with (`wifid` on Kindle, `netagent`/inkview on PocketBook, `wpa_supplicant` unit on reMarkable)
   - a default-DROP firewall (Kindle)
   - privilege escalation via `su` (PocketBook)

## 0. What the plugin needs from a device (baseline from `main.lua`)

| Requirement | How the plugin uses it today (Kobo) |
|---|---|
| KOReader running with root (or CAP_NET_ADMIN) | `hostapd`, `ip addr add`, `udhcpd`, writing `/dev/wmtWifi` |
| Wi-Fi driver with AP mode exposed via **nl80211/cfg80211** | `hostapd` is built with `driver=nl80211` only |
| A way to get an AP interface | Marvell `moal` → `uap0`; MediaTek gen4m → write `A` to `/dev/wmtWifi` → `ap0` |
| A way to load/unload the Wi-Fi module without the vendor stack fighting back | `./enable-wifi.sh` / `./disable-wifi.sh` (KOReader Kobo scripts), `NetworkMgr` |
| Driver identification | `WIFI_MODULE` env var exported by KOReader's Kobo launcher |
| CPU/kernel able to run bundled binaries | see below |
| `ip` (iproute2/BusyBox) | assigning `192.168.42.1/24` |

### Bundled binaries (inspected locally)

- `hostapd`: **hostapd 2.10**, statically linked against **glibc** (Debian bookworm, GCC 12.2),
  ARMv7-A, **VFPv3 + NEON, hard-float**, `driver_nl80211` only, ELF note `for GNU/Linux 3.2.0`
  → **needs Linux kernel ≥ 3.2** and an ARMv7 CPU with NEON. Since it is static, the userland
  float ABI (armel vs armhf) of the target does **not** matter.
- `udhcpd`: Kobo's own **BusyBox v1.31.0**, static, ARMv7 VFPv2 hard-float, no kernel-version note.

**These binaries are not a hard constraint.** hostapd can be rebuilt for other driver backends
(`wext`, Realtek's `rtl871xdrv`, vendor patches), older kernels (e.g. with musl or an older
glibc toolchain such as NiLuJe's koxtoolchain), or other architectures. udhcpd can come from any
static BusyBox. So in this report a binary mismatch counts as **rebuild work**, not a blocker.
The real constraints are: **Wi-Fi hardware/driver AP support, root, and whether the vendor
network stack can be kept from fighting the AP.**



## 1. Kindle (jailbroken, KOReader)

Confidence: **[H]** high, **[M]** medium, **[L]** low. "Verified" means I checked the primary source myself while writing this report.

### 1.1 Key finding

**MediaTek Kindles (PW5 and later) run the same Wi-Fi stack as the Kobo Libra Colour** [H, verified]. A bellatrix Kindle (MT8110 = MT8512 die, kernel `4.9.77-lab126`, glibc 2.20) has these modules loaded:

```
wlan_drv_gen4m   1776292  0
wmt_chrdev_wifi    11440  1 wlan_drv_gen4m
wmt_drv           963016  4 wmt_cdev_bt,wlan_drv_gen4m,wmt_chrdev_wifi
```
([kindle_system_info.md](https://raw.githubusercontent.com/zampierilucas/kindle-ble-hid/master/kindle_system_info.md))

These are the modules the plugin's `wlan_drv_gen4m` backend relies on. `wmt_chrdev_wifi` is the module that provides `/dev/wmtWifi` in MediaTek's connectivity stack. So the existing "write `A` → `ap0` → hostapd nl80211" path should port almost directly.

Still unconfirmed on a Kindle: that `/dev/wmtWifi` accepts `A` and actually creates `ap0`.

The kernel config dump from the same device family shows `CONFIG_CFG80211=y`, `CONFIG_NL80211_TESTMODE=y` and `CONFIG_MTK_COMBO_WIFI=y` [M]. It also shows `CONFIG_MTK_WIFI_MCC_SUPPORT=y` (multi-channel concurrency), which hints that STA+AP concurrency might be possible; that is untested. `CONFIG_CFG80211_WEXT` is not set, so use `iw`, not `iwconfig`.

KOReader itself sets `isMTK = yes` [H, verified] on: PW5, PW5 SE, PW6, Basic 4 (2022), Basic 5 (2024), Scribe, Scribe 3, Colorsoft, Scribe Colorsoft.
([device.lua](https://github.com/koreader/koreader/blob/master/frontend/device/kindle/device.lua))

**No Kindle uses Marvell/NXP**, so there is no `uap0`/`moal` path on Kindle.

### 1.2 Per-model table

| Model | KOReader platform | SoC / CPU | Kernel | Wi-Fi chip / driver | AP path | Conf. |
|---|---|---|---|---|---|---|
| K4 NT, Touch, PW1 | yoshi / yoshime | i.MX50, Cortex-A8 (NEON) | 2.6.31-rt11 | Atheros AR6003 (inferred), vendor `ar6003` | vendor wext ioctls only | M/L |
| PW2, Basic 7th gen, Voyage, PW3 | wario | i.MX6 SoloLite, Cortex-A9 | 3.0.35 | Atheros AR6003G/AR6803G, vendor `ar6003` (lsmod on PW2); built **without** `AR6003_CFG80211`. The defconfig also has `CONFIG_ATH6KL=m` | wext only on stock; rebuilt `ath6kl` could give nl80211 | H |
| Oasis 1 | duet | i.MX6SL | 3.0.35 | Broadcom, driver unknown; `CFG80211=y` | probably nl80211 | M |
| Basic 8th gen | heisenberg | i.MX6 family | 3.10.53 | Broadcom BCM4343, driver unknown | probably nl80211 | M/L |
| Oasis 2, Oasis 3 | zelda | i.MX7D, Cortex-A7 | 4.1.15 | Broadcom BCM4343 | probably nl80211 | M |
| PW4, Basic 10th gen | rex | i.MX6SLL, Cortex-A9 | 4.1.15 | Broadcom BCM4343 | probably nl80211 | M |
| **PW5 / SE, Basic 4 (2022), Scribe** | bellatrix | MT8110 (= MT8512), Cortex-A53 in AArch32 | 4.9.77 | **MediaTek CONSYS: `wmt_drv`, `wmt_chrdev_wifi`, `wlan_drv_gen4m`** | **same as Kobo Libra Colour** | **H** |
| Basic 5 (2024), PW6, Scribe 2, Colorsoft | bellatrix3/4 | MT8110 / MT8113(S) | 4.9.77 (Basic 2024, Scribe 2024) | MediaTek, assumed same modules | as above | M |
| Scribe 3, Scribe Colorsoft (2025) | new platforms | quad-core, vendor not public; KOReader flags them `isMTK` | ? | ? | ? | L |
| K2 / DX / K3 | legacy | ARM11 (ARMv6) | 2.6.2x | Atheros AR6002 | none shown working | out of scope |

Kernel and chip sources for the table: [linux-3.0.35-lab126 mirror](https://github.com/katadelos/linux-3.0.35-lab126) (wario/duet defconfigs), [PW2 lsmod/config gist](https://gist.github.com/gdamjan/13fc8c75a2f8bb34541da0948739baed), [kindle-hid-passthrough compatibility notes](https://github.com/zampierilucas/kindle-hid-passthrough/blob/main/docs/compatibility.md), [kexec-kindle-mt8512](https://github.com/SolAstrius/kexec-kindle-mt8512), [techinfodepot](https://techinfodepot.shoutwiki.com/wiki/Amazon_Kindle_7_Gen_(WP63GW)).

### 1.3 Binaries, kernel and ABI

- **Every Kindle except K2/DX/K3** is ARMv7 with NEON, so the CPU can run the current hostapd.
- **Kernel ≥ 3.2** (needed by the current static glibc 2.36 hostapd):
  - OK: 3.10 (heisenberg), 4.1 (zelda/rex), 4.9 (MTK).
  - **Too old**: 3.0.35 (wario, duet) and 2.6.31 (yoshi). These need a hostapd rebuilt with musl or an older-kernel glibc toolchain (e.g. koxtoolchain).
- **Userland ABI**: firmware ≥ 5.16.3 is armhf (KOReader's `kindlehf` build) [H]. This doesn't matter for static binaries.
  ([kindlemodding.org](https://kindlemodding.org/jailbreaking/post-jailbreak/koreader.html))
- **Present in stock firmware**: `wpa_supplicant`/`wpa_cli` and `iptables` [H].
- **Unverified**: `hostapd`, `udhcpd`, `iw`, `ip`. Assume they're absent and bundle them. A static `iw` would also help debugging.

### 1.4 Root and jailbreak (state as of Oct 2026)

- **Jailbreak coverage** [M, fast-moving]: some public method exists for most firmware up to 5.19.x.
  - [WinterBreak](https://kindlemodding.org/jailbreaking/WinterBreak/) (< 5.18.1)
  - LanguageBreak (≤ 5.16.2.1.1)
  - AdBreak (5.18.1–5.18.5, ad-supported only)
  - Sanctuary (5.16.4–5.18.3)
  - [SpringBreak](https://github.com/KindleModding/SpringBreak)
  - [SpiderCat](https://blog.the-ebook-reader.com/2026/09/01/new-spidercat-kindle-jailbreak-is-the-easiest-method-yet/) (5.16.3–5.19.5, incl. PW6, Colorsoft, Scribe 2)
  - Shadow (5.19.4–5.19.6)
  - Status for 5.20.x is unknown.
- **KOReader runs as root** [H]: its SSH plugin calls `iptables` directly on Kindle, and users get a root shell through KOReader's dropbear.

### 1.5 Wi-Fi management: the main porting difference

- **KOReader never drives the Wi-Fi hardware itself on Kindle** [H, verified]. Amazon's `wifid`/`cmd` daemons do it over LIPC:
  - On: `com.lab126.cmd wirelessEnable 1` + `com.lab126.wifid enable 1`.
  - Fallback without LIPC bindings: `lipc-set-prop -i com.lab126.wifid enable <0|1>`.
  - The interface is hardcoded: `return "wlan0" -- so far, all Kindles appear to use wlan0`.
  - There are no `enable-wifi.sh`/`disable-wifi.sh` scripts and no `WIFI_MODULE` env var, so `BACKENDS` lookup by `WIFI_MODULE` won't work.
- **wifid is an upstart job** (`/etc/upstart/wifid.conf`), so `stop wifid` / `start wifid` should work [M].
  ([MobileRead](https://www.mobileread.com/forums/showthread.php?t=262385))
- **Will wifid fight the AP?** Undocumented. Mode `A` makes `wlan0` go away on the Libra Colour, and wifid/cmd would probably react to that. Safe approach: turn Wi-Fi off via KOReader, `stop wifid`, run the AP, then reverse everything.
- **MTK firmware daemons**: on MTK Kindles they appear to be started by an upstart `wmt` job at boot and stay running [M]. On Kobo, KOReader has to start `wmt_loader`/`wmt_launcher` itself (koreader#16222). So the reboot risk is probably lower on Kindle, but the plugin should still **check they are running and abort if not**, rather than start them.
- **Never `rmmod wlan_drv_gen4m`**: Amazon's connsys driver doesn't fully power down on unload [M].
- **Firewall: a real blocker unless handled** [H]. Stock Kindle iptables has `INPUT` policy `DROP` and accepts only `usb0` and ESTABLISHED/RELATED on `wlan0`. On `ap0`, the firewall would drop DHCP DISCOVER (UDP 67) and every service port (SSH, rsync, HTTP).
  ([MobileRead](https://www.mobileread.com/forums/showthread.php?p=2413909), [KOReader SSH plugin](https://github.com/koreader/koreader/blob/master/plugins/SSH.koplugin/main.lua))
  - The plugin must `iptables -I INPUT -i ap0 -j ACCEPT` (and OUTPUT) on start and delete those rules on stop.
- **Suspend**:
  - Kindle sleep is handled by Amazon's `powerd`; KOReader's `Kindle:readyToSuspend` just delegates to it [H, verified].
  - Wi-Fi generally dies on suspend [M], same as on Kobo.
  - `lipc-set-prop com.lab126.powerd preventScreenSaver 1` (what KOReader's KeepAlive plugin does) stops timeout sleep. A power-button press still suspends.
  - The plugin should set it while the AP is up, and tear the AP down cleanly on suspend.
- **No hidden AP/tethering feature** in Kindle firmware [M]. In Amazon's Wi-Fi Simple Setup the Kindle is the *client*.
- **Prior art**: no report found of hostapd or a soft AP running on any Kindle [M].
  - The closest is a 2011 K3 thread about `/etc/init.d/wifi --mode=ap`, never shown working.
  - USBNetwork (RNDIS/ECM on `usb0`) is the established alternative for wired transfers.

### 1.6 Feasibility per Kindle family

| Family | Verdict | Why |
|---|---|---|
| **MTK: PW5/SE, Basic 2022/2024, PW6, Scribe 1/2, Colorsoft** | **Likely** | Same gen4m/WMT stack as Libra Colour, kernel 4.9, current hostapd binary should run unchanged |
| Broadcom: PW4, Basic 10th, Oasis 2/3, Basic 8th | **Possible with work** | BCM4343 can do AP; driver (bcmdhd vs brcmfmac) and AP-capable firmware unverified; kernels OK for current binary |
| Broadcom: Oasis 1 | Possible with more work | as above, plus kernel 3.0.35 needs a rebuilt hostapd |
| Atheros: PW2, Basic 7th, Voyage, PW3 | **Possible with significant work** | Stock `ar6003` is wext-only. Either use vendor ioctls (no hostapd, WPA uncertain), or build `cfg80211`+`ath6kl_sdio` modules from Amazon's GPL 3.0.35 tree and use a musl hostapd (nl80211) |
| K4 / Touch / PW1 | Unlikely | kernel 2.6.31, vendor driver, very old cfg80211 |
| Scribe 3 / Scribe Colorsoft (2025) | Unknown | hardware not yet documented |
| K2 / DX / K3 | Out of scope | ARMv6, ancient kernels |

### 1.7 Porting sketch for MTK Kindles

1. **Guard**: replace `if not Device:isKobo()` with a per-platform backend selection.
2. **Detection**: `Device:isKindle() and Device:isMTK()`, plus checks that `/dev/wmtWifi` exists and `/sys/module/wlan_drv_gen4m` is present. Don't rely on `WIFI_MODULE`.
3. **Start sequence**:
   1. Remember whether `/sys/class/net/wlan0` existed.
   2. `NetworkMgr:turnOffWifi()`, which sends LIPC `wirelessEnable 0`.
   3. `stop wifid`.
   4. Check that the WMT daemons/upstart job are running; abort if not.
   5. `echo A > /dev/wmtWifi` and wait for `ap0`. The existing `writeWmt` and `waitForInterface` can be reused.
   6. Start hostapd. Then run `ip addr add 192.168.42.1/24 dev ap0` and `iptables -I INPUT -i ap0 -j ACCEPT; iptables -I OUTPUT -o ap0 -j ACCEPT`, then start udhcpd.
   7. `lipc-set-prop com.lab126.powerd preventScreenSaver 1`.
4. **Stop**: reverse in order. Delete the iptables rules, `echo 0 > /dev/wmtWifi`, `start wifid`, `preventScreenSaver 0`, then offer to turn Wi-Fi back on (the same ConfirmBox as on Kobo).
5. **Binaries**: the existing static armhf hostapd (nl80211) and udhcpd should run as-is on kernel 4.9.

### 1.8 On-device checks (MTK Kindle, via KOReader's SSH or terminal)

```sh
uname -a; cat /etc/version.txt; ls -l /dev/wmtWifi /dev/stpwmt
lsmod | grep -Ei 'wmt|gen4m'; status wmt; status wifid; ps | grep -Ei 'wmt|wifid|wpa'
for b in iw ip hostapd udhcpd iptables; do which $b; done; busybox --list | grep -E '^(ip|udhcpd)$'
iptables-save
# AP smoke test
lipc-set-prop com.lab126.cmd wirelessEnable 0; sleep 3; stop wifid
echo A > /dev/wmtWifi; sleep 3; ls /sys/class/net; dmesg | tail -40
/mnt/us/koreader/plugins/hotspot.koplugin/hostapd -dd /tmp/koreader_hostapd.conf
# restore
echo 0 > /dev/wmtWifi; start wifid; lipc-set-prop com.lab126.cmd wirelessEnable 1
```

For Broadcom Kindles, first identify the driver and firmware:

```sh
readlink -f /sys/class/net/wlan0/device/driver
ls /sys/module | grep -Ei 'dhd|brcm|bcm'
cat /sys/module/*dhd*/parameters/{firmware_path,op_mode} 2>/dev/null
find / -xdev \( -name '*apsta*' -o -name 'brcmfmac*' -o -name '*4343*' \) 2>/dev/null
```

## 2. PocketBook

Confidence: **[H]** high, **[M]** medium, **[L]** low. "Verified" means I checked the primary source myself.
(The research subagent was cut off by an API safeguard partway through its report. Its findings below are marked [M] unless I re-checked them.)

### 2.1 Key findings

- **Current PocketBooks (B288 SoC) have AP-capable hardware and a modern Wi-Fi stack** [H, verified]. PocketBook's published B288 kernel (`B288.config`) is `Linux/arm 3.10.65` with:
  ```
  CONFIG_CFG80211=y   CONFIG_NL80211_TESTMODE=y   CONFIG_MAC80211=y
  CONFIG_XRADIO=m     CONFIG_XRADIO_SDIO=y        # CONFIG_XRADIO_5GHZ_SUPPORT is not set
  CONFIG_XRADIO_SUSPEND_POWER_OFF=y               CONFIG_NETFILTER=y  CONFIG_IP_NF_IPTABLES=y
  ```
  ([pocketbook/kernel-b288 B288.config](https://raw.githubusercontent.com/pocketbook/kernel-b288/master/B288.config))
  - XRadio (XR819) is a **mac80211 soft-MAC** driver. AP mode then comes from mac80211 and works with the plugin's existing `driver=nl80211` hostapd.
  - Kernel 3.10.65 is ≥ 3.2, so the current static armhf hostapd should run as-is. B288 is a dual Cortex-A7 with NEON.
  - The subagent read the driver source and reported it advertises AP / P2P-GO / ad-hoc, with up to 2 STA + 1 AP on one channel (STA+AP concurrency) [M]. This is **better than the Kobo MediaTek case**, where client and AP are exclusive.
- **Root is the real blocker on PocketBook, not Wi-Fi** [H for the KOReader behaviour, verified].
  - KOReader runs as a normal app with no root (as user `reader` per the subagent [M]).
  - KOReader's code already uses `/mnt/secure/su` **when it exists**. `device.lua` does `su = util.pathExists("/mnt/secure/su") and ...` for `hwclock`, and `koreader.app` uses it for raw input.
    ([device.lua](https://raw.githubusercontent.com/koreader/koreader/master/frontend/device/pocketbook/device.lua), [koreader.app](https://raw.githubusercontent.com/koreader/koreader/master/platform/pocketbook/koreader.app))
  - So a plugin can follow the same pattern: run `hostapd`, `ip` and `udhcpd` through `/mnt/secure/su` if present, and otherwise show "this PocketBook needs to be rooted".
  - The community "pbjb" jailbreak installs that setuid `su` on B288-era and older devices [M]. Newer B300 devices are reported to be much harder to root [M].
- **Newer B300 devices** (PocketBook's 2025–26 generation, kernel 4.9.x [M]): PocketBook published `kernel-b300` (updated Mar 2026). Its `drivers/net/wireless` contains `xradio`, `bcmdhd`, `rtl8723bs_vq0`, `rtl8723cs`, and the generic vendor dirs [H, verified].
  ([kernel-b300 drivers/net/wireless](https://github.com/pocketbook/kernel-b300/tree/master/drivers/net/wireless))
  - Which of these drivers B300 devices actually use is **not verified**: no defconfig is visible at the repo root. The subagent's claim of an AIC8800 chip on B300 could not be confirmed.
- **No prior art** [M]: no reports of hostapd, a soft AP or ad-hoc on any PocketBook (MobileRead, GitHub, Russian-language forums).
- **No built-in AP or Wi-Fi Direct feature** in PocketBook firmware [M].

### 2.2 Per-model table

| Models (KOReader class) | SoC / CPU | Kernel | Wi-Fi chip / driver | AP-capable? | STA+AP? | Conf. |
|---|---|---|---|---|---|---|
| 515, 614, 624/625, 626 (Touch Lux 3), 840 (InkPad 1) | Allwinner A13, Cortex-A8 | 3.0.8 | PB626: RTL8188EUS on internal USB, vendor `8188eu`; built with `CONFIG_IOCTL_CFG80211` + `CONFIG_AP_MODE` | Yes if kernel cfg80211 is on (unknown), otherwise needs an `rtl871xdrv` hostapd | No (`CONCURRENT_MODE` off) | M (source: [Platform_A13](https://github.com/pocketbook/Platform_A13)) |
| 631 (Touch HD / HD 2) | i.MX6 SoloLite | 3.0.35 | unknown out-of-tree; `CFG80211` **not set**, WEXT only | only via a vendor wext backend | No | M (source: [Platform_MX6](https://github.com/pocketbook/Platform_MX6)) |
| 650 (Ultra) | i.MX6SL | 3.0.35 | out-of-tree full-MAC (`CFG80211=y`, no mac80211) | unknown | unknown | L |
| **627 (Touch Lux 4), 628 (Touch Lux 5), 740 (InkPad 3), 616/617 (Basic Lux 2/3), 632 (Touch HD 3), 633 (Color), 740-2 (InkPad 3 Pro), 1040 (InkPad X), and other B288 models** | **Allwinner B288**, 2× Cortex-A7 | **3.10.65** | **XRadio `xradio_wlan` (XR819 likely), mac80211**, 2.4 GHz only | **Yes** (nl80211) | **Yes** (single channel) | **H** for kernel/driver config, M for per-model mapping |
| Newer models (Verse / Verse Pro / Era / Era Color / InkPad 4 / InkPad Color 2-3 and successors; exact SoC split between B288 and B300 per model is unverified) | B288 or B300 | 3.10.65 or 4.9.x | B288 as above; B300 driver unverified (tree has xradio, bcmdhd, rtl8723bs/cs) | likely | unknown | L |

KOReader's model classes (from `device.lua`) cover 515…1040 and ColorLux. It has an `isB288SoC` flag but no B300 references yet [H, verified].

### 2.3 Wi-Fi management and coexistence

- **KOReader doesn't drive the Wi-Fi hardware on PocketBook** [H, verified]. It calls the firmware's **inkview** API:
  - On: `inkview.WiFiPower(1)` then `inkview.NetConnect(nil)`.
  - Off: `inkview.NetDisconnect()`.
  - State: `inkview.QueryNetwork()`.
  - Keep-alive: `inkview.NetMgrPing()`.
  - There are no shell scripts, no interface name in KOReader, and no `WIFI_MODULE`.
- **The firmware's network manager** (`netagent` and friends, [M]) owns the Wi-Fi power and wpa_supplicant. A plugin would need to:
  1. Power Wi-Fi on through inkview, or load `xradio_wlan` itself as root.
  2. Keep the firmware from reconnecting or powering down the radio. Whether `NetDisconnect()` leaves the radio powered for an AP is **unknown**.
  3. Create the AP. With STA+AP concurrency, a separate interface (`iw dev wlan0 interface add ap0 type __ap`) might coexist with the firmware's client, which would avoid fighting it. This needs on-device testing.
- **Suspend**: `XRADIO_SUSPEND_POWER_OFF=y` means the radio powers off on suspend [H for the config]. On suspend KOReader only sends `REQ_KEYLOCK`, and `setAutoStandby` toggles `iv_sleepmode` [H, verified]. The plugin should disable auto-standby while the AP is up, like KeepAlive does.
- **Firewall**: netfilter/iptables are built in. Whether the stock rules block inbound traffic like on Kindle is unknown; check `iptables -L`.

### 2.4 Feasibility per PocketBook family

| Family | Verdict | Why |
|---|---|---|
| **B288 devices, rooted (setuid `/mnt/secure/su` present)** | **Likely / possible with moderate work** | mac80211 XRadio driver with AP and STA+AP, kernel 3.10, current binaries should run. Unknowns: how to coexist with netagent/inkview |
| B288 devices, not rooted | **Impossible** without root | KOReader runs unprivileged |
| B300 devices | **Unknown / possible with work** | Wi-Fi driver unverified; root much harder |
| A13 devices (Touch Lux 3 and older) | Possible with significant work | Realtek vendor driver + kernel 3.0.8 → rebuilt hostapd (`rtl871xdrv` or nl80211 with a cfg80211 kernel), plus root |
| i.MX6 devices (631, 650) | Unlikely | WEXT-only / unknown vendor driver, kernel 3.0.35 |

### 2.5 Porting sketch for B288

1. **Detection**: `Device:isPocketBook()` and `Device.isB288SoC`, `/mnt/secure/su` exists, and `/sys/module/xradio_wlan` is present (or `readlink /sys/class/net/wlan0/device/driver`).
2. **Privilege wrapper**: prefix every privileged command with `/mnt/secure/su `, the same pattern KOReader uses for `hwclock`.
3. **Bring-up**: try **concurrent mode** first, without touching the firmware's client connection:
   `iw dev wlan0 interface add ap0 type __ap`, then hostapd on `ap0`.
   If that fails, use exclusive mode: `NetDisconnect()`, keep the radio powered, and run hostapd on `wlan0`.
4. Then `ip addr add 192.168.42.1/24`, udhcpd, `iptables -I INPUT -i ap0 -j ACCEPT` if needed, and disable auto-standby.

### 2.6 On-device checks (PocketBook, via KOReader terminal / SSH, as root)

```sh
uname -a; cat /proc/cpuinfo | grep -E 'Hardware|Features'; ls -l /mnt/secure/su; id
lsmod; ls /sys/module | grep -Ei 'xradio|8188|8723|8189|dhd|aic'; readlink -f /sys/class/net/wlan0/device/driver
ps | grep -Ei 'netagent|wpa_|dhcp'; ls /ebrmain/bin | head -50
for b in iw ip hostapd udhcpd iptables; do which $b; done; busybox --list | grep -E '^(ip|udhcpd)$'
iptables -L -n
# concurrency smoke test (needs a static iw)
iw list | sed -n '/Supported interface modes/,/Supported commands/p'; iw list | grep -A6 'interface combinations'
iw dev wlan0 interface add ap0 type __ap && ip link set ap0 up && ls /sys/class/net
```

## 3. Other KOReader platforms

Confidence: **[H]** high, **[M]** medium, **[L]** low.

### 3.1 Summary

| Platform | Wi-Fi chip / driver | AP capable? | Root? | Feasibility |
|---|---|---|---|---|
| **reMarkable 1** | Broadcom/Cypress, `brcmfmac` (exact chip unconfirmed) [M] | Yes, brcmfmac AP over nl80211 [H] | Yes, SSH as root [H] | **Likely** |
| **reMarkable 2** | Broadcom/Cypress SDIO, `brcmfmac` (DT `brcm,bcm4329-fmac`) [H] | Yes [H] (firmware-dependent) | Yes [H] | **Likely** |
| rM Paper Pro (ferrari) | Not confirmed, probably NXP (moal/mwifiex) [L] | Probably, via `uap0` [L] | Developer Mode (wipes device) [H] | Possible with work |
| rM Paper Pro Move (chiappa) | NXP IW611, NXP out-of-tree mwifiex [M] | Probably (IW61x has uAP) [M] | Developer Mode [H] | Possible with work |
| Android readers (Boox, Bigme, Meebook, Hisense, inkBOOK, Nook, older Android Tolinos) | n/a | System tethering already exists | n/a | **Out of scope** (see 3.3) |
| Tolino Shine 5 (Kobo firmware, "Kobo mode") | Kobo Clara BW hardware (T302) [M] | Same as Clara BW | Same as Kobo | Same as Kobo MediaTek port |
| bq Cervantes | Realtek `8189fs` (wext), Broadcom `dhd` (nl80211) on PCB 22/23 [H] | 8189fs needs rtl871xdrv hostapd or cfg80211 build [M]; dhd usually needs `_apsta` firmware [M] | Probably [M] | Possible with work |
| Bookeen Cybook | Realtek `8188eu` vendor driver, kernel 3.0.8, wext [H] | Yes, with rtl871xdrv-patched hostapd [M] | Probably [L] | Possible with work |
| Sony PRS-T1/T2/T3 | Atheros AR6003 + vendor `wmiconfig` [H for T2] | ath6kl AP is b/g-only and unreliable [M] | Custom port | **Unlikely** (KOReader frontend may have dropped it) |

### 3.2 reMarkable (best non-Kobo Linux target)

- **rM2 Wi-Fi hardware** [H]: the mainline DTS declares `brcm,bcm4329-fmac` on usdhc2. That compatible string is generic to brcmfmac and does not identify the exact chip.
  ([imx7d-remarkable2.dts](https://raw.githubusercontent.com/torvalds/linux/master/arch/arm/boot/dts/nxp/imx/imx7d-remarkable2.dts))
- **Firmware** [H]: reMarkable publishes Cypress firmware for 43430/43455/4339 and others. Its changelog mentions "Concurrent APSTA" and a "SoftAP association fix". It also lists a known issue: "softap low throughput with iMX6UL".
  ([reMarkable/brcmfmac-firmware](https://github.com/reMarkable/brcmfmac-firmware))
- **KOReader already takes over Wi-Fi** [H]: `platform/remarkable/enable-wifi.sh` runs these steps.
  1. `modprobe brcmfmac`
  2. stop xochitl's `wpa_supplicant` systemd unit
  3. `ifconfig wlan0 up`
  4. start dhcpcd and its own wpa_supplicant

  This is the same "take the interface away from the vendor stack" pattern the hotspot needs.
  ([enable-wifi.sh](https://raw.githubusercontent.com/koreader/koreader/master/platform/remarkable/enable-wifi.sh), [PR #11287](https://github.com/koreader/koreader/pull/11287))
- **Root** [H]: dropbear SSH logs in as root. Paper Pro and later models need Developer Mode first. SSH over Wi-Fi needs `rm-ssh-over-wlan on` on OS > 3.20.
  ([remarkable.guide](https://remarkable.guide/guide/access/ssh.html))
- **Paper Pro family** [H/M]:
  - Kernel source has `ferrari_defconfig` (Paper Pro), `chiappa_defconfig` (Move) and `tatsu_defconfig` (Paper Pure, i.MX9).
    ([linux-imx-rm](https://github.com/reMarkable/linux-imx-rm))
  - The Move uses an i.MX93 with an NXP IW611 on NXP's mwifiex driver.
    ([chiappa notes](https://github.com/gitman-101111/chiappa))
  - KOReader has supported Paper Pro officially since v2025.08, through XOVI and the QTFB shim. That PR did not change Wi-Fi handling.
    ([PR #13620](https://github.com/koreader/koreader/pull/13620))
- **Prior art**: none found for hostapd on reMarkable.
- **Porting sketch** (inference): this is close to the Kobo `moal` backend minus `uap0`.
  - **rM1/rM2**: stop `wpa_supplicant`, run hostapd (`driver=nl80211`, `interface=wlan0`), add the IP, then start udhcpd. The current static armhf binaries probably run as-is, since i.MX6SL and i.MX7D have NEON.
    - Watch for xochitl restarting wpa_supplicant on resume.
  - **Paper Pro family**: likely `interface=uap0` and aarch64 binaries.

### 3.3 Android e-readers: out of scope

Android readers (Boox, Bigme, Meebook, Hisense, inkBOOK, Nook, older Tolinos on Android) already have a system hotspot/tethering feature. The project motto is "avoid reinventing the wheel", so they are **out of scope**. This plugin would add nothing over the system feature, and without root it couldn't run hostapd anyway.

### 3.4 Other Linux ports

- **Cervantes** [H]: KOReader's `enable-wifi.sh` chooses the driver by PCB ID (from `ntxinfo`).
  - PCB 22/23: `dhd` with `-D nl80211`.
  - Everything else: `8189fs` with `-D wext`.
  - Interface: `eth0`.
  - ([enable-wifi.sh](https://raw.githubusercontent.com/koreader/koreader/master/platform/cervantes/enable-wifi.sh))
- **Bookeen** [H]:
  - Loads `8188eu.ko` for kernel 3.0.8 with `-D wext` on `wlan0`.
  - The Realtek 8188eu + [hostapd-rtl871xdrv](https://github.com/pritambaral/hostapd-rtl871xdrv) combination is a well-known AP setup.
  - ([wlan.sh](https://raw.githubusercontent.com/koreader/koreader/master/platform/bookeen/wlan.sh))
  - The current static glibc hostapd (needs kernel ≥ 3.2) would **not** run on kernel 3.0.8, so this target needs a rebuilt hostapd.
- **Sony PRS-T** [L–M]: `platform/sony-prstux` still exists, but there is no frontend device dir in current master. The chip is AR6003 with `wmiconfig`, whose AP support is weak.

### 3.5 Wi-Fi chip families → hostapd backend

Based on the kernel driver list ([wireless.docs.kernel.org](https://wireless.docs.kernel.org/en/latest/en/users/drivers.html)) and the sources above:

| Chip family | Driver | AP mode | hostapd backend |
|---|---|---|---|
| Broadcom/Cypress BCM43xx | `brcmfmac` (mainline) | Yes, if firmware includes AP [H] | nl80211 |
| Broadcom/Cypress BCM43xx | `bcmdhd`/`dhd` (vendor) | Usually needs `_apsta` firmware [M] | nl80211 |
| Marvell/NXP 88W87xx/8987/8997, IW416/IW61x | `mwifiex` (mainline) | Yes [H] | nl80211 |
| Marvell/NXP 88W87xx/8987/8997, IW416/IW61x | `moal`/`mlan` (NXP vendor) | Separate `uap0` (as on Clara 2E) | nl80211 |
| MediaTek SoC-integrated | gen4m vendor | Via `/dev/wmtWifi` (as on Libra Colour) | nl80211 |
| MediaTek discrete | `mt76` | Yes [H] | nl80211 |
| Realtek RTL8189FS/ES, 8723BS, 8188EU | vendor / staging | Yes [M] | `rtl871xdrv` (wext builds) or nl80211 (cfg80211 builds) |
| TI WL18xx | `wlcore` | Yes [H] | nl80211 |
| Atheros AR6003 | `ath6kl` / vendor `ar6000` | b/g only, unreliable [M] | nl80211 |
| XRadio XR819 | out-of-tree | Unclear [L] | ? |

## 4. Recommendations for future work

### 4.1 Suggested order

1. **Kindle MTK (PW5 class).** It has the highest payoff and the lowest risk, because most of the code already exists. The first step is the smoke test in §1.8 on a jailbroken PW5/Basic 2022+.
2. **PocketBook B288 (rooted).** Run the smoke test in §2.6. Try STA+AP concurrency first: if it works, the plugin won't have to fight `netagent` at all.
3. **reMarkable 1/2.** Simple and well understood (same pattern as KOReader's own `enable-wifi.sh`).
4. **Broadcom Kindles.** Identify the driver and firmware first (§1.8, Broadcom block).
5. Everything else only on user demand, since each needs custom hostapd builds.

### 4.2 Plugin refactor that would make ports cheap

Today `main.lua` mixes Kobo assumptions into the generic flow. To port it, split it into a generic core and per-platform backends:

| Concern | Generic core | Per-platform backend provides |
|---|---|---|
| Device detection | `Device:isKobo()/isKindle()/isPocketBook()/isRemarkable()` → pick a platform module | driver detection (e.g. `WIFI_MODULE` on Kobo; `/sys/module/*`, `readlink /sys/class/net/wlan0/device/driver` elsewhere) |
| Privileges | `run(cmd)` helper | prefix (`""` on Kobo/Kindle/reMarkable, `/mnt/secure/su ` on PocketBook) |
| Radio ownership | — | `takeOver()` / `giveBack()`: Kobo scripts, `stop/start wifid` + LIPC, inkview `NetDisconnect`, `systemctl stop wpa_supplicant` |
| AP interface | `waitForInterface()` | `uap0` / `ap0` via `/dev/wmtWifi` / `iw … type __ap` / plain `wlan0` |
| hostapd | config writer, `driver=` from backend | backend name (`nl80211`, `rtl871xdrv`) and binary path (per-arch/per-kernel builds) |
| Firewall | `openFirewall(iface)` / `closeFirewall(iface)` with `iptables -I`/`-D` | whether it's needed (Kindle: yes) |
| Sleep | tear down on `onSuspend`, inhibit standby while running | `preventScreenSaver` (Kindle), `iv_sleepmode` (PocketBook), KOReader's standard on Kobo |

**Detail to fix during the refactor:** the paths `/tmp/koreader_*` are fine on all platforms. The plugin currently writes the hostapd config with the passphrase in `/tmp`. That's acceptable, but on multi-user PocketBook (`reader` vs root) check the file permissions.

### 4.3 hostapd build matrix (only if "with work" targets are pursued)

| Build | Targets |
|---|---|
| current: static glibc 2.36, armhf, nl80211, kernel ≥ 3.2 | Kobo, Kindle MTK/Broadcom (3.10+), PocketBook B288, reMarkable 1/2 |
| static **musl** (or glibc `--enable-kernel=2.6.31`), nl80211 | Kindle wario/duet (3.0.35) with rebuilt `ath6kl`/Broadcom, PocketBook A13 if cfg80211 is on |
| static musl, **`rtl871xdrv`** backend | Bookeen (8188eu), Cervantes (8189fs), PocketBook A13 (8188eu without cfg80211) |
| aarch64 static, nl80211 | reMarkable Paper Pro family |

Also bundle a static **`iw`** (libnl): on every new platform it's the fastest way to answer "does this driver do AP / AP+STA?" (`iw list`).

## 5. Open questions (need a device)

- **Kindle MTK**:
  - Does `echo A > /dev/wmtWifi` create `ap0` as on Kobo?
  - Does stopping `wifid` cleanly hand over the radio?
  - Does Bluetooth (also on WMT) survive the mode switch?
  - Is STA+AP possible (`CONFIG_MTK_WIFI_MCC_SUPPORT=y`)?
- **Kindle Broadcom**: bcmdhd or brcmfmac? Is AP firmware present?
- **PocketBook B288**:
  - Does `iw dev wlan0 interface add ap0 type __ap` work while the firmware's client is connected?
  - Does netagent power the radio down on `NetDisconnect` or after idle?
  - What are the stock iptables rules?
- **PocketBook B300**: which Wi-Fi chip and driver (check `lsmod`)?
- **reMarkable**: does xochitl restart `wpa_supplicant` on resume? Which chip is in the Paper Pro?

---

### Main sources

- KOReader: [kindle/device.lua](https://github.com/koreader/koreader/blob/master/frontend/device/kindle/device.lua), [pocketbook/device.lua](https://raw.githubusercontent.com/koreader/koreader/master/frontend/device/pocketbook/device.lua), [pocketbook/koreader.app](https://raw.githubusercontent.com/koreader/koreader/master/platform/pocketbook/koreader.app), [remarkable/enable-wifi.sh](https://raw.githubusercontent.com/koreader/koreader/master/platform/remarkable/enable-wifi.sh), [cervantes/enable-wifi.sh](https://raw.githubusercontent.com/koreader/koreader/master/platform/cervantes/enable-wifi.sh), [bookeen/wlan.sh](https://raw.githubusercontent.com/koreader/koreader/master/platform/bookeen/wlan.sh), [SSH.koplugin](https://github.com/koreader/koreader/blob/master/plugins/SSH.koplugin/main.lua), [issue #16222](https://github.com/koreader/koreader/issues/16222)
- Kindle MTK system dump: [kindle_system_info.md](https://raw.githubusercontent.com/zampierilucas/kindle-ble-hid/master/kindle_system_info.md); Kindle 3.0.35 kernel mirror: [katadelos/linux-3.0.35-lab126](https://github.com/katadelos/linux-3.0.35-lab126); jailbreaks: [kindlemodding.org](https://kindlemodding.org/), [KindleModding on GitHub](https://github.com/KindleModding)
- PocketBook kernels: [kernel-b288](https://github.com/pocketbook/kernel-b288), [kernel-b300](https://github.com/pocketbook/kernel-b300), [Platform_A13](https://github.com/pocketbook/Platform_A13), [Platform_MX6](https://github.com/pocketbook/Platform_MX6)
- reMarkable: [brcmfmac-firmware](https://github.com/reMarkable/brcmfmac-firmware), [linux-imx-rm](https://github.com/reMarkable/linux-imx-rm), [remarkable.guide](https://remarkable.guide/guide/access/ssh.html)
- Wi-Fi drivers: [kernel wireless driver list](https://wireless.docs.kernel.org/en/latest/en/users/drivers.html), [hostapd-rtl871xdrv](https://github.com/pritambaral/hostapd-rtl871xdrv)
