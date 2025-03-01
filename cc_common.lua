--
-- Name:		clangd-config/cc_common.lua
-- Purpose:		Share code for reading premake5 data.
-- Copyright:	See attached license file
--

-- luals
---@module 'premake5'

---@type Module
local module = premake.modules.clangd_config
local Main = module.main

--- Common needs when generating
---@class Common
-- ---@field ConfigInfo Util.ConfigInfo
-- ---@field Toolset Toolset
-- ---@field Workspace Workspace
local M = {}

local Util = module.Util

-- Writing --
-------------

-- "cache" of function
---@type fun(string): string?
---@diagnostic disable-next-line: undefined-global
local json_encode = json.encode
local function escapeValue(toEscape)
	local json_text = json_encode(toEscape)
--	print("esc json_text: ", json_text)
	return json_text
end

--- Configure for writing Yaml
---@param p premake
function M.yamlWriting(p)
	--p.eol('\r\n')
	p.indent("  ")
	p.escaper(escapeValue)
end

--- Configure back to default
---@param p premake
function M.resetWriting(p)
	--p.eol('\n')
	p.indent(nil, nil)
	p.escaper(nil)
end

-- Call Premake apis --
-----------------------

function M.normalizeSystem(system)
	local fields = premake.fields
	return premake.api.checkValue(fields.system, system) or system
end

function M.normalizeArchitecture(arch)
	local fields = premake.fields
	return premake.api.checkValue(fields.architecture, arch, "string") or arch
end

function M.normalizeToolset(cc)
	local fields = premake.fields
	return premake.api.checkValue(fields.toolset, cc) or cc
end

---@param prj Premake.Project
---@return string path without trailing '/'
function M.getCompilationDatabaseDirectory(prj)
	return string.format("%s/%s", prj.location, prj.name)
end

---@param prj Premake.Project
---@return string
function M.getCompilationDatabaseFilename(prj)
	local dir = M.getCompilationDatabaseDirectory(prj)
	return string.format("%s/%s", dir, module.FILENAME_DATABASE)
end


-- Read Premake infos --
------------------------

--- Target informations (toolset name, os, architecture)
---@class TargetInfo
---@field cc string Toolset name
---@field system string os
---@field arch string platform
local TargetInfo = {}

--- Create from defaults
---@return TargetInfo
function TargetInfo.new(opts)
	local o = opts or {}
	o.cc		= o.cc		or ""
	o.system	= o.system	or ""
	o.arch		= o.arch	or ""
	return o
end
Util.makeClass(TargetInfo)

--- Create from options
---@return TargetInfo
function TargetInfo.createDefault()
	local opts = {}
	opts.cc		= _OPTIONS.cc
	opts.system	= os.target()
	opts.arch	= os.targetarch()

	return TargetInfo.new(opts)
end

---@class TargetInfoConfig : TargetInfo
---@field cfg Premake.Config
---@field flags table Internal use
local TargetInfoConfig = Util.prepareChildClass(TargetInfo)

--- Create for config
---@param cfg Premake.Config
function TargetInfoConfig.new(cfg)
	local o = {}
	o.cc		= M.normalizeToolset(cfg.toolset)
	o.system	= M.normalizeSystem(cfg.system)
	o.arch		= M.normalizeArchitecture(cfg.platform)
	o.cfg = cfg
	o.flags = {}

	o = TargetInfo.new(o)

	--local types = { WindowedApp = 0, ConsoleApp = 1, StaticLib = 2, SharedLib = 3 }
	-- types[cfg.kind]

	return o
end
Util.makeClass(TargetInfoConfig)

function TargetInfoConfig.isDebugBuild(self)
	local rc = self.flags["isDebugBuild"]
	if rc == nil then
		rc = premake.config.isDebugBuild(self.cfg)
		self.flags["isDebugBuild"] = rc
	end
	return rc
end

--- Used to order by debug/release, system, arch
local function getCompareConfig()
	local dflt = TargetInfo.createDefault()

	---@param a TargetInfoConfig
	---@param b TargetInfoConfig
	---@return boolean true if a before b
	local function compare(a, b)
		-- os
		local a_t, b_t = (a.system == dflt.system), (b.system == dflt.system)
		if a_t ~= b_t then return a_t end
		-- arch
		a_t, b_t = (a.arch == dflt.arch), (b.arch == dflt.arch)
		if a_t ~= b_t then return a_t end
		-- release
		a_t, b_t = a:isDebugBuild(), b:isDebugBuild()
		if a_t ~= b_t then return not a_t end
		-- ??
		a_t, b_t = (a.cc == "clang"), (b.cc == "clang")
		if a_t ~= b_t then return a_t end

		if a.system ~= b.system	then return a.system < b.system	end
		if a.arch ~= b.arch		then return a.arch < b.arch		end
		if a.cc ~= b.cc			then return a.cc < b.cc			end
		-- Hope it's ok
		return a.cfg.name < b.cfg.name
	end

	return compare
end


---@param wks Premake.Workspace
---@param logger Printer
---@return Premake.Config?
local function selectConfig(wks, logger)
	assert(logger ~= nil, "param")
	logger:write("Select config: ")

	local configName = Main.getConfigName()
	if configName ~= nil then
		logger:writeFmt("search for '%s'", configName)
		local name = configName:lower()
		for cfg in premake.workspace.eachconfig(wks) do
			if name == cfg.name:lower() then
				logger:writeLine(", ok")
				return cfg
			end
		end
		logger:write(", not found, ")
	end

	logger:write("scan configurations ... ")
	local configs = {}
	for cfg in premake.workspace.eachconfig(wks) do
		local tic = TargetInfoConfig.new(cfg)
		table.insert(configs, tic)
	end
	if #configs == 0 then
		logger:writeLine("build configurations empty?")
		return nil
	end

	table.sort(configs, getCompareConfig())
	local cfg = configs[1].cfg
	logger:writeLineFmt("selected '%s'", cfg.name)
	return cfg
end

local selectedConfig = nil
--- Get configuration to use (keep result cached)
---@param wks Premake.Workspace
---@param logger Printer
---@return Premake.Config?
function M.getSelectedConfig(wks, logger)
	if selectedConfig == nil then
		selectedConfig = selectConfig(wks, logger)
	end
	return selectedConfig
end

--- Create a logger and configure it depending on _OPTIONS
---@return Printer
function M.newLogger()
	local logger = Util.Printer.new()
	if not _OPTIONS.verbose then
		logger.enabled = false
	end
	return logger
end

local sharedLogger = nil
--- Get a singleton instance of a logger
---@return Printer
function M.getSharedLogger()
	if sharedLogger == nil then
		sharedLogger = M.newLogger()
	end
	return sharedLogger
end


---@enum E_Language
local E_Language = {
	['c'] = 1,
	['cpp'] = 2,
}
M.E_Language = E_Language

---@class FileType
---@field lang E_Language?
---@field code boolean false: header, true: code
local FileType = {}

---@param ft FileType
---@param lang E_Language
function FileType.setCode(ft, lang)
	ft.lang = lang
	ft.code = true
end

---@param ft FileType
---@param lang E_Language?
function FileType.setHeader(ft, lang)
	ft.lang = lang
	ft.code = false
end

---@param node Premake.Tree.NodeLeaf
---@param cfg Premake.Config
---@return boolean, string
local function getCompileAs(node, cfg)
	if node.compileas and node.compileas ~= "Default" then
		return true, node.compileas
	end
	if cfg.compileas and cfg.compileas ~= "Default" then
		return true, cfg.compileas
	end
	local filecfg = premake.fileconfig.getconfig(node, cfg)
	if filecfg and filecfg.compileas and filecfg.compileas ~= "Default" then
		return true, filecfg.compileas
	end
	return false, ''
end

---@param prj Premake.Project
---@return E_Language?
function M.getProjectLanguage(prj)
	local test = prj.language
	if premake.languages.iscpp(test) then return E_Language.cpp
	elseif premake.languages.isc(test) then return E_Language.c
	end
	return nil
end

---
---@param node Premake.Tree.NodeLeaf
---@return FileType
function M.getFileType(node, cfg)
	local ft = { }

	local test, compileas = getCompileAs(node, cfg)
	if test then
		if premake.languages.iscpp(compileas) then FileType.setCode(ft, E_Language.cpp)
		elseif premake.languages.isc(compileas) then FileType.setCode(ft, E_Language.c)
		else FileType.setHeader(ft, nil)
		end
	else
		local filename = node.name
		if path.iscppfile(filename) then FileType.setCode(ft, E_Language.cpp)
		elseif path.iscfile(filename) then FileType.setCode(ft, E_Language.c)
		elseif path.iscppheader(filename) then FileType.setHeader(ft, E_Language.cpp)
		else FileType.setHeader(ft, nil)
		end
	end

	return ft
end



--
return M
