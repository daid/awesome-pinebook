local awful = require("awful")
local wibox = require("wibox")
local naughty = require("naughty")
local dbusRemoteObject = require("pinebook.dbusRemoteObject")
local gli = require("lgi")
local GLib = gli.GLib

local function updateWifiState(widget, new_state)
    if widget.wifi_state == new_state then return end
    widget.wifi_state = new_state
    naughty.notify{text="Wifi:"..new_state}

    if new_state == "disconnected" then
        widget.color = "#aa2020"
    elseif new_state == "connecting" then
        widget.color = "#aaaa20"
    elseif new_state == "connected" then
        widget.color = "#20aa20"
    end
end

local function addWifiDevice(widget, device_path)
    local device = dbusRemoteObject.system("org.freedesktop.NetworkManager", device_path, "org.freedesktop.NetworkManager.Device")
    device.monitorProperty("State", function(state)
        if state == 100 then
            updateWifiState(widget, "connected")
        elseif state == 50 or state == 70 or state == 80 or state == 90 then
            updateWifiState(widget, "connecting")
        else
            --naughty.notify{text="Wifi state:"..tostring(state)}
            updateWifiState(widget, "disconnected")
        end
    end)

    widget.wifi_networks = {}
    widget.wifi_networks_info = {}
    local wifi_device = dbusRemoteObject.system("org.freedesktop.NetworkManager", device_path, "org.freedesktop.NetworkManager.Device.Wireless")
    
    local function addAccessPoint(path)
        local obj = dbusRemoteObject.system("org.freedesktop.NetworkManager", path, "org.freedesktop.NetworkManager.AccessPoint")
        widget.wifi_networks[path] = obj
        widget.wifi_networks_info[path] = {}
        obj.getPropertyValue("Ssid", function(value)
            local name = ""
            for idx=1,#value do
                name = name..string.char(value[idx])
            end
            widget.wifi_networks_info[path].name = name
        end)
        obj.monitorProperty("Strength", function(strength)
            if wifi_device.properties.ActiveAccessPoint == path then
                widget:set_value(strength / 100)
            end
        end)
    end
    local function removeAccessPoint(path)
        widget.wifi_networks[path].disconnectAllSignals()
        widget.wifi_networks[path] = nil
        widget.wifi_networks_info[path] = nil
    end
    wifi_device.getPropertyValue("AccessPoints", function(list)
        for idx=1,#list do
            addAccessPoint(list[idx])
        end
        wifi_device.connectToSignal("AccessPointAdded", function(path) addAccessPoint(path[1]) end)
        wifi_device.connectToSignal("AccessPointRemoved", function(path) removeAccessPoint(path[1]) end)
    end)
    wifi_device.monitorProperty("ActiveAccessPoint")
end

local function createNetworkWidget()
    local widget = wibox.widget{
        forced_width = 8,
        value = 1.0,
        color = "#202020",
        background_color = "#202020",
        widget = wibox.widget.progressbar
    }
    
    local nm = dbusRemoteObject.system("org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager")
    nm.GetAllDevices(nil, function(result)
        for idx=1,#result[1] do
            local device_path = result[1][idx]
            dbusRemoteObject.system("org.freedesktop.NetworkManager", device_path, "org.freedesktop.NetworkManager.Device").getPropertyValue("DeviceType", function(result)
                if result.value == 2 then
                    addWifiDevice(widget, device_path)
                end
            end)
        end
    end)
    return wibox.widget{widget, forced_width = 8, direction = 'east', layout = wibox.container.rotate}
end

return createNetworkWidget
