# Item Cam 2
Follow an item around your base like in the Factorio trailer. Spiritual successor to [DaveMcW's Item Cam](https://mods.factorio.com/mod/itemcam), rewritten for 2.0 and Space Age content support.

The default hotkey is `Alt + C`, also comes with shortcut "Follow item" in hotbar. When pressed, you select what you want to start follow. If it's supported, almost all GUI elements get hidden and your journey begins.

Pressing same hotkey, or `/stop-item-cam` in chat if you're truly stuck, will stop following your item.

## Bug reporting
The mod is not exhaustively tested. **Guaranteed not to work well in multiplayer**.

If mod errors out while you're following something or it doesn't continue as you're expecting it to:
- Save just before you start following
- Enable `Debug focus tracker` in mod settings and try reproduce your issue
- Once you do, exit game, no need to save
- Post the before save and `factorio-current.log`

`Debug focus tracker` has tick-precise information on the focus tracker's behavior and will make debugging way easier.

## Things it can follow right now
- Belts, splitters, undergrounds, any and all sideload configurations
- Mining drills, assemblers, furnaces (recyclers), etc. with resource/recipe that has some item output
- Inserters, chests, train cargo wagons
- Logistic bots picking up and delivering items
- Space Age content: rockets with cargo, space platform hubs and their pods

## Limitations
- You can't watch the cargo pod processions. API limitation. Sorry!
- You can't select specific item to follow when it comes out of a recipe with multiple results. Not yet
- Focus tracker doesn't know about when item spoils in container. Not yet
- Inserters and mining drills shuffling items on ground can't be tracked. Not yet
- Watching item in space platform hub / cargo landing pad might incur UPS drops because of API limitations and an inefficient polling system

## Things that are planned to be trackable:
- Fluids in general - fluid wagons, pumps
- Crafting machines with recipes that have only fluid output
- Non-SA satellite's Space science pack output
- Specific item coming out of crafting machine depending on conditions. For example, if you're doing scrap recycling first, idea is to tell Item Cam that you specifically want processing unit to get tracked first.
- Loaders, linked belts, other modded content interactions as time goes
