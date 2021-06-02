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
    --self:exposeValue('firstCompletionTime') -- TODO This feature is incomplete, and not listed in the documentation.
    self:exposeValue('timesCompleted')
    self:exposeValue('pristineHasBeenStarted')
    self:exposeValue('pristineHasBeenCompleted')

    self:exposeFunction('getProgress', artifact.getProgress)
    self:exposeFunction('solve', artifact.solve)

    self:exposeFunction('isAvailable', artifact.isAvailable)
    self:exposeFunction('getWeeksUntilAvailable', artifact.getWeeksUntilAvailable)

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
    self.pristineHasBeenStarted = false
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

    if self.hasPristineVersion then
        if C_QuestLog.IsQuestFlaggedCompleted(self.pristineQuestID) then
            self.pristineHasBeenCompleted = true
        end
        if C_QuestLog.GetLogIndexForQuestID(self.pristineQuestID) then
            self.pristineHasBeenStarted = true
        end
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
        completedPristineArtifact.pristineHasBeenStarted = false
        completedPristineArtifact.pristineHasBeenCompleted = true
        completedPristineArtifact.events.updated:trigger()
    end

    local completedRareArtifact = rareQuestMap[questID]
    if completedRareArtifact then
        completedRareArtifact.hasBeenCompleted = true
        completedRareArtifact.events.updated:trigger()
    end
end)

WoWEvents.QUEST_ACCEPTED:addListener(function(questID)
    local completedPristineArtifact = pristineQuestMap[questID]
    if completedPristineArtifact then
        completedPristineArtifact.pristineHasBeenStarted = true
        completedPristineArtifact.events.updated:trigger()
    end
end)

function Artifact:getProgress(useKeystones)
    -- Return the current progress (number of fragments), the number of total
    -- fragments to solve, and whether the artifact can be solved
    -- If this is not the active artifact, returns 0, 0, false
    -- This will interact with the native archaeology window if it is open

    local activeArtifact = self.race:getActiveArtifact()
    if activeArtifact ~= self then return 0, 0, false end

    SetSelectedArtifact(self.race.index)
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

function Artifact:isAvailable()
    -- Returns whether an artifact is available for discovery right now.
    -- Applicable to rare Legion artifacts only.
    -- Returns a boolean indicating whether the artifact is currently available
    -- as a research quest, and a number indicating how many more weeks,
    -- including the current one. If the artifact is not currently available,
    -- the second number is always 0.
    -- For all other artifacts, always returns (true, 0).

    -- Check whether this is a Legion rare
    if self.rarity == 'common' then return true, 0 end
    if self.race.key ~= 'demonic' and self.race.key ~= 'highmountaintauren' and self.race.key ~= 'highborne' then return true, 0 end

    local cyclePosition = math.ceil(private.Excavatinator.legionCycleWeek / 2)
    local cycleItem = private.data.legionSchedule[cyclePosition]

    if cycleItem.itemID == self.itemID then return true, (private.Excavatinator.legionCycleWeek % 2) + 1 end
    return false, 0
end

function Artifact:getWeeksUntilAvailable()
    -- Returns the number of weeks until this artifact is available as a
    -- research quest. Applicable to rare Legion artifacts only.
    -- If the artifact is the current Legion rare project, this will return 0.
    -- Otherwise, returns the number of weeks until it is, where a 1 means it
    -- will be available next week.
    -- For all other artifacts, this always returns 0.

    -- Check whether this is a Legion rare
    if self.rarity == 'common' then return 0 end
    if self.race.key ~= 'demonic' and self.race.key ~= 'highmountaintauren' and self.race.key ~= 'highborne' then return 0 end

    -- If this is the current project, then we're done - return 0.
    local cyclePosition = math.ceil(private.Excavatinator.legionCycleWeek / 2)
    local cycleItem = private.data.legionSchedule[cyclePosition]
    if cycleItem.itemID == self.itemID then return 0 end

    local weeks = (private.Excavatinator.legionCycleWeek % 2) - 1
    for i=1, #private.data.legionSchedule do
        cyclePosition = cyclePosition + 1
        if cyclePosition > #private.data.legionSchedule then cyclePosition = 1 end
        weeks = weeks + 2

        cycleItem = private.data.legionSchedule[cyclePosition]
        if cycleItem.itemID == self.itemID then break end
    end

    if cycleItem.itemID == self.itemID then return weeks end
    return -1 -- Something went wrong
end