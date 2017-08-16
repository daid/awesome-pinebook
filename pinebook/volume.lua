local wibox = require("wibox")
local naughty = require("naughty")
local awful = require("awful")
local volume_notification = nil

-- Set the speaker and headphone volume to 100% in the alsa mixer.
-- We use pulse audio to manage the volume, which is "multiplied" with this volume.
awful.spawn("amixer -q set 'speaker volume' 100%")
awful.spawn("amixer -q set 'headphone volume' 100%")

local function volumeWidgetConstructor()
    local volume_bar = wibox.widget{
        border_color = "#202020",
        background_color = "#202020",
        color = "#4040aa",
        max_value = 100,
        widget=wibox.widget.progressbar
    }

    local function updateVolume(add_notification)
        awful.spawn.easy_async("pacmd list-sinks", function(stdout, stderr, reason, exit_code)
            local volume = stdout:match("volume: .-%%")
            volume = tonumber(volume:match("(%d+)%%"))
            local muted = stdout:match("muted: (%a+)")
            if muted == "yes" then
                muted = "(muted)"
            else
                muted = ""
            end
            
            if add_notification then
                volume_notification = naughty.notify({
                    text=string.format("Volume changed: %d%% %s", volume, muted),
                    replaces_id=volume_notification
                }).id
            end

            if muted == "" then
                volume_bar:set_value(volume)
            else
                volume_bar:set_value(0)
            end
        end)
    end

    awesome.connect_signal("volume_changed", function() updateVolume(true) end)
    updateVolume()

    return wibox.widget{volume_bar, forced_width = 8, direction = 'east', layout = wibox.container.rotate}
end

return volumeWidgetConstructor
