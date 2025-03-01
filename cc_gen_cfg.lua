--
-- Name:		clangd-config/cc_gen_cfg.lua
-- Purpose:		Generate a config file
-- Copyright:	See attached license file
--

-- luals
---@module 'premake5'

---@type Module
local module = premake.modules.clangd_config
local Common = module.Common

--- Sub module creating config.yaml file
---@class GenConfig
local M = {}

local Util = module.Util
local Array = Util.Array
local Set = Util.Set

---@class ConfigInfo
---@field buildoptions Set
---@field c_flags Set c flags only
---@field cpp_flags Set cpp flags only
---@field defines Set
---@field undefines Set
---@field include_dirs Set
local ConfigInfo = {}

---@param cfg Premake.Config
function ConfigInfo.new(cfg)
	local o = {}

	o.buildoptions = Set.new(cfg.buildoptions)
	local toolset = premake.config.toolset(cfg)
	o.c_flags = Set.new( toolset.getcflags(cfg) )
	o.cpp_flags = Set.new( toolset.getcppflags(cfg) )
	o.defines = Set.new( toolset.getdefines(cfg.defines) )
	o.undefines = Set.new( toolset.getundefines(cfg.undefines) )

	local tmp = nil
	if cfg.includedirs or cfg.externalincludedirs or cfg.frameworkdirs or cfg.includedirsafter then
		tmp = toolset.getincludedirs(cfg, cfg.includedirs, cfg.externalincludedirs, cfg.frameworkdirs, cfg.includedirsafter)
	end
	o.include_dirs = Set.new(tmp)

	return o
end
Util.makeClass(ConfigInfo)

---@return ConfigInfo
function ConfigInfo.copy(self)
	return table.deepcopy(self)
end

function ConfigInfo.intersect(self, o)
	for k, v in pairs(self) do
		self[k] = Set.newIntersection(v, o[k])
	end
end

function ConfigInfo.exclude(self, o)
	for k, v in pairs(self) do
		self[k] = Set.newExclusion(v, o[k])
	end
end

---@return boolean True If any member is not empty
function ConfigInfo.any_value(self)
	for _, v in pairs(self) do
		if #v > 0 then return true end
	end
	return false
end


local E_Language = Common.E_Language

---@class ProjectInfo
---@field prj Premake.Project
---@field lang E_Language? Project language
---@field ci ConfigInfo
local ProjectInfo = {}

---@param prj Premake.Project
---@param ci ConfigInfo
---@param lang E_Language?
---@return ProjectInfo
function ProjectInfo.new(prj, ci, lang)
	local o = {}
	o.prj = prj
	o.lang = lang or Common.getProjectLanguage(prj)
	o.ci = ci

	return o
end
Util.makeClass(ProjectInfo)

---@param prj Premake.Project
---@param cfg Premake.Config
local function findProjectConfig(prj, cfg)
	for prjCfg in premake.project.eachconfig(prj) do
		if prjCfg.name == cfg.name then return prjCfg end
	end
end



-- Only for path without starting with (../)*
---@class Branches
local Branches = {}
function Branches.new()
	local o = {}

	return o
end
Util.makeClass(Branches)

-- Add path
function Branches.add(self, path)
	local node = self
	for _, seg in ipairs(path) do
		local subnode = node[seg]
		if subnode == nil then
			subnode = {}
			node[seg] = subnode
		end
		node = subnode
	end
end

-- Add root if not exist, cut path where it differs
function Branches.merge(self, path)
	if #path == 0 then return end

	-- Scan path
	local p_iter = Array.Iterator.new(path)
	p_iter:next()
	local node = self[p_iter.value]
	if node == nil then
		-- New root
		self:add(path)
		return
	end

	-- Cut at "change"
	local goOn = p_iter:next()
	while goOn do
		if node[p_iter.value] == nil then
			Array.truncate(node, 1)
			return
		end
		node = node[p_iter.value]
	end
end

---@param node table
---@return table[]
function Branches.listPaths(node)
	local paths = {}
	for k, subnode in pairs(node) do
		local subPaths = Branches.listPaths(subnode)
		if #subPaths > 0 then
			for _, list in ipairs(subPaths) do
				local path = { [1] = k }
				Array.add(path, list)
				table.insert(paths, path)
			end
		else
			local path = { [1] = k }
			table.insert(paths, path)
		end
	end
	return paths
end

---@param prj Premake.Project
---@param cfg Premake.Config
---@return string[]
local function grabFilters(prj, cfg)

	---@type table<string, Branches>
	local extBranches = {}

	-- TODO: check
	local pathProjectFile = prj.location
	local pathRoot = prj.basedir
	---@param relPath string path relative to project file
	local function getFilePathRelativeToRoot(relPath)
		return path.rebase(relPath, pathProjectFile, pathRoot)
	end

	---@param node Premake.Tree.NodeLeaf
	local function grabFilter(node)
		if node.generated then return end
		--

		local filetype = Common.getFileType(node, cfg)
		local take = (filetype.lang == Common.E_Language.c) or (filetype.lang == Common.E_Language.cpp)
		if take then
			local ext = node.extension
			local branches = extBranches[ext]
			if branches == nil then
				branches = Branches.new()
				extBranches[ext] = branches
			end

			-- node.parent do no always have complete path => extra work :/
			local path = getFilePathRelativeToRoot(node.reldirectory)
			---@diagnostic disable-next-line: cast-local-type
			path = string.explode(path, '/', true)
			branches:merge(path)
		end
	end

	local tree = premake.project.getsourcetree(prj)
	premake.tree.traverse(tree, {
		onleaf = grabFilter
	})

	local filters = {}
	for ext, br in pairs(extBranches) do
		local paths = Branches.listPaths(br)
		for _, path in ipairs(paths) do
			local filter = table.concat(path, '/') .. '.*\\' .. ext
			table.insert(filters, filter)
		end
	end
	return filters
end


---@param wks Premake.Workspace
M.generate = function(wks)
	local logger = Common.getSharedLogger()

	local p = premake
	Common.resetWriting(p) -- getdefines escape names

	local cfg = Common.getSelectedConfig(wks, logger)
	assert(cfg ~= nil, "No configuration => abort")

	-- Cache
	local P_W = premake.workspace

	-- Grab options for projects
	---@type ProjectInfo[]
	local prjInfoList = {}
	-- Common options
	---@type E_Language?
	local lang_main = nil
	local lang_first = true
	---@type ConfigInfo
	local ci_main = nil
	for prj in P_W.eachproject(wks) do
		local lang = Common.getProjectLanguage(prj)
		if lang == E_Language.cpp or lang == E_Language.c then
			local prjCfg = findProjectConfig(prj, cfg)
			if prjCfg ~= nil then
				local ci = ConfigInfo.new(prjCfg)
				local pi = ProjectInfo.new(prj, ci, lang)
				table.insert(prjInfoList, pi)
				--
				if lang_first == false then
					if lang_main ~= lang then
						lang_main = nil
					end
				else
					lang_main = lang
				end
				if ci_main ~= nil then
					ci_main:intersect(ci)
				else
					ci_main = ci:copy()
				end
			end
		end
	end


	---@param set Set
	---@return string?, boolean
	local function toString(set, first)
		if #set == 0 then
			return nil, first
		end

		local buffer = {}
		for _, v in ipairs(set) do
			if first == false then
				table.insert(buffer, ', ')
			else
				first = false
			end
			local tmp = p.esc(v)
			table.insert(buffer, tmp)
		end

		return table.concat(buffer), first
	end

	Common.yamlWriting(p)
	local sf = string.format
	-- Write if
	local function wif(str)
		if str ~= nil then p.w(str) end
	end

	p.w( sf('# Configuration [%s]', cfg.name) )
	p.w('---')
	p.w('CompileFlags:')
	p.push()
		if lang_main ~= nil then
			local compiler = iif(lang_main == E_Language.cpp, "clang++", "clang")
			p.w( sf("Compiler: %s", p.esc(compiler) ) )
			p.w("# Note: 'clang' can be used with '-xc++' (treat all files as C++)")
		end
		p.w('Add: [')
		p.push()
			p.w("# '-xc++'")
			local tmp, first = nil, true
			tmp, first = toString(ci_main.c_flags, first)		wif(tmp)
			tmp, first = toString(ci_main.cpp_flags, first)		wif(tmp)

			tmp, first = toString(ci_main.buildoptions, first)	wif(tmp)

			tmp, first = toString(ci_main.defines, first)		wif(tmp)
			tmp, first = toString(ci_main.undefines, first)		wif(tmp)

			tmp, first = toString(ci_main.include_dirs, first)	wif(tmp)
		p.pop()
		p.w(']')
		p.w( sf("#CompilationDatabase: %s", p.esc("/path_to/concatenated/compilation_database_file")) )
	p.pop()
	p.w()
	p.w('#Diagnostics:')
	p.push()
		p.w( "#Suppress: 'pp_including_mainfile_in_preamble' # Templates friend classes" )
	p.pop()
	p.w()
	p.w('#Index:')
	p.push()
		p.w( '#StandardLibrary: No' )
		p.push()
			p.w('#External:')
			p.w('#MountPoint: /??')
			p.w('#File: /??')
		p.pop()
	p.pop()
	p.w('...')
	p.w()

	-- Track all generated files for jq concat command
	---@type string[]
	local compDbFiles = {}

	p.w('# Projects')
	for _, pi_ in ipairs(prjInfoList) do
		-- Must precise type: https://github.com/LuaLS/lua-language-server/issues/2969i
		---@type ProjectInfo
		local pi = pi_

		p.w('---')
		p.w( sf('# [%s]', pi.prj.name) )
		p.w('If:')
		p.push()
			p.w('PathMatch: [')
			local filters = grabFilters(pi.prj, cfg)
			if #filters > 0 then
			p.push()
				p.w( toString(filters, true) )
			p.pop()
			end
			p.w(']')
			p.w()
		p.pop()
		p.w('CompileFlags:')
		p.push()
			if lang_main == nil then
				local compiler = iif(pi.lang == E_Language.cpp, "clang++", "clang")
				p.w( sf("Compiler: %s", p.esc(compiler) ) )
			end

			local ci_prj = pi.ci:copy()
			ci_prj:exclude(ci_main)
			local any_value = ci_prj:any_value()
			if not any_value then
				p.w(' # No specifities')
			else
				p.w('Add: [')
				p.push()
					tmp, first = nil, true
					tmp, first = toString(ci_prj.c_flags, first)		wif(tmp)

					tmp, first = toString(ci_prj.cpp_flags, first)		wif(tmp)

					tmp, first = toString(ci_prj.defines, first)		wif(tmp)

					tmp, first = toString(ci_prj.undefines, first)		wif(tmp)

					tmp, first = toString(ci_prj.include_dirs, first)	wif(tmp)
				p.pop()
				p.w(']')
			end
				local pathDb = Common.getCompilationDatabaseDirectory(pi.prj)
				p.w( sf("#CompilationDatabase: %s", p.esc(pathDb)) )
				table.insert(compDbFiles, Common.getCompilationDatabaseFilename(pi.prj))
		p.pop()
		p.w('...')
		p.w() -- ventilate

	end

	table.insert(compDbFiles, 1, "# jq -s 'add'")
	table.insert(compDbFiles, '>');
	table.insert(compDbFiles, module.FILENAME_DATABASE);
	p.w('# Concat all:')
	p.w( table.concat(compDbFiles, ' ') )
	p.w()

end

--
return M
