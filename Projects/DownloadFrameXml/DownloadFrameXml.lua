--[[
sudo apt update
sudo apt install gh
gh auth login
- set and read the token in `GITHUB_TOKEN`
	- or just assign a variable with the token in `gho_*` format

remember to
- delete `(int)MAX_SUMMONABLE_HUNTER_PETS` from uhh some patch
- delete 9.2.7 apidocs as those dont contain anything
]]

local pathlib = require("path")
local https = require("ssl.https")
local cjson = require("cjson")
local ltn12 = require("ltn12")

local util = require("wowdoc")
local log = require("wowdoc.log")
local products = require("wowdoc.products")
local tags = require("wowdoc.git.framexml_tags")

-- os.getenv("GITHUB_TOKEN") did not return the token on WSL even if the env var was set
local GITHUB_TOKEN = util:run_command("gh auth token")

---@type GetheBranch[]
local branches = {
	"live",
	"classic",
	"classic_era",
}

local m = {}

local function SendHttpsRequest(url)
	local headers = {
		["Authorization"] = "Bearer "..GITHUB_TOKEN,
		["User-Agent"] = "WowpediaDoc"
	}
	local body = {}
	local _, code = https.request{
		url = url,
		headers = headers,
		sink = ltn12.sink.table(body)
	}
	-- idk why sometimes I get HTTP 400 and 403, nothing wrong with the user agent
	if code ~= 200 then
		error("HTTP "..code)
	end
	local res = table.concat(body)
	local data = cjson.decode(res)
	return data
end

function m:DownloadZip(name)
	local url, version
	if products.gethe_branch[name] then
		url, version = self:GetGithubBranch(name)
	elseif name:find("%d+%.%d+%.%d+") then
		url, version = self:GetGithubTag(name)
	else
		error("No known branch or valid tag found")
	end
	local patch, build = self:GetPatchBuild(name, version)
	local fileBaseName = string.format("%s (%s)", patch, build)
	local fileExtName = fileBaseName..".zip"

	local zipFolder = pathlib.join("FrameXML", "zips")
	local zipFile = pathlib.join(zipFolder, fileExtName)
	util:DownloadFile(url, zipFile)
	return fileBaseName, zipFile
end

function m:GetGithubBranch(v)
	local URL_BRANCH = "https://github.com/Gethe/wow-ui-source/archive/refs/heads/%s.zip"
	-- version.txt is included since 11.0.7
	local URL_BRANCH_VERSION = "https://raw.githubusercontent.com/Gethe/wow-ui-source/refs/heads/%s/version.txt"
	local version = https.request(URL_BRANCH_VERSION:format(v))
	return URL_BRANCH:format(v), version
end

function m:GetGithubTag(v)
	local URL_TAG = "https://github.com/Gethe/wow-ui-source/archive/refs/tags/%s.zip"
	local version = self:GetCommitVersion(v)
	return URL_TAG:format(v), version
end

function m:GetCommitVersion(tag)
	local tag_url = string.format("https://api.github.com/repos/Gethe/wow-ui-source/git/refs/tags/%s", tag)
	local data1 = SendHttpsRequest(tag_url)

	local commits_url = string.format("https://api.github.com/repos/Gethe/wow-ui-source/git/commits/%s", data1.object.sha)
	local data2 = SendHttpsRequest(commits_url)

	local version = data2.message
	return version
end

function m:GetPatchBuild(name, msg)
	-- up to 5.2.0 is in "Build %d" format
	if msg:find("Build") then -- Build 16650
		local build = msg:match("Build (%d+)")
		return name, build
	end
	local patterns = {
		"(%d+%.%d+%.%d+)%.(%d+)",    -- 11.1.7.61967
		"(%d+%.%d+%.%d+) %((%d+)%)", -- 11.1.7 (61967)
	}
	for _, v in pairs(patterns) do
		local patch, build = msg:match(v)
		if patch then
			return patch, build
		end
	end
end

function m:UnpackZip(branch, fileBaseName, zipFile)
	local gameTypeFolder = pathlib.join("FrameXML", branch)
	local unpackFolder = pathlib.join(gameTypeFolder, fileBaseName)
	if not pathlib.exists(unpackFolder) then
		local command = string.format('unzip "%s" -d "%s"', zipFile, unpackFolder)
		util:run_command(command)
	end
end

local function DownLoadUnpack(tag, branch)
	local fileBaseName, zipFile = m:DownloadZip(tag)
	m:UnpackZip(branch, fileBaseName, zipFile)
end

local function main(_tag, _branch)
	pathlib.mkdir(pathlib.join("FrameXML", "zips"))
	if _tag then
		DownLoadUnpack(_tag, _branch)
	else
		for _, branch in pairs(branches) do
			pathlib.mkdir(pathlib.join("FrameXML", branch))
			for _, tag in pairs(tags[branch]) do
				DownLoadUnpack(tag, branch)
			end
		end
	end
	log:success("Done")
end

main("12.0.0", "live")
-- main()
