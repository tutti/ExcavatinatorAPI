local _, private = ...

local Class = private.Class

local Accessor = Class:extend()
private.Accessor = Accessor

function Accessor:construct(underlying)
    self.underlying = underlying
    self.exposedValues = {}
    self.exposedConstants = {}
    self.exposedVariables = {}
    self.exposedFunctions = {}

    self.access = {}
    setmetatable(self.access, {
        __index = function(tbl, key)
            if self.exposedValues[key] then return self.underlying[key] end
            if self.exposedConstants[key] then return self.exposedConstants[key] end
            if self.exposedVariables[key] then return self.exposedVariables[key](self.underlying) end
            if self.exposedFunctions[key] then return function(_tbl, ...) return self.exposedFunctions[key](self.underlying, ...) end end
            return nil
        end,
        __newindex = function() error('Cannot set value on read-only table.') end,
        __metatable = nil,
    })
end

function Accessor:exposeValue(valueName)
    self.exposedValues[valueName] = true
end

function Accessor:exposeConstant(valueName, value)
    self.exposedConstants[valueName] = value
end

function Accessor:exposeVariable(valueName, func)
    self.exposedVariables[valueName] = func
end

function Accessor:exposeFunction(functionName, func)
    self.exposedFunctions[functionName] = func
end