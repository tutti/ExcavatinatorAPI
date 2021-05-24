local _, private = ...

local Class = private.Class
local Accessor = private.Accessor

local FindAccessor = Accessor:extend()

function FindAccessor:construct(find)
    Accessor.construct(self, find)

    self:exposeConstant('digsiteID', find.data.digsiteID)
    self:exposeConstant('race', _G.Excavatinator:getRaceByID(find.data.raceID))
    self:exposeConstant('worldX', find.data.worldX)
    self:exposeConstant('worldY', find.data.worldY)
    self:exposeConstant('mapX', find.data.mapX)
    self:exposeConstant('mapY', find.data.mapY)
    self:exposeConstant('mapID', find.data.mapID)
end

local Find = Class:extend()
private.Find = Find

function Find:construct(findData)
    self.data = findData
    self.accessor = FindAccessor:new(self)
end