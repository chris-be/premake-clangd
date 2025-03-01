--
-- Name:		clangd-config/cc_gen_db.lua
-- Purpose:		Generate a compilation database file
-- Copyright:	See attached license file
--

-- luals
---@module 'premake5'

---@type Module
local Module = premake.modules.clangd_config
local Common = Module.Common

--- Sub module creating compile_commands.json files
---@class GenDatabase
local M = {}

---@param prj Premake.Project
---@return string[]
local function grabCompiledFiles(prj)

	local files = {}

	---@param node Premake.Tree.Node
	local function grabFileName(node)
		if node.generated then return end
		--
		local take
		local test = node.compileas
		if test and test ~= "Default" then
			take = premake.languages.iscpp(test) or premake.languages.isc(test)
		else
			test = node.abspath
			take = path.iscppfile(test) or path.iscfile(test)
		end

		if take then
			table.insert(files, node.abspath)
		end
	end

	local tree = premake.project.getsourcetree(prj)
	premake.tree.traverse(tree, {
		onleaf = grabFileName
	})

	return files
end


---@param prj Premake.Project
M.generate = function(prj)
	local p = premake

	-- Reset?
	-- Common.resetWriting(p)
	local files = grabCompiledFiles(prj)
	assert(files ~= nil, "No files => abort")

	Common.yamlWriting(p)

	local sf = string.format
	--- Prepare simple property (escape !!)
	local function prop(name, value, trailingComma)
		local str = p.esc(value)
		if trailingComma == true then
			return sf('"%s": %s,', name, str)
		end
		return sf('"%s": %s', name, str)
	end
	--- Write property
	local function wprop(name, value, trailingComma)
		p.w( prop(name, value, trailingComma) )
	end
	-- Write if
	local function wif(str)
		if str ~= nil then p.w(str) end
	end

	local directory = prop("directory", prj.location, true)

	-- https://clang.llvm.org/docs/JSONCompilationDatabase.html
	p.w('[')
	p.push()
		local last = #files
		for i, file in ipairs(files) do
			p.w('{')
			p.push()
				p.w(directory)
				p.w( sf('"arguments": [ %s ],', '"/usr/bin/clang++"') )
				wprop( "file", file )
			p.pop()
			local close = '},'
			if i == last then close = '}' end
			p.w(close)
		end
	p.pop()
	p.w(']')
	p.w()

end

--
return M
