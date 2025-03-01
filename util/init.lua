--
-- Name:		clangd-config/util/init.lua
-- Purpose:		Some classes, utilities and some tests.
-- Copyright:	See attached license file
--

---@class Util
---@field Array Array
---@field Set Set
---@field Printer Printer
---@field Debug Debug
local M = {
	---@see _init_module
	lazy_load_subpkgs = {
		Array	= "Array",
		Set		= "Set",
		Printer	= "Printer",
		Debug	= "Debug",
	}
}

-- Make a table a "class"
-- index itself ; override .new() or create it
---@param class table Table used for "class"
function M.makeClass(class)
	class.__index = class

	local old_new = class.new
	if old_new ~= nil then
		-- override
		class.new = function(...)
			local o = old_new(...)
			setmetatable(o, class)
			return o
		end
	else
		-- create
		class.new = function(opts)
			local o = opts or {}
			setmetatable(o, class)
			return o
		end
	end
end

-- Prepare a table for inheriting a "parent"
-- "makeClass" must be called on it (after defining ".new" if needed)
---@param parent table "parent class"
---@return table Child class
function M.prepareChildClass(parent)
	return parent.new()
end




------------------------
-------------------
---------

--[[

---@class FilePath
local FilePath = {}
---@param path string
---@return FilePath
function FilePath.new(path)
	local o = string.explode(path, '/', true)
	assert(type(o) == "table", "Humm...")
	---@type FilePath
	return o
end

---@param fp FilePath
---@return boolean
function FilePath.startWith(self, fp)
	-- Quick exit
	if #fp > #self then return false end

	local s_iter = Array.Iterator.new(self)
	local o_iter = Array.Iterator.new(fp)
	while s_iter:next() do
		if o_iter:next() then
			if s_iter.value ~= o_iter.value then
				return false
			end
		else
			return true
		end
	end
	-- include fp empty
	return true
end

---@param a FilePath
---@param b FilePath
---@return boolean true if a before b
function FilePath.compare(a, b)
	local tmp = #a - #b
	if tmp ~= 0 then
		return (tmp < 0)
	end

	local a_iter = Array.Iterator.new(a)
	local b_iter = Array.Iterator.new(b)
	while a_iter:next() do
		b_iter:next()
		if a_iter.value < b_iter.value then
			return true
		elseif a_iter.value > b_iter then
			return false
		end
	end
	-- equals
	return false
end

--]]

--- Create a new table with common keys of both tables
---@param table1 table
---@param table2 table
---@return table Keeps values from table1
function M.intersect(table1, table2)
	local ti = {}
	for k, v in pairs(table1) do
		if table2[k] ~= nil then
			ti[k] = v
		end
	end
	return ti
end

function M.tests()
	local Debug = M.Debug
	local Set = M.Set

	local dbg = Debug.new()

	local s1 = Set.new()
	s1:add("zlib")	s1:add("alo")	s1:add("blob")	s1:add("c++")
	dbg:print("s1", s1)

	local s2 = Set.new()
	s2:addValues("zlib", "alo", "blob", "c++")
	dbg:print("s2", s2)

	local s3 = Set.new()
	s3:addValues("c++", "zlib")
	dbg:print("s3", s3)

	s1:intersect(s2)
	dbg:print("s1 inter s2", s1)

	s2:intersect(s3)
	dbg:print("s2 inter s3", s2)

	s3 = Set.new()
	s3:addValues("c++", "zlib")
	s3:intersect(s1)
	dbg:print("s3 inter s1", s3)

end

--
return M
