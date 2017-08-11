local naughty = require("naughty")
local awful = require("awful")
local volume_notification = nil

awesome.connect_signal("volume_changed", function()
    awful.spawn.easy_async("pacmd list-sinks", function(stdout, stderr, reason, exit_code)
        local volume = stdout:match("volume: .-%%")
        volume = volume:match("%d+%%")
        local muted = stdout:match("muted: (%a+)")
        if muted == "yes" then
            muted = " (muted)"
        else
            muted = ""
        end
        volume_notification = naughty.notify({
            text="Volume changed: "..volume.." "..muted,
            replaces_id=volume_notification
        }).id
    end)
end)

-- Set the speaker and headphone volume to 100%
-- We use pulse audio to manage the volume, which is "multiplied" with this volume.
awful.spawn("amixer -q set 'speaker volume' 100%")
awful.spawn("amixer -q set 'headphone volume' 100%")
