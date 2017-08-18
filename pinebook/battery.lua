local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")
local naughty = require("naughty")
local dbusRemoteObject = require("pinebook.dbusRemoteObject")

local function formatTime(seconds)
    if seconds > 60 * 60 then
        return string.format("%.1f hours", seconds / 60 / 60)
    end
    if seconds > 60 then
        return string.format("%d minutes", seconds / 60)
    end
    return string.format("%d seconds", seconds)
end

local function getAverageBatteryChangeTime(battery_history)
    --Calculate the average time the battery needs to go up or down 1%
    --For this, we look at the history, which can contain 3 type of events:
    --Suspend/Resume events
    --Charge events (when the battery percentage changes)
    --Charging state changes
    
    --For charging/discharging time, we look at all the charge events between when the state isn't changing
    --  And there is no suspend/resume event in between.
    
    local charging = nil
    local previous_charge = nil
    local previous_charge_time = nil
    local charge_delta_count = 0
    local charge_delta_accumulator = 0
    local discharge_delta_count = 0
    local discharge_delta_accumulator = 0
    for index, data in ipairs(battery_history) do
        local event_time = data[1]
        local event = data[2]
        if event == "suspend" then
            previous_charge = nil
        end
        if event == "resume" then
            previous_charge = nil
        end
        if event == "charging" then
            charging = data[3]
        end
        if event == "charge" and index > 2 then
            if previous_charge ~= nil and charging ~= nil then
                local delta_time = event_time - previous_charge_time
                local delta_charge = data[3] - previous_charge
                delta_time = delta_time / math.abs(delta_charge)
                
                if charging then
                    charge_delta_count = charge_delta_count + 1
                    charge_delta_accumulator = charge_delta_accumulator + delta_time
                else
                    discharge_delta_count = discharge_delta_count + 1
                    discharge_delta_accumulator = discharge_delta_accumulator + delta_time
                end
            end
            previous_charge = data[3]
            previous_charge_time = event_time
        end
    end
    return charge_delta_accumulator / charge_delta_count, discharge_delta_accumulator / discharge_delta_count
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
        if value == 1 then
            table.insert(battery_history, {os.time(), "charging", true })
        else
            table.insert(battery_history, {os.time(), "charging", false })
        end
    end)
    upower_battery.monitorProperty("Percentage", function(value)
        battery_bar:set_value(value)
        if value < 10 then
            naughty.notify{text="Low battery: "..value.."%", timeout=30, preset=naughty.config.presets.critical}
        end
        if #battery_history > 1000 then
            table.remove(battery_history, 1)
        end
        table.insert(battery_history, {os.time(), "charge", value})
    end)

    local login1_manager = dbusRemoteObject.system('org.freedesktop.login1', '/org/freedesktop/login1', 'org.freedesktop.login1.Manager')
    login1_manager.connectToSignal("PrepareForSleep", function(parameters)
        local entering_sleep = parameters[1]
        if entering_sleep then
            table.insert(battery_history, {os.time(), "suspend"})
        else
            table.insert(battery_history, {os.time(), "resume"})
        end
        if not entering_sleep and upower.properties.LidIsClosed then
            awful.spawn("systemctl suspend")
        end
    end)

    local tt = awful.tooltip({
        objects = { battery_bar },
        timer_function = function()
            local charge = upower_battery.properties.Percentage
            result = string.format("%d%%", charge)
            local charge_time, discharge_time = getAverageBatteryChangeTime(battery_history)
            result = result .. "\n" .. formatTime(charge * discharge_time) .. " battery time remaining"
            result = result .. "\n" .. formatTime((100 - charge) * charge_time) .. " till full charge"
            --[[
            t0 = battery_history[1][1]
            for _, data in ipairs(battery_history) do
                t, v, s = unpack(data)
                result = result .. "\n" .. (t - t0) .. ":" .. tostring(s) .. ":" .. v
                t0 = t
            end
            --]]
            return result
        end
    })
    
    battery_bar:connect_signal("button::press", function()
        local f = io.open("/tmp/battery.debug.txt", "w")
        local t0 = battery_history[1][1]
        for _, data in ipairs(battery_history) do
            f:write(string.format("%d;%s;%s\n", data[1] - t0, data[2], tostring(data[3])))
        end
        f:close()
    end)

    return wibox.widget{battery_bar, forced_width = 8, direction = 'east', layout = wibox.container.rotate}
end

return batteryWidget
