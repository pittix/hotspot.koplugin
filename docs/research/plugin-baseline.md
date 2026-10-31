---
topic: plugin-baseline
last_reviewed: 2026-10-31
---

# Plugin baseline: what a device must provide

### BASE-C01: bundled hostapd binary
- claim: `hostapd` is **hostapd 2.10**, statically linked against **glibc**, built with **Debian GCC 12.2.0-14** (bookworm), ARMv7-A, **VFPv3 + NEON, hard-float** (`Tag_ABI_VFP_args: VFP registers`). Only the **nl80211** driver backend is compiled in. The ELF ABI note says `for GNU/Linux 3.2.0`.
- confidence: high
- status: verified
- sources: S-LOC-01, S-KIN-33 (toolchain for rebuilds)
- recheck: `file hostapd; readelf -A hostapd; strings hostapd | grep -E 'hostapd v|^2\.10$|GCC: |GLIBC_ABI_DT_RELR|driver_nl80211'`
- notes:
  - **Needs Linux ≥ 3.2** (glibc aborts with "FATAL: kernel too old" on older kernels) and an ARMv7 CPU with NEON.
  - Static, so the target's userland float ABI (armel/softfp vs armhf) is irrelevant.
  - glibc 2.36 is inferred from the bookworm toolchain and the presence of `GLIBC_ABI_DT_RELR` (inference).
  - Per decision D1 it can be rebuilt: musl or `--enable-kernel=2.6.3x` for old kernels, the `rtl871xdrv` backend for Realtek vendor drivers, aarch64 for Paper Pro.

### BASE-C02: bundled udhcpd binary
- claim: `udhcpd` is Kobo's own **BusyBox v1.31.0** (2019-06-10), static, ARMv7 VFPv2 hard-float, with no kernel-version ELF note. It runs as the `udhcpd` applet because of its file name.
- confidence: high
- status: verified
- sources: S-LOC-02
- recheck: `file udhcpd; readelf -A udhcpd; strings udhcpd | grep 'BusyBox v'`

### BASE-C03: device requirements derived from main.lua
- claim: today the plugin needs:
  1. Root, for hostapd, `ip addr`, udhcpd, `insmod`, and writing `/dev/wmtWifi`.
  2. A Wi-Fi driver with AP mode via nl80211/cfg80211.
  3. A way to get an AP interface: Marvell `moal` → `uap0`; MediaTek gen4m → write `A` to `/dev/wmtWifi` → `ap0`.
  4. Loading and unloading the radio with Kobo's `./enable-wifi.sh` / `./disable-wifi.sh` and KOReader's `NetworkMgr`.
  5. Driver identification through the `WIFI_MODULE` env var, which only KOReader's Kobo launcher exports.
  6. `ip` (iproute2 or BusyBox).
  7. The `Device:isKobo()` guard must pass.

  On MediaTek it also starts `wmt_loader`/`wmt_launcher` if missing (koreader#16222) and treats STA/AP as exclusive.
- confidence: high
- status: verified
- sources: S-LOC-03, S-LOC-04, S-LOC-05 (upstream original), S-KOR-10, S-KOR-11
- recheck: read `main.lua` (`BACKENDS`, `Device:isKobo`, `WIFI_MODULE`, `enable-wifi.sh`)
- notes: **The Kobo-isms to abstract for any port**:
  - the `isKobo` guard
  - `WIFI_MODULE`
  - enable/disable-wifi.sh (they exist on Kobo, reMarkable and Cervantes; **not** on Kindle or PocketBook)
  - the assumption that the plugin already runs as root (false on PocketBook)

  **New concerns on other platforms:**
  - a vendor network daemon to stop or coexist with (Kindle `wifid`, PocketBook `netagent`/inkview, reMarkable `wpa_supplicant` unit)
  - a default-DROP firewall (Kindle)
  - `su` wrapping (PocketBook)
  - standby inhibit (Kindle `preventScreenSaver`, PocketBook `iv_sleepmode`)

### BASE-C04: target refactor (proposal, not a fact)
- claim: split `main.lua` into a generic core plus per-platform backends:
  - **generic core**: config writers, IP/DHCP, firewall open/close, suspend teardown
  - **per-platform backend**: detection, privilege prefix, `takeOver()`/`giveBack()` of the radio, AP interface creation, hostapd driver/binary choice, standby inhibit
- confidence: n/a
- status: inference
- sources: (design proposal in `../other-ereaders-report.md` §4.2)
