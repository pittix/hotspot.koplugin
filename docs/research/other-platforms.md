---
topic: other-platforms
last_reviewed: 2026-10-31
---

# Other KOReader platforms

## Summary verdicts (2026-10-31)

| Platform | Verdict | Key claims |
|---|---|---|
| bq Cervantes | Possible with work | OTH-C01 |
| Bookeen Cybook | Possible with work | OTH-C02 |
| Sony PRS-T1/T2/T3 | Unlikely | OTH-C03, OTH-C04 |
| Tolino Shine 5 (Kobo firmware) | Same as the Kobo MediaTek port | OTH-C05 |
| Android readers (Boox, Bigme, Meebook, Hisense, inkBOOK, Nook, older Android Tolinos) | **Out of scope (D2)** | OTH-C06, OTH-C07 |

## Claims

### OTH-C01: Cervantes Wi-Fi drivers
- claim: KOReader's Cervantes `enable-wifi.sh` picks the driver by PCB ID (`ntxinfo`). PCB 22/23 load `dhd` with wpa_supplicant `-D nl80211`; all others load `8189fs` with `-D wext`. The interface is `eth0`. The hardware is Netronix-based; the Wi-Fi blob is closed; BQ's unlock server is down.
- confidence: high (script); medium (rest)
- status: agent
- sources: S-KOR-06, S-OTH-02
- notes: the 8189fs path needs an `rtl871xdrv` hostapd unless the module was built with cfg80211; the dhd path may need AP firmware (see BRCM-C06)

### OTH-C02: Bookeen Wi-Fi driver
- claim: KOReader's Bookeen `wlan.sh` loads `/lib/modules/3.0.8+/8188eu.ko` (with `rtw_initmac`), uses `wlan0` and `-D wext`, and has vendor `nvram`/`power` tools. Models: Odyssey, Muse, Ocean, Saga, Diva (OMAP3611 or Allwinner A13).
- confidence: high
- status: agent
- sources: S-KOR-07, S-KOR-08, S-CHIP-03
- notes: Realtek 8188eu + rtl871xdrv hostapd is a well-known AP setup. Kernel 3.0.8 < 3.2, so it needs a rebuilt hostapd (musl).

### OTH-C03: KOReader platform list
- claim: current KOReader `frontend/device` dirs are android, bookeen, cervantes, dummy, generic, kindle, kobo, pocketbook, remarkable and sdl. `platform/sony-prstux` still exists, but there is no frontend device dir for it, so Sony support may be gone.
- confidence: medium
- status: agent
- sources: S-KOR-18, S-KOR-19

### OTH-C04: Sony PRS-T Wi-Fi
- claim: PRS-T2 uses an Atheros AR6003 with vendor `wmiconfig` tooling. ath6kl's AP is b/g-only and unreliable; the vendor driver's AP support is unclear.
- confidence: high (chip); medium (AP)
- status: agent
- sources: S-OTH-01, ATH-C09

### OTH-C05: Tolino Shine 5
- claim: Tolino Shine 5 (T302) is Kobo Clara BW hardware. Running Kobo firmware needs "Kobo mode", which wipes the device. Tolino firmware 5.x ignores `KoboRoot.tgz`.
- confidence: medium
- status: agent
- sources: S-OTH-03, S-OTH-04
- notes: in Kobo mode it inherits whatever the Kobo MediaTek backend does

### OTH-C06: Android Tolinos are Kobo hardware (out of scope)
- claim: Shine 4 = Clara 2E, Vision 6 ≈ Libra 2, Epos 3 = Sage, running Android. KOReader needs root there.
- confidence: medium
- status: agent
- sources: S-OTH-05

### OTH-C07: Android readers (out of scope, D2)
- claim: Android already provides system tethering. A non-root app can't run hostapd; `startLocalOnlyHotspot` gives random credentials and would need KOReader launcher (Kotlin + manifest) changes. Recorded only for traceability; **not to be pursued**.
- confidence: high
- status: agent
- sources: S-OTH-06, S-OTH-07, S-OTH-08
