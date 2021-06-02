# Excavatinator API
This is the API the addon Excavatinator uses. This exists because Blizzard's API for archaeology is inadequate at the best of times, and exists as a separate addon now for anyone who wants to use Excavatinator's data without requiring Excavatinator's UI installed.

## Excavatinator
This is the name of the object made available in the global namespace to access Excavatinator's data and methods.

#### Excavatinator.ready
A boolean value that indicates whether Excavatinator has had a chance to load all of the information it needs. There is a corresponding event that will be triggered when this has happened.

#### Excavatinator.numberOfRaces
The number of archaeology races in the game.

#### Excavatinator.numberOfCrates
The number of crates (the item "Restored Artifact") the player has in their inventory.

#### Excavatinator.numberOfCrateableArtifacts
The number of artifacts the player has in their inventory that can be crated (i.e. any common artifact from Mists and later). This includes duplicates.

#### Excavatinator.events
Contains general events you may want to listen to. See the Events section for more information.

#### Excavatinator:getActiveDigsites()
Returns a list of active digsites for the player's current continent. The list contains Digsite objects.

#### Excavatinator:getCurrentDigsite()
Returns the digsite the player is currently at, or nil if the player is not at a digsite. This is a Digsite object.

#### Excavatinator:getFindsForDigsite(digsiteID)
Get a list of finds for a specific digsite, or an empty table if there were no finds for that digsite. The list contains Find object.

#### Excavatinator:getFindsForCurrentDigsite()
Get a list of finds for the digsite the player is currently at, or an empty table if the player is not at a digsite. The list contains Find objects.

#### Excavatinator:getAllFinds()
Get a complete list of all finds Excavatinator has recorded. The list contains Find objects.

#### Excavatinator:getCrateableArtifacts()
Get a list of item IDs for the artifacts the player has in their inventory that can be crated. The list will not contain duplicates.

#### Excavatinator:getRaceByIndex(index)
Look up a race by index. Note that this is Excavatinator's index for the race, not WoW's. Returns a Race object.

#### Excavatinator:getRaceByID(id)
Look up a race by ID. This is the ID the game uses for the race; these IDs are not sequential, or even particularly logical. Returns a Race object.

#### Excavatinator:getRaceByKey(key)
Look up a race by its key. The key is a lower case identifier used by Excavatinator, and may be used to look up a race without knowing its index or ID. Returns a Race object. The following are the available keys as of writing:
    - drust
    - zandalari
    - demonic
    - highmountaintauren
    - highborne
    - ogre
    - draenorclans
    - arakkoa
    - mogu
    - pandaren
    - mantid
    - vrykul
    - troll
    - tolvir
    - orc
    - nerubian
    - nightelf
    - fossil
    - draenei
    - dwarf

#### Excavatinator:printUnmappedArtifactInfo()
Print all archaeology projects that could not be mapped to an item or spell name, and then all items that could not be mapped to a project.

## Race
Race objects contain information about the archaeology race they represent. They are returned from Excavatinator's lookup methods, and can also be found on the artifacts.

#### race.id
The numerical ID of the race. This is the same ID that can be used to look it up.

#### race.key
The key of the race. This is the same key that can be used to look it up.

#### race.name
The localised name of the race.

#### race.icon
The icon ID for the race. Can be used with WoW's texture system.

#### race.fragmentID
The ID of the currency used for the race's fragments.

#### race.keystoneID
The item ID of the race's keystone. Will be nil for the Fossil race.

#### race.numberOfArtifacts
The number of artifacts this race has.

#### race.events
Events available for this Race. See the Events section for more information.

#### race:getProgress(includePristine)
Get the player's progress for the race. Returns three numbers: The current progress, the progress max, and the total number of solves. If includePristine is true, this will count pristine artifacts as separate progress points.

#### race:getArtifactByName(name)
Look up an artifact by its name. This can be either the item name or the name of the associated spell, or the name of the associated archaeology project, if it has been mapped. Returns an Artifact object, or nil if none were found. See the Mapping section for more information about mapping.

#### race:getActiveArtifact()
Get the currently active artifact for the race. Returns an Artifact object, or nil if the active artifact was not found.

#### race:getArtifact(index)
Get an artifact by its index. Returns an Artifact object. Can be used with numberOfArtifacts to iterate over the artifacts, if getAllArtifacts is inconvenient to use.

#### race:getAllArtifacts()
Get a list of all artifacts for this race. Each will be an Artifact object.
Note that while the Artifact objects returned are always the same, the table containing them is created on every call. This is done to avoid cross-pollution between addons; the result of this call can safely be cached as the result will never change.

#### race:setArtifactMapping(itemOrSpellName, projectName)
Set the mapping from item or spell name to project name, if they are different. See the Mapping section for more information.

## Artifact
Artifact objects contain information about a single artifact.

#### artifact.race
The race the artifact belongs to. This is the actual Race object, not its ID or any other indirect reference.

#### artifact.itemID
The ID of the item you get when solving the project.

#### artifact.itemName
The name of the item you get when solving the project.

#### artifact.spellID
The ID of the spell used to solve the project.

#### artifact.spellName
The name of the spell used to solve the project. Often matches the item name, but can differ significantly.

#### artifact.icon
The ID of the icon for the artifact, taken from its spell. Can be used with WoW's texture system.

#### artifact.rarity
Either "common" or "rare".

#### artifact.patch
The patch version when the artifact was introduced. Likely of no value most of the time, but can be useful if you want to create a single version of an addon that works with both live data and PTR/beta data.

#### artifact.canCrate
A boolean that indicates whether the artifact is crateable. Does not indicate whether the player can currently crate the artifact, only whether it is crateable by nature.

#### artifact.keystoneSlots
The number of slots available on the project to insert keystones into.

#### artifact.hasPristineVersion
A boolean that indicates whether a pristine version exists for the artifact.

#### artifact.pristineItemID
If the artifact has a pristine version, this is the item ID for it (i.e. the item that starts the pristine quest). If not, this is nil.

#### artifact.pristineQuestID
If the artifact has a pristine version, this is the quest ID for it. If not, this is nil.

#### artifact.pristineHasBeenStarted
A boolean that indicates whether the player has started the pristine artifact quest for the artifact, but not yet turned it in. If the artifact doesn't have a pristine version, this is false.

#### artifact.pristineHasBeenCompleted
A boolean that indicates whether the player has completed the pristine version of the artifact. If the artifact doesn't have a pristine version, this is false.

#### artifact.hasAchievement
A boolean that indicates whether there is one or more achievements associated with solving this project multiple times.

#### artifact.achievementRequirement
The number of times the project must be completed to get the associated achievement. If there are multiple serial achievements, the highest value is used. If there is no achievement, this is nil.

#### artifact.hasBeenCompleted
A boolean that indicates whether the player has completed this artifact at least once.

#### artifact.timesCompleted
The number of times the player has completed this artifact. Will be 0 if they haven't.

#### artifact.events
Events available for this Artifact. See the Events section for more information.

#### artifact:getProgress(useKeystones)
Get the player's progress for this artifact. Returns two numbers and a boolean: The current number of fragments, the total number of fragments needed, and whether the player has enough fragments to solve the artifact. If useKeystones is true, this will use any keystones the player has, up to the artifact's limit. If this is not the active artifact for its race, always returns 0, 0, false.
This function interacts with the default archaeology interface if it is open.

#### artifact:solve(useKeystones)
Solves the artifact if possible. If useKeystones is true, this will use any keystones the player has, up to the artifact's limit. This starts a cast for the player.

#### artifact:isAvailable()
If the artifact is a rare artifact from Legion, returns whether the artifact's quest is available right now (true/false), and for how many weeks (1 for only this week, 2 for this week and next, 0 if not currently available). For all other artifacts, returns (true, 0).

#### artifact:getWeeksUntilAvailable()
If the artifact is a rare artifact from Legion, returns how many weeks (including the current one) until the artifact's quest will be available (e.g. if the artifact will be available next week, this is 1). If the artifact is available right now, this returns 0. For all other artifacts, returns 0.

## Digsite
Digsite objects represent a digsite. These objects are transient, and only remain alive while the digsite is active and the player remains on the continent; the next time the same digsite is encountered a new object is created to represent it.

#### digsite.id
The ID assigned to the digsite by WoW. Numeric

#### digsite.name
The localized name of the digsite, as reported by the WoW API.

#### digsite.race
The race which the digsite produces fragments for, if it is known; nil if it is not. The race will be known if the player has made at least one find at the digsite. This is the actual Race object.

#### digsite.worldMapX
The X coordinate for the digsite's location on the continent map (not a zone map). This is a map coordinate (between 0 and 1).

#### digsite.worldMapY
The Y coordinate for the digsite's location on the continent map (not a zone map). This is a map coordinate (between 0 and 1).

## Find
Finds represent unique locations where the player has found artifact fragments.

#### find.digsiteID
The ID of the digsite this find was made at.

#### find.race
The race the find had fragments for. This is the actual Race object.

#### find.worldX
The X world coordinate for the find.

#### find.worldY
The Y world coordinate for the find.

#### find.mapID
The map ID for where the find was made, and which the map coordinates are for.

#### find.mapX
The X map coordinate for the find.

#### find.mapY
The Y map coordinate for the find.

## Events
Excavatinator API has an event system. The central Excavatinator object has a few general ones, and every Race and Artifact object has some related to that object as well.

### How to use an event

#### event:addListener(fn)
Set a listener to be called every time the event is triggered. The listener will be returned.

#### event:addOnceListener(fn)
Set a listener to be called only the next time the event is triggered. Otherwise behaves like event:addListener(fn).

#### event:removeListener(fn)
Removes a listener. It will no longer receive events. You will need to keep a reference to the original listener to be able to remove it.

### Available events

#### artifact.events.updated
Triggered whenever the artifact object might have changed in some way, for example if it has been completed, or if the number of fragments have changed. No arguments passed.

#### artifact.events.completed
Triggered whenever the artifact has been completed. No arguments passed.

#### race.events.updated
Triggered whenever the race object might have changed in some way, or one of its artifacts might have. No arguments passed.

#### Excavatinator.events.cratesUpdated
Triggered whenever the crate information changes, such as when the player crates an artifact or completes a new one. No arguments passed.

#### Excavatinator.events.enterDigsite
Triggered whenever the player enters a digsite. Passes the digsite as argument.

#### Excavatinator.events.leaveDigsite
Triggered whenever the player leaves a digsite, or the digsite goes away for any other reason (e.g. it's completed). No arguments passed.

#### Excavatinator.events.newDigsiteFind
Triggered whenever the player makes a new find. Does not trigger when the player locates fragments at a previously known find. Passes the find as argument.

#### Excavatinator.events.digsitesUpdated
Triggered whenever the active digsite data changes. This includes when the player makes a first find at a digsite, which makes the digsite's race known.

#### Excavatinator.events.artifactUpdated
Triggered whenever an artifact's updated event triggers. Passes the updated artifact as argument.

#### Excavatinator.events.artifactCompleted
Triggered whenever an artifact's completed event triggers. Passes the completed artifact as argument.

#### Excavatinator.events.raceUpdated
Triggered whenever a race's updated event triggers. Passes the updated race as argument.

#### Excavatinator.events.ready
Triggered once, after Excavatinator has finished loading all of its data. After this has triggered, all data and functions for Excavatinator will be completely ready for use.

#### Excavatinator.events.readyForMapping
Triggered once, after Excavatinator has loaded its race objects but before it loads its artifact objects. This is the ideal time to set up mappings. See the Mapping section for more information.

## Mapping
Blizzard's API for archaeology projects has some limitations. It only returns projects the current character has seen, and those projects do not have unique, universal identifiers, aside from their names. Excavatinator uses these names to match projects to items, but there are times when Blizzard has given different names to a project and its corresponding item or spell. Excavatinator's mapping functionality is its attempt to solve this.

To provide mapping for an artifact, use the race's setArtifactMapping function. This function takes two arguments - the first, the item or spell name, and the second, the project name. The ideal time to do this is when Excavatinator triggers its readyForMapping event.

Excavatinator itself contains code for this mapping for the English artifacts. This code, which also serves as a complete example of how to do mapping, looks like this:

    Excavatinator.events.readyForMapping:addOnceListener(function()
        Excavatinator:getRaceByKey('demonic'):setArtifactMapping('Wyrmy Tunkins', 'Infernal Device')
        Excavatinator:getRaceByKey('highborne'):setArtifactMapping('Dark Shard of Sciallax', 'Orb of Sciallax')
        Excavatinator:getRaceByKey('tolvir'):setArtifactMapping('Crawling Claw', 'Mummified Monkey Paw')
    end)

If you want to see anything Excavatinator knows about unmapped artifacts, call Excavatinator:printUnmappedArtifactInfo(). This will print the unmapped projects and unmapped item names. Note that this will also print the item names of any artifacts you haven't discovered yet, as those also can't be mapped to a project (the API doesn't return them).