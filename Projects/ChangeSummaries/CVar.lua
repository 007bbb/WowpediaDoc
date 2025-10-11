-- similar codebase as https://wowpedia.fandom.com/wiki/Module:API_info/cvar
local util = require("wowdoc")
local pathlib = require("path")
local m = {}
local data = {}

local ConsoleCategory = {
	[0] = "Debug",
	[1] = "Graphics",
	[2] = "Console",
	[3] = "Combat",
	[4] = "Game",
	[5] = "Default",
	[6] = "Net",
	[7] = "Sound",
	[8] = "Gm",
	[9] = "Reveal",
	[10] = "None",
}

local function GetData(flavor)
	local tbl = util:DownloadAndRun(
		string.format("https://raw.githubusercontent.com/Ketho/BlizzardInterfaceResources/%s/Resources/CVars.lua", flavor),
		string.format(pathlib.join(CACHE_LUA, "CVars_%s.lua"), flavor)
	)
	return tbl[1]
end

local function GetCVarInfo(name)
	local cvar = data[2].var[name] or data[1].var[name]
	if cvar then
		local t = {"apitooltip"}
		table.insert(t, "type=cvar")
		table.insert(t, "name="..name)
		-- cannot use unpack()
		local default, category, account, character, secure, help = cvar[1], cvar[2], cvar[3], cvar[4], cvar[5], cvar[6]
		if #default > 0 then
			table.insert(t, "default="..default)
		end
		if account or character then
			table.insert(t, "scope="..(account and "Account" or character and "Character"))
		end
		if category ~= 5 then -- Default
			table.insert(t, "cat="..category)
		end
		if #help > 0 then
			table.insert(t, "desc="..help)
		end
		return string.format("{{%s}}", table.concat(t, "|"))
	end
	local command = data[2].command[name] or data[1].command[name]
	if command then
		local t = {"apitooltip"}
		table.insert(t, "type=command")
		table.insert(t, "name="..name)
		local category,  help = command[1], command[2]
		if category ~= 5 then -- Default
			table.insert(t, "cat="..category)
		end
		if #help > 0 then
			table.insert(t, "desc="..help)
		end
		return string.format("''{{%s}}''", table.concat(t, "|"))
	end
end

-- check if it's not some minor CVar attribute change
function m:SanitizeCVars(ApiTypes)
	local added = util:ToMap(ApiTypes.CVars.changes["+"])
	local removed = util:ToMap(ApiTypes.CVars.changes["-"])
	for k in pairs(added) do
		if removed[k] then
			added[k] = nil
			removed[k] = nil
		end
	end
	-- cba safely removing while iterating
	util:Wipe(ApiTypes.CVars.changes["+"])
	util:Wipe(ApiTypes.CVars.changes["-"])
	for k in pairs(added) do
		table.insert(ApiTypes.CVars.changes["+"], k)
	end
	for k in pairs(removed) do
		table.insert(ApiTypes.CVars.changes["-"], k)
	end
end

function m.main(name, patch1, patch2)
	data[1] = GetData(patch1)
	data[2] = GetData(patch2)
	return GetCVarInfo(name)
end

return m
