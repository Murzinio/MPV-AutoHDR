local mp = require 'mp'
local ffi = require 'ffi'
local msg = require 'mp.msg'

-- User settings can be adjusted here
local scripts_path = "C:/Program Files/mpv/portable_config/scripts/"
local periodic_check_interval = 1
local log_enabled = true
local log_path = scripts_path .. "hdr_detection.log"

local hdr_settings_on = 
{
    ["target-colorspace-hint"] = "yes",
    ["inverse-tone-mapping"] = "yes",
    ["target-peak"] = "400",
    ["target-trc"] = "pq",
    ["tone-mapping"] = "bt.2446-a"
}

local hdr_settings_off = 
{
    ["target-colorspace-hint"] = "no",
    ["inverse-tone-mapping"] = "no",
    ["target-peak"] = "auto",
    ["target-trc"] = "auto",
    ["tone-mapping"] = "auto"
}

local current_hdr_state = nil

local function write_log(message)
    if not log_enabled then return end
    
    local success, file = pcall(io.open, log_path, "a+")
    if not success then
        msg.error("Failed to open log file: " .. tostring(file))
        return
    end
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_entry = string.format("[%s] %s\n", timestamp, message)
    
    file:write(log_entry)
    file:close()
end

-- Initialize log file
local function init_log()
    if not log_enabled then return end
    
    local success, file = pcall(io.open, log_path, "w")
    if not success then
        msg.error("Failed to create log file: " .. tostring(file))
        log_enabled = false
        return
    end
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    file:write(string.format("[%s] HDR Detection Script Started\n", timestamp))
    file:write(string.format("[%s] MPV Version: %s\n", timestamp, mp.get_property("mpv-version")))
    file:close()
    
    msg.info("Log file initialized at: " .. log_path)
end

-- Define the FFI interface to our DLL
ffi.cdef[[
    bool IsHDREnabled();
]]

-- Load the DLL
local hdr_dll_path = scripts_path .. "/HDRCheck.dll"
local hdr_lib = nil

local function load_hdr_dll()
    local success, lib = pcall(ffi.load, hdr_dll_path)
    if not success then
        msg.error("Failed to load HDR detection DLL: " .. tostring(lib))
        write_log("Error loading DLL: " .. tostring(lib))
        return nil
    end
    write_log("Successfully loaded HDR detection DLL")
    return lib
end

-- Function to check if HDR is enabled using the DLL
local function is_hdr_enabled()
    if not hdr_lib then
        hdr_lib = load_hdr_dll()
        if not hdr_lib then
            return false
        end
    end
    
    local success, result = pcall(function()
        return hdr_lib.IsHDREnabled()
    end)
    
    if success then
        write_log("HDR detection check result: " .. tostring(result))
        return result
    else
        msg.error("Failed to call HDR detection function: " .. tostring(result))
        write_log("Error calling HDR detection function: " .. tostring(result))
        return false
    end
end

-- Function to print current HDR-related settings
local function print_hdr_settings()
    write_log("Current HDR settings:")
    for prop, _ in pairs(hdr_settings_on) do
        local value = mp.get_property(prop)
        msg.info(prop .. " = " .. (value or "nil"))
        write_log("  " .. prop .. " = " .. (value or "nil"))
    end
end

-- Function to apply HDR settings
local function apply_hdr_settings()
    local hdr_enabled = is_hdr_enabled()
    
    -- Only apply changes if the HDR state has changed
    if current_hdr_state ~= hdr_enabled then
        current_hdr_state = hdr_enabled
        
        if hdr_enabled then
            msg.info("HDR detected, applying HDR settings")
            write_log("HDR detected, applying HDR settings")
            for prop, value in pairs(hdr_settings_on) do
                local prev_value = mp.get_property(prop)
                mp.set_property(prop, value)
                write_log("  Changed " .. prop .. ": " .. tostring(prev_value) .. " -> " .. value)
            end
        else
            msg.info("HDR not detected, using default settings")
            write_log("HDR not detected, using default settings")
            for prop, value in pairs(hdr_settings_off) do
                local prev_value = mp.get_property(prop)
                mp.set_property(prop, value)
                write_log("  Changed " .. prop .. ": " .. tostring(prev_value) .. " -> " .. value)
            end
        end
        
        -- Log current settings after change
        print_hdr_settings()
    end
end

init_log()

-- Apply settings at startup and when playing a new file
mp.register_event("file-loaded", function()
    write_log("New file loaded: " .. (mp.get_property("filename") or "unknown"))
    apply_hdr_settings()
end)

-- Check periodically in case HDR state changes while watching
local timer = mp.add_periodic_timer(periodic_check_interval, function()
    write_log("Periodic HDR check")
    apply_hdr_settings()
end)

-- Add key binding to manually check HDR status
mp.add_key_binding("Ctrl+h", "manual_hdr_check", function()
    write_log("Manual HDR check triggered")
    apply_hdr_settings()
    
    local status = current_hdr_state and "ENABLED" or "DISABLED"
    mp.osd_message("HDR is " .. status)
end)

write_log("Script initialization complete")