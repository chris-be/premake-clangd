--
-- Name:		clangd-config/util/Array.lua
-- Copyright:	See attached license file
--

---@type Util
local Util = premake.modules.clangd_config.Util

---@class Array
local Array = {}

--- Truncate
---@param toUpdate any{]
---@param index number Start index (included)
function Array.truncate(toUpdate, index)
	for i=#toUpdate,index,-1 do
		toUpdate[i] = nil
	end
end

--- Add values from another array
---@param toUpdate any{]
---@param toAdd any[]
function Array.add(toUpdate, toAdd)
	for _, v in ipairs(toAdd) do
		table.insert(toUpdate, v)
	end
end

---@class ArrayIterator
---@field array any[] Array iterating on
---@field iter fun(any, number?): number?, any Iterator
---@field key number? Current key
---@field value any? Current value
local ArrayIterator = {}
Array.Iterator = ArrayIterator

---@param array any[]
---@return ArrayIterator
function ArrayIterator.new(array)
	local o = {}
	o.iter, o.array, o.key = ipairs(array)

	return o
end
Util.makeClass(ArrayIterator)

---@return boolean True if value
function ArrayIterator.next(self)
	self.key, self.value = self.iter(self.array, self.key)
	return self.key ~= nil
end


--
return Array
