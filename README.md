# rpg game

A 3D open-world sandbox adventure RPG built in **Godot 4.7.2**, inspired by the
systems and freedom of *Skyrim*. Single-player only, with first-person and
third-person cameras.

## Current status

**Phase 3 — Persistence and World**

Working now:

- Boot screen → main menu → test room, with a fade between scenes
- One `CharacterBody3D` player with walk, sprint, jump, gravity, and mouse look
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
- A **chunk manager** that streams `chunk_<x>_<z>.tscn` scenes around the player
  with threaded loading; several managers can sit side by side through
  `chunk_origin`, one per biome
- A **four-biome exterior** reached through the back door, with a stone arch
  that leads back inside:
  - **plains** (grass, broadleaf trees, rocks) around the spawn and the arch
  - **ice** to the north (snow, ice pillars, dead trees, frozen ponds)
  - **desert** to the north-east (sand, cacti, bleached rocks, dry shrubs)
  - **ocean** to the east (shallow sea, sandbars, palms, shells)
- A first **AreaGate** doorway trigger that carries health, inventory, equipment,
  world time, and opened chests/doors across a scene change
- Pause menu with resume, save, load, return to menu, and quit
- Persistent master volume and fullscreen settings
- F3 debug overlay showing FPS, state, camera mode, and position
- Six core Autoload services, input map, named collision layers, audio buses

Not built yet:

- More than two fixed save slots (manual + autosave)
- A town, a house interior, and points of interest in the exterior
- Blended biome edges: today the four biomes meet at straight seams
- Quests, NPC schedules, dialogue, shops, crafting (Phase 4+)
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
| **Mouse** | Look around |
| **Shift** | Sprint |
| **Space** | Jump |
| **Left click** | Attack |
| **E** | Interact with a door or chest |
| **I** | Open / close the inventory |
| **V** | Toggle first / third person |
| **Esc** | Pause / resume (Save and Load live here) |
| **F5** | Quick save to the manual slot |
| **F9** | Quick load the newest save |
| **F3** | Toggle debug overlay |
| **J / M** | Journal / map (future) |

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
camera collision near a wall, walk, sprint, jump, gravity, the door, the chest,
the HUD, the fade overlay, and pausing.

`phase2_smoke` loads the same room and exercises the RPG loop: item
definitions, the item database, stacking and capacity, equip/unequip, health,
stamina, chest loot reaching the inventory, the inventory panel, an enemy that
chases and hits, armor reducing that hit, sword swings killing it, and drinking
a potion.

`phase3_smoke` covers the world clock, the version-1 save format, the slot model,
`newest_slot()` selection, quicksave and autosave isolation (temporarily backing
up and restoring slots 0 and 1), the saveable contract on the player, chests,
the door, and the enemy, a full write/read/apply round trip, corrupt and
future-version saves, chunk streaming from test fixtures, the real
`features/world/chunks/` set and the three biome chunk sets, the room's exit
gate, the HUD clock, and the pause-menu save/load buttons.

They print `PHASE0_SMOKE_OK` / `PHASE1_SMOKE_OK` / `PHASE2_SMOKE_OK` /
`PHASE3_SMOKE_OK` when everything passes.

Saves are written to `user://saves/slot_0/save.json` (manual/quicksave) and
`user://saves/slot_1/save.json` (autosave); on Windows that is
`%APPDATA%\Godot\app_userdata\rpg game\saves\slot_<n>\save.json`.

## Project structure

```text
assets/     models, textures, audio, fonts, animations
core/       autoload services, game state, save helpers
features/   player, interaction, combat, inventory, quests, NPCs, world, UI
data/       item, quest, NPC, ability, and loot definitions
scenes/     boot, menus, and test maps
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
