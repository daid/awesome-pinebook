local awful = require("awful")
local wibox = require("wibox")
local naughty = require("naughty")

local wlan_state = ""

--Abuse the progressbar to get a filled area
local widget = wibox.widget{
    forced_width = 8,
    value = 1.0,
    color = "#202020",
    widget = wibox.widget.progressbar
}

local function updateWirelessWidget()
    if wlan_state == "disconnected" then
        widget.color = "#aa2020"
    elseif wlan_state == "connecting" then
        widget.color = "#aaaa20"
    elseif wlan_state == "connected" then
        widget.color = "#20aa20"
    end
end

local function updateWirelessState()
    awful.spawn.easy_async("nmcli -t -f device,state,connection device", function(stdout, stderr, exitreason, exitcode)
        for line in string.gmatch(stdout, "[^\n]+") do
            local device, state, connection = string.match(line, "([^:]*):([^:]*):([^:]*)")
            if device == "wlan0" then
                wlan_state = state
                wlan_connection = connection
            end
        end
        updateWirelessWidget()
    end)
end

local monitor_pid = awful.spawn.with_line_callback("nmcli monitor", {
    stdout = function(line)
        if string.sub(line, 1, 7) == "wlan0: " then
            if string.find(line, "disconnected") then
                naughty.notify{text="Wireless disconnected"}
            elseif string.find(line, "connecting") then
                naughty.notify{text="Wireless connecting"}
            elseif string.find(line, "connected") then
                naughty.notify{text="Wireless connected"}
            end
            updateWirelessState()
        end
    end,
})
awesome.connect_signal("exit", function()
    awful.spawn("kill " .. monitor_pid)
end)

local tt = awful.tooltip({
    objects = { widget },
    timer_function = function()
        return wlan_state..":"..wlan_connection
    end
})

updateWirelessState()

return widget
