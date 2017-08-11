local gli = require("lgi")
local Gio = gli.Gio
local GLib = gli.GLib

local dbus = {}
local dbusBus = {}
local dbusObjectProxy = {}
local dbusCallProxy = {}
function dbusBusFactory(bus_name)
    bus = nil
    if bus_name == "system" then
        bus = Gio.bus_get_sync(Gio.BusType.SYSTEM)
    end
    if bus_name == "session" then
        bus = Gio.bus_get_sync(Gio.BusType.SESSION)
    end
    if bus == nil then
        error("Unknown bus type: " .. bus_name)
    end
    return setmetatable({_bus = bus}, dbusBus)
end
function dbusBus.__call(self, name, path, interface)
    --Construct a dbus object proxy.
    return setmetatable({
        _bus = self._bus,
        _name = name,
        _path = path,
        _interface = interface,
        _property_change_callbacks = {},
        _property_values = {}
    }, dbusObjectProxy)
end
function dbusObjectProxy.__index(self, key)
    if key == "monitorProperty" then
        return function(property_name, callback)
            local bus = rawget(self, "_bus")
            local name = rawget(self, "_name")
            local path = rawget(self, "_path")
            local interface = rawget(self, "_interface")
            local property_values = rawget(self, "_property_values")
            bus:call(
                name, path, 'org.freedesktop.DBus.Properties', 'Get',
                GLib.Variant("(ss)", {interface, property_name}), nil, Gio.DBusConnectionFlags.NONE, -1, nil,
                function(bus, res)
                    res, err = bus:call_finish(res)
                    if err then
                        error(err)
                    end
                    property_values[property_name] = res[1].value
                    local property_change_callbacks = rawget(self, "_property_change_callbacks")
                    if property_change_callbacks[property_name] == nil then
                        property_change_callbacks[property_name] = {}
                    end
                    
                    if callback ~= nil then
                        callback(property_values[property_name])
                        table.insert(property_change_callbacks[property_name], callback)
                    end
                    
                    if rawget(self, "_property_monitor") == nil then
                        rawset(self, "_property_monitor", bus:signal_subscribe(
                            name, "org.freedesktop.DBus.Properties", "PropertiesChanged", path,
                            nil, Gio.DBusSignalFlags.NONE, 
                            function(connection, sender_name, object_path, interface_name, signal_name, parameters)
                                if parameters[1] == interface then
                                    for property_name, callbacks in pairs(property_change_callbacks) do
                                        if parameters[2][property_name] ~= nil then
                                            local value = parameters[2][property_name]
                                            property_values[property_name] = value
                                            for _, callback in ipairs(callbacks) do
                                                callback(value)
                                            end
                                        end
                                    end
                                end
                            end))
                    end
                end)
        end
    end
    if key == "properties" then
        return rawget(self, "_property_values")
    end
    if key == "connectToSignal" then
        return function(signal_name, callback)
            local bus = rawget(self, "_bus")
            local name = rawget(self, "_name")
            local path = rawget(self, "_path")
            local interface = rawget(self, "_interface")
            bus:signal_subscribe(name, interface, signal_name, path, nil, Gio.DBusSignalFlags.NONE,
                function(connection, sender_name, object_path, interface_name, signal_name, parameters)
                    callback(parameters)
                end)
        end
    end
    return setmetatable({
        _bus = rawget(self, "_bus"),
        _object = self,
        _method = key
    }, dbusCallProxy)
end
function dbusCallProxy.__call(self, args, callback)
    local bus = rawget(self, "_bus")
    local object = rawget(self, "_object")
    local name = rawget(object, "_name")
    local path = rawget(object, "_path")
    local interface = rawget(object, "_interface")
    local method = rawget(self, "_method")
    
    bus:call(
        name, path, interface, method,
        args, nil, Gio.DBusConnectionFlags.NONE, -1, nil,
        function(bus, res)
            res, err = bus:call_finish(res)
            if err ~= nil then
                error(err)
            else
                callback(res)
            end
        end)
end

dbus._bus_cache = {}
function dbus.__index(self, key)
    local cache = rawget(self, "_bus_cache")
    if cache[key] == nil then
        cache[key] = dbusBusFactory(key)
    end
    return rawget(self, "_bus_cache")[key]
end

return setmetatable(dbus, dbus)
