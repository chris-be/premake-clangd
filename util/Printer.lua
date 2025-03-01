--
-- Name:		clangd-config/util/Printer.lua
-- Copyright:	See attached license file
--

---@type Util
local Util = premake.modules.clangd_config.Util

---@class Printer
---@field space string to use for 1 indentation
---@field enabled boolean If write is enabled
---@field indent number Current indentation
---@field onNewLine boolean true if "needs to indent"
local Printer = {}

---@return Printer
function Printer.new(opts)
	local o = opts or {}
	o.space = o.space or '  '
	o.enabled = o.enabled or true
	o.indent = o.indent or 0
	o.onNewLine = o.onNewLine or true
	return o
end
Util.makeClass(Printer)

--- Increment indent level
function Printer.levelDn(self)
	self.indent = self.indent + 1
end
--- Decrement indent level
function Printer.levelUp(self)
	if self.indent > 0 then
		self.indent = self.indent - 1
	end
end

--- Called for each "write" (handle enabled state)
function Printer._write(self, s)
	if self.enabled then
		io.write(s)
	end
end

--- Write a new line
function Printer.newLine(self)
	self:_write('\n')
	self.onNewLine = true
end
--- Write indentation (using indent and space)
function Printer.writeIndent(self)
	if self.onNewLine then
		if self.enabled then
---@diagnostic disable-next-line: unused-local
			for i=1,self.indent do
				io.write(self.space)
			end
		end
		self.onNewLine = false
	end
end
--- Write string (indent if needed)
---@param ... any concatenated items
function Printer.write(self, ...)
	self:writeIndent()

	local va = {...}
	for i=1, select('#', ...) do
		local v = va[i]
		self:_write(tostring(v))
	end
end
--- Same as 'write' and add a newline
function Printer.writeLine(self, ...)
	self:write(...)
	self:newLine()
end

--- Format string and write it
function Printer.writeFmt(self, fmt, ...)
	local str = string.format(fmt, ...)
	self:writeIndent()
	self:_write(str)
end
function Printer.writeLineFmt(self, fmt, ...)
	local str = string.format(fmt, ...)
	self:writeIndent()
	self:_write(str)
	self:newLine()
end


--
return Printer
