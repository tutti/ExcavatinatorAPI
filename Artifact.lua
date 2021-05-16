local _, private = ...

local Class = private.Class
local WoWEvents = private.WoWEvents
local Event = private.Event
local Timer = private.Timer
local Accessor = private.Accessor

local ArtifactAccessor = Accessor:extend()

function ArtifactAccessor:construct(artifact)
    Accessor.construct(self, artifact)

    self:exposeConstant('race', artifact.race.accessor.access)

    self:exposeValue('itemID')
    self:exposeValue('itemName')
    self:exposeValue('spellID')
    self:exposeValue('spellName')
    self:exposeValue('icon')
    self:exposeValue('rarity')
    self:exposeValue('patch')
    self:exposeValue('canCrate')
    self:exposeValue('keystoneSlots')

    self:exposeValue('hasPristineVersion')
    self:exposeValue('pristineItemID')
    self:exposeValue('pristineQuestID')

    self:exposeValue('hasAchievement')
    self:exposeValue('achievementRequirement')

    self:exposeValue('hasBeenCompleted')
    self:exposeValue('firstCompletionTime')
    self:exposeValue('timesCompleted')
    self:exposeValue('pristineHasBeenCompleted')

    self:exposeFunction('getProgress', artifact.getProgress)
    self:exposeFunction('solve', artifact.solve)

    local eventAccessor = Accessor:new(artifact.events)
    for k, v in pairs(artifact.events) do
        eventAccessor:exposeConstant(k, v.listenable)
    end
    self:exposeConstant('events', eventAccessor.access)
end

local Artifact = Class:extend()
private.Artifact = Artifact

local pristineQuestMap = {}
local rareQuestMap = {}

function Artifact:construct(data, race)
    -- Universal artifact information
    self.race = race -- The race the artifact belongs to
    self.itemID = data.item
    self.itemName = GetItemInfo(self.itemID) or "unknown"
    self.spellID = data.spell
    self.spellName, _, self.icon = GetSpellInfo(self.spellID)
    self.rarity = data.rarity
    self.rareQuestID = data.rareQuest
    if self.rareQuestID then rareQuestMap[self.rareQuestID] = self end
    self.patch = data.patch
    self.canCrate = data.crate or false
    self.keystoneSlots = 0
    self._loaded = false

    -- Pristine artifact information
    self.hasPristineVersion = data.pristine and true or false
    if self.hasPristineVersion then
        self.pristineItemID = data.pristine.item
        self.pristineQuestID = data.pristine.quest
        pristineQuestMap[data.pristine.quest] = self
    end

    -- Achievement artifact information
    self.hasAchievement = data.achieve and true or false
    self.achievementRequirement = data.achieve

    -- Player artifact information (to be overwritten by player data)
    self.hasBeenCompleted = false
    self.firstCompletionTime = 0
    self.timesCompleted = 0
    self.pristineHasBeenCompleted = false

    -- Events
    self.events = {
        updated = Event:new('updated'),
        completed = Event:new('completed'),
    }
    self.events.updated:addListener(function()
        private.events.artifactUpdated:trigger(self.accessor.access)
        self.race.events.updated:trigger()
    end)
    self.events.completed:addListener(function()
        private.events.artifactCompleted:trigger(self.accessor.access)
    end)

    -- Accessor
    self.accessor = ArtifactAccessor:new(self)
end

function Artifact:_loadInfo(description, icon, keystoneSlots, completionTime, completionCount)
    -- Called by the artifact's race when information becomes available
    -- Does not trigger events, as this is related to loading the information
    -- in the first place

    self.description = description or self.description
    self.icon = icon or self.icon
    self.keystoneSlots = keystoneSlots or self.keystoneSlots
    self.firstCompletionTime = completionTime or self.firstCompletionTime
    if completionCount > 0 then
        self.hasBeenCompleted = true
        self.timesCompleted = completionCount
    end

    if self.hasPristineVersion and C_QuestLog.IsQuestFlaggedCompleted(self.pristineQuestID) then
        self.pristineHasBeenCompleted = true
    end

    self._loaded = true
end

function Artifact:_completed()
    -- Internal function
    -- Called when the artifact is marked as completed
    self.hasBeenCompleted = true
    self.timesCompleted = self.timesCompleted + 1
    self.events.updated:trigger()
    self.events.completed:trigger()

    -- Rarely, the completed event goes out before the race's active artifact
    -- has been updated from WoW's side. Set up a backup timeout to deal with
    -- this.
    local activeArtifact = self.race:getActiveArtifact()
    Timer:setTimeout(function()
        local nowActive = self.race:getActiveArtifact()
        if nowActive ~= activeArtifact then
            self.race.events.updated:trigger()
        end
    end, 0.5)
end

-- Add an event listener to listen for completed quests, which marks the
-- pristine version of an artifact as completed if it was a pristine artifact
-- quest, and the same if it was a rare artifact quest (Legion).
WoWEvents.QUEST_TURNED_IN:addListener(function(questID)
    local completedPristineArtifact = pristineQuestMap[questID]
    if completedPristineArtifact then
        completedPristineArtifact.pristineHasBeenCompleted = true
        completedPristineArtifact.events.updated:trigger()
    end

    local completedRareArtifact = rareQuestMap[questID]
    if completedRareArtifact then
        completedRareArtifact.hasBeenCompleted = true
        completedRareArtifact.events.updated:trigger()
    end
end)

function Artifact:getProgress(useKeystones)
    -- Return the current progress (number of fragments), the number of total
    -- fragments to solve, and whether the artifact can be solved
    -- If this is not the active artifact, returns 0, 0, false
    -- This will interact with the native archaeology window if it is open

    local activeArtifact = self.race:getActiveArtifact()
    if activeArtifact ~= self then return 0, 0, false end

    SetSelectedArtifact(self.race.id)
    if useKeystones then
        while SocketItemToArtifact() do end
    else
        -- RemoveItemFromArtifact returns the function itself for some reason
        -- So this just removes 10 keystones, far more than any artifact has
        -- ever used, just to be sure.
        for i=1, 10 do RemoveItemFromArtifact() end
    end

    local fragments, added, needed = GetArtifactProgress()
    return fragments + added, needed, fragments + added >= needed
end

function Artifact:solve(useKeystones)
    -- Solve the artifact if possible
    -- This will start a cast for the player
    local _, _, canSolve = self:getProgress(useKeystones)
    if not canSolve then return end
    SolveArtifact()
end