---
topic: remarkable
last_reviewed: 2026-10-31
---

# reMarkable (KOReader target, not strictly an e-reader)

## Summary verdicts (2026-10-31)

| Model | Verdict | Key claims |
|---|---|---|
| reMarkable 1 | Likely | RM-C03, RM-C04, RM-C09 |
| reMarkable 2 | Likely | RM-C01, RM-C02, RM-C03, RM-C04 |
| Paper Pro (ferrari) | Possible with work | RM-C05, RM-C07 |
| Paper Pro Move (chiappa) | Possible with work | RM-C05, RM-C06 |
| Paper Pure (tatsu) | Possible with work, untested | RM-C05 |

## Claims

### RM-C01: rM2 Wi-Fi is Broadcom on SDIO (brcmfmac)
- claim: the mainline DTS declares `brcm,bcm4329-fmac` on `usdhc2`, with a `brcm_reg` regulator and a 32 kHz clock through mmc-pwrseq. The compatible string is generic to brcmfmac and doesn't name the exact chip.
- confidence: high
- status: agent
- sources: S-RM-01, S-RM-02

### RM-C02: reMarkable's Cypress firmware mentions SoftAP
- claim: reMarkable's `brcmfmac-firmware` repo covers 43430/43455/4339 and others. It mentions "Concurrent APSTA" and a "SoftAP association fix", and lists the known issue "softap low throughput with iMX6UL".
- confidence: high
- status: agent
- sources: S-RM-03

### RM-C03: KOReader already takes Wi-Fi over from xochitl
- claim: `platform/remarkable/enable-wifi.sh`:
  1. loads `brcmfmac` if missing
  2. stops the `wpa_supplicant` systemd service (comment: "used by xochitl") and any standalone instance (`wpa_cli terminate`)
  3. runs `ifconfig wlan0 up`
  4. ensures `dhcpcd` is running
  5. starts its own `wpa_supplicant -B -C /var/run/wpa_supplicant` on `wlan0`
- confidence: high
- status: verified
- sources: S-KOR-04
- notes: this is the same "take the radio from the vendor stack" pattern the hotspot needs

### RM-C04: root access
- claim: dropbear SSH logs in as root (password under Settings > Help > Copyright and licenses). Paper Pro, Move and Pure need Developer Mode, which wipes the device. SSH over Wi-Fi needs `rm-ssh-over-wlan on` on those and on rM2 with OS > 3.20.
- confidence: high
- status: agent
- sources: S-RM-04

### RM-C05: Paper Pro family kernels
- claim: reMarkable's kernel repo has `ferrari_defconfig` (Paper Pro), `chiappa_defconfig` (Move) and `tatsu_defconfig` (Paper Pure, i.MX9 / Cortex-A55). The Paper Pro SoC is a quad Cortex-A53 at 1.8 GHz (fits i.MX8MM). Its Wi-Fi chip is not publicly identified.
- confidence: high (defconfigs); low (Paper Pro chip)
- status: agent
- sources: S-RM-05

### RM-C06: Paper Pro Move Wi-Fi
- claim: the Move is an i.MX93 with an NXP IW611, driven by NXP's out-of-tree mwifiex (`sd_w61x_v1.bin.se`). NXP drivers usually expose a `uap0` AP interface.
- confidence: medium
- status: agent / inference
- sources: S-RM-06

### RM-C07: KOReader on Paper Pro
- claim: KOReader has supported Paper Pro officially since v2025.08 (PR #13620), via XOVI, QTFB and rmpp-qtfb-shim. That PR did not change Wi-Fi handling. Move users run it through AppLoad. Toltec supports only OS ≤ 3.3.x.
- confidence: high
- status: agent
- sources: S-KOR-17, S-RM-07, S-RM-08, S-RM-09

### RM-C08: no prior art for an AP on reMarkable
- claim: no hostapd/AP project for reMarkable was found. `webinterface-wifi` only exposes the USB web UI over Wi-Fi.
- confidence: medium (negative result)
- status: agent
- sources: S-RM-10

### RM-C09: rM1 shares the Wi-Fi script and can't unload modules
- claim: rM1 uses the same KOReader Wi-Fi script (brcmfmac) and has no `CONFIG_MODULE_UNLOAD`.
- confidence: medium
- status: agent
- sources: S-KOR-05

## Porting sketch (inference)

- **rM1/rM2**:
  1. stop the `wpa_supplicant` unit
  2. hostapd (`driver=nl80211`, `interface=wlan0`), then `ip addr add 192.168.42.1/24 dev wlan0`, then udhcpd
  3. reverse on stop and restart the unit
  - The current static armhf binaries probably run as-is (i.MX6SL/i.MX7D have NEON; kernel ≥ 3.2).
  - Watch for xochitl restarting wpa_supplicant on resume (Q-RM-01).
- **Paper Pro family**: likely `interface=uap0`; needs **aarch64** binaries.
