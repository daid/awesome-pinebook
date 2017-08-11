local awful = require("awful")

return awful.util.table.join(
    awful.key({ modkey }, "b", function() awful.spawn("chromium-browser") end,
              {description = "Start browser", group="launcher"})

)
