# Outdated
This information is not up-to-date at the moment. It will be rewritten.

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

#### Excavatinator:getCrateableArtifacts()
Get a list of item IDs for the artifacts the player has in their inventory that can be crated. The list will not contain duplicates.

#### Excavatinator:getRaceByID(id)
Look up a race by ID. IDs are sequential, with the newest races having the smallest IDs. Returns a Race object. Since the IDs have historically changed when new races are added, if you're looking up a specific race I recommend looking up races by key instead, however IDs are better for iterating over the races.

#### Excavatinator:getRaceByKey(key)
Look up a race by its key. The key is a lower case identifier used by Excavatinator, and may be used to look up a race without knowing its ID. Returns a Race object. The following are the available keys as of writing:
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

## Race
Race objects contain information about the archaeology race they represent. They are returned from Excavatinator's lookup methods, and can also be found on the artifacts.

#### race.id
The numerical ID of the race. This is the same ID that could be used to look it up.

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
A reference to the race the artifact belongs to. This is the actual Race object, not its ID.

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

#### Excavatinator.events.artifactUpdated
Triggered whenever an artifact's updated event triggers. Passes the updated artifact as argument.

#### Excavatinator.events.artifactCompleted
Triggered whenever an artifact's completed event triggers. Passes the completed artifact as argument.

#### Excavatinator.events.raceUpdated
Triggered whenever a race's updated event triggers. Passes the updated race as argument.

#### Excavatinator.events.cratesUpdated
Triggered whenever the crate information changes, such as when the player crates an artifact or completes a new one.

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

## Known issues

## TODO List
- Remove as many interactions with the default archaeology window as possible. Calculate progress by counting keystones and fragments, not by simulating entering the main window.
- Cache digsite objects to ensure they remain the same between uses.