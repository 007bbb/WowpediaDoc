-- when we dont need the Blizzard_APIDocumentation addon
local lfs = require("lfs")
local pathlib = require("path")
local util = require("wowdoc")
local get_framexml = require("wowdoc.loader.get_framexml_path")

local m = {}
local docTables = {}

local parent = {
	["."] = true,
	[".."] = true,
}

APIDocumentation = {}

---@diagnostic disable-next-line: duplicate-set-field
function APIDocumentation:AddDocumentationTable(info)
	table.insert(docTables, info)
end

-- only checks for :AddDocumentationTable files
---@param version string e.g. `12.0.0 (63728)`
function m:LoadBlizzardDocs(version)
	util:Wipe(docTables)
	local docgen_path = get_framexml:GetFramexmlPath(version)
	for fileName in lfs.dir(docgen_path) do
		if not parent[fileName] and not fileName:find("%.toc") then
			local subfolder = pathlib.join(docgen_path, fileName)
			local file = loadfile(subfolder)
			if not file then
				error(string.format("could not load file: %s", subfolder))
			else
				file()
			end
		end
	end
	return util:CopyTable(docTables)
end

return m
