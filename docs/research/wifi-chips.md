---
topic: wifi-chips
last_reviewed: 2026-10-31
scope_note: per D3 only 1–2 clients matter; client limits are informational
---

# Wi-Fi chip families, AP support, and prior art outside e-readers

## CHIP-C01: chip family → driver → AP → hostapd backend
- claim:

| Chip family | Driver | AP mode | hostapd backend | Seen in |
|---|---|---|---|---|
| Marvell/NXP 88W8987 etc. | `moal`/`mlan` (NXP vendor) | separate `uap0` | nl80211 | Kobo Clara 2E (plugin works) |
| Marvell/NXP 88W87xx/8997, IW416/IW61x | `mwifiex` (mainline) | yes | nl80211 | rM Paper Pro Move (NXP out-of-tree variant) |
| Marvell/NXP IW61x | `nxpwifi` (upstream, in progress) | in progress | nl80211 | — |
| MediaTek SoC-integrated | gen4m vendor (`wlan_drv_gen4m` + WMT) | via `/dev/wmtWifi` `A` → `ap0` | nl80211 | Kobo Libra Colour (plugin works), MTK Kindles |
| MediaTek discrete | `mt76` | yes | nl80211 | — |
| Broadcom/Cypress BCM43xx | `brcmfmac` (mainline) | yes, if firmware includes AP | nl80211 | reMarkable 1/2, Raspberry Pi |
| Broadcom/Cypress BCM43xx | `bcmdhd`/`dhd` (vendor) | yes: `op_mode=2` or AP firmware | nl80211 (cfg80211 build) | Kindle Basic 8th gen (+ probably PW4/Oasis 2/3), Cervantes PCB 22/23 |
| XRadio XR819 | `xradio_wlan` (mac80211) | yes (PB-C02) | nl80211 | PocketBook B288 |
| Realtek RTL8188EU, RTL8189FS/ES, RTL8723BS | vendor / staging | yes | `rtl871xdrv` (wext builds) or nl80211 (cfg80211 builds) | Bookeen, Cervantes, PocketBook A13 |
| Atheros AR6003 | vendor `ar6003`/`ar6000` | wmiconfig, no AP security | (vendor-patched hostapd, source not found) | Kindle PW2/PW3/Voyage/Basic 7th stock |
| Atheros AR6003 | `ath6kl` (upstream/QCA) | yes, b/g only | nl80211 | Kindle (needs module swap), Sony PRS-T |
| TI WL18xx | `wlcore` | yes | nl80211 | — |

- confidence: medium overall
- status: agent (mixed)
- sources: S-CHIP-01, S-CHIP-04, plus per-row claims
- notes: Realtek caveat: `cfg80211_rtw_add_virtual_intf` in 8189fs/es/8723bs only creates monitor interfaces, which matters only for a *separate* AP interface (S-CHIP-02)

## Atheros AR6003 / ath6kl

### ATH-C01: upstream ath6kl supports AP mode
- claim: ath6kl moved out of staging in Linux 3.2. AP mode came from the 2011 "ath6kl: AP mode and P2P" series (commits 6a7c9bad, 6e4604c8). The kernel docs list "AP mode (requires hostapd 1.0 or newer)", WPA/WPA2, and no monitor mode. The cover letter said AP "requires a new firmware build".
- confidence: high (docs); medium (firmware remark)
- status: agent (docs, commits); snippet (cover letter)
- sources: S-ATH-02, S-ATH-03, S-ATH-04, S-ATH-05, S-ATH-06

### ATH-C02: Kindle AR6003 is the hw2.1.1 revision ath6kl supports
- claim: the Kindle Touch vendor firmware path is `/opt/ar6k/target/AR6003/hw2.1.1/`. A PW3 ran upstream ath6kl with linux-firmware hw2.1.1 (station mode, partial results).
- confidence: high
- status: agent + verified (PW3, see KIN-C24)
- sources: S-KIN-15, S-KIN-14

### ATH-C03: AP is b/g only; disable 11n
- claim: the staging commit says "AP mode can be operated only in b/g mode". With 802.11n on, hostapd fails `nl80211: Failed to set channel (freq=2437): -22`. Use `hw_mode=g`, `ieee80211n=0`.
- confidence: medium
- status: agent
- sources: S-ATH-07, S-ATH-10, S-ATH-11

### ATH-C04: client limit
- claim: `#define AP_MAX_NUM_STA 10` in `ath6kl/wmi.h`. Changing it requires recompiling both driver and firmware. Irrelevant under D3 (1–2 clients).
- confidence: high
- status: verified
- sources: S-ATH-01

### ATH-C05: firmware is redistributable
- claim: linux-firmware `ath6k/AR6003/hw2.1.1/` ships `fw-2.bin`, `fw-3.bin` (API 3, ≥ 3.2.0.12), `athwlan.bin`, `otp.bin`, `data.patch.bin`, `endpointping.bin`, `bdata.SD31.bin`, `bdata.SD32.bin` and `bdata.WB31.bin`, under LICENCE.atheros_firmware (redistributable). Use the device's own board data (`bdata.SD32.bin` matches stock per KIN-C24).
- confidence: high (files/licence); medium (fw-3 for AP)
- status: agent
- sources: S-ATH-08, S-ATH-09

### ATH-C06: other devices that ran an AP with ath6kl
- claim:
  - Digi ConnectCore 6 (i.MX6, AR6233, ath6kl): softAP ≤ 5 clients plus AP-STA concurrency [high].
  - Android 4.2.2 on AR6003: hostapd nl80211 works when started manually; re-toggling fails because wlan0 is busy [medium].
  - NXP i.MX6 Sabre with AR6103: the proprietary driver worked as a client, not as an AP, so the user moved to ath6kl [snippet].
  - Seagate GoFlex Satellite is **not** Atheros (negative).
- confidence: per item
- status: agent / snippet
- sources: S-ATH-14, S-ATH-12, S-ATH-15, S-ATH-16, S-ATH-18

### ATH-C07: later tethering fixes to cherry-pick
- claim: 2016 Aldebaran fixes in ath6kl (merged ~4.8/4.9):
  - `270df8f80d67`: WPA 4-way handshake stalls at msg 1/4 (RX `pad_before_data_start`)
  - `76b817f6c9a9`: carrier not cleared on AP stop
  - `f3651bae5644`: regulatory disconnect

  These were reported on AR9374; whether they affect AR6003 is unverified.
- confidence: medium
- status: agent
- sources: S-ATH-13

### ATH-C08: Amazon's own build already has ath6kl with AP SME
- claim: see KIN-C18, KIN-C20 and KIN-C21. The wario defconfig builds `cfg80211`/`ath6kl` as modules. Amazon's ath6kl (QCA 3.3-OSR compat) sets `WIPHY_FLAG_HAVE_AP_SME` (upstream added this in commit 562a74803f48) and has a `board_data_file` param.
- confidence: high
- status: verified
- sources: S-KIN-04, S-KIN-06, S-KIN-08, S-ATH-20

### ATH-C09: vendor AR6kSDK AP path is not recommended
- claim: AR6kSDK 3.0 `wmiconfig` has softAP commands (`--ssid`, `--numsta`, `--commit` → WMI_AP_COMMIT_CONFIG, `--wmode gonly`, ACLs, …) but **no AP security option**. Android's CAF `wlan_tool` loads `ar6000.ko fwmode=1` and runs a vendor hostapd with an ar6000 backend; that hostapd source was not found, and upstream hostapd has no such backend.
- confidence: high (wmiconfig); medium (rest)
- status: agent
- sources: S-ATH-17

### ATH-C10: backports for kernel 3.0
- claim: backports **v4.4.2** is the last release supporting 3.0 kernels (the README moved to "3.10 and above" in Oct 2017), and it includes ath6kl with AP. For kernels 3.10/4.1, backports up to ~5.10 apply.
- confidence: high (4.4.2 / 3.0); medium (5.10 bound)
- status: agent
- sources: S-ATH-19

## Broadcom BCM4343W / bcmdhd / brcmfmac

### BRCM-C01: brcmfmac BCM43430 support starts at Linux 4.1
- claim: "brcmfmac: add support for BCM43430 SDIO chipset" (Mar 2015) landed in Linux 4.1, so kernels 3.0/3.10 have no in-kernel brcmfmac support for this chip.
- confidence: medium-high
- status: agent
- sources: S-BRCM-01

### BRCM-C02: brcmfmac firmware is redistributable
- claim: linux-firmware ships `brcm/brcmfmac43430-sdio.bin` (→ `cypress/cyfmac43430-sdio.bin`) plus `.clm_blob` under LICENCE.cypress (redistributable), and NVRAM files incl. `brcmfmac43430-sdio.MUR1DX.txt`.
- confidence: high
- status: agent
- sources: S-ATH-08

### BRCM-C03: Raspberry Pi AP and AP+STA recipe
- claim: Raspberry Pi 3 / Zero W (BCM43430/43438) run APs with plain hostapd nl80211 on brcmfmac. AP+STA works via `iw dev wlan0 interface add uap0 type __ap` on the same channel only, with `uap0` up before hostapd starts.
- confidence: medium
- status: agent
- sources: S-BRCM-02

### BRCM-C04: client limits (informational, D3)
- claim: about 7–10 clients in practice. In one report, 43455 firmware 7.45.202 crashed at the 8th client.
- confidence: medium
- status: agent
- sources: S-BRCM-03, S-BRCM-04

### BRCM-C05: NXP 4.1.15 BSP uses bcmdhd
- claim: NXP `imx_4.1.15_2.0.0_ga` builds `CONFIG_BCMDHD=y`, `CONFIG_BCMDHD_SDIO=y`. bcmdhd Kconfig defaults are fw `/system/vendor/firmware/fw_bcmdhd.bin` and nvram `/system/etc/wifi/bcmdhd.cal`. `BCMDHD_WEXT` is only available when CFG80211 is off. This is the basis for the inference that PW4/Basic 10th/Oasis 2/3 (4.1.15) use bcmdhd.
- confidence: high (BSP); medium (Kindle inference)
- status: agent
- sources: S-BRCM-07, S-BRCM-08

### BRCM-C06: proven AP recipe with bcmdhd on the same module (Murata 1DX / BCM4343W)
- claim: SomLabs VisionSOM-6ULL wiki:
  1. `rfkill unblock all`
  2. a hostapd.conf with no `driver=` line (nl80211): `hw_mode=g`, `wpa=2`, `wpa_key_mgmt=WPA-PSK`, `rsn_pairwise=CCMP`
  3. `echo 2 > /sys/module/bcmdhd/parameters/op_mode`
  4. `ip addr add …`
  5. `hostapd -B`, then `udhcpd`

  It uses stock upstream hostapd (Debian package). Android does the same by writing an `*_apsta.bin` path to `/sys/module/bcmdhd/parameters/firmware_path` with `BOARD_HOSTAPD_DRIVER := NL80211`.
- confidence: high (documented); medium (transfer to Kindle)
- status: agent
- sources: S-BRCM-10, S-BRCM-05
- notes: on Kindle, `op_mode` takes effect at firmware download, i.e. at module load, so re-`insmod` with `op_mode=2` plus Amazon's fw/nvram params

### BRCM-C07: single bcmdhd firmware covers SoftAP since v1.141.100.6
- claim: NXP imx-firmware history: "Remove the fw_bcmdhd_apsta.bin binaries, as they are no longer needed as of bcmdhd v 1.141.100.6 … The new fw_bcmdhd.bin supports following modes: STA/Client, Soft AP, Simultaneous STA/Soft AP." The Kindle Basic 8th gen bcmdhd is 1.201.59 (newer), so its `fw_bcmdhd_sr.bin` is **probably** a combined image. This also explains an unresolved NXP thread ("AP-ENABLED but not visible", blamed on a missing apsta file).
- confidence: medium (NXP history); medium-low (Kindle firmware content)
- status: snippet (NXP history); inference (Kindle)
- sources: S-BRCM-11, S-BRCM-09, S-KIN-12
- recheck: on device `strings /opt/brcm*/wifi/firmware/fw_bcmdhd*.bin | tail -2` and an `op_mode=2` test (Q-KIN-07)

### BRCM-C08: fallback AP firmware options
- claim: if the stock firmware won't beacon (keep the device's own NVRAM in every case):
  1. NXP firmware-imx `bcm/1DX_BCM4343W/fw_bcmdhd.bin` (NXP licence, redistribution unchecked)
  2. AOSP `fw_bcm4343[_a1][_apsta].bin`, whose licence allows unmodified redistribution "only for use with a Broadcom Product"
  3. Cypress `brcmfmac43430-sdio.bin` under bcmdhd (unconfirmed; the reverse direction, DHD firmware under brcmfmac, has been seen working)
- confidence: high (AOSP licence); low (Cypress under bcmdhd)
- status: agent
- sources: S-BRCM-12, S-BRCM-06, S-BRCM-13
