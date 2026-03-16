module("luci.controller.modemserver", package.seeall)
local http = require "luci.http"
local io = require "io"
local fs = require "nixio.fs"
local sys = require "luci.sys"
local nixio = require "nixio"
local util = require "luci.util"

local json = require("luci.jsonc")
uci = luci.model.uci.cursor()

-- Configuration parameters - modify according to actual situation


-- function index()
-- 	entry({"admin", "modemserver"}, firstchild(), luci.i18n.translate("Cellular Module"), 25).dependent=false
-- 	entry({"admin", "modemserver", "modemapp"}, template("modemserver/5Gmodem"), luci.i18n.translate("Cellular Network"),1).leaf = true
--     --Module info
-- 	-- entry({"admin", "modemserver", "5Gmodeminfo"}, template("modemserver/5Gmodeminfo"), luci.i18n.translate("Compact Cellular"),2).leaf = true
--     -- entry({"admin", "modemserver", "qmodem", "get_modem_cfg"}, call("getModemCFG"), nil).leaf = true
-- 	-- entry({"admin", "modemserver", "qmodem", "modem_ctrl"}, call("modemCtrl")).leaf = true
-- end

function index()
    -- Main menu points directly to template, no submenu created
    entry({"admin", "modemserver"}, template("modemserver/5Gmodem"), luci.i18n.translate("Cellular Module"), 25).dependent = false
end

--[[
@Description Execute shell script
@Params
	command shell command
]]
function shell(command)
	local odpall = io.popen(command)
	local odp = odpall:read("*a")
	odpall:close()
	return odp
end

-- Function to split USB info string
local function split_usb_info(str)
    local result = {}
    -- Use string.gmatch to match all |-separated parts
    for part in string.gmatch(str, "([^|]+)") do
        table.insert(result, part)
    end
    return result
end

-- Translate entries in modem_info
function translate_modem_info(result)
	modem_info = result["modem_info"]
	response = {}
	for k,entry in pairs(modem_info) do
		if type(entry) == "table" then
			key = entry["key"]
			full_name = entry["full_name"]
			if full_name then
				full_name = luci.i18n.translate(full_name)
			elseif key then
				full_name = luci.i18n.translate(key)
			end
			entry["full_name"] = full_name
			if entry["class"] then
				entry["class"] = luci.i18n.translate(entry["class"])
			end
			table.insert(response, entry)
		end
	end
	return response
end

function getModemCFG()
	local cfgs={}
	-- local translation={}
    local translation = unix_send_get(
        "modem_001",  -- modemid
        "/core?output=json",    -- path
        {             -- params
            type = "signal",
            format = "json"
        }
    )
    -- Decode JSON string
    local modems = json.parse(translation)
    if modems then
        -- Iterate array with ipairs (sequential access)
        local modemsdata = modems.data
        for index, modem in ipairs(modemsdata) do
            local config = {}
            config["cfg"] = modem.DEVID or "Unknown"
            config["name"] = modem.product or "Unknown"
            config["at_port"] = modem.HistorySerialPort or "/dev/ttyUSB2"
            config["manufacturer"] = modem.oem_manufacturer or "Unknown"
            config["platform"] = modem.platform or "Unknown"
            table.insert(cfgs, config)
        end
    end

	-- Set values
	local data={}
	data["cfgs"]=cfgs
	data["translation"]= {}
	-- Write to web interface
	luci.http.prepare_content("application/json")
	luci.http.write_json(data)
end

function modemCtrl()
	local action = http.formvalue("action")
	local cfg_id = http.formvalue("cfg")
	local params = http.formvalue("params")
	local translate = http.formvalue("translate")
	-- if params then
	-- 	result = shell(modem_ctrl..action.." "..cfg_id.." ".."\""..params.."\"")
	-- else 
	-- 	result = shell(modem_ctrl..action.." "..cfg_id)
	-- end

    -- Split string
    local parts = split_usb_info(cfg_id)
    -- Get each value individually
    local usb_id = parts[1]       -- "usb:v2C7Cp0801d0504dc00dsc00dp00icFFiscFFipFFin04"
    local device_path = parts[2]  -- "/dev/ttyUSB3"
    local manufacturer = parts[3] -- "quectel"
    local chip_vendor = parts[4]  -- "qualcomm"

    result = shell(modem_ctrl..action.." "..device_path.." ".." "..manufacturer.." ".." "..chip_vendor.." ")

	if translate == "1" then
		modem_more_info = json.parse(result)
		modem_more_info = translate_modem_info(modem_more_info)
		result = json.stringify(modem_more_info)
	end
	luci.http.prepare_content("application/json")
	luci.http.write(result)
end