--
-- Name:		clangd-config/util/Debug.lua
-- Copyright:	See attached license file
--

---@type Util
local Util = premake.modules.clangd_config.Util
local Printer = Util.Printer

---@class Debug
---@field printer Printer Printer to use
---@field cache table Avoid recursivity
local Debug = {}

---@return Debug
function Debug.new(opts)
	local o = opts or {}
	o.printer = o.printer or Printer.new()
	o.cache = {}
	return o
end
Util.makeClass(Debug)

--- Print recursively object content
---@param self Debug
---@param title any
---@param obj table
---@param maxLevel number? Max recursive level
function Debug.print(self, title, obj, maxLevel)
	local p = self.printer
	local _type = type(obj)
	if _type == "table" then
		if self.cache[obj] then
			p:writeLine("Recursive { ", obj, " }")
		else
			p:write(title, " { ", obj)
			if maxLevel == nil or p.indent < maxLevel then
				p:newLine()
				p:levelDn()
				self.cache[obj] = true
				for key, value in pairs(obj) do
					self:print(key, value, maxLevel)
				end
				self.cache[obj] = nil
				p:levelUp()
			else
				p:writeLine("=> max level reached")
			end
			p:writeLine("}")
		end
	elseif _type == "function" then
		p:writeLine(title, "=> function")
	else
		p:writeLine(title, " = ", obj)
	end
end

--- Print only defined keys
---@param self Debug
---@param title any
---@param obj table
---@param keys string[]
---@param maxLevel number? Max recursive level for filtered values
function Debug.print_values(self, title, obj, keys, maxLevel)
	local p = self.printer
	p:writeLine(title, "{")
	if maxLevel ~= nil then
		-- Take level {} into account
		maxLevel = maxLevel + 1
	end
	p:levelDn()
		for _, k in ipairs(keys) do
			self:print(k, obj[k], maxLevel)
		end
	p:levelUp()
	p:writeLine("]")
end

--- Print a list
---@param self Debug
---@param title any
---@param obj any[]
---@param maxLevel number? Max recursive level for filtered values
function Debug.print_ipairs(self, title, obj, maxLevel)
	local p = self.printer
	p:writeLine(title, "[")
	if maxLevel ~= nil then
		-- Take level [] into account
		maxLevel = maxLevel + 1
	end
	p:levelDn()
		for i, v in ipairs(obj) do
			self:print(i, v, maxLevel)
		end
	p:levelUp()
	p:writeLine("]")
end


--- Convenience: Debug.new():print(title or "", obj, maxLevel)
---@param obj table
---@param maxLevel number?
---@param title any?
function Debug.quick_print(obj, maxLevel, title)
	local dbg = Debug.new()
	title = title or "quick_print"
	dbg:print(title, obj, maxLevel)
end

--- Convenience: Debug.new():print_values(title or "", obj, keys, maxLevel)
---@param obj table
---@param keys string[]
---@param maxLevel number?
---@param title any?
function Debug.quick_print_values(obj, keys, maxLevel, title)
	local dbg = Debug.new()
	title = title or "quick_print_values"
	dbg:print_values(title, obj, keys, maxLevel)
end

--- Convenience: Debug.new():print_ipairs(title or "", obj, maxLevel)
---@param obj table
---@param maxLevel number?
---@param title any?
function Debug.quick_print_ipairs(obj, maxLevel, title)
	local dbg = Debug.new()
	title = title or "quick_print_ipairs"
	dbg:print_ipairs(title, obj, maxLevel)
end



--
return Debug
