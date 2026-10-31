local ConfirmBox = require("ui/widget/confirmbox")
local Device = require("device")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ffiutil = require("ffi/util")
local logger = require("logger")
local util = require("util")
local _ = require("gettext")
local T = ffiutil.template

-- Requires a wifi chip whose driver can run an access point (see BACKENDS).
-- Tested on Kobo. The Kindle backend follows a recipe verified on a Kindle Voyage
-- by kindshare (see README), but has not been tested with this plugin yet.
if not (Device:isKobo() or Device:isKindle()) then
    return { disabled = true }
end

local PLATFORM = Device:isKindle() and "kindle" or "kobo"

-- Supported wifi drivers, keyed by kernel module name. On Kobo the driver comes
-- from the WIFI_MODULE variable KOReader exports; on Kindle it is detected from
-- the loaded kernel modules.
local BACKENDS = {
    -- Marvell/NXP 88W8987 (Kobo Clara 2E): the moal driver exposes a uap0 virtual AP interface.
    moal = { platform = "kobo", iface = "uap0" },
    -- MediaTek MT8113 (Kobo Libra Colour, and likely Clara BW / Clara Colour):
    -- writing "A" to /dev/wmtWifi switches the chip to AP mode and creates ap0,
    -- writing "0" leaves AP mode and powers wifi off (like KOReader's disable-wifi.sh).
    -- The chip cannot be a wifi client and an access point at the same time.
    wlan_drv_gen4m = { platform = "kobo", iface = "ap0", wmt = "/dev/wmtWifi" },
    -- Atheros AR6003 with Amazon's ath6kl_sdio driver (Kindle Voyage on firmware 5.13.6).
    -- Recipe from unrealJune's kindshare (https://github.com/unrealJune/kindshare):
    -- the access point runs on wlan0 itself, so Amazon's wifid and wpa_supplicant
    -- are stopped while it runs, and the stock firewall (INPUT policy DROP) needs
    -- ACCEPT rules. The kernel (3.0.35) is too old for the glibc hostapd, hence the
    -- musl build. The chip's firmware never authorizes clients on an open network,
    -- and drops clients when HT/WMM are advertised, so WPA2 and plain 802.11g are forced.
    ath6kl_sdio = {
        platform = "kindle",
        iface = "wlan0",
        module = "ath6kl_sdio",
        hostapd = "hostapd.musl",
        require_wpa2 = true,
        system_udhcpd = true,
        hostapd_extra =
            "ieee80211n=0\n"  ..
            "wmm_enabled=0\n" ..
            "auth_algs=1\n"   ..
            "dtim_period=1\n" ..
            "beacon_int=100\n" ..
            "max_num_sta=4\n",
    },
}
-- Kindle wifi drivers to look for, so that an unsupported one can be named to the user.
local KINDLE_DRIVERS = { "ath6kl_sdio", "ar6003", "ar6000", "wlan_drv_gen4m", "bcmdhd", "dhd", "brcmfmac" }

local SENTINEL        = "/tmp/koreader_hotspot_active"
local UDHCPD_PID      = "/tmp/koreader_udhcpd.pid"
local UDHCPD_LEASES   = "/tmp/koreader_udhcpd.leases"
local UDHCPD_CONF     = "/tmp/koreader_udhcpd.conf"
local HOSTAPD_PID     = "/tmp/koreader_hostapd.pid"
local HOSTAPD_CONF    = "/tmp/koreader_hostapd.conf"
local HOSTAPD_LOG     = "/tmp/koreader_hostapd.log"
local FIREWALL_STATE  = "/tmp/koreader_hotspot_iptables"

local function isModuleLoaded(name)
    local f = io.open("/proc/modules", "r")
    if not f then return false end
    local prefix = name .. " "
    for line in f:lines() do
        if line:sub(1, #prefix) == prefix then
            f:close()
            return true
        end
    end
    f:close()
    return false
end

-- The detected wifi driver, and its backend once a supported one is found.
-- Detection is retried until then: on Kindle the driver may only be loaded
-- after Wi-Fi has been turned on.
local DRIVER, BACKEND

local function detectBackend()
    if BACKEND then return BACKEND end
    if PLATFORM == "kobo" then
        DRIVER = os.getenv("WIFI_MODULE")
    else
        DRIVER = nil
        for _i, name in ipairs(KINDLE_DRIVERS) do
            if isModuleLoaded(name) then
                DRIVER = name
                break
            end
        end
    end
    local backend = DRIVER and BACKENDS[DRIVER]
    -- A backend only applies to its own platform (e.g. the Kobo MediaTek
    -- backend relies on Kobo's wifi scripts).
    if backend and backend.platform == PLATFORM then
        BACKEND = backend
    end
    return BACKEND
end

local function requiresWpa2()
    local backend = detectBackend()
    return backend ~= nil and backend.require_wpa2 == true
end

local function hasCommand(name)
    return os.execute("command -v " .. name .. " >/dev/null 2>&1") == 0
end

-- Kindle's BusyBox may lack `ip`, so these fall back to ifconfig.
local function setAddress(iface)
    if hasCommand("ip") then
        return os.execute("ip addr add 192.168.42.1/24 dev " .. iface) == 0
    end
    return os.execute("ifconfig " .. iface .. " 192.168.42.1 netmask 255.255.255.0 up") == 0
end

local function flushAddress(iface)
    if hasCommand("ip") then
        os.execute("ip addr flush dev " .. iface .. " 2>/dev/null")
    else
        os.execute("ifconfig " .. iface .. " 0.0.0.0 2>/dev/null")
    end
end

local function setLink(iface, up)
    if hasCommand("ip") then
        os.execute("ip link set " .. iface .. (up and " up" or " down"))
    else
        os.execute("ifconfig " .. iface .. (up and " up" or " down"))
    end
end

-- Kindle: the stock firewall drops new inbound connections (INPUT policy DROP),
-- which would block DHCP requests and file transfers over the hotspot.
-- The rules this plugin adds are recorded, so that only those are removed again.
local FIREWALL_RULES = { "INPUT -i %s -j ACCEPT", "OUTPUT -o %s -j ACCEPT" }

local function openFirewall(iface)
    local f = io.open(FIREWALL_STATE, "w")
    for _i, fmt in ipairs(FIREWALL_RULES) do
        local rule = string.format(fmt, iface)
        local chain, spec = rule:match("^(%S+) (.*)$")
        if os.execute("iptables -C " .. rule .. " 2>/dev/null") ~= 0
                and os.execute("iptables -I " .. chain .. " 1 " .. spec) == 0
                and f then
            f:write(rule, "\n")
        end
    end
    if f then f:close() end
end

local function closeFirewall()
    local f = io.open(FIREWALL_STATE, "r")
    if not f then return end
    for rule in f:lines() do
        os.execute("iptables -D " .. rule .. " 2>/dev/null")
    end
    f:close()
    os.remove(FIREWALL_STATE)
end

-- Kindle: keeps powerd from suspending the device while the hotspot runs
-- (wifi stops on suspend). The same call KOReader's KeepAlive plugin uses.
local function preventKindleScreenSaver(prevent)
    os.execute("lipc-set-prop com.lab126.powerd preventScreenSaver "
        .. (prevent and "1" or "0") .. " >/dev/null 2>&1")
end

-- Sends a one-character command ("A" or "0") to the MediaTek wifi control device.
local function writeWmt(cmd)
    local f = io.open(BACKEND.wmt, "w")
    if not f then
        logger.warn("Hotspot: cannot open", BACKEND.wmt)
        return false
    end
    f:write(cmd)
    local ok, err = f:close()
    if not ok then
        logger.warn("Hotspot: writing", cmd, "to", BACKEND.wmt, "failed:", err)
        return false
    end
    return true
end

local Hotspot = WidgetContainer:extend{
    name = "hotspot",
    is_doc_only = false,
}

function Hotspot:init()
    self.ssid     = G_reader_settings:readSetting("hotspot_ssid")
                    or (PLATFORM == "kindle" and "KindleAP" or "KoboAP")
    self.channel  = G_reader_settings:readSetting("hotspot_channel")  or "6"
    self.security = G_reader_settings:readSetting("hotspot_security") or "open"
    self.password = G_reader_settings:readSetting("hotspot_password") or ""
    self.autostart = G_reader_settings:isTrue("hotspot_autostart")

    if self.autostart then
        self:start()
    end

    self.ui.menu:registerToMainMenu(self)
    self:onDispatcherRegisterActions()
end

function Hotspot:isRunning()
    return util.pathExists(SENTINEL)
end

-- Polls up to 5 s for the AP interface to appear.
function Hotspot:waitForInterface()
    local sysfs = "/sys/class/net/" .. BACKEND.iface
    for _ = 1, 20 do
        ffiutil.sleep(0.25)
        if util.pathExists(sysfs) then
            return true
        end
    end
    return false
end

-- Loads the wifi kernel module (if not already loaded) without triggering
-- NetworkMgr's network scan / connection attempt.
function Hotspot:ensureModuleLoaded()
    if util.pathExists("/sys/class/net/" .. BACKEND.iface) then
        return true
    end
    logger.info("Hotspot: wifi module not loaded, running enable-wifi.sh")
    os.execute("./enable-wifi.sh")
    return self:waitForInterface()
end

local function isRunningProcess(name)
    return os.execute("pidof " .. name .. " >/dev/null 2>&1") == 0
end

-- MediaTek: when Nickel first turns wifi on after boot, it also starts the
-- wmt_loader and wmt_launcher firmware daemons. KOReader's enable-wifi.sh does not,
-- and powering the chip without them reboots the Kobo
-- (koreader/koreader#13197, fix from koreader/koreader#16222).
-- Starts them like Nickel does. Returns false if that is not possible.
function Hotspot:startMediatekDaemons()
    if isRunningProcess("wmt_launcher") then
        return true
    end
    if not (util.pathExists("/usr/bin/wmt_loader") and util.pathExists("/usr/bin/wmt_launcher")) then
        logger.warn("Hotspot: wmt_loader/wmt_launcher not found")
        return false
    end
    logger.info("Hotspot: starting wmt_loader and wmt_launcher")
    if not isModuleLoaded("wmt_drv") then
        os.execute(string.format("insmod /drivers/%s/mt66xx/wmt_drv.ko", os.getenv("PLATFORM") or ""))
    end
    if not isRunningProcess("wmt_loader") then
        os.execute("/usr/bin/wmt_loader >/dev/null 2>&1 &")
    end
    os.execute("/usr/bin/wmt_launcher -p /lib/firmware >/dev/null 2>&1 &")
    -- Give the daemons time to settle before the chip is powered on.
    for _ = 1, 12 do
        ffiutil.sleep(0.25)
        if isRunningProcess("wmt_launcher") then
            ffiutil.sleep(1)
            return true
        end
    end
    logger.warn("Hotspot: wmt_launcher did not start")
    return false
end

-- MediaTek: the wifi modules are loaded once and never unloaded. If nothing
-- has loaded them since boot, start the firmware daemons, then cycle
-- KOReader's own wifi scripts once.
function Hotspot:ensureMediatekModulesLoaded()
    if isModuleLoaded(DRIVER) and isRunningProcess("wmt_launcher") then
        return true
    end
    local msg = InfoMessage:new{
        text = _("Loading Wi-Fi modules…"),
    }
    UIManager:show(msg)
    UIManager:forceRePaint()
    local ok = self:startMediatekDaemons()
    if ok then
        logger.info("Hotspot: wifi modules not loaded, cycling enable-wifi.sh and disable-wifi.sh")
        os.execute("./enable-wifi.sh")
        os.execute("./disable-wifi.sh")
        ok = isModuleLoaded(DRIVER)
    end
    UIManager:close(msg)
    if not ok then
        UIManager:show(InfoMessage:new{
            icon = "notice-warning",
            text = _("Hotspot: Wi-Fi has not been started since the Kobo restarted.\n\nTurn on Wi-Fi once from the Kobo home screen, then try again."),
        })
    end
    return ok
end

-- Kindle: takes wlan0 over from Amazon's wifid (kindshare's recipe).
function Hotspot:bringUpKindleInterface()
    logger.info("Hotspot: stopping wifid and wpa_supplicant")
    os.execute("stop wifid >/dev/null 2>&1")
    os.execute("killall wpa_supplicant >/dev/null 2>&1")
    ffiutil.sleep(2)
    if not util.pathExists("/sys/class/net/" .. BACKEND.iface) then
        logger.info("Hotspot: loading", BACKEND.module)
        os.execute("modprobe " .. BACKEND.module .. " >/dev/null 2>&1")
        if not self:waitForInterface() then
            return false
        end
    end
    setLink(BACKEND.iface, true)
    return true
end

-- Kindle: gives wlan0 back to wifid, which reconnects as usual.
function Hotspot:restoreKindleWifi()
    closeFirewall()
    flushAddress(BACKEND.iface)
    setLink(BACKEND.iface, false)
    logger.info("Hotspot: starting wifid")
    os.execute("start wifid >/dev/null 2>&1")
end

-- Makes the AP interface available.
-- Returns ok, and whether a failure was already reported to the user.
function Hotspot:bringUpInterface()
    if BACKEND.platform == "kindle" then
        return self:bringUpKindleInterface()
    end
    if not BACKEND.wmt then
        return self:ensureModuleLoaded()
    end
    if not self:ensureMediatekModulesLoaded() then
        return false, true
    end
    if util.pathExists("/sys/class/net/" .. BACKEND.iface) then
        return true
    end
    logger.info("Hotspot: switching the MediaTek chip to AP mode")
    if not writeWmt("A") then
        return false
    end
    return self:waitForInterface()
end

-- A failed start must not leave the chip in AP mode (MediaTek: KOReader would
-- then believe wifi is on), nor leave wifid stopped (Kindle).
function Hotspot:abortStart()
    if BACKEND.wmt then
        self:stopHostapd()
        writeWmt("0")
    elseif BACKEND.platform == "kindle" then
        self:stopHostapd()
        self:restoreKindleWifi()
    end
end

function Hotspot:startHostapd()
    local bin = self.path .. "/" .. (BACKEND.hostapd or "hostapd")
    if not util.pathExists(bin) then
        logger.warn("Hotspot: no hostapd binary found at", bin)
        return false
    end

    local f = io.open(HOSTAPD_CONF, "w")
    if not f then return false end

    local conf = string.format(
        "interface=%s\n"      ..
        "driver=nl80211\n"    ..
        "ssid=%s\n"           ..
        "hw_mode=g\n"         ..
        "channel=%s\n"        ..
        "ignore_broadcast_ssid=0\n",
        BACKEND.iface, self.ssid, self.channel)

    conf = conf .. (BACKEND.hostapd_extra or "")

    local wpa2 = self.security == "wpa2" or BACKEND.require_wpa2
    if wpa2 and self.password ~= "" then
        conf = conf .. string.format(
            "wpa=2\n"                    ..
            "wpa_passphrase=%s\n"        ..
            "wpa_key_mgmt=WPA-PSK\n"     ..
            "rsn_pairwise=CCMP\n",
            self.password)
    end

    f:write(conf)
    f:close()

    -- hostapd daemonizes itself; -B runs in background, -P writes the pid file.
    -- Errors printed before it daemonizes end up in HOSTAPD_LOG.
    local rc = os.execute(string.format(
        "%s -B -P %s %s >%s 2>&1", bin, HOSTAPD_PID, HOSTAPD_CONF, HOSTAPD_LOG))
    if rc ~= 0 then
        logger.warn("Hotspot: hostapd failed to start, see", HOSTAPD_LOG)
        return false
    end
    -- give it a moment to bring the interface up before we assign an IP
    ffiutil.sleep(1)
    return true
end

function Hotspot:stopHostapd()
    local f = io.open(HOSTAPD_PID, "r")
    if not f then return end
    local pid = f:read("*l")
    f:close()
    if pid then
        os.execute("kill " .. pid .. " 2>/dev/null")
    end
    os.remove(HOSTAPD_PID)
    os.remove(HOSTAPD_CONF)
end

function Hotspot:startDHCP()
    local bin = self.path .. "/udhcpd"
    -- Kindle: the firmware's BusyBox has udhcpd (kindshare uses it).
    if BACKEND.system_udhcpd and hasCommand("udhcpd") then
        bin = "udhcpd"
    elseif not util.pathExists(bin) then
        logger.info("Hotspot: no udhcpd binary found, skipping DHCP")
        return
    end
    local f = io.open(UDHCPD_CONF, "w")
    if not f then return end
    f:write(string.format(
        "start         192.168.42.10\n"  ..
        "end           192.168.42.100\n" ..
        "interface     %s\n"             ..
        "pidfile       %s\n"             ..
        "lease_file    %s\n"             ..
        "option subnet 255.255.255.0\n"  ..
        "option router 192.168.42.1\n"   ..
        "option dns    8.8.8.8\n"        ..
        "option lease  3600\n",
        BACKEND.iface, UDHCPD_PID, UDHCPD_LEASES))
    f:close()
    os.execute(string.format("%s %s", bin, UDHCPD_CONF))
    logger.info("Hotspot: udhcpd started")
end

function Hotspot:stopDHCP()
    local f = io.open(UDHCPD_PID, "r")
    if not f then return end
    local pid = f:read("*l")
    f:close()
    if pid then
        os.execute("kill " .. pid .. " 2>/dev/null")
    end
    os.remove(UDHCPD_PID)
    os.remove(UDHCPD_CONF)
end

-- `done` (optional) runs once the hotspot has started or failed to, e.g. to refresh the menu.
function Hotspot:start(done)
    if self:isRunning() then return end

    if not detectBackend() then
        local text
        if PLATFORM == "kindle" and not DRIVER then
            text = _("Hotspot: no Wi-Fi driver is loaded.\n\nTurn on Wi-Fi once, then try again.")
        else
            text = T(_("Hotspot: this device's Wi-Fi chip (%1) is not supported yet."), DRIVER or _("unknown"))
        end
        UIManager:show(InfoMessage:new{
            icon = "notice-warning",
            text = text,
        })
        return
    end

    if BACKEND.require_wpa2 and #self.password < 8 then
        UIManager:show(InfoMessage:new{
            icon = "notice-warning",
            text = _("Hotspot: this Wi-Fi chip only works with WPA2.\n\nSet a WPA2 password (at least 8 characters) in the hotspot menu first."),
        })
        return
    end

    -- MediaTek: the chip cannot be a wifi client and an access point at the same time.
    if BACKEND.wmt and NetworkMgr:isWifiOn() then
        UIManager:show(ConfirmBox:new{
            text = _("The hotspot cannot run while Wi-Fi is on.\n\nTurn off Wi-Fi and start the hotspot?"),
            ok_text = _("Turn off Wi-Fi and start hotspot"),
            ok_callback = function()
                NetworkMgr:toggleWifiOff(function()
                    UIManager:nextTick(function()
                        self:startHotspot()
                        if done then done() end
                    end)
                end, true)
            end,
        })
        return
    end

    -- Kindle: the access point takes over wlan0, so the normal connection drops.
    if BACKEND.platform == "kindle" and NetworkMgr:isWifiOn() then
        UIManager:show(ConfirmBox:new{
            text = _("While the hotspot runs, the Kindle's normal Wi-Fi is disconnected. It reconnects when you stop the hotspot.\n\nStart the hotspot?"),
            ok_text = _("Start hotspot"),
            ok_callback = function()
                self:startHotspot()
                if done then done() end
            end,
        })
        return
    end

    self:startHotspot()
    if done then done() end
end

function Hotspot:startHotspot()
    local ok, reported = self:bringUpInterface()
    if not ok then
        if BACKEND.platform == "kindle" then
            self:abortStart()
        end
        if reported then return end
        UIManager:show(InfoMessage:new{
            icon = "notice-warning",
            text = T(_("Hotspot: %1 interface not found."), BACKEND.iface),
        })
        return
    end

    logger.info("Hotspot: starting — SSID:", self.ssid, "channel:", self.channel)

    flushAddress(BACKEND.iface)
    if BACKEND.platform == "kindle" then
        openFirewall(BACKEND.iface)
    end

    if not self:startHostapd() then
        self:abortStart()
        UIManager:show(InfoMessage:new{
            icon = "notice-warning",
            text = T(_("Hotspot: failed to start hostapd. Is the binary installed in the plugin directory?\n\nDetails: %1"), HOSTAPD_LOG),
        })
        return
    end

    if setAddress(BACKEND.iface) then
        local f = io.open(SENTINEL, "w")
        if f then f:close() end
        self:startDHCP()
        if BACKEND.platform == "kindle" then
            preventKindleScreenSaver(true)
        end

        UIManager:show(InfoMessage:new{
            timeout = 6,
            text = T(_("Hotspot started.\n\nSSID: %1\nIP address: 192.168.42.1"), self.ssid),
        })
    else
        self:abortStart()
        UIManager:show(InfoMessage:new{
            icon = "notice-warning",
            text = _("Hotspot: one or more commands failed. Check the logs."),
        })
    end
end

-- `done` (optional) runs once the hotspot has stopped, e.g. to refresh the menu.
function Hotspot:stop(done)
    if not self:isRunning() then return end

    logger.info("Hotspot: stopping")
    self:stopDHCP()
    self:stopHostapd()

    if not detectBackend() then
        -- Should not happen: the hotspot was started with a backend.
        logger.warn("Hotspot: Wi-Fi backend not detected, only clearing state")
        os.remove(SENTINEL)
        if done then done() end
        return
    end

    if BACKEND.platform == "kindle" then
        self:restoreKindleWifi()
        preventKindleScreenSaver(false)
        os.remove(SENTINEL)
        if done then done() end
        UIManager:show(InfoMessage:new{
            text = _("Hotspot stopped. Wi-Fi is back under the Kindle's control."),
            timeout = 3,
        })
        return
    end

    flushAddress(BACKEND.iface)

    if not BACKEND.wmt then
        setLink(BACKEND.iface, false)
        os.remove(SENTINEL)
        if done then done() end
        UIManager:show(InfoMessage:new{
            text = _("Hotspot stopped."),
            timeout = 2,
        })
        return
    end

    -- MediaTek: leaving AP mode powers wifi off.
    writeWmt("0")
    os.remove(SENTINEL)
    if done then done() end
    UIManager:show(ConfirmBox:new{
        text = _("Hotspot stopped. Wi-Fi is off."),
        ok_text = _("Turn on Wi-Fi"),
        cancel_text = _("Keep Wi-Fi off"),
        ok_callback = function()
            NetworkMgr:toggleWifiOn(nil, false, true)
        end,
    })
end

function Hotspot:onToggleHotspot(done)
    if self:isRunning() then
        self:stop(done)
    else
        self:start(done)
    end
end

function Hotspot:showSsidDialog(touchmenu_instance)
    self.ssid_dialog = InputDialog:new{
        title = _("Hotspot SSID"),
        input = self.ssid,
        buttons = {{
            {
                text = _("Cancel"),
                id = "close",
                callback = function()
                    UIManager:close(self.ssid_dialog)
                end,
            },
            {
                text = _("Save"),
                is_enter_default = true,
                callback = function()
                    local v = self.ssid_dialog:getInputText()
                    if v and v ~= "" then
                        self.ssid = v
                        G_reader_settings:saveSetting("hotspot_ssid", v)
                        UIManager:close(self.ssid_dialog)
                        if touchmenu_instance then
                            touchmenu_instance:updateItems()
                        end
                    end
                end,
            },
        }},
    }
    UIManager:show(self.ssid_dialog)
    self.ssid_dialog:onShowKeyboard()
end

function Hotspot:showPasswordDialog(touchmenu_instance)
    self.pw_dialog = InputDialog:new{
        title = _("WPA2 password"),
        input = self.password,
        text_type = "password",
        buttons = {{
            {
                text = _("Cancel"),
                id = "close",
                callback = function()
                    UIManager:close(self.pw_dialog)
                end,
            },
            {
                text = _("Save"),
                is_enter_default = true,
                callback = function()
                    local v = self.pw_dialog:getInputText()
                    if v and #v >= 8 then
                        self.password = v
                        G_reader_settings:saveSetting("hotspot_password", v)
                        UIManager:close(self.pw_dialog)
                        if touchmenu_instance then
                            touchmenu_instance:updateItems()
                        end
                    else
                        UIManager:show(InfoMessage:new{
                            icon = "notice-warning",
                            text = _("WPA2 password must be at least 8 characters."),
                            timeout = 3,
                        })
                    end
                end,
            },
        }},
    }
    UIManager:show(self.pw_dialog)
    self.pw_dialog:onShowKeyboard()
end

local CHANNELS = {"1", "6", "11"}

function Hotspot:addToMainMenu(menu_items)
    local channel_items = {}
    for _i, ch in ipairs(CHANNELS) do
        table.insert(channel_items, {
            text = T(_("Channel %1"), ch),
            checked_func = function() return self.channel == ch end,
            callback = function()
                self.channel = ch
                G_reader_settings:saveSetting("hotspot_channel", ch)
            end,
        })
    end

    menu_items.hotspot = {
        text = _("Wi-Fi hotspot"),
        sorting_hint = "network",
        checked_func = function() return self:isRunning() end,
        sub_item_table = {
            {
                text = _("Enable hotspot"),
                checked_func = function() return self:isRunning() end,
                check_callback_updates_menu = true,
                callback = function(touchmenu_instance)
                    -- On MediaTek and Kindle, starting can wait for a confirmation
                    -- dialog, so refresh the menu when the toggle completes.
                    self:onToggleHotspot(function()
                        touchmenu_instance:updateItems()
                    end)
                end,
            },
            {
                text_func = function()
                    return T(_("SSID: %1"), self.ssid)
                end,
                keep_menu_open = true,
                enabled_func = function() return not self:isRunning() end,
                callback = function(touchmenu_instance)
                    self:showSsidDialog(touchmenu_instance)
                end,
            },
            {
                text_func = function()
                    return T(_("Channel: %1"), self.channel)
                end,
                enabled_func = function() return not self:isRunning() end,
                sub_item_table = channel_items,
            },
            {
                -- Some chips (Kindle AR6003) only work with WPA2.
                text = _("Open network (no password)"),
                checked_func = function() return self.security == "open" and not requiresWpa2() end,
                enabled_func = function() return not self:isRunning() and not requiresWpa2() end,
                callback = function()
                    self.security = "open"
                    G_reader_settings:saveSetting("hotspot_security", "open")
                end,
            },
            {
                text = _("WPA2 password protection"),
                checked_func = function() return self.security == "wpa2" or requiresWpa2() end,
                enabled_func = function() return not self:isRunning() end,
                callback = function()
                    self.security = "wpa2"
                    G_reader_settings:saveSetting("hotspot_security", "wpa2")
                end,
            },
            {
                text_func = function()
                    local masked = self.password ~= "" and string.rep("*", #self.password) or _("(not set)")
                    return T(_("WPA2 password: %1"), masked)
                end,
                keep_menu_open = true,
                enabled_func = function()
                    return (self.security == "wpa2" or requiresWpa2()) and not self:isRunning()
                end,
                callback = function(touchmenu_instance)
                    self:showPasswordDialog(touchmenu_instance)
                end,
            },
            {
                text = _("Start hotspot with KOReader"),
                checked_func = function() return self.autostart end,
                callback = function()
                    self.autostart = not self.autostart
                    G_reader_settings:flipNilOrFalse("hotspot_autostart")
                end,
            },
        },
    }
end

function Hotspot:onDispatcherRegisterActions()
    Dispatcher:registerAction("toggle_hotspot", {
        category = "none",
        event    = "ToggleHotspot",
        title    = _("Toggle Wi-Fi hotspot"),
        general  = true,
    })
end

return Hotspot
