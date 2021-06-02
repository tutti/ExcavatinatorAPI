local _, private = ...

local Class = private.Class
local Find = private.Find
local Timer = private.Timer
local WoWEvents = private.WoWEvents
local Accessor = private.Accessor

local ActiveDigsiteAccessor = Accessor:extend()
function ActiveDigsiteAccessor:construct(activeDigsite)
    Accessor.construct(self, activeDigsite)

    self:exposeConstant('id', activeDigsite.digsite.researchSiteID)
    self:exposeConstant('name', activeDigsite.digsite.name)
    self:exposeVariable('race', function() return activeDigsite.raceID and _G.Excavatinator:getRaceByID(activeDigsite.raceID) or nil end)
    self:exposeConstant('worldMapX', activeDigsite.digsite.position.x)
    self:exposeConstant('worldMapY', activeDigsite.digsite.position.y)
end

function len(pos1, pos2)
    -- Uses the map vector functions of two vectors to calculate their distance
    local pos = pos1:Clone()
    pos:Subtract(pos2)
    return pos:GetLength()
end

local FindManager = Class:extend()

function FindManager:construct()
    if not ExcavatinatorAPIPinDB then ExcavatinatorAPIPinDB = {} end -- In case the variable wasn't set up yet

    self.data = ExcavatinatorAPIPinDB
    self.finds = {}
    self.digsites = {}

    self.activeDigsites = {}
    self.lastActiveDigsites = ''
    self.currentDigsite = nil
    self.lastDigsite = nil

    for i, item in ipairs(self.data) do
        self.digsites[item.digsiteID] = self.digsites[item.digsiteID] or {}
        local find = Find:new(item)
        self.digsites[item.digsiteID][#self.digsites[item.digsiteID]+1] = find
        self.finds[#self.finds+1] = find
    end

    Timer:setInterval(function()
        self:updateDigsite()
    end, 0.1)

    -- Register to listen for the find event
    WoWEvents.ARCHAEOLOGY_FIND_COMPLETE:addListener(function(_, _, raceID)
        self:registerFind(raceID)
    end)
end

function FindManager:updateDigsiteList()
    -- Find the continent level map ID
    local mapID = C_Map.GetBestMapForUnit('player')
    if not mapID then return end -- Player is not on a map (loading screen?)
    local map = C_Map.GetMapInfo(C_Map.GetBestMapForUnit('player'))
    while map and map.mapType ~= Enum.UIMapType.Continent do
        map = C_Map.GetMapInfo(map.parentMapID)
    end
    if not map then return end

    local digsites = C_ResearchInfo.GetDigSitesForMap(map.mapID)

    -- Mark all digsites as inactive first
    for i, digsite in pairs(self.activeDigsites) do
        digsite.active = false
    end

    -- Update the found digsites and mark them active
    for i, digsite in ipairs(digsites) do
        self.activeDigsites[digsite.researchSiteID] = self.activeDigsites[digsite.researchSiteID] or { digsite = digsite }
        if not self.activeDigsites[digsite.researchSiteID].accessor then
            self.activeDigsites[digsite.researchSiteID].accessor = ActiveDigsiteAccessor:new(self.activeDigsites[digsite.researchSiteID])
        end

        if not self.activeDigsites[digsite.researchSiteID].raceID then
            self.activeDigsites[digsite.researchSiteID].raceID = self.digsites[digsite.researchSiteID] and self.digsites[digsite.researchSiteID][1].data.raceID or nil
        end

        self.activeDigsites[digsite.researchSiteID].active = true
    end

    local activeDigsiteIDs = {}

    -- Remove inactive digsites
    for i, digsite in pairs(self.activeDigsites) do
        if not digsite.active then
            self.activeDigsites[i] = nil
        else
            activeDigsiteIDs[#activeDigsiteIDs+1] = i
        end
    end

    -- Sort active digsite IDs
    table.sort(activeDigsiteIDs)

    -- Combine with found race IDs
    local _len = #activeDigsiteIDs -- Because the length'll change
    for i=1, _len do
        activeDigsiteIDs[#activeDigsiteIDs+1] = self.activeDigsites[activeDigsiteIDs[i]].raceID or 0
    end

    -- Create a string to compare to previous
    local activeString = table.concat(activeDigsiteIDs, ',')
    if activeString ~= self.lastActiveDigsites then
        self.lastActiveDigsites = activeString
        private.events.digsitesUpdated:trigger()
    end
end

function FindManager:updateDigsite()
    self:updateDigsiteList()

    if not CanScanResearchSite() then
        self.lastDigsite = self.currentDigsite
        self.currentDigsite = nil
        if self.lastDigsite then private.events.leaveDigsite:trigger() end
        return
    end

    local info = C_ResearchInfo.GetDigSitesForMap(C_Map.GetBestMapForUnit('player'))
    if #info == 0 then
        self.currentDigsite = nil
        return
    end

    local player = C_Map.GetPlayerMapPosition(C_Map.GetBestMapForUnit('player'), 'player')

    local found = info[1]
    local length = len(found.position, player)

    for i=2, #info do
        local newLength = len(info[i].position, player)
        if newLength < length then
            found = info[i]
            length = newLength
        end
    end

    if not self.currentDigsite or found.researchSiteID ~= self.currentDigsite.digsite.researchSiteID then
        self.currentDigsite = self.activeDigsites[found.researchSiteID]
        private.events.enterDigsite:trigger(self.currentDigsite)
    end
end

function FindManager:registerNewFind(findData)
    -- Set up the digsite if it's not already registered
    self.digsites[findData.digsiteID] = self.digsites[findData.digsiteID] or {}

    -- Add the find data to the data list
    self.data[#self.data+1] = findData

    -- Create a Find for the data and add it to the finds and digsites
    local find = Find:new(findData)
    self.digsites[findData.digsiteID][#self.digsites[findData.digsiteID]+1] = find
    self.finds[#self.finds+1] = find

    -- Emit an event for the new find
    private.events.newDigsiteFind:trigger(find.accessor.access)
end

function FindManager:registerFind(raceID)
    local digsite = self.currentDigsite or self.lastDigsite
    if not digsite then return end -- If there is no digsite to tie the find to, ignore it

    local playerMap = C_Map.GetBestMapForUnit('player')
    local playerPosition = C_Map.GetPlayerMapPosition(playerMap, 'player')
    local playerX, playerY = UnitPosition('player')

    local data = {
        raceID = raceID,
        digsiteID = digsite.digsite.researchSiteID,
        worldX = playerX,
        worldY = playerY,
        mapX = playerPosition.x,
        mapY = playerPosition.y,
        mapID = playerMap,
    }

    -- If the digsite is unknown, register as a new find
    if not self.digsites[data.digsiteID] then return self:registerNewFind(data) end

    -- Find the nearest existing find for the digsite
    local nearest = self.digsites[data.digsiteID][1]
    local nearestDistance = math.sqrt(math.pow(playerX - nearest.data.worldX, 2) + math.pow(playerY - nearest.data.worldY, 2))
    for i=2, #self.digsites[data.digsiteID] do
        local distance = math.sqrt(math.pow(playerX - self.digsites[data.digsiteID][i].data.worldX, 2) + math.pow(playerY - self.digsites[data.digsiteID][i].data.worldY, 2))
        if distance < nearestDistance then
            nearest = self.digsites[data.digsiteID][i]
            nearestDistance = distance
        end
    end

    -- If the distance is less than 12, recognise this as the same find
    if nearestDistance > 12 then
        return self:registerNewFind(data)
    end
end

private.loadFindManager = function()
    private.FindManager = FindManager:new()
    return private.FindManager
end