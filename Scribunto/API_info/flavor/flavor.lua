-- https://wowpedia.fandom.com/wiki/Module:API_info/flavor/api
-- https://wowpedia.fandom.com/wiki/Module:API_info/flavor/event
local util = require("wowdoc")

local IsMainlinePTR = false

local flavor = {
	mainline = 0x1,
	vanilla = 0x2,
	mists = 0x4,
	mainline_beta = 0x8,
}

local m = {}

local sources = {
	api = {
		url = "https://raw.githubusercontent.com/Ketho/BlizzardInterfaceResources/%s/Resources/GlobalAPI.lua",
		cache = pathlib.join(PATHS.BLIZZRES, "GlobalAPI_%s.lua"),
		out = pathlib.join(PATHS.SCRIBUNTO, "API_info.flavor.api.lua"),
		location = function(tbl)
			return tbl[1]
		end,
		map = function(tbl)
			return util:ToMap(tbl)
		end,
		update = function(t)
			-- C_Timer is in framexml in vanilla
			t["C_Timer.NewTimer"] = 0xF
			t["C_Timer.NewTicker"] = 0xF
		end,
		addition = function(file)
			file:write([[
	-- lua
	["strsplit"] = 0xF,
	["strsplittable"] = 0xF,
]])
		end,
	},
	event = {
		url = "https://raw.githubusercontent.com/Ketho/BlizzardInterfaceResources/%s/Resources/Events.lua",
		cache = pathlib.join(PATHS.BLIZZRES, "Events_%s.lua"),
		out = pathlib.join(PATHS.SCRIBUNTO, "API_info.flavor.event.lua"),
		location = function(tbl)
			return tbl
		end,
		map = function(tbl)
			local t = {}
			for _, events in pairs(tbl) do
				for _, event in pairs(events) do
					t[event] = true
				end
			end
			return t
		end,
	},
}

-- https://github.com/Ketho/BlizzardInterfaceResources/branches
local branches = {
	"mainline",
	"vanilla",
	"mists",
	"mainline_beta",
}

function m:GetData(sourceType)
	local info = sources[sourceType]
	local parts = {}
	local data = {}
	for _, branch in pairs(branches) do
		local fileTbl = util:DownloadAndRun(
			info.url:format(branch),
			info.cache:format(branch)
		)
		local location = info.location(fileTbl)
		parts[branch] = info.map(location)
		for name in pairs(parts[branch]) do
			data[name] = true
		end
	end
	for k in pairs(data) do
		local mainline
		if IsMainlinePTR then
			mainline = parts.mainline_ptr[k] and flavor.mainline_ptr or 0
		else
			mainline = parts.mainline[k] and flavor.mainline or 0
		end
		local vanilla = parts.vanilla[k] and flavor.vanilla or 0
		local mists = parts.mists[k] and flavor.mists or 0
		local mainline_beta = parts.mainline_beta[k] and flavor.mainline_beta or 0
		data[k] = mainline | vanilla | mists | mainline_beta
	end
	return data
end

local function main()
	for source, info in pairs(sources) do
		local data = m:GetData(source)
		if info.update then
			info.update(data)
		end
		print("writing", info.out)
		local file = io.open(info.out, "w")
		file:write("-- https://github.com/Ketho/WowpediaDoc/blob/master/Scribunto/API_info/flavor/flavor.lua\n")
		file:write('local data = {\n')
		for _, name in pairs(util:SortTable(data)) do
			local flavors = data[name]
			file:write(string.format('\t["%s"] = 0x%X,\n', name, flavors))
		end
		if info.addition then
			info.addition(file)
		end
		file:write("}\n\nreturn data\n")
		file:close()
	end
end

-- hack
if IsMainlinePTR then
	flavor.mainline = nil
	flavor.mainline_ptr = 0x1
	branches[1] = "mainline_beta"
end

main()
