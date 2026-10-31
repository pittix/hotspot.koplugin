---
topic: open-questions
last_reviewed: 2026-10-31
---

# Open questions (need a device)

Format: `Q-<AREA>-<nn>`, followed by the question, the claims it would settle, and the commands to run.
Run as root (Kindle/reMarkable: KOReader SSH or terminal; PocketBook: through `/mnt/secure/su`).
A static `iw` binary (libnl) makes most of these easier; consider bundling one for diagnostics.
When answered, record the result under the question with date + device + firmware, and update the linked claim's status.

## Generic (any new Linux device)

```sh
uname -a; cat /proc/cpuinfo | grep -E 'Hardware|Features'; ls -l /lib/ld-linux*
lsmod; readlink -f /sys/class/net/*/device/driver; ls /sys/class/ieee80211/
zcat /proc/config.gz 2>/dev/null | grep -E 'CFG80211|NL80211|WIRELESS_EXT|MODULE_UNLOAD|BRIDGE|NETFILTER'
for b in iw ip ifconfig iwconfig iwpriv hostapd udhcpd dnsmasq wpa_cli iptables; do which $b; done
busybox --list | grep -E '^(ip|udhcpd|iw)$'
iw list | sed -n '/Supported interface modes/,/Supported commands/p'   # look for "* AP"
iw list | grep -A6 'interface combinations'                             # AP+STA concurrency
iptables-save
```

## Kindle

### Q-KIN-01: does `/dev/wmtWifi` `A` create `ap0` on MTK Kindles, and are the WMT daemons running? (KIN-C01, KIN-C13)
```sh
ls -l /dev/wmtWifi /dev/stpwmt; lsmod | grep -Ei 'wmt|gen4m'; status wmt; ps | grep -i wmt
lipc-set-prop com.lab126.cmd wirelessEnable 0; sleep 3; stop wifid
echo A > /dev/wmtWifi; sleep 3; ls /sys/class/net; dmesg | tail -40
# restore
echo 0 > /dev/wmtWifi; start wifid; lipc-set-prop com.lab126.cmd wirelessEnable 1
```

### Q-KIN-02: does stopping wifid cleanly hand over the radio? (KIN-C09)
```sh
status wifid; cat /etc/upstart/wifid.conf; status cmd; ps | grep -Ei 'wifid|wpa_|dhcp'
```

### Q-KIN-03: stock firewall rules on current firmware (KIN-C10)
```sh
iptables-save
```

### Q-KIN-04: is STA+AP possible on MTK (MCC)? Does Bluetooth survive the mode switch? (KIN-C04)
```sh
iw dev wlan0 interface add ap0 type __ap   # while connected as client
```

### Q-KIN-05: full hostapd smoke test on MTK
```sh
/mnt/us/koreader/plugins/hotspot.koplugin/hostapd -dd /tmp/koreader_hostapd.conf
# expect AP-ENABLED; join from a phone; check udhcpd lease and ping 192.168.42.1
```

### Q-KIN-06: Atheros Kindles: are ath6kl/cfg80211 modules shipped, and is cfg80211 a module? (KIN-C18, KIN-C19, KIN-C27)
```sh
lsmod | grep -iE 'ath6kl|ar6000|ar6003'          # ath6kl_sdio loaded => Voyage-like, kindshare recipe applies (KIN-C28)
iw phy phy0 info | sed -n '/Supported interface modes/,/^\t[A-Z]/p'   # need "* AP"
find /lib/modules/$(uname -r) -name '*ath6kl*' -o -name 'cfg80211.ko' -o -name 'compat*.ko' -o -name 'ar6003.ko'
modinfo <each>.ko | grep -E 'vermagic|parm'     # board_data_file?
zcat /proc/config.gz | grep -E 'CFG80211|ATH6KL|AR6003'
ls -R /opt/ar6k/target/; ls /sys/module/ar6003/parameters; iwpriv wlan0
grep -rn 'ar6003\|ath6kl\|insmod\|modprobe' /etc/upstart /etc/init.d 2>/dev/null
```

### Q-KIN-07: Broadcom Kindles: which driver/params, and does the stock firmware beacon with op_mode=2? (KIN-C23, BRCM-C06, BRCM-C07)
```sh
ls /sys/module | grep -iE 'dhd|brcm'
for p in /sys/module/*dhd*/parameters/*; do echo "$p: $(cat $p)"; done   # firmware_path, nvram_path, op_mode
grep -rn 'dhd\|brcm' /etc/upstart /etc/init.d 2>/dev/null                # Amazon's insmod line
ls -l /opt/brcm*/wifi/firmware/; strings /opt/brcm*/wifi/firmware/fw_bcmdhd*.bin | tail -2
# AP test: stop wifid; rmmod <dhd>; insmod <dhd>.ko op_mode=2 <Amazon's firmware_path/nvram_path>
# hostapd -dd <conf>  → device_ap_sme=1, AP-ENABLED; join from a phone
```

### Q-KIN-08: what Wi-Fi hardware do Scribe 3 / Scribe Colorsoft (2025) have? (KIN-C06)
Run the generic block.

## PocketBook

### Q-PB-01: does XRadio allow AP and AP+STA on device? (PB-C02)
```sh
iw list | sed -n '/Supported interface modes/,/Supported commands/p'; iw list | grep -A6 'interface combinations'
iw dev wlan0 interface add ap0 type __ap && ip link set ap0 up && ls /sys/class/net
```

### Q-PB-02: which user does KOReader run as; is /mnt/secure/su present? (PB-C04, PB-C05)
```sh
id; ls -l /mnt/secure/su
```

### Q-PB-03: does netagent power the radio down on NetDisconnect or after idle? (PB-C15)
```sh
ps | grep -Ei 'netagent|wpa_|dhcp'; ls /ebrmain/bin | head -50
# toggle Wi-Fi off in KOReader, then: ls /sys/class/net; lsmod | grep xradio
```

### Q-PB-04: which Wi-Fi chip/driver on B300 devices? (PB-C08, PB-C10)
```sh
lsmod; readlink -f /sys/class/net/wlan0/device/driver; uname -r
```

### Q-PB-05: stock iptables rules
```sh
iptables -L -n
```

## reMarkable

### Q-RM-01: does xochitl restart wpa_supplicant on resume? (RM-C03)
```sh
systemctl status wpa_supplicant dhcpcd; journalctl -u wpa_supplicant --since -10min
```

### Q-RM-02: which Wi-Fi chip is in the Paper Pro (ferrari), and does it expose uap0? (RM-C05)
```sh
lsmod; dmesg | grep -Ei 'mlan|moal|mwifiex|brcmf|wlan'; iw dev
```

### Q-RM-03: does the rM1 firmware include AP? (RM-C09)
```sh
dmesg | grep -i brcmf; iw list | grep -A10 'Supported interface modes'
```
