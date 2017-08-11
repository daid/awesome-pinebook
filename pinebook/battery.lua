local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")
local naughty = require("naughty")
local dbusRemoteObject = require("pinebook.dbusRemoteObject")

local function formatTime(seconds)
    if seconds > 60 * 60 then
        return string.format("%d hours", seconds / 60 / 60)
    end
    if seconds > 60 then
        return string.format("%d minutes", seconds / 60)
    end
    return string.format("%d seconds", seconds)
end

local function batteryWidget()
    local battery_bar = wibox.widget{
        border_color = "#202020",
        background_color = "#202020",
        color = {type="linear", from = {20, 0}, to = {0, 0}, stops = { {0, "#AECF96"}, {0.5, "#88A175"}, {1.0, "#FF5656"} } },
        max_value = 100,
        widget=wibox.widget.progressbar
    }
    local battery_history = {}
    battery_bar:set_value(0)

    local upower = dbusRemoteObject.system('org.freedesktop.UPower', '/org/freedesktop/UPower', 'org.freedesktop.UPower')
    local upower_battery = dbusRemoteObject.system('org.freedesktop.UPower', '/org/freedesktop/UPower/devices/battery_battery', 'org.freedesktop.UPower.Device')
    upower.monitorProperty("LidIsClosed", function(value)
        if value == true then
            --When the lid closes, suspend the system.
            awful.spawn("systemctl suspend")
        end
    end)
    upower_battery.monitorProperty("State", function(value)
        if upower_battery.properties.Percentage ~= nil then
            table.insert(battery_history, {os.time(), upower_battery.properties.Percentage, value })
        end
    end)
    upower_battery.monitorProperty("Percentage", function(value)
        battery_bar:set_value(value)
        table.insert(battery_history, {os.time(), value, upower_battery.properties.State})
    end)

    local login1_manager = dbusRemoteObject.system('org.freedesktop.login1', '/org/freedesktop/login1', 'org.freedesktop.login1.Manager')
    login1_manager.connectToSignal("PrepareForSleep", function(parameters)
        local entering_sleep = parameters[1]
        table.insert(battery_history, {os.time(), -1, entering_sleep})
        if not entering_sleep and upower.properties.LidIsClosed then
            awful.spawn("systemctl suspend")
        end
    end)

    local tt = awful.tooltip({
        objects = { battery_bar },
        timer_function = function()
            result = string.format("%d%%", upower_battery.properties.Percentage)
            t0 = battery_history[1][1]
            for _, data in ipairs(battery_history) do
                t, v, s = unpack(data)
                result = result .. "\n" .. (t - t0) .. ":" .. tostring(s) .. ":" .. v
            end
            return result
        end
    })
--]]
    return wibox.widget{battery_bar, forced_width = 8, direction = 'east', layout = wibox.container.rotate}
end

return batteryWidget()
