local awful = require("awful")

--[[
    Bind the extra keys that the pinebook provides but awesomewm ignores.
    On the top row, with the [fn] key we have:
        XF86Sleep
        XF86HomePage
        (touchpad enable/disable, does not arrive at awesomewm)
        XF86AudioLowerVolume
        XF86AudioRaiseVolume
        XF86AudioMute
        XF86AudioPlay
        XF86AudioPrev
        XF86AudioNext

    Top right power button:
        XF86PowerOff
--]]

local function runAndSignal(cmd, signal)
    awful.spawn.easy_async(cmd, function(stdout, stderr, reason, exit_code)
        awesome.emit_signal(signal)
    end)
end

local function changeBacklight(amount)
    local f = io.open("/sys/class/backlight/lcd0/brightness", "r")
    local new_value = f:read("*all") + amount
    f:close()
    if new_value < 1 then new_value = 1 end
    if new_value > 255 then new_value = 255 end
    
    f = io.open("/sys/class/backlight/lcd0/brightness", "w")
    f:write(string.format("%d", new_value))
    f:close()
end

return awful.util.table.join(
    awful.key({}, "XF86AudioLowerVolume", function() runAndSignal("pactl set-sink-volume 0 -5%", "volume_changed") end),
    awful.key({}, "XF86AudioRaiseVolume", function() runAndSignal("pactl set-sink-volume 0 +5%", "volume_changed") end),
    awful.key({}, "XF86AudioMute", function() runAndSignal("pactl set-sink-mute 0 toggle", "volume_changed") end),    

    --Adjust brighness with up and down keys
    awful.key({ modkey }, "Down", function() changeBacklight(-8) end,
              {description = "reduce display brighness", group="power"}),
    awful.key({ modkey }, "Up", function() changeBacklight(8) end,
              {description = "increase display brighness", group="power"}),
    awful.key({ modkey, "Shift" }, "Down", function() changeBacklight(-32) end,
              {description = "reduce display brighness", group="power"}),
    awful.key({ modkey, "Shift" }, "Up", function() changeBacklight(32) end,
              {description = "increase display brighness", group="power"}),

    awful.key({}, "XF86Sleep", function() awful.spawn("systemctl suspend") end,
              {description = "suspend to lower power", group="power"}),
    awful.key({}, "XF86PowerOff", function() awful.spawn("systemctl suspend") end,
              {description = "suspend to lower power", group="power"}),
    awful.key({ modkey }, "XF86PowerOff", function() awful.spawn("systemctl poweroff") end,
              {description = "shut down", group="power"})
)
