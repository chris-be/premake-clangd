--
-- Name:		clangd-config/clangd-config.lua
-- Purpose:		Generate configuration files for clangd.
-- Copyright:	See attached license file
--

-- luals
---@module 'premake5'
verbosef("Loading: clangd-config")

local includedFirst = (premake.modules.clangd_config == nil)
if includedFirst then
	include("_init_module")
	include("_preload")
end
local module = premake.modules.clangd_config
assert(module ~= nil, "-_-")

--- Main: handle actions
---@class Main
local M = {}

-- Initialized on first need
local genConfigEnabled = nil
local genConfigName = nil
local genDatabaseEnabled = nil

---@param enabled boolean
local function getMessageEnabled(enabled)
	if enabled then return "enabled" end
	return "disabled"
end

---@return boolean
function M.isGenConfigEnabled()
	if genConfigEnabled == nil then
		local name = module.OPTIONS.gen_config
		-- newoption handles default value (no need to test empty value)
		local option = _OPTIONS[name]
		genConfigEnabled = (option ~= "false")
		if genConfigEnabled then
			if (option ~= "true") then
				genConfigName = option
			else
				genConfigName = nil
			end
		end

		local msg = getMessageEnabled(genConfigEnabled)
		verbosef("%s [%s]: %s", module.TITLE_MODULE, name, msg)
	end

	return genConfigEnabled
end

---@return string? Build configuration option
function M.getConfigName()
	if genConfigEnabled == nil then
		M.isGenDatabaseEnabled()
	end
	return genConfigName
end

function M.isGenDatabaseEnabled()
	if genDatabaseEnabled == nil then
		local name = module.OPTIONS.gen_database
		-- newoption handles default value (no need to add test 'or "true"')
		genDatabaseEnabled = (_OPTIONS[name]) == "true"

		local msg = getMessageEnabled(genDatabaseEnabled)
		verbosef("%s [%s]: %s", module.TITLE_MODULE, name, msg)
	end

	return genDatabaseEnabled
end


function M.generateWorkspace(wks)
--[[
	if _OPTIONS['test'] then
		module.Util.tests()
	end
--]]

	if M.isGenConfigEnabled() then
		local fun_gen = module.gen_config.generate
		premake.generate(wks, module.FILENAME_CONFIG, fun_gen)
	end
end

function M.cleanWorkspace(wks)
	if M.isGenConfigEnabled() then
		print("CLEAN : [", module.FILENAME_CONFIG, "]")
		-- premake.clean.file(wks, module.FILENAME_CONFIG)
	end
end

function M.generateProject(prj)
	if M.isGenDatabaseEnabled() then
		local P_P = premake.project
		if P_P.iscpp(prj) or P_P.isc(prj) then
			local dbFile = module.Common.getCompilationDatabaseFilename(prj)
			local fun_gen = module.gen_database.generate
			premake.generate(prj, dbFile, fun_gen)
		end
	end
end

function M.cleanProject(prj)
	if M.isGenDatabaseEnabled() then
		local dbFile = module.Common.getCompilationDatabaseFilename(prj)
		print("CLEAN : [", dbFile, "]")
		-- premake.clean.file(prj, dbFile)
	end
end

if includedFirst then
	-- Register (avoid lazy loading)
	module.main = M
end

--[[
-- ----------------
-- Modules
module.Util			= Util
module.Common		= include("cc_common.lua")
-- Work
module.main			= M
module.gen_config	= include("cc_gen_cfg.lua")
module.gen_database	= include("cc_gen_db.lua")
--]]

print("clangd-config module loaded.")
--
return M
