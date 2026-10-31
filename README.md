# hotspot.koplugin

A KOReader plugin that turns your Kobo (and, experimentally, a Kindle Voyage) into a Wi-Fi access point. 'Hotspot' is maybe a little misleading since this access point won't give you internet access, but it's useful for connecting other devices directly to your Kobo — for example, to transfer books over rsync/SSH.

## What it does

- Broadcasts a Wi-Fi AP (SSID, channel, and optional WPA2 password are all configurable)
- Assigns the Kobo the static IP `192.168.42.1` on the AP interface
- Runs a DHCP server so connecting devices get addresses in `192.168.42.10–100`
- Menu lives under **Settings -> Network -> Wi-Fi hotspot**
- Can be set to start automatically with KOReader

## Supported devices

The plugin picks the AP interface from the Wi-Fi driver: on Kobo the one KOReader reports (`WIFI_MODULE`), on Kindle the loaded kernel module.

| Device | Wi-Fi driver | AP interface | Status |
|---|---|---|---|
| Kobo Clara 2E | Marvell/NXP 88W8987 (`moal`) | `uap0` | Tested |
| Kobo Libra Colour | MediaTek MT8113 (`wlan_drv_gen4m`) | `ap0` | Tested (firmware 4.46.23836, KOReader v2026.07.2) |
| Kobo Clara BW, Clara Colour | MediaTek MT8113 (`wlan_drv_gen4m`) | `ap0` | Untested (same driver source as the Libra Colour) |
| Kindle Voyage (jailbroken) | Atheros AR6003 (`ath6kl_sdio`) | `wlan0` | **Untested with this plugin.** The same recipe works in [kindshare](https://github.com/unrealJune/kindshare) (Voyage, firmware 5.13.6) |

On other devices, **Enable hotspot** reports that the Wi-Fi chip is not supported yet. Other Atheros Kindles (PW2, PW3, Basic 7th gen) use this backend automatically if their firmware loads `ath6kl_sdio`. Check with `lsmod | grep -iE 'ath6kl|ar6000|ar6003'`. Amazon's older `ar6003`/`ar6000` driver can't run an access point. See [docs/other-ereaders-report.md](docs/other-ereaders-report.md) for other models.

## How it works

### hostapd

The plugin writes a minimal `hostapd` config to `/tmp` and starts the bundled `hostapd` binary. hostapd handles the full 802.11 AP management: beacon frames, association, WPA2 handshake, etc.

### IP assignment and DHCP

After hostapd brings the AP interface (`uap0` or `ap0`) into AP mode, the plugin assigns `192.168.42.1/24` via `ip addr add`. It then starts the bundled `udhcpd` (a BusyBox DHCP server) , handing out leases from `.10` to `.100` with the Kobo as the default gateway.

### MediaTek Kobos (Libra Colour and similar)

MediaTek's driver has no always-present AP interface. Writing `A` to `/dev/wmtWifi` switches the chip to AP mode and creates `ap0`. Writing `0` leaves AP mode and powers Wi-Fi off, the same way KOReader's `disable-wifi.sh` does.

The chip cannot be a Wi-Fi client and an access point at the same time. So on these devices:

- **Starting with Wi-Fi on:** if KOReader's Wi-Fi is on, the plugin asks first (**Cancel** / **Turn off Wi-Fi and start hotspot**).
- **Wi-Fi not used since boot:** the plugin first starts MediaTek's firmware daemons (`wmt_loader`, `wmt_launcher`), as Nickel does. Then it loads the Wi-Fi kernel modules by turning Wi-Fi on and off once ("Loading Wi-Fi modules..."). Without the daemons, powering the chip reboots the Kobo (the same bug as [koreader#13197](https://github.com/koreader/koreader/issues/13197); fix from [koreader#16222](https://github.com/koreader/koreader/issues/16222)). If the daemons cannot be started, the plugin asks you to turn Wi-Fi on once from the Kobo home screen instead.
- **Stopping:** stopping the hotspot powers Wi-Fi off. The plugin then asks whether to turn Wi-Fi back on or keep it off.

hostapd logs `Failed to set TX queue parameters` and `Could not set station <name> flags for kernel driver` on this driver. Both are harmless: clients connect and the WPA2 handshake completes.

### Kindle Voyage (Atheros AR6003, experimental)

This backend ports the access-point recipe from unrealJune's [kindshare](https://github.com/unrealJune/kindshare) ([MobileRead thread](https://www.mobileread.com/forums/showthread.php?p=4604552)), which was verified end to end on a Kindle Voyage with firmware 5.13.6 (kernel 3.0.35-lab126, Amazon's `ath6kl_sdio` driver). It hasn't been tested with this plugin yet: reports are welcome.

- **Normal Wi-Fi is off while the hotspot runs.** The access point uses `wlan0` itself, so the plugin stops Amazon's `wifid` and `wpa_supplicant` first. If Wi-Fi is on, the plugin asks before doing so. Stopping the hotspot starts `wifid` again, and the Kindle reconnects as usual.
- **WPA2 is required.** On an open network the chip's firmware never authorizes clients: they associate but get no DHCP reply. The plugin refuses to start until a WPA2 password is set.
- **Plain 802.11g.** The plugin adds `ieee80211n=0`, `wmm_enabled=0`, `dtim_period=1` and `max_num_sta=4` to the hostapd config. The driver rejects WMM setup, and clients drop within seconds when HT/WMM are advertised.
- **Firewall.** The stock firewall drops new inbound connections, so the plugin adds `iptables` ACCEPT rules for `wlan0` (INPUT and OUTPUT) and removes only the rules it added when the hotspot stops.
- **Sleep.** The plugin sets `preventScreenSaver` through `lipc` while the hotspot runs, like KOReader's KeepAlive plugin, and clears it on stop.
- **Binaries.** Kernel 3.0.35 is too old for the bundled `hostapd` (static glibc, needs kernel 3.2 or newer), so this backend uses `hostapd.musl` (see [Binaries](#binaries)). DHCP uses the Kindle's own BusyBox `udhcpd`, falling back to the bundled one.

### Known limitation

KOReader turns Wi-Fi off when the Kobo goes to sleep, which also stops the hotspot. Keep the Kobo awake while the hotspot is in use.

## Binaries

| File | What | Used by |
|---|---|---|
| `hostapd` | hostapd 2.10, static glibc, ARMv7 hard-float, nl80211. Needs kernel 3.2 or newer | Kobo backends |
| `hostapd.musl` | hostapd 2.11, static musl, ARMv7 hard-float (VFPv3-D16), nl80211. No kernel-version floor | Kindle backend |
| `udhcpd` | BusyBox 1.31 (a Kobo's own BusyBox, renamed) | DHCP, all backends |

`hostapd.musl` is built by [`tools/build-hostapd-musl.sh`](tools/build-hostapd-musl.sh) with the config in [`tools/hostapd-musl.defconfig`](tools/hostapd-musl.defconfig). The script downloads hostapd 2.11, libnl 3.7.0 and Bootlin's `armv7-eabihf--musl--stable-2025.08-1` cross-toolchain into `.tmp/` (gitignored) and checks their checksums. It cross-compiles on the host, with no Docker or QEMU needed. The recipe (versions, static `-Os` build, hostapd config) comes from kindshare's `build/` directory (MIT, Copyright (c) 2026 June Philip). Build of 2026-10-31: SHA-256 `368f1706616bb9bc7fb6bf093467ca8865b28fcbf3f9654a5fd3523f66ce8fa0`.

hostapd is BSD-licensed. libnl, which is statically linked into both hostapd binaries, is LGPL-2.1: the build script and the upstream sources it fetches are what you need to rebuild or relink it.

## Porting to a different device

This was made to work with my Kobo Clara 2E, but it should work with most Kobo devices (I think, I haven't tested it on anything other than my own Kobo). The plugin itself is very simple, so it should be fairly easy to port to other devices. The main thing that would need to be done is to check if your device's network card supports broadcasting an AP, and getting `hostapd` and `udhcpd` binaries compatible with your device.

### 1. Check for a virtual AP interface

This plugin is built around the Marvell `uap0` interface. Other chipsets may expose a similar capability under a different name (e.g. `wlan1`, `ap0`). SSH into your device and check:

```bash
ip link show
cat /sys/class/net/*/uevent | grep -i ap
```

If your driver supports simultaneous client + AP mode, you'll see a second interface. If it doesn't, you'd need `hostapd` with a different driver backend (e.g. `driver=nl80211` on a mac80211-based driver) and may need to manage the interface differently.

Add your driver to the `BACKENDS` table in `main.lua`, keyed by the `WIFI_MODULE` value KOReader reports (`echo $WIFI_MODULE` in KOReader's terminal), with the name of its AP interface.

### 2. Obtain hostapd for your architecture

The bundled `hostapd` binary is a statically linked ARMv7 hard-float executable built for Kobo (Freescale i.MX6, `armhf`). For a different architecture you need to cross-compile it. For an ARMv7 device with a kernel older than 3.2, use `hostapd.musl` or rebuild it with `tools/build-hostapd-musl.sh`.

### 3. Obtain udhcpd for your architecture

The bundled `udhcpd` binary is a copy of the device's own BusyBox binary, renamed so that BusyBox's multi-call dispatch runs it as the `udhcpd` applet. We did not cross-compile this: Kobo already ships BusyBox with the `udhcpd` applet included.

**To check on your target device:**

```bash
busybox --list | grep udhcpd
```

If `udhcpd` is listed, copy the BusyBox binary into the plugin directory and name it `udhcpd`:

```bash
cp $(which busybox) plugins/hotspot.koplugin/udhcpd
```

If the device does not have BusyBox, or has BusyBox without the `udhcpd` applet, you will need to cross-compile BusyBox yourself.

### 4. Verify `ip` is available

The plugin uses the `ip` command (iproute2) to assign the gateway address. Most KOReader-supported devices have this. If yours doesn't, you can substitute `ifconfig uap0 192.168.42.1 netmask 255.255.255.0 up` instead.

### 5. Extend the device guard

`main.lua` has an early return that disables the plugin on devices other than Kobo and Kindle:

```lua
if not (Device:isKobo() or Device:isKindle()) then
    return { disabled = true }
end
```

Add your platform there, and give your backend a `platform` field (see `BACKENDS`), so a driver name shared across platforms doesn't pick another platform's backend. The Kindle backend shows what a non-Kobo platform needs: driver detection from `/proc/modules`, taking the interface over from the vendor's network daemon, and firewall rules.

## Credits

- [Ying Stokes (thorondir)](https://github.com/thorondir/hotspot.koplugin): the original plugin, for the Kobo Clara 2E.
- [unrealJune (June Philip)](https://github.com/unrealJune/kindshare): the Kindle Voyage access-point recipe and the hostapd musl build that the Kindle backend is based on.
- shuvashish76 and NiLuJe ([koreader#13197](https://github.com/koreader/koreader/issues/13197)) and winterwurzel ([koreader#16222](https://github.com/koreader/koreader/issues/16222)): diagnosis and fix for the MediaTek reboot when Wi-Fi is first powered without Nickel's firmware daemons.
- Research sources for other devices: [docs/research/sources.md](docs/research/sources.md).
