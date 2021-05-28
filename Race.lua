local _, private = ...

local Class = private.Class
local Artifact = private.Artifact
local Event = private.Event
local Accessor = private.Accessor

local UnmappedArtifact = Class:extend()

function UnmappedArtifact:construct(race, name, description, icon, keystoneSlots, completionTime, completionCount)
    self.race = race
    self.completionCount = 0 -- To avoid passing nil to math.max
end

function UnmappedArtifact:_setData(name, description, icon, keystoneSlots, completionTime, completionCount)
    self.name = name
    self.description = description
    self.icon = icon
    self.keystoneSlots = keystoneSlots
    self.completionTime = completionTime
    self.completionCount = math.max(self.completionCount, completionCount)
end

function UnmappedArtifact:_completed()
    self.completionCount = self.completionCount + 1
end

function UnmappedArtifact:_getData()
    return self.description, self.icon, self.keystoneSlots, self.completionTime, self.completionCount
end

local RaceAccessor = Accessor:extend()

function RaceAccessor:construct(race)
    Accessor.construct(self, race)

    self:exposeValue('id')
    self:exposeValue('key')
    self:exposeValue('name')
    self:exposeValue('icon')

    self:exposeValue('fragmentID')
    self:exposeValue('keystoneID')

    self:exposeVariable('numberOfArtifacts', function() return #race.artifacts end)

    self:exposeFunction('getProgress', race.getProgress)
    self:exposeFunction('getArtifactByName', function(tb, ...)
        local artifact = race:getArtifactByName(...)
        if artifact then return artifact.accessor.access else return nil end
    end)
    self:exposeFunction('getActiveArtifact', function(tb, ...)
        local artifact = race:getActiveArtifact(...)
        if artifact then return artifact.accessor.access else return nil end
    end)
    self:exposeFunction('setArtifactMapping', race.setArtifactMapping)

    -- These functions are only available on the accessor
    -- They don't exist on the actual race object
    self:exposeFunction('getArtifact', function(tb, i)
        local artifact = race.artifacts[i]
        if not artifact then return nil end
        return artifact.accessor.access
    end)
    self:exposeFunction('getAllArtifacts', function(tb)
        local artifacts = {}
        for i, artifact in ipairs(race.artifacts) do
            artifacts[i] = artifact.accessor.access
        end
        return artifacts
    end)

    local eventAccessor = Accessor:new(race.events)
    for k, v in pairs(race.events) do
        eventAccessor:exposeConstant(k, v.listenable)
    end
    self:exposeConstant('events', eventAccessor.access)
end

local Race = Class:extend()
private.Race = Race

-- itemName -> artifactName
-- Crawling Claw -> Mummified Monkey Paw (Tol'vir)
-- Wyrmy Tunkins -> Infernal Device
-- Dark Shard of Sciallax -> Orb of Sciallax

function Race:construct(index, key, data)
    -- Basic information
    self.index = index
    self.key = key
    self.id = data.id
    self.name, self.icon = GetArchaeologyRaceInfo(index)

    -- Fragments and keystones
    self.fragmentID = data.fragment
    self.keystoneID = data.keystone
    self.keystones = self.keystoneID and GetItemCount(self.keystoneID) or 0

    -- Convert artifact data into artifact objects
    self.artifacts = {}
    self.artifactsByItemName = {}
    self.artifactsByItemID = {}
    self.artifactsBySpellName = {}
    self.unmappedArtifactsByName = {}
    self.artifactMappings = {}

    self._lastSeenSolves = 0

    -- Events
    self.events = {
        updated = Event:new('updated')
    }
    self.events.updated:addListener(function() private.events.raceUpdated:trigger(self.accessor.access) end)

    -- Accessor
    self.accessor = RaceAccessor:new(self)

    for i=1, #data.artifacts do
        local artifact = Artifact:new(data.artifacts[i], self)
        self.artifacts[i] = artifact
        self.artifactsByItemName[artifact.itemName:lower()] = artifact
        self.artifactsByItemID[artifact.itemID] = artifact
        local ignoreName = GetSpellInfo(223858)
        if artifact.spellName ~= ignoreName then self.artifactsBySpellName[artifact.spellName:lower()] = artifact end
        -- Some expansions just made "Archaeology Project" the name of the spell
        -- These can't be used to identify the artifact
    end
end

function Race:_attemptLoad()
    local artifactCount = GetNumArtifactsByRace(self.index)
    local unmappedArtifacts = {}
    for i=1, artifactCount do
        local name, description, _, iconID, _, keystoneCount, _, _, completionTime, completionCount = GetArtifactInfoByRace(self.index, i)
        local artifact = self:getArtifactByName(name)
        if artifact then
            if not artifact._loaded then artifact:_loadInfo(description, icon, keystoneCount, completionTime, completionCount) end
        else
            unmappedArtifacts[name:lower()] = self:_getUnmappedArtifactByName(name) or UnmappedArtifact:new(self)
            unmappedArtifacts[name:lower()]:_setData(name, description, iconID, keystoneCount, completionTime, completionCount)
        end
    end

    self.unmappedArtifactsByName = unmappedArtifacts
end

function Race:_artifactCompletedEvent(name)
    -- Internal function

    local artifact = self:getArtifactByName(name)
    if artifact then
        artifact:_completed()
        return
    end
end

function Race:_currencyEvent(currencyName)
    -- Internal function
    -- Called when a currency chat event happened, and checks whether the
    -- currency that changed was the fragment for this race, and if so updates
    -- the race.

    local before = self.fragments
    local currency = C_CurrencyInfo.GetCurrencyInfo(self.fragmentID)

    if currencyName == currency.name then
        local active = self:getActiveArtifact()
        if active then
            active.events.updated:trigger()
        else
            self.events.updated:trigger()
        end
    end
end

function Race:_itemEvent()
    -- Internal function
    -- Might be triggered because an artifact was solved, or the number of
    -- keystones in the player's bags changed.
    -- Or, because something we don't care about happened.

    local didUpdate = false

    local lastSeenSolves = self._lastSeenSolves
    local _, _, solves = self:getProgress()
    if lastSeenSolves ~= solves then didUpdate = true end
    self._lastSeenSolves = solves

    if self.keystoneID then
        local before = self.keystones
        self.keystones = GetItemCount(self.keystoneID)

        if before ~= self.keystones then didUpdate = true end
    end

    if didUpdate then
        local active = self:getActiveArtifact()
        if active then
            active.events.updated:trigger() -- Will also trigger self.updated, which is why that's not done here
        else
            self.events.updated:trigger()
        end
    end
end

function Race:_getUnmappedArtifactByName(name)
    return self.unmappedArtifactsByName[name:lower()]
end

function Race:getArtifactByName(name)
    if self.artifactMappings[name:lower()] then name = self.artifactMappings[name:lower()] end
    return self.artifactsByItemName[name:lower()] or self.artifactsBySpellName[name:lower()]
end

function Race:getActiveArtifact()
    local name = GetActiveArtifactByRace(self.index)
    if not name then return nil end
    return self:getArtifactByName(name)
end

function Race:getProgress(includePristine)
    local completed, total, solves = 0, #self.artifacts, 0
    for i=1, #self.artifacts do
        if self.artifacts[i].hasBeenCompleted then completed = completed + 1 end
        solves = solves + self.artifacts[i].timesCompleted
        if includePristine and self.artifacts[i].hasPristineVersion then
            total = total + 1
            if self.artifacts[i].pristineHasBeenCompleted then completed = completed + 1 end
        end
    end
    self._lastSeenSolves = solves
    return completed, total, solves
end

function Race:setArtifactMapping(itemOrSpellName, artifactName)
    local artifact = self:getArtifactByName(itemOrSpellName)
    local unmapped = self.unmappedArtifactsByName[artifactName:lower()]

    self.artifactMappings[artifactName:lower()] = itemOrSpellName:lower()

    if not (artifact and unmapped) then return end
    if artifact._loaded then return end
    artifact:_loadInfo(unmapped:_getData())
    artifact.events.updated:trigger()
end