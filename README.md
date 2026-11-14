# rpg game

A 3D open-world sandbox adventure RPG built in **Godot 4.7.2**, inspired by the
systems and freedom of *Skyrim*. Single-player only, with first-person and
third-person cameras.

## Current status

**Phase 4 — Sandbox life (started)**

Working now:

- Boot screen → main menu → test room, with a fade between scenes
- **Mycelgrove Hollow**, a storybook village built from the reference map:
  main street, chapel, bell tower, bakery, Rowan's house, the seamstress's yew
  cottage, market, keepers' quarter, beekeeping district and Hive Tower, garden,
  cemetery, ruins, river, bridges, and enterable interiors
- Five villagers with a simple day/night schedule: Auntie Bell works behind the
  bakery counter **08:00–18:00**, while Rowan, the blind seamstress, and Thatch
  are outside their homes and go inside at **18:00–08:00**. Thatch walks between
  the Honeyed Way and the Hive Tower by day. Fern wanders the main street at all
  hours. Talk to them with **E**.
- Two short **quests**: Auntie Bell trades a Hearth-Silk for Sporebread, and
  Rowan's ledger page starts the search for the ledger itself
- Two café **customers** who come and go on their own schedule
- A **continuous world** around the village — no separate overworld scene and no
  gates to other maps
- A full-screen **storybook map** on **M**, with a "You are here" marker in town
  and a card for each outlying village
- A **dialogue window** for villagers with speaker, role, multi-line text,
  **E**/**Space** to advance, and **Esc** to close
- One `CharacterBody3D` player with walk, double-tap run, crouch, hold-to-hop
  jump, gravity, and mouse look
- Idle, walk, run, jump, and sword-swing animations on a placeholder humanoid body
- **V** toggles first and third person without moving the player
- Third-person camera that pulls in near walls instead of clipping
- Crosshair, `[E]` interaction prompt, and item notification toasts
- A door that opens and closes, and chests that hand real loot to the player
- **Inventory** (**I**) with stacking, capacity, equip, and use
- **Equipment**: main-hand weapon and body armor change your damage and armor
- **Stamina** that a swing spends and that regenerates over time
- **Melee combat**: left click swings at an enemy in front of you
- One placeholder enemy that idles, chases, and hits back; armor reduces the hit
- Health and stamina bars plus the equipped-weapon readout on the HUD
- **Save / Load** from the pause menu, and **Continue** on the main menu
- **Autosave** on every finished scene change, into a dedicated slot so it can
  never overwrite a deliberate save
- **F5** quick save and **F9** quick load; Continue loads whichever save
  (manual or autosave) is newest
- A versioned, human-readable JSON save that records the scene, world time,
  player position, health, stamina, inventory, equipment, opened chests, opened
  doors, and defeated enemies
- A **world clock** (day and hour) advanced while playing, shown top-right on
  the HUD
- A **continuous exterior** around the village, built at runtime by `TownRealm`
  as a 520 m half-extent ring of ground, roads, rivers, lakes, and seven biome
  regions:
  - **plains** to the south-west and west, **marsh** to the south
  - **arctic** to the north, **deep forest** to the north-east
  - **desert** to the east, **ocean shelf** to the south-east
- Two outlying villages inside the same continuous world: **Ashfall** in the
  northern bog, and **Thornridge** in the eastern rock hills
  - Ashfall: ash grey and bog mud, standing pools, reeds, dead snags, cold violet
    lanterns, and a flag of falling flakes over a marsh
  - Thornridge: slate and rust, rock outcrops, thorn scrub, standing stones, a dry
    gully with a low stone bridge on the road, and a bridge-and-peaks flag
  - Three enterable interiors in each village (houses, a bothy, a shrine, a forge,
    and an inn), plus two wandering villagers per village
- Soft gradient seams between the seven biome floors, so regions blend instead of
  meeting at a hard line
- A dense forest belt with varied tree kinds (round, pine, fern, dead snag,
  stump, cactus), tinted ground grass with flowers and mushrooms, and reeds along
  the water — batched into multi-meshes so a whole meadow costs one draw call
- **AreaGate** doorway triggers that carry health, inventory, equipment, world
  time, and opened chests/doors across a scene change
- **Multi-room interiors** for Rowan (hall, dining room, bedroom, and a study
  holding the desk and ledger) and Auntie Bell (café floor, bar, lounge, and a
  private room behind the counter)
- A **Guest** enemy that lunges, flashes red when hit, and vanishes in a smoke
  puff on defeat
- A **locked café back room**: Auntie Bell hands over a bakery key when the
  Sporebread quest is finished, and the door remembers being unlocked
- Pause menu with resume, save, load, return to menu, and quit
- Persistent master volume and fullscreen settings
- F3 debug overlay showing FPS, state, camera mode, and position
- Six core Autoload services, input map, named collision layers, audio buses

Not built yet:

- More than two fixed save slots (manual + autosave)
- Points of interest in the deeper forest and desert
- Crafting and shops (later in Phase 4)
- Magicka and spells (they arrive with the ability system)
- Death screen, loot drops, and enemy variety (later phases)

## How to run

1. Open `project.godot` in **Godot 4.7.2**.
2. Press **F5** (Run Project).
3. The boot screen routes to the main menu.
4. Choose **New Game** to enter the test room.

## Controls

| Input | Action |
|---|---|
| **W A S D** | Move |
| **W, W (hold)** | Double-tap forward to run |
| **Left Shift** | Crouch |
| **Space** | Jump; hold to keep hopping (costs stamina) |
| **Mouse** | Look around |
| **Left click** | Attack |
| **E** | Interact with a door, chest, or villager; advance dialogue |
| **Space** | Also advances dialogue while it is open |
| **I** | Open / close the inventory |
| **M** | Open / close the storybook map |
| **V** | Toggle first / third person |
| **Esc** | Close dialogue / map, or pause (Save and Load live here) |
| **F5** | Quick save to the manual slot |
| **F9** | Quick load the newest save |
| **F3** | Toggle debug overlay |
| **J** | Journal (future) |

New games start in **first person**. Press **V** to switch to third person and back.

## Validation

Open a smoke test scene in the editor and press **F6**, or run:

```text
godot --headless --path . tests/phase0_smoke.tscn
godot --headless --path . tests/phase1_smoke.tscn
godot --headless --path . tests/phase2_smoke.tscn
godot --headless --path . tests/phase3_smoke.tscn
```

`phase0_smoke` checks the autoloads, main scene, input actions, collision
layers, audio buses, settings round-trip, and pause flow.

`phase1_smoke` loads the real test room and drives the player: camera toggle,
camera collision near a wall, walk, double-tap running, crouch, jump, held-jump
stamina hopping, gravity, the door, the chest, the HUD, the fade overlay, and
pausing.

`phase2_smoke` loads the same room and exercises the RPG loop: item
definitions, the item database, stacking and capacity, equip/unequip, health,
stamina, chest loot reaching the inventory, the inventory panel, an enemy that
chases and hits, armor reducing that hit, sword swings killing it, and drinking
a potion.

`phase3_smoke` covers the world clock, the version-1 save format, the slot model,
`newest_slot()` selection, quicksave and autosave isolation (temporarily backing
up and restoring slots 0 and 1), the saveable contract on the player, chests,
the door, and the enemy, a full write/read/apply round trip, corrupt and
future-version saves, chunk streaming from the `tests/fixtures/chunks/`
fixtures, `chunk_origin` placement, the room's exit gate, the HUD clock, the
town's continuous `Realm` node, and the pause-menu save/load buttons.

They print `PHASE0_SMOKE_OK` / `PHASE1_SMOKE_OK` / `PHASE2_SMOKE_OK` /
`PHASE3_SMOKE_OK` when everything passes.

Saves are written to `user://saves/slot_0/save.json` (manual/quicksave) and
`user://saves/slot_1/save.json` (autosave); on Windows that is
`%APPDATA%\Godot\app_userdata\rpg game\saves\slot_<n>\save.json`.

## Project structure

```text
assets/     models, textures, audio, fonts, animations, maps
core/       autoload services, game state, save helpers
features/   player, interaction, combat, inventory, quests, NPCs, world, UI
data/       item, quest, NPC, ability, and loot definitions
scenes/     boot, menus, town, and the test room
ui/         shared theme resources
tests/      smoke tests
```

## Rules for contributors

Read `AGENTS.md` before changing anything. It defines the architecture, naming,
communication, save, and performance rules for the project.

## Notes

- Do not edit `.godot/`; it is generated by the editor.
- The project is designed around feature folders and small reusable components.
- **Continue** loads the newest save or autosave; it is enabled as soon as
  either slot exists.
