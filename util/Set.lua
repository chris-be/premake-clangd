--
-- Name:		clangd-config/util/Set.lua
-- Copyright:	See attached license file
--

---@type Util
local Util = premake.modules.clangd_config.Util
local Array = Util.Array
local SetIterator = Array.Iterator

---@class Set
local Set = {}

---@param array? any[]
function Set.new(array)
	local o = {}

	if array ~= nil then
		for _, v in ipairs(array) do
			table.insert(o, v)
		end
		table.sort(o)
	end

	return o
end
Util.makeClass(Set)

---@return boolean, number? Found flag. Index (exact or where to put if ~= nil)
function Set.find(self, toFind)
	local right = #self
	if right == 0 then
		return false, 1
	end

	local left = 1
	local isBefore
	repeat
		local middle = (left + right) // 2
		assert(middle > 0, "bad algo")
		local test = self[middle]
		if toFind == test then
			return true, middle
		else
			isBefore = (toFind < test)
			if isBefore then
				right = middle
			else
				left = middle + 1
			end
		end
	until(left >= right)

	if isBefore then return false, right end
	return false, left
end

---@return boolean
function Set.has(self, toFind)
	local found = self:find(toFind)
	return found
end

function Set.add(self, value)
	local found, idx = self:find(value)
	if not found then
		table.insert(self, idx, value)
	end
end

function Set.addValues(self, ...)
	local args = {...}
	for _, value in ipairs(args) do
		local found, idx = self:find(value)
		if not found then
			table.insert(self, idx, value)
		end
	end
end

function Set.eachValue(self)
	local iter = SetIterator.new(self)
	return function()
		return iter:next()
	end
end

--- Create a new Set keeping common values of both sets
---@return Set
function Set.newIntersection(self, o)
	local X = Set.new()

	local s_iter = SetIterator.new(self)
	local o_iter = SetIterator.new(o)

	local goOn = s_iter:next() and o_iter:next()
	while goOn do
		local s_value = s_iter.value
		local o_value = o_iter.value
		if s_value < o_value then
			goOn = s_iter:next()
		elseif s_value > o_value then
			goOn = o_iter:next()
		else
			table.insert(X, s_value)
			goOn = s_iter:next() and o_iter:next()
		end
	end

	return X
end

function Set.newExclusion(self, o)
	local S = {}

	local s_iter = SetIterator.new(self)
	local o_iter = SetIterator.new(o)

	local goOn = s_iter:next() and o_iter:next()
	while goOn do
		local s_value = s_iter.value
		local o_value = o_iter.value
		if s_value < o_value then
			table.insert(S, s_value)
			goOn = s_iter:next()
		elseif s_value > o_value then
			goOn = o_iter:next()
		else
			goOn = s_iter:next() and o_iter:next()
		end
	end

	goOn = (s_iter.key ~= nil)
	while goOn do
		table.insert(S, s_iter.value)
		goOn = s_iter:next()
	end

	return S
end

--- Replace values (may be faster than "remove")
local function replaceValues(toUpdate, values)
	for i, v in ipairs(values) do
		toUpdate[i] = v
	end
end

---
function Set.set(self, o)
	replaceValues(self, o)
	Array.truncate(self, #o+1)
end

---@param o Set
function Set.intersect(self, o)
	local X = Set.newIntersection(self, o)
	Set:set(X)
end

---@param o Set
function Set.exclude(self, o)
	local S = Set.newExclusion(self, o)
	self:set(S)
end


--
return Set
