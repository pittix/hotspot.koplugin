# hotspot.koplugin

A KOReader plugin that turns your Kobo into a Wi-Fi access point. 'Hotspot' is maybe a little misleading since this access point won't give you internet access, but it's useful for connecting other devices directly to your Kobo — for example, to transfer books over rsync/SSH.

## What it does

- Broadcasts a Wi-Fi AP (SSID, channel, and optional WPA2 password are all configurable)
- Assigns the Kobo the static IP `192.168.42.1` on the AP interface
- Runs a DHCP server so connecting devices get addresses in `192.168.42.10–100`
- Menu lives under **Settings → Network → Wi-Fi hotspot**
- Can be set to start automatically with KOReader

## How it works

### hostapd

The plugin writes a minimal `hostapd` config to `/tmp` and starts the bundled `hostapd` binary. hostapd handles the full 802.11 AP management: beacon frames, association, WPA2 handshake, etc.

### IP assignment and DHCP

After hostapd brings `uap0` into AP mode, the plugin assigns `192.168.42.1/24` via `ip addr add`. It then starts the bundled `udhcpd` (a BusyBox DHCP server) , handing out leases from `.10` to `.100` with the Kobo as the default gateway.

## Porting to a different device

This was made to work with my Kobo Clara 2E, but it should work with most Kobo devices (I think, I haven't tested it on anything other than my own Kobo). The plugin itself is very simple, so it should be fairly easy to port to other devices. The main thing that would need to be done is to check if your device's network card supports broadcasting an AP, and getting `hostapd` and `udhcpd` binaries compatible with your device.

### 1. Check for a virtual AP interface

This plugin is built around the Marvell `uap0` interface. Other chipsets may expose a similar capability under a different name (e.g. `wlan1`, `ap0`). SSH into your device and check:

```bash
ip link show
cat /sys/class/net/*/uevent | grep -i ap
```

If your driver supports simultaneous client + AP mode, you'll see a second interface. If it doesn't, you'd need `hostapd` with a different driver backend (e.g. `driver=nl80211` on a mac80211-based driver) and may need to manage the interface differently.

Update the interface name (`uap0`) in `main.lua` if it differs.

### 2. Obtain hostapd for your architecture

The bundled `hostapd` binary is a statically linked ARMv7 hard-float executable built for Kobo (Freescale i.MX6, `armhf`). For a different architecture you need to cross-compile it.

### 3. Obtain udhcpd for your architecture

The bundled `udhcpd` binary is a copy of the device's own BusyBox binary, renamed so that BusyBox's multi-call dispatch runs it as the `udhcpd` applet. We did not cross-compile this — Kobo already ships BusyBox with the `udhcpd` applet included.

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

### 5. Remove the Kobo guard

`main.lua` has an early return that disables the plugin on non-Kobo devices:

```lua
if not Device:isKobo() then
    return { disabled = true }
end
```

Remove or replace this with whatever device check is appropriate for your target.
