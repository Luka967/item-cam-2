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
- Belts, splitters, undergrounds, any and all sideload configurations, modded loaders, linked belts, lane splitters
- Inserters, chests, train cargo wagons, logistic bots picking up and delivering items
- Mining drills, assemblers, furnaces (recyclers), etc. with ability to follow specific item out of multiple results
- Space Age: Plants and how they grow, rockets and their cargo pods, space platform hubs and their cargo pods

## Limitations
- You can't watch the cargo pod processions. It may be possible but was not visited yet
- Focus tracker doesn't know about when item spoils in container. Not yet

## Things that are planned to be trackable:
- Fluids in general - pipes, fluid wagons, pumps, valves
- Crafting machines with recipes that have only fluid output
- Non-SA satellite's Space science pack output
