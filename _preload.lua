--
-- Name:		clangd-config/_preload.lua
-- Purpose:		Define clangd-config action (and options).
-- Copyright:	See attached license file
--

-- luals
---@module 'premake5'
verbosef("Loading: _preload")

---@type Module
local module = include("_init_module")
if module == nil then
	-- Second include => nil
	module = premake.modules.clangd_config
end

-- Actions and options
newaction({
	trigger         = "clangd-config",
	shortname       = "clangd",
	description     = "Generate clangd configuration files",
	toolset         = "clang",

	valid_kinds     = { "ConsoleApp", "WindowedApp", "StaticLib", "SharedLib" },
	valid_languages = { "C", "C++" },
	valid_tools     = {
		cc	= { "clang", "gcc", "msc" },
	},

	pathVars        = {
		["wks.location"]             = { absolute = true,  token = "$(WORKSPACE_DIR)" },
		["wks.name"]                 = { absolute = false, token = "$(WORKSPACE_NAME)" },
		["sln.location"]             = { absolute = true,  token = "$(WORKSPACE_DIR)" },
		["sln.name"]                 = { absolute = false, token = "$(WORKSPACE_NAME)" },
		["prj.location"]             = { absolute = true,  token = "$(PROJECT_DIR)" },
		["prj.name"]                 = { absolute = false, token = "$(PROJECT_NAME)" },
		["cfg.targetdir"]            = { absolute = true,  token = "$(PROJECT_DIR)$(TARGET_OUTPUT_DIR)" },
		["cfg.buildcfg"]             = { absolute = false, token = "$(TARGET_NAME)" },
		["cfg.buildtarget.basename"] = { absolute = false, token = "$(TARGET_OUTPUT_BASENAME)" },
		["cfg.buildtarget.relpath"]  = { absolute = false, token = "$(TARGET_OUTPUT_FILE)" },
		["file.directory"]           = { absolute = true,  token = "$file_dir" },
		["file.basename"]            = { absolute = false, token = "$file_name" },
		["file.abspath"]             = { absolute = true,  token = "$file" },
	},

	onWorkspace = function(wks)
		module.main.generateWorkspace(wks)
	end,

	onProject = function(prj)
		module.main.generateProject(prj)
	end,

	onCleanWorkspace = function(wks)
		module.main.cleanWorkspace(wks)
	end,

	onCleanProject = function(prj)
		module.main.cleanProject(prj)
	end,

	-- Nothing to do
	onCleanTarget = function(tgt)

	end
})

newoption({
	trigger = module.OPTIONS.gen_config,
	value = "TARGET",
	description = [[clangd-config) generate 'config.yaml' for TARGET configration
     configuration name     use given build configuration
     true                   first in order of 'os', 'arch', 'release/debug'
     false                  Disabled (*)
]],							-- Tabulations marker
	default = "false"
})

newoption({
	trigger = module.OPTIONS.gen_database,
	value = "ENABLE",
	description = "clangd-config) create compilation database file",
	allowed = {
		{ "true", "Enabled (*)" }, { "false", "Disabled" }
	},
	default = "true"
})


-- Decide when the full module should be loaded.
return function(cfg)
	return (_ACTION == "clangd-config")
end
