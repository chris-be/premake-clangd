--
-- Name:		clangd-config/_init_module.lua
-- Purpose:		Create minimal module (with lazy loading) used by _preload and clangd-config.
-- Copyright:	See attached license file
--

-- luals
---@module 'premake5'

-- Used for LazyLoading
local myId = "_init_module.lua"
verbosef("Loading: %s", myId)

---@class Module
---@field Util Util
---@field Common Common
---@field main Main
---@field gen_config GenConfig
---@field gen_database GenDatabase
local module = {
	_VERSION	= "1.0.0-dev",

	-- Defines
	TITLE_MODULE		= "clangd-config",
	FILENAME_CONFIG		= "clangd_config.yaml",
	FILENAME_DATABASE	= "compile_commands.json",

	-- Command line options
	OPTIONS = {
		gen_config		= "clangd-config",
		gen_database	= "clangd-commands"
	},

	lazy_load_subpkgs = {
		Util = "util/init",
		Common = "cc_common",
		main = "clangd-config",
		gen_config = "cc_gen_cfg",
		gen_database = "cc_gen_db"
	}
}

local function ensureTrailingSlash(path)
	local c = path[#path]
	if c ~= '/' and c ~= '\\' then path = path .. '/' end
	return path
end

-- Lazy loading
---@param obj table Table to set __index
---@param root string Root path where to search files
---@param subpkgs table<string, string> table key => relative path and file to load (without extension)
local function attachLazyLoader(obj, root, subpkgs)
	root = ensureTrailingSlash(root)

	-- Check recursive calls -_-
	local loadFlag = {}
	local function funcIndex(t, key)
		local subFile = subpkgs[key]
		if subFile ~= nil then
--			verbosef("Lazy loading: %s", subFile)
			assert(loadFlag[subFile] == nil, "Recursive 'require'")

			loadFlag[subFile] = false
			local m = include(root .. subFile)
			if m == nil then
				local msg = string.format("clangd-config) Error loading '%s'", subFile)
				error(msg)
			end
			loadFlag[subFile] = true
			if type(m.lazy_load_subpkgs) == "table" then
				local subDir = path.getdirectory(subFile)
				if #subDir > 1 and subDir[1] ~= '.' then
					subDir = root .. subDir
				end
				attachLazyLoader(m, subDir, m.lazy_load_subpkgs)
			end

			rawset(t, key, m)
			return m
		end
		return nil
	end

	setmetatable(obj, { __index = funcIndex })
end

local root = os.locate(myId)
assert(root ~= nil, "can't load")
root = string.sub(root, 1, -(#myId+1))
attachLazyLoader(module, root, module.lazy_load_subpkgs)


-- Register
premake.modules.clangd_config = module

--
return module

--[[
Is this idea reasonable?
table.insert(package.searchers, function(modName)
	print(modName)
	return nil
end)
--]]
