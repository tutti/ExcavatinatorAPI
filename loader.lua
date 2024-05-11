local _, private = ...

-- This is a loader that ensures all items and spells are loaded and ready.
-- It takes a callback that will be called when they are.
private.loader = function(callback)
    local itemIDs = {} -- If in Cataclysm, there is no "Crated Artifact"
    if private.TOC_VERSION >= 50000 then
        local itemIDs = { 87399 } -- The "Crated Artifact" item ID
    end
    local spellIDs = { 80451 } -- The "Survey" spell ID

    for k, race in pairs(private.data.races) do
        if private.TOC_VERSION >= race.patch then
            if race.keystone then itemIDs[#itemIDs+1] = race.keystone end
            for i=1, #race.artifacts do
                if race.artifacts[i].patch < private.TOC_VERSION then
                    itemIDs[#itemIDs+1] = race.artifacts[i].item
                    spellIDs[#spellIDs+1] = race.artifacts[i].spell
                    if race.artifacts[i].pristine then
                        itemIDs[#itemIDs+1] = race.artifacts[i].pristine.item
                    end
                end
            end
        end
    end

    local resolvedItemIDs = 0
    local resolvedSpellIDs = 0

    for i=1, #itemIDs do
        local mixin = Item:CreateFromItemID(itemIDs[i])
        mixin:ContinueOnItemLoad(function()
            resolvedItemIDs = resolvedItemIDs + 1
            if resolvedItemIDs >= #itemIDs and resolvedSpellIDs >= #spellIDs then
                callback()
            end
        end)
    end

    for i=1, #spellIDs do
        local mixin = Spell:CreateFromSpellID(spellIDs[i])
        GetSpellDescription(spellIDs[i]) -- It seems sometimes this isn't loaded as part of the mixin
        mixin:ContinueOnSpellLoad(function()
            resolvedSpellIDs = resolvedSpellIDs + 1
            if resolvedItemIDs >= #itemIDs and resolvedSpellIDs >= #spellIDs then
                callback()
            end
        end)
    end
end