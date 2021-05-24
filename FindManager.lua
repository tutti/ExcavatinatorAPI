local _, private = ...

local Class = private.Class
local Find = private.Find
local Timer = private.Timer
local WoWEvents = private.WoWEvents

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

    self.currentDigsite = nil

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

function FindManager:updateDigsite()
    if not CanScanResearchSite() then
        if self.currentDigsite then private.events.leaveDigsite:trigger() end
        self.currentDigsite = nil
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

    if not self.currentDigsite or found.researchSiteID ~= self.currentDigsite.researchSiteID then
        self.currentDigsite = found
        private.events.enterDigsite:trigger(found)
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
    if not self.currentDigsite then return end -- If there is no digsite to tie the find to, ignore it

    local playerMap = C_Map.GetBestMapForUnit('player')
    local playerPosition = C_Map.GetPlayerMapPosition(playerMap, 'player')
    local playerX, playerY = UnitPosition('player')

    local data = {
        raceID = raceID,
        digsiteID = self.currentDigsite.researchSiteID,
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