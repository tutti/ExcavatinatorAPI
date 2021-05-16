local EXCAVATINATOR_NAME, private = ...

local Race = private.Race
local WoWEvents = private.WoWEvents
local Accessor = private.Accessor

local Excavatinator = {
    events = private.events,
    ready = false,

    numberOfCrates = 0,
    numberOfCrateableArtifacts = 0,
    crateableArtifacts = {},

    numberOfRaces = 0,
}

local eventsAccessor = Accessor:new(private.events)
for k, v in pairs(private.events) do
    eventsAccessor:exposeConstant(k, v.listenable)
end

local racesByID = {}
local racesByKey = {}

local accessor = Accessor:new(Excavatinator)
accessor:exposeValue('ready')
accessor:exposeValue('numberOfCrates')
accessor:exposeValue('numberOfCrateableArtifacts')
accessor:exposeValue('numberOfRaces')
accessor:exposeConstant('events', eventsAccessor.access)
accessor:exposeFunction('getCrateableArtifacts', function()
    local artifacts = {}
    for i, artifact in ipairs(Excavatinator.crateableArtifacts) do artifacts[i] = artifact end
    return artifacts
end)
accessor:exposeFunction('getRaceByID', function(self, id)
    local race = racesByID[id]
    if race then return race.accessor.access end
end)
accessor:exposeFunction('getRaceByKey', function(self, key)
    local race = racesByKey[key]
    if race then return race.accessor.access end
end)

_G.Excavatinator = accessor.access

local function updateCrateInformation()
    Excavatinator.numberOfCrates = GetItemCount(87399)
    local crateables = {}
    local crateableCount = 0

    for r, race in pairs(racesByID) do
        for a, artifact in pairs(race.artifacts) do
            if artifact.canCrate then
                local count = GetItemCount(artifact.itemID)
                if count > 0 then
                    crateables[#crateables+1] = artifact.itemID
                    crateableCount = crateableCount + count
                end
            end
        end
    end
    Excavatinator.crateableArtifacts = crateables
    Excavatinator.numberOfCrateableArtifacts = crateableCount
end

local function load(src)
    for i=1, #private.data.raceList do
        local race = Race:new(i, private.data.races[private.data.raceList[i]])
        racesByID[i] = race
        racesByKey[private.data.raceList[i]] = race
    end

    Excavatinator.numberOfRaces = #private.data.raceList

    updateCrateInformation()

    -- Trigger the readyForMapping event
    private.events.readyForMapping:trigger()

    for i=1, #racesByID do
        racesByID[i]:_attemptLoad()
    end

    -- Trigger the loaded event
    Excavatinator.ready = true
    private.events.ready:trigger()
end

function Excavatinator:getRaceByID(id)
    return racesByID[id]
end

function Excavatinator:getRaceByKey(key)
    return racesByKey[key]
end

-- Wait for everything to be loaded and ready from the API's side before loading
-- anything in the addon
local addonLoaded = false
local historyReady = false
local dataFetched = false

private.loader(function()
    dataFetched = true
    if addonLoaded and historyReady then load() end
end)

WoWEvents.ADDON_LOADED:addOnceListener(function(addonName)
    if addonName == EXCAVATINATOR_NAME then
        addonLoaded = true
        if historyReady then
            if dataFetched then load() end
        else
            RequestArtifactCompletionHistory()
        end
    end
end)

WoWEvents.RESEARCH_ARTIFACT_HISTORY_READY:addOnceListener(function()
    historyReady = true
    if addonLoaded and dataFetched then load() end
end)

WoWEvents.RESEARCH_ARTIFACT_COMPLETE:addListener(function(name)
    for i=1, #racesByID do
        racesByID[i]:_artifactCompletedEvent(name)
    end
end)

WoWEvents.CHAT_MSG_CURRENCY:addListener(function(line)
    -- A currency was added, which might be a fragment
    local s, e = line:find('%b[]')
    if not s then return end
    for i=1, #racesByID do
        racesByID[i]:_currencyEvent(line:sub(s+1, e-1))
    end
end)

WoWEvents.BAG_UPDATE_DELAYED:addListener(function()
    -- An item was added or removed, which might be a keystone
    for i=1, #racesByID do
        racesByID[i]:_itemEvent()
    end

    -- Or it might be a crate or crateable artifact
    local cratesBefore, crateablesBefore = Excavatinator.crates, Excavatinator.crateableArtifacts
    updateCrateInformation()
    if cratesBefore ~= Excavatinator.crates or crateablesBefore ~= Excavatinator.crateableArtifacts then
        private.events.cratesUpdated:trigger()
    end
end)

-- Set up mapping for artifacts in English
-- This is also an example of how this can be done for any other languages
private.events.readyForMapping:addOnceListener(function()
    Excavatinator:getRaceByKey('demonic'):setArtifactMapping('Wyrmy Tunkins', 'Infernal Device')
    Excavatinator:getRaceByKey('highborne'):setArtifactMapping('Dark Shard of Sciallax', 'Orb of Sciallax')
    Excavatinator:getRaceByKey('tolvir'):setArtifactMapping('Crawling Claw', 'Mummified Monkey Paw')
end)