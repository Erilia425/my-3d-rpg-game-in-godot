# AGENTS.md

Operating manual for AI agents and contributors working on **rpg game**.

Read this file completely before inspecting, creating, editing, or deleting anything.
When a request conflicts with this file, stop and ask the user which rule wins.

---

## 1. Project summary

| Item | Value |
|---|---|
| Working title | **rpg game** |
| Engine | **Godot 4.7.2** (project format 4.7) |
| Genre | 3D open-world sandbox adventure RPG |
| Design reference | *The Elder Scrolls V: Skyrim* (systems and feel, not assets or lore) |
| Perspective | First-person and third-person, toggleable at runtime |
| Players | **Single-player only** |
| Renderer | Forward+ |
| Physics | Jolt Physics |
| Primary development platform | Windows PC (D3D12 configured) |
| Language | GDScript, statically typed where practical |
| Target frame rate | 60 FPS on minimum-spec hardware (hardware TBD) |
| Current phase | **Phase 4 — Sandbox life** (started: villagers, quests, dialogue, schedules, continuous world) |
| Project state | Phases 0-3 implemented. Phase 4 has villagers, day/night schedules, a dialogue window, two quests, a café, multi-room interiors, one continuous world built from a `TownRealm` node, the first magic slice (Recall and Anchor), four named magic teachers (the Blind Seamstress, Thatch, Corin Vale, Silas Graye) with their own curricula, the market vending machine (odd coin, sea glass, gemstones), dirt lanes from the atlas tileset, well lore, a notice board, a communal garden, a revealed minimap, river wading, a code-built workbench in three regional styles, hand-painted odd coin, Field Notes (places walked, rooms entered, stride records, lessons learned), named first-visit lines, synthesised ambience with regional beds and rain trimming, two original music loops, calendar-driven rain and mist, sound sliders in the pause menu, Auntie Bell's shop counter, and village lore for Ashfall and Thornridge. The wider shop economy and the rest of the magic tree are still deferred. |

### Design pillars

1. **A living sandbox.** NPCs, schedules, factions, and world state should continue to feel alive, not wait for the player.
2. **Freedom of approach.** Combat, stealth, dialogue, and exploration should be viable paths where practical.
3. **Persistent consequences.** Opened chests, defeated enemies, completed quests, and changed relationships must survive save/load.
4. **Seamless-feeling exploration.** The world may load behind the scenes, but the player should rarely see a hard stop.

### Original content only

Do not copy Skyrim assets, names, quest text, maps, music, or lore. Use the reference for mechanical inspiration and build original content.

---

## 2. Non-negotiable rules

1. **Inspect before editing.** Read the relevant files and check for existing work first.
2. **Never delete or overwrite existing files without explicit permission.** This includes scenes, scripts, resources, and assets.
3. **Do not skip ahead in the roadmap.** Implement only the current approved phase.
4. **Stop at phase gates.** When a phase is complete, report results and wait for approval before starting the next phase.
5. **Keep changes small and reviewable.** One feature or fix per change set.
6. **Do not add autoloads, addons, plugins, or third-party dependencies without approval.**
7. **Do not change the renderer, physics engine, project settings, input actions, or collision layer meanings without documenting the reason.**
8. **Never edit generated files or folders:** `.godot/`, `.import/`, export output, or engine caches.
9. **Use `res://` paths in code.** Never hard-code absolute filesystem paths.
10. **Ask when requirements are ambiguous.** Do not invent large design decisions.
11. **Leave the project runnable after every change.** Never commit or hand over a broken main scene.
12. **Report every file changed and how to test it.**

### Scope guards

- No multiplayer, networking, lobbies, or server code. This is single-player only.
- No C# or GDExtension without explicit approval.
- No copyrighted or ripped assets.
- No massive asset-pack imports without approval.
- No "while I was here" refactors that are unrelated to the task.
- No rewriting a working system wholesale when a targeted fix will do.

---

## 3. Current project state

Phase 0, Phase 1, and Phase 2 are implemented and validated with Godot 4.7.2:

- `res://scenes/boot.tscn` is the main scene.
- Six autoloads exist: `Events`, `Settings`, `SaveManager`, `SceneRouter`, `Game`, `Debug`.
- The main menu, test room, pause menu, settings, and F3 overlay work.
- Input actions and 3D collision layer names are configured.
- Audio buses exist: Master, Music, SFX, UI, Ambience, Voice.
- `icon.svg` exists and imports correctly.
- Git is initialized; `.godot/` is ignored.
- Smoke tests: `tests/phase0_smoke.tscn` and `tests/phase1_smoke.tscn`.

Phase 1 adds a playable walking skeleton:

- `features/player/player.tscn` — one `CharacterBody3D` for both perspectives.
  Walk, sprint, jump, gravity, mouse look, and **V** first/third-person toggle.
- The player body is a primitive humanoid placeholder under `Visual/Model`
  (torso, head, arms, legs) animated by an `AnimationPlayer` with `idle`,
  `walk`, `run`, and `jump` clips. A rigged model can replace `Visual/Model`
  later without touching movement, collision, or cameras.
- Third-person `SpringArm3D` with camera collision (`world` + `camera_blocker`).
- `features/interaction/interaction_component.gd` — ray from the head along the
  active camera, 3 m reach, emits prompts through `Events`.
- `features/interaction/door.tscn` — hinged door that opens and closes.
- `features/interaction/chest.tscn` — one-shot chest; grants its `loot_id` to the
  interactor's inventory and stays closed when the inventory is full.
- `features/ui/hud.tscn` — crosshair, `[E]` interaction prompt, item toast.
- `SceneRouter` fades to black and back around scene changes.

Phase 2 adds the core RPG loop:

- `data/items/item_data.gd` — one `ItemData` resource class describing every
  item (kind, stack size, value, equip slot, damage, armor, restore amounts).
  Definitions live in `data/items/*.tres`; runtime counts never do.
- `core/utils/item_database.gd` — static `ItemDatabase` mapping ids to preloaded
  definitions. No autoload; add new items to both the folder and this table.
- `features/inventory/inventory_component.gd` — stacks, capacity (slots), add,
  remove, query, and `inventory_changed` / `item_added` / `item_removed`.
- `features/inventory/equipment_component.gd` — main-hand and body slots; moves
  items out of the inventory and derives attack damage and armor.
- `features/stats/health_component.gd` — health pool with damage, heal, death,
  and revive. `features/stats/stats_component.gd` — stamina with regeneration.
  (Magicka is deferred until spells exist.)
- `features/combat/attack_component.gd` — sphere sweep in front of the active
  camera; damages the closest living enemy in reach.
- `features/combat/enemy.tscn` — placeholder enemy: idle, chase, melee attack,
  death. 40 health, 8 damage; flat armor reduction applies on the player side.
- `features/player/player_combat.gd` — attack input, stamina cost, swing
  animation, and a placeholder respawn on death.
- `features/ui/hud.tscn` / `hud.gd` — health and stamina bars, equipped-weapon
  readout, and an inventory panel (**I**) that equips or uses the selected item.
- `features/player/player.tscn` — one player scene now carries
  `HealthComponent`, `StatsComponent`, `InventoryComponent`,
  `EquipmentComponent`, `PlayerCombat`, and `AttackComponent`, plus an `attack`
  clip. Player collision mask became `world + enemy` (5) so bodies collide.

Phase 3 adds persistence, world time, and streaming:

- `core/autoload/save_manager.gd` — version-1 JSON saves at
  `user://saves/slot_<n>/save.json`, written atomically through a temp file.
  `build_save_dict()`, `write_save_dict()`, `read_slot()`, `apply_save()`, and
  `delete_slot()` are public so tests and tools can work without the disk.
  `collect_saveables()` and `get_saved_at()` are public too.
- `features/world/world_clock.gd` — `class_name WorldClock`, a static service
  (no autoload) holding `day` and `hour`. `Game` advances it while playing;
  `SaveManager` persists it under `world.time`.
- The **saveable contract**: a node joins the `saveable` group and implements
  `get_save_id() -> StringName`, `save_data() -> Dictionary`, and
  `load_data(data: Dictionary) -> void`.
  - `features/player/player_controller.gd` — aggregate saveable id `player`:
    position, yaw, pitch, camera mode, health, stamina, inventory, equipment.
  - `features/interaction/chest.gd` — id per instance, `{"open": bool}`.
  - `features/interaction/door.gd` — id per instance, `{"open": bool}`.
  - `features/combat/enemy.gd` — id per instance, position, yaw, health, `dead`.
- `core/autoload/game.gd` — advances the clock, resets it on new game, and
  `load_game()` reads the slot, reloads the recorded scene, then applies the
  save. Save/load UI lives in `features/ui/pause_menu.tscn`.
- `features/ui/hud.tscn` / `hud.gd` — `TimeLabel` plus a 0.5 s `ClockTimer`
  showing `WorldClock.get_time_string()`.
- `features/world/chunk_manager.gd` — `class_name ChunkManager`, streams
  `<chunk_directory>/chunk_<x>_<z>.tscn` within `load_radius` of a tracked node
  using threaded loads and a 0.25 s timer. `chunk_origin` is the world chunk
  coordinate of that folder's `chunk_0_0.tscn`, so several managers (one per
  biome) can tile the world. A missing chunk file is remembered and skipped.
- `features/world/area_gate.gd` — `class_name AreaGate`, an `Area3D` doorway
  that calls `Game.travel_to()`. It arms only after the player has been outside
  it, so arriving inside a gate never bounces the player straight back.
- **Save slots:** slot 0 is the manual/quicksave slot, slot 1 is the autosave
  slot. `Game.autosave()` can never overwrite a manual save. `Game.quick_save()`
  (**F5**) writes slot 0, `Game.quick_load()` (**F9**) loads the newest slot, and
  `Game.continue_game()` does the same from the main menu.
- **Autosave:** `Game` autosaves after every finished gameplay scene change
  (new game, load door). Autosave is suppressed while `load_game()` or
  `travel_to()` is mid-flight, then triggered explicitly after travel.
- `scenes/town.tscn` is the exterior. The separate overworld scene and its chunk
  content were removed: the town grows its own surroundings from a `Realm` node.
- `features/world/town/town_realm.gd` (`class_name TownRealm`) — builds a 520 m
  half-extent ground ring around the 212 m town square: seven biome floors
  (arctic north, deep forest north-east, desert east, ocean shelf south-east,
  marsh south, plains south-west and west), ten gradient seams between those
  floors, three roads, four river extensions, two lakes, the ocean, two outlying
  villages (**Ashfall** in the northern bog and **Thornridge** in the eastern
  rock hills), a dense forest belt plus roadside trees, and batched ground cover.
  Trees vary in size, tint, and kind (round, pine, fern, dead snag, stump,
  cactus) instead of repeating one mesh.
- Performance: forest trees, ground art (rocks, mushrooms, flowers, ferns,
  stumps), reeds, and dead trees are `MultiMeshInstance3D` batches, so a meadow
  of flowers costs one draw call. Only roadside and village trees carry
  colliders. `TownParts.merge_children()` merges each building and ribbon into
  one mesh per material.
- `features/world/chunk_manager.gd` — `class_name ChunkManager`, still present
  and covered by the Phase 3 fixtures, but the shipped world no longer streams
  chunks. `chunk_origin` still places a chunk set in world space.
- `scenes/test_room.tscn` — door, three chests, and the enemy carry stable save
  ids; the back door has a threshold pad and an `ExitGate` to the town.
- `tests/phase3_smoke.tscn` covers all of the above; `tests/fixtures/chunks/`
  holds two tiny fixture chunks used only by that test.

Phase 4 begins with the village:

- `scenes/town.tscn` — **Mycelgrove Hollow**, a blockout of the reference map:
  main street, chapel, bell tower, Auntie Bell's bakery, Rowan's house/office,
  the seamstress's yew cottage, market square, keepers' quarter, beekeeping
  district and Hive Tower, communal garden, cemetery, old settlement ruins, the
  river and its bridges, and 39 enterable interiors.
- `features/npc/npc.gd` + `npc.tscn` — one reusable villager. Primitive body
  with exported colours, floating name/role labels, optional apron, long skirt,
  blindfold, wide-brim hat or beekeeper veil, and optional waypoint wandering.
  Villagers are interactable and speak one-line barks through the HUD toast.
- The four named villagers follow a simple day/night schedule. Auntie Bell works
  behind her bakery counter from **08:00 to 18:00**; from **18:00 to 08:00** she
  is in her private back room. Rowan, the blind seamstress, and Thatch are
  outside their homes **08:00–18:00** and inside the house, yew cottage, and
  beekeeper cottage **18:00–08:00**. Each villager is authored twice — one home
  placement and one daytime placement — and `npc.gd` hides the inactive one from
  `WorldClock`, so nothing teleports between scenes. **Thatch** walks the Honeyed
  Way past the Hive Tower during the day. **Fern** has no home and wanders the
  main street at all hours.
- `features/npc/quest_npc.gd` — `QuestNpc extends Npc`, adding offer, waiting,
  and turn-in lines, a gift on quest start, and a deliver/reward item pair.
  Two quests ship: `quest.sporebread` (Bell: Sporebread → Hearth-Silk) and
  `quest.rowan_ledger` (Rowan: a ledger page, completed by picking the ledger up).
- `features/quests/quest_log.gd` — `class_name QuestLog`, a static quest service
  (no autoload, same pattern as `WorldClock`) holding quest state in the save's
  `world` block.
- `features/combat/guest.gd` + `guest.tscn` — the Guest enemy. A `CharacterBody3D`
  with a `HealthComponent`, an `AnimatedSprite3D` billboard, a tweened lunge, a
  red hit flash, a procedural smoke dissolve on death, one random mushroom or
  flower drop, and save/restore.
- `features/interaction/ledger_book.tscn` + `ledger_book.gd` — Rowan's ledger, a
  saveable interactable that grants the ledger item, finishes
  `quest.rowan_ledger`, and opens two lore pages.
- `features/world/interiors/interior_room.gd` — layouts are chosen by the
  `layout` export. New in this pass: `rowan_manor` (13 × 9.5 m; front hall,
  corridor, dining west, bedroom east-front, study east-back with the desk and
  ledger) and `cafe` (14 × 10 m; bar and oven north, four café tables, a lounge,
  and a private bedroom/store behind the counter), plus partition helpers
  (`_partition_z`, `_partition_x`) and `_sprite_prop()` for upright 2D furniture
  billboards. `hollow_house` is the imported 2D testing house. New in this pass:
  `forge` (hearth, anvil on a stump, quench barrel, slack tub, weapon rack, tool
  shelf, coal bin, bench) for Thornridge.
- `features/world/town/town_realm.gd` — the two outlying villages are data, not
  systems. `VILLAGES` holds each settlement's name, centre, house count, ground
  tints, flag palette and placement, emblem, map card text, interiors, and the
  people who wander it. Both are repainted patches of their region (Ashfall: ash
  grey and bog mud with pools, reeds, dead snags, cold violet lanterns; Thornridge:
  slate and rust with rock outcrops, thorn scrub, standing stones, and a low stone
  bridge over a dry gully on the EastRoad), so neither reads as a house cluster
  dropped on sand or snow.
- Six new interiors reached through runtime `AreaGate` nodes under `Realm` (the
  town's own `Gates` node is untouched): **Ashfall** house, bothy, shrine;
  **Thornridge** house, forge, inn. Each holds one villager and one saveable
  sprite chest. A pale sill pad marks the three doors in each village that open.
- Four unnamed villagers wander the two village greens on a 15 m ring using the
  existing `Npc` scene and primitive bodies: Ashfall's Sable (bog-watcher) and
  Pell (reed-cutter), Thornridge's Halvard (bridge-warden) and Orla (stonecutter).
- Village flags: a cloth banner on a pole at each green. The cloth is drawn into
  an `ImageTexture` at runtime, so the Ashfall flag (grey-white gradient over
  marsh green, three falling flakes above reeds, one flake almost moth-shaped) and
  the Thornridge flag (slate field, white stone bridge, rust peaks) are content in
  `town_realm.gd`, not new art files.
- `assets/maps/mycelgrove_hollow_map.png` — the storybook reference map, kept in
  the project so future town work is checked against it.
- `features/ui/map_screen.tscn` + `map_screen.gd` — the full-screen storybook
  map on **M** (Esc also closes). It is a child of the HUD, so every gameplay
  scene gets it; it blocks the player like the inventory and does not pause.
  In the town it draws a "You are here" tag from the player's world position.
  The two village cards are built at runtime from `TownRealm.VILLAGES` (name,
  mood, symbol, flag swatches), anchored north and east, and the nearest card
  highlights when the player stands near it. Outside the map's world bounds the
  tag hides and the footer names the nearest village instead of resetting to
  "Mycelgrove Hollow".
- `features/interaction/locked_door.gd` + `locked_door.tscn` — a hinged door that
  refuses to open without a key, prints a HUD hint, never consumes the key, and
  persists its `unlocked` state through the save `save_id`. The café's private
  back room uses it (`door.bakery_private`); the key `item.bakery_key` is granted
  by Auntie Bell at the Sporebread turn-in through `QuestNpc`'s
  `extra_reward_item` / `extra_reward_amount`.
- `features/dialogue/dialogue_window.tscn` + `dialogue_window.gd` — the
  storybook conversation panel. A villager emits
  `Events.dialogue_requested(speaker, role, lines)`; the HUD-owned window shows
  one line at a time, **E** or **Space** advances, and **Esc** closes. It blocks
  the player like the inventory, and the map and inventory stay closed while it
  is open.
- `features/ledger/ledger.gd` — `class_name Ledger`, a static service (no
  autoload) recording **imbalance** (0–100) and unpaid **debts**. The HUD word is
  `Balanced` (< 20), `Thin` (20–59) or `Watched` (≥ 60). It saves in the
  `world.ledger` block and is reset by `Game.new_game()`.
- `features/magic/spell_caster.gd` — `class_name SpellCaster`, a Player child.
  **R** casts the first spell, **Recall**: 20 memory charge and one
  `item.memory_honey` dose reveal a nearby `memory`-group target through the
  dialogue window. Silk does not pay the cost; when silk is below 20 the cast
  still works but leaks 10 imbalance into the Ledger. A refused cast never eats
  the dose.
- `features/magic/memory_stone.gd` + `memory_stone.tscn` — a stone that keeps a
  title and a paragraph. **E** on it asks the player's SpellCaster to Recall it,
  so the stone and **R** share one rule and one cost. The visual is built in
  code. `Realm/CaveMemoryStone` stands beside the Old Adit.
- `data/items/memory_honey.tres` — prepared honey (`restore_mana = 40`), made by
  `recipe.memory_honey` from 1 ordinary honey + 1 Hearth-Silk Thread. Ordinary
  honey stays food; only prepared honey is spell fuel.
- `StatsComponent` now also owns **silk** (`max_silk`, repaired, never
  regenerated) and **anchoring** (a tooth count, `max_anchoring`) beside the
  memory pool. `get_memory()` / `spend_memory()` / `restore_memory()` are
  aliases for the old mana API so saves and the bed keep working.
- `features/magic/magic_lessons.gd` — `class_name MagicLessons`, a static service
  (no autoload) holding every named teacher's curriculum. Four teachers: the
  Blind Seamstress (5 lessons — honey moves, silk holds, teeth anchor, the Ledger
  keeps the account, what she knows of Fern), Thatch (3 — the hive makes the
  fuel, honey must be prepared, what the swarm remembers), Corin Vale (3 — a
  tooth is a name, do not improvise, what is filed stays filed), and Silas Graye
  (3 — the Ledger records, debt is not evil, who keeps the account). Fourteen
  lessons in all. Progress is `QuestLog` flags under
  `teach.<teacher_id>.<n>`, so both placements of a person share one curriculum
  and a save remembers it. `get_taught_total()` / `get_total()` feed Field Notes.
- `features/npc/magic_teacher.gd` — `class_name MagicTeacher extends QuestNpc`.
  The conversation in front of a curriculum: quest lines first (so Thatch and the
  Seamstress keep their quests untouched), then one lesson per talk, then a
  repeat line once the curriculum is finished. The `curriculum` export picks the
  list and `teacher_id` is the save namespace (it falls back to the curriculum
  id). A lesson with a gift is **not** marked taught when the bag is full, so the
  gift is never lost. An unfinished teacher wears a floating `LessonMarker`
  counting the lessons left. The Seamstress's last lesson follows the
  `OPEN_QUESTIONS` decisions of 2026-11-13 and unlocks
  `discovery.what_she_knows`.
- Teacher placements: the Seamstress is on the street **08:00–18:00** and in
  `seamstress_cottage.tscn` at night; Thatch walks the Honeyed Way **08:00–18:00**
  and is in `beekeeper_cottage.tscn` at night; Corin Vale is in the square
  **08:00–18:00** and in `toothkeepers_house.tscn` at night; Silas Graye keeps
  the edge of the trees at all hours.
- `features/magic/spell_caster.gd` — the second spell, **Anchor** on **T**
  (`cast_anchor`). It spends one tooth and 10 memory and holds for
  `StatsComponent.anchor_guard_seconds` (60 s). While it holds, `can_contain()`
  returns true, so a Recall the silk cannot hold does not leak. The guard is
  transient and never written to a save; the HUD Anchors row reads
  `Anchors 2/3 (held)` while it lasts.
- Field Notes: the Stride column ends with **Lessons learned N of 14**, read from
  `MagicLessons`.
- Interior layouts `_seamstress` and `_office` now contain a usable bed
  (`_bed_body()`), so the Seamstress and the Toothkeeper have somewhere to sleep
  and the player can rest there. `_hive` stays a workplace.
- `features/world/town/town_building.gd` — building nameplates moved from the
  roof to a **door-level `DoorPlate`**. New `owner_name` and `is_home` exports
  produce two short lines: the building name, then `Home of <owner>`, or
  `Empty` for a home with no owner. A building with no label, no owner and
  `is_home = false` gets no plate, so background cottages stay quiet.
- HUD: `Vitals` shows **Memory** (label + bar) and one compact row —
  `Silk`, `Anchors`, `Ledger: …` — instead of a blue mana bar. The Ledger word
  refreshes with the 0.5 s clock timer.
- `features/interaction/vending_machine.gd` + `vending_machine.tscn` — the
  unlabelled machine in the market square (`Machine.market_square` id,
  `machine.market_square` save id). Six slots, all hidden until the odd coin
  goes in. After that it takes **sea glass** and **pale gemstones** (both mined
  in the Old Adit) and vends moss-covered rocks, small opals, mushrooms to
  plant, tiny sacks of dirt, faux ivory brooches, and a gnome statue. Payment is
  taken only after the goods fit in the bag; a refused vend costs nothing.
  The panel is code-built like the cart's, and the cabinet is code-built like
  the memory stone. Teeth are deliberately **not** currency here.
- `data/items/spider_coin.tres` — **The Odd Coin**, the machine's key. It waits
  in Rowan's own house (`features/world/interiors/rooms/rowans_house.tscn`,
  node `OddCoin`, save id `pickup.town.rowans_house.odd_coin`).
- `features/world/cave/mine_cave.gd` — new `GlassSeam0` seam
  (`gather.cave.glass_0`) drops sea glass, with a gemstone as its rare extra.
  `item.seaglass`, `item.moss_rock`, `item.small_opal`,
  `item.faux_ivory_brooch`, `item.planting_mushroom`, `item.dirt_sack` and
  `item.gnome_statue` are new definitions in `data/items/` with icons in
  `assets/icons/items/`.
- `scenes/town.tscn` — the machine stands at `(10.5, 0, 0.5)` facing the
  square, clear of the stalls and carts (checked with a physics overlap query,
  not by eye).

- `features/interaction/lore_well.gd` + `lore_well.tscn` — three town wells
  (`WellCounting`, `WellHoney`, `WellBell`) that speak through the dialogue
  window and pay once: 12 silk, a jar of honey, and a Hearth-Silk Thread. The
  reward is stored under a `QuestLog` flag, so a paid well only remembers. A low
  warm light makes each one findable at dusk.
- `features/quests/bounty_board.gd` + `bounty_board.tscn` — the market notice
  board. Four repeatable bounties (fieldstone, spruce, flowers, mushrooms) pay
  coins and experience through `Progression`; the board saves how many times
  each bounty was filled.
- `features/world/town/garden_plot.gd` + `garden_plot.tscn` — the communal
  garden bed. A planting mushroom plus a dirt sack plant a crop; after
  `grow_days` (2) it harvests three mushrooms and returns one seed. Moss rocks
  and the gnome statue can be placed in the bed.
- `features/world/world_map.gd` — `class_name WorldMap`, a static service like
  `QuestLog` (no autoload). It records `CELL_SIZE`-metre squares as the player
  walks (`REVEAL_RADIUS` 26 m) and saves them in `world.map`; a new game clears
  it. `Game.new_game()`, `Game._transient_save()` and `SaveManager` all carry it.
- `features/ui/minimap.gd` — the corner parchment map. It draws only revealed
  squares, tints the town and the two roads, turns an arrow with the player, and
  hides while the map, inventory, or dialogue owns the screen. It redraws on the
  HUD's 0.5 s clock tick, never per frame.
- `features/world/river_wade.gd` — `class_name RiverWade`, one area per river
  with a box per polyline segment. Inside it the player moves at `speed_scale`
  (0.55) and hears one line the first time; bridges stay the dry route. Wading
  is felt, never a wall, so falling in cannot soft-lock a run.
- `features/world/town/town_realm.gd` — `_paths()` lays nine atlas-cut dirt and
  cobble lanes from the market to the bakery, Rowan's house, the chapel, the
  keepers, the north and east gates, and the south and row lanes, with more
  house-to-house lanes stitched in. `_verge_flowers()` mixes three new flower
  cluster textures into every verge. `_river()` now spawns the wading area.
  `_hidden_memories()` places four reward-paying memory stones away from the
  roads (`HiddenMemoryMill/Ferry/Swarm/Names`).
- `assets/from_2d/materials/path_dirt.png`, `path_cobble.png` and
  `assets/from_2d/sprites/flower_cluster_a|b|c.png` — cut from
  `Fantasy Village Path Tileset Atlas.png`; the sprite flowers are keyed to
  transparency.
- `features/crafting/crafting_station.gd` — the station's shipped box `Mesh` is
  hidden and a code-built `Bench` takes its place, so the market bench reads as a
  workbench without an art import. The bench is dressed in planks with gaps,
  splayed legs, stretchers, a shelf, a basket/crate/bundle, a vice with a screw
  and handle, a tool rail with three hanging tools and a leaning saw, a lit
  lantern (with a warm `BenchLight`), a stool, sprigs, floor shavings, and a brass
  plaque. Helpers `_placed_box()` and `_cyl()` keep it readable.
- `assets/from_2d/sprites/odd_coin.png` / `assets/icons/items/spider_coin.svg` —
  The Odd Coin is drawn rather than fetched: a wobbling hand-cut silver rim, a
  gold face, a beaded ring, and an engraved spider, with pits, scratches, and a
  chipped edge. The sprite is 96 × 96 with a transparent edge and a soft shadow.
- `features/player/movement_stats.gd` — `class_name MovementStats`, a static
  service (no autoload) keeping four numbers: jumps taken, best jump height, best
  drop, highest point, and best airtime. `player_controller.gd` calls
  `record_jump()` on takeoff and `record_landing()` from `_track_air()`, so
  walking off a ledge counts as a drop. Saved as `world.movement`.
- `features/world/exploration_log.gd` — `class_name ExplorationLog`, a static
  service listing 14 named areas as ground circles (the Hollow's squares and
  districts, the Old Adit, then Ashfall and Thornridge). The HUD calls `check()`
  on its 0.5 s tick, so no new `Area3D` and no edits to the 39 interiors. A first
  visit announces itself once through the toast. Saved as `world.exploration`.
- `features/ui/field_notes.tscn` + `field_notes.gd` — the Field Notes panel on
  **C**: a parchment sheet with a ticked Places list and a Stride column (jumps,
  highest jump, longest drop, longest airtime, highest point). It is a HUD child,
  blocks the player like the inventory, and closes with **C** or **Esc**.
- `core/autoload/debug.gd` — the F3 overlay gained two lines: jumps/best/drop and
  places seen out of the total.
- `assets/audio/ambience/` — four original synthesised loops (wind, night drone
  with crickets, river flow, distant bell). Nothing is sampled from a recording.
- `features/world/ambient_audio.gd` — `class_name AmbientAudio`, a plain node in
  `scenes/town.tscn` (not a seventh autoload). Day plays the wind loop, night the
  drone plus occasional distant bells; `looped_wav()` sets the loop at runtime so
  import settings cannot break it. `make_river_loop()` builds one positional
  `AudioStreamPlayer3D` per river, owned by its `RiverWade` area.
- `features/world/town/town_realm.gd` — `_village_lore()` adds one well and two
  hidden memory stones to each outlying village: `AshfallWell` (pays 12 silk),
  `HiddenMemoryAshfallCount`, `HiddenMemoryAshfallLantern`,
  `ThornridgeWell` (pays three stone), `HiddenMemoryThornBridge`, and
  `HiddenMemoryThornQuarry`. Every reward pays once under a `QuestLog` flag.
- `data/items/small_opal.tres` / `faux_ivory_brooch.tres` — the two vended
  trinkets now do something: the opal repairs 18 silk, the brooch grants one
  anchor slot. `ItemData` gained `restore_silk` and `grant_anchoring`, applied by
  `PlayerController.use_item()`.
- `features/interaction/vendor_counter.gd` + `vendor_counter.tscn` — `class_name
  VendorCounter`, a standing counter where one villager sells their own goods.
  `TABLES[&"bell"]` is Auntie Bell's list: sporebread 6, honey 5, prepared
  (memory) honey 14, cabbage x2 for 3. Coins come from `Progression` and goods go
  into `InventoryComponent`, so the counter owns neither. `get_price()` applies
  the vendor's own favor discount (`Progression.get_discount`), every purchase
  adds one favor, and payment is taken only after the goods fit, so a full bag
  never eats the coins. It is deliberately separate from the market's
  `LedgerShopPanel`: that is a general store of upgrades, this is someone's
  counter with a face behind it. `BellCounter` stands in `bakery_interior.tscn`
  at `(1.6, 0, -1.45)`, on clear floor in front of the café bar.
- `features/crafting/crafting_station.gd` — `station_kind` (`market`, `forge`,
  `loom`) changes the working clutter while the frame stays the same, so a bench
  is recognisable anywhere. The market bench keeps the vice, tool rail, saw,
  basket, crate, stool, sprigs and shavings; the forge bench swaps in an anvil
  with a horn and hammer, tongs, a quench barrel, a coal heap and a low red forge
  fire; the loom bench builds an upright frame with warp threads, spools, a
  finished bolt and scissors. `_bench_lamp()` is shared, so each bench has its own
  light at its own colour and strength. `thornridge_forge.tscn` is `forge`; a new
  `LoomStation` in `old_loom_tower.tscn` is `loom` (thread and prepared honey).
- `features/world/weather.gd` — `class_name Weather`, one node in
  `scenes/town.tscn`. Weather is derived from the calendar, not stored:
  `kind_for_day(day)` uses `posmod(day, 7)` so days 0 and 4 rain, day 2 is misty
  and the rest are clear. That means an old save loads into the weather that day
  always had, and no save field is needed. Rain is one `CPUParticles3D` that
  follows the player twice a second. The node never touches the sun; it hands a
  calm-weather fog density to `FogSurge.set_base_density()`, so the two systems
  cannot fight over `environment.fog_density`.
- `features/world/fog_surge.gd` — gained `set_base_density()`, the one hook
  `Weather` uses. While a surge is running the new value is picked up on the next
  transition; while calm it applies at once.
- `assets/audio/music/` + `features/audio/music_player.gd` — `class_name
  MusicPlayer`, one looping bed per scene: `menu_theme.wav` on the main menu and
  `hollow_theme.wav` in the town. Deliberately a plain node, not an autoload, so
  the six approved services stay six and a track dies with its scene. The loop is
  set at runtime through `AmbientAudio.looped_wav()`, the volume rides the `Music`
  bus, and a fade-in keeps a scene change from starting with a click.
- `assets/audio/ambience/` — three more original loops: `marsh_insects.wav`,
  `snow_hush.wav`, `cave_drips.wav`. `AmbientAudio` gained a third player
  (`Region`, -25 dB) chosen by the player's position, using the same north/south/
  east bands as the realm's floors, plus `rain_trim_db` so the base loop drops
  6 dB while it rains. `get_region()` exists for tests.
- `features/world/exploration_log.gd` — gained rooms and a written line per
  place. Interiors are counted by **scene**, not position (`note_scene()` +
  `ROOM_PREFIX`, id `room.<file_basename>`), because every interior places the
  player near the origin and a distance test would tick the market. `ROOM_TITLES`
  names the rooms whose file name reads badly, with a camel-case prettify
  fallback. `LINES` holds one sentence per area; `get_line()` returns it. Rooms
  save under `world.exploration.rooms`.
- `features/ui/hud.gd` — `_note_places()` now branches: the town counts by
  position, any other scene calls `_note_room()`. A first visit speaks through
  `Events.dialogue_requested("Field Notes", title, [line])` instead of a bare
  toast, so the note arrives as a sentence; if a conversation is already open it
  falls back to the toast rather than stacking panels.
- `features/ui/field_notes.gd` — the Places scroll ends with a `Rooms entered (N)`
  section listing the interiors walked into.
- `core/autoload/settings.gd` — `audio/ambience_volume` (0.8) is a real setting
  and applies the `Ambience` bus. `features/ui/pause_menu.gd` builds the sound
  rows in code above **Resume** (`MusicRow`, `AmbienceRow`, `EffectsRow`), each
  with a slider that writes the setting, saves it and re-applies the buses. The
  shipped scene layout and every `%UniqueName` in it are untouched.

- `features/world/town/town_ribbon.gd` — a lane, river, or road is now **one
  welded strip**, not a chain of boxes with a square patch on every bend. The
  old geometry is what made a dirt lane read as a row of stamped tiles: each
  piece met the next at a seam, and the joint patches squared off every corner.
  `_build_strip()` walks the polyline once, mitres the shared edge so the width
  holds around a bend, and emits one `ArrayMesh`. Width tapers over the last 3 m
  at each end (to 55%) and wobbles ±7% along the length, so a path starts and
  stops in the grass instead of being cut off square. Water keeps an even width.
  The textures are unchanged and still triplanar-projected; only the geometry
  moved. Ripples are untouched.
- `features/npc/npc.gd` — `wander_radius`, `wander_center` and
  `wander_point_count` join the existing authored `wander_points`. When a radius
  is set and no points are authored, `_prepare_wander()` builds a ring at load
  time, seeded from `hash(npc_name)`, so the same villager takes the same route
  every load and a save never catches them mid-teleport. Nine town villagers now
  walk the market square on their own rings; the four outlying-village folk keep
  their authored 15 m rings around their own green.
- `features/world/fog_surge.gd` — a surge is now **dangerous**, not just
  atmospheric. While the fog holds (`_haunt()`, hold phase only) it drains memory
  charge (`memory_drain_per_second`, 3.0) and frays silk
  (`silk_drain_per_second`, 1.0), and every `summon_interval` (7 s) it sends a
  creature out of the mist, up to `max_summons` (3). A summon only appears on
  open ground: `_mist_spot()` raycasts the floor and rejects any spot already
  inside a collider, so nothing steps out of a wall. `force_surge()`,
  `is_dangerous()` and `get_summon_count()` exist for tests. Setting
  `dangerous = false` restores the old atmosphere-only behaviour.
- `features/world/cave/wild_caves.gd` (`class_name WildCaves`) — a cave that is a
  different cave every time it is entered. The Old Adit (`mine_cave.tscn`) is
  untouched and stays a fixed, saveable mine. This generator lays four to seven
  overlapping circles as chambers; a chamber's wall ring skips any arc that is
  already inside a neighbour, so two overlapping circles leave a passage instead
  of a wall. That one rule produces the whole cave, with no corridor authoring
  and no way to generate a sealed room. One floor and one ceiling span the
  bounds; walls are unrotated rock blocks so art and collision match exactly
  (`TownParts.collision()` is axis-aligned only). Boulders, stalagmites,
  stalactites and roof lumps break up each chamber; one Omni light per chamber
  plus glowing crystal clusters keep it dark. Seams, ghost spiders and the way
  out are added per visit, and **nothing inside is saveable**: a cave that
  changes shape should not remember what was mined in a shape that is gone.
  `get_cave_seed()`, `get_chamber_count()` and `get_wall_count()` exist for tests.
- `features/world/cave/wild_caves.tscn` — the wild cave as a playable scene:
  player, HUD, pause menu, and a `Music` node playing `cave_theme.wav`.
- `features/world/cave/spider_lair.tscn` — the Spider Mother's lair: the same
  generator with `fixed_seed = 20261114`, `is_lair = true`, three or four
  chambers, two ghost spiders, web strands, hanging cocoons, violet light and one
  seam. A lair should not move between visits, so its seed is fixed and its
  gate is stable.
- `features/npc/spider_mother.gd` (`class_name SpiderMother extends QuestNpc`) —
  her silhouette is the point: a woman's torso above a spider's abdomen, eight
  legs in four pairs, pale web markings down her back, a shawl of thread, and
  four small eyes instead of eight (the face is still a woman's). Only
  `_build_model()` is overridden, so her dialogue, gift, quest lines and save
  data are the same `QuestNpc` behaviour as every other villager.
- `scenes/town.tscn` — the `SpiderMother` node left `Villagers`. She now stands
  in `spider_lair.tscn`, and her old standing spot in the open grass south of the
  old cottages is the way down to her.
- `features/world/town/town_realm.gd` — `_spider_stair()` builds that way down at
  `LAIR_STAIR = (-12, -46)`: a stone mound, two pillars and a lintel framing a
  black opening, three shallow steps, violet lanterns, webbing across the lintel,
  a `The Webbed Stair` sign, and a `LairGate` (`AreaGate`, `interior = true`) into
  `spider_lair.tscn`. The town's ground is one solid slab, so the stair cannot be
  dug into it: the arch stands at ground level and the gate at its mouth carries
  the player into the part that is actually underground. The spot is registered
  as a keep-clear circle so no tree grows through it. `_wild_cave_mouth()` builds
  a second way down at `WILD_CAVE_MOUTH = (-56, -62)`: the `Breathing Cleft`, a
  split in a low outcrop with cold blue lanterns, and a `WildCaveGate` into
  `wild_caves.tscn`.
- `features/interaction/stuffed_rabbit.gd` (`class_name StuffedRabbit extends
  StaticBody3D`) — Mister Rabbit, stitched from grey cloth with one red button
  eye, a patched belly and an ear sewn back on. He breathes (a 1.4 cm vertical
  swell), he turns to face anyone within 3.5 m and keeps facing them, and looking
  at him offers three lines about a toy that is warmer than it should be. Nothing
  explains it. E on him opens the dialogue window.
- `features/world/interiors/rooms/garden_cottage.tscn` — `MisterRabbit` sits
  beside `LittleEli`.
- `assets/audio/music/cave_theme.wav` + `tools/make_cave_theme.py` — a 28-second
  original cave loop: a low drone, a brown-noise breath, scattered water drips and
  two far rumbles. Every sustained tone completes a whole number of cycles in
  28 s, so the loop has no click; the first and last 40 ms are tapered against
  any DC offset. Synthesised, not sampled.
- `tests/gathering_smoke.gd` — grew to **347 checks**. New checks: a lane is one
  welded `ArrayMesh`; each of the nine town villagers wanders with at least four
  points; at least four village folk wander their own green; the Spider Mother is
  gone from `Villagers` and a `LairGate` into `spider_lair.tscn` stands in her old
  spot; a `WildCaveGate` into `wild_caves.tscn` opens out past the old cottages;
  fog is dangerous, drains memory and silk, and summons a creature; the lair keeps
  its seed and holds the Mother with an abdomen, legs and a head; two wild cave
  visits produce different seeds; and Mister Rabbit is interactable, named when
  looked at, and built from more than one part.

Still deferred: the wider shop economy (one counter exists), the five magic
branches, and spells beyond Recall. Four named teachers exist (the Blind
Seamstress, Thatch, Corin Vale, Silas Graye) and the Anchor spell ships, but the
wider magic tree does not.

The project folder path contains a space (`rpg game`). This is harmless; do not
rename or move it without permission.

---

## 4. Architecture

### 4.1 Style

Use **feature-first folders**, **component composition**, **data-driven Resources**, and a **thin service layer**.

Do not build deep inheritance trees. Do not create one giant `player.gd` or `game.gd`.

```text
Player (CharacterBody3D)
├── CollisionShape3D
├── Visual (Node3D)
├── CameraRig (Node3D)
│   ├── FirstPersonCamera (Camera3D)
│   └── ThirdPersonArm (SpringArm3D)
│       └── ThirdPersonCamera (Camera3D)
├── HealthComponent
├── StatsComponent
├── InventoryComponent
├── InteractionComponent
├── StateMachine
└── AnimationTree
```

Each component:

- owns exactly one responsibility,
- exposes a small public API,
- announces changes with signals,
- never reaches into unrelated branches of the scene tree.

### 4.2 Layers

```text
┌──────────────────────────────────────────┐
│ UI / Input                               │
│ HUD, menus, prompts, keybinds            │
└──────────────────┬───────────────────────┘
                   │ commands (method calls)
┌──────────────────▼───────────────────────┐
│ Gameplay features                        │
│ player, combat, inventory, quests, AI    │
└──────────────────┬───────────────────────┘
                   │ facts (signals / events)
┌──────────────────▼───────────────────────┐
│ Core services                            │
│ Events, Game, SceneRouter, Save, Settings│
└──────────────────┬───────────────────────┘
                   │
┌──────────────────▼───────────────────────┐
│ Data definitions + world content         │
│ Items, quests, NPCs, regions, loot       │
└──────────────────────────────────────────┘
```

### 4.3 Folder structure

```text
res://
├── AGENTS.md
├── README.md
├── project.godot
├── .gitignore
├── assets/
│   ├── models/
│   ├── textures/
│   ├── audio/
│   ├── fonts/
│   └── animations/
├── core/
│   ├── autoload/          # events.gd, game.gd, scene_router.gd, ...
│   ├── state/             # game state machine
│   ├── save/              # saveable contract, migrations
│   └── utils/             # IDs, helpers, validation
├── features/
│   ├── player/
│   ├── interaction/
│   ├── stats/
│   ├── combat/
│   ├── inventory/
│   ├── ai/
│   ├── npc/
│   ├── dialogue/
│   ├── quests/
│   ├── world/             # chunks, spawners, time, saveables
│   └── ui/                # HUD, menus, screens
├── data/
│   ├── items/             # .tres item definitions
│   ├── quests/
│   ├── npcs/
│   ├── abilities/
│   └── loot/
├── scenes/
│   ├── boot.tscn
│   ├── main_menu.tscn
│   └── test_room.tscn
├── ui/
│   └── theme/
└── tests/
```

Each feature folder contains its own scenes, scripts, components, and resources. Put things where they belong, not in a generic `scripts/` dump.

### 4.4 Planned autoloads

Only these six are approved initially. Do not add more without discussion.

| Autoload | Responsibility | Must NOT do |
|---|---|---|
| `Events` | Typed signal declarations only | Hold state or gameplay logic |
| `Game` | Run state, new game, pause, quit to menu | Know specific level nodes |
| `SceneRouter` | Scene changes, fades, loading screen | Own gameplay |
| `SaveManager` | Save slots, serialization, migrations | Know about UI |
| `Settings` | Load/save/apply configuration | Make gameplay decisions |
| `Debug` | Overlay, console, cheats | Remain active in release builds |

Planned public contracts:

```gdscript
# Game
func new_game(slot: int = 0) -> void
func save_game(slot: int = 0) -> bool
func load_game(slot: int = 0) -> bool
func pause_game() -> void
func resume_game() -> void
func toggle_pause() -> void
func quit_to_menu() -> void

# SceneRouter
func goto_scene(path: String, fade: bool = true) -> void
func reload_current() -> void

# SaveManager
func save_slot(slot: int) -> bool
func load_slot(slot: int) -> bool
func has_slot(slot: int) -> bool
func delete_slot(slot: int) -> bool

# Settings
func get_setting(key: StringName, default: Variant = null) -> Variant
func set_setting(key: StringName, value: Variant) -> void
func apply_all() -> void
func save_settings() -> bool
```

Autoloads may call downward into services. They must not reach into a gameplay scene's children.

### 4.5 Data-driven content

Use `Resource` definitions (`.tres`) for content:

- `ItemData` — id, name, icon, model, stack size, value, tags
- `AbilityData` — cost, cooldown, animation, effect
- `QuestData` — objectives, prerequisites, rewards
- `NPCDefinition` — id, scene, schedule, dialogue
- `LootTable` — weighted drops

Keep **definitions** separate from **runtime state**:

- `ItemData` describes an iron sword.
- `InventoryComponent` stores how many the player owns.
- `QuestData` describes requirements.
- `QuestLog` stores progress.

Never hard-code item stats, quest text, or loot tables inside gameplay scripts.

### 4.6 State ownership

Every piece of mutable state has exactly one owner.

| State | Owner |
|---|---|
| Health | `HealthComponent` |
| Inventory | `InventoryComponent` |
| Equipment | `EquipmentComponent` |
| Player input | `PlayerController` |
| Quest progress | `QuestLog` |
| World time | `WorldClock` service |
| Opened containers | Container's persistent save state |
| Pause state | `Game` |
| Camera mode | Player camera rig |
| UI visibility | UI controller, driven by signals |

---

## 5. Naming conventions

| Kind | Convention | Example |
|---|---|---|
| Files and folders | `snake_case` | `health_component.gd`, `test_room.tscn` |
| Classes | `PascalCase` | `class_name HealthComponent` |
| Node names | `PascalCase` | `CameraRig`, `InteractionPrompt` |
| Functions and variables | `snake_case` | `take_damage()`, `move_speed` |
| Private members | leading underscore | `_current_target` |
| Constants | `SCREAMING_SNAKE_CASE` | `MAX_HEALTH` |
| Signals | past tense, `snake_case` | `health_changed`, `item_added` |
| Groups | lowercase, singular role | `player`, `enemy`, `interactable`, `saveable` |
| Content IDs | namespaced `snake_case` | `item.iron_sword`, `quest.smith_intro`, `npc.blacksmith` |
| Collision layers | named, never bare numbers in code | `world`, `player`, `enemy` |

Additional rules:

- Use `StringName` for IDs and action names.
- Use `%UniqueName` for scene-unique nodes instead of long `get_node()` paths.
- Cache node references with `@onready` or `@export`; do not search the tree every frame.
- Avoid abbreviations except widely understood ones (`ui`, `id`, `npc`, `fx`).
- Do not put spaces in new file names.

---

## 6. Communication rules

### 6.1 Decision table

| Situation | Use | Example |
|---|---|---|
| Child notifies parent | Signal | `HealthComponent.health_changed` |
| Owner commands child | Direct method call | `inventory.add_item(id, 1)` |
| Unrelated systems react | Event bus signal | `Events.item_collected` |
| UI displays state | Subscribe to signals | HUD listens to `stats_changed` |
| UI requests action | Command method | `game.toggle_pause()` |
| Save references object | Stable ID | `"chest.smith_01"` |
| Long operation | `await` / signal | Threaded scene load |

### 6.2 Rules

1. **Signals go up, calls go down.** A component notifies its owner; the owner commands its children.
2. **The event bus carries facts, not requests.** Events are past tense and have no return value.
3. **Never use the event bus to fetch state.** Read state from its owner through a command or query method.
4. **UI never owns the truth.** It displays and requests; gameplay decides.
5. **Save files use stable IDs, never `NodePath`s or scene paths.**
6. **Do not emit an event from a listener of that same event.**
7. **Do not add an event until at least one producer and one consumer exist.**
8. **Disconnect signals when the listener is freed.** Use `CONNECT_ONE_SHOT` where appropriate.
9. **Keep signal arguments small and typed.** More than three arguments usually means a data object is needed.
10. **Sibling systems communicate through their owner or the event bus**, not by reaching sideways with `get_parent()`.

### 6.3 Example flow: opening a chest

```text
Player presses Interact
  -> InteractionComponent finds the chest
  -> Chest.open() checks whether it is already open
  -> Chest calls InventoryComponent.add_item("item.iron_sword", 1)
  -> Inventory emits item_added
       -> HUD updates
       -> Events.item_collected is emitted
            -> QuestSystem updates an objective
            -> Audio plays a pickup sound
  -> Chest emits Events.container_opened("chest.smith_01")
  -> SaveManager marks that chest dirty for the next autosave
```

The UI never queries the chest. The quest system never reaches into the inventory. The save system does not walk the whole scene tree every frame.

### 6.4 Anti-patterns

- `get_node("../../Player")` from inside a component
- UI directly changing health or inventory
- Event bus request/response
- Saving `NodePath`s
- One giant `player.gd` or `game.gd`
- Vague signals with six arguments
- Per-frame event emissions
- Circular signal loops

---

## 7. Player and camera rules

- Use one `Player` scene for both perspectives. Do not create separate first-person and third-person player scenes.
- New games start in **first person**. Pressing **V** toggles to third person and back.
- The player is a `CharacterBody3D` with a capsule collision shape.
- Movement is camera-relative.
- **Third person:** `SpringArm3D` handles camera collision; the camera must not clip through walls.
- **First person:** camera sits at the head; hide the head/body meshes appropriately without changing collision.
- Toggling perspective must preserve position, yaw, and pitch. No teleporting and no snap to a different location.
- Mouse capture is enabled only during gameplay. Menus and pause release the cursor.
- Input action for toggling perspective: `toggle_camera`, bound to **V**.
- Locomotion: **Left Shift** crouches; running is a **double-tap of forward** (hold the second press to keep running). The `sprint` action still exists but has no key of its own, so tests and controllers can drive it directly.
- Holding **Space** keeps jumping (the next hop starts on landing) and each hop costs stamina, so hopping stops when stamina runs out.
- Crouching lowers the camera and movement speed only; the collision shape height is unchanged, so crouching cannot wedge the player in geometry.
- Support keyboard/mouse first; controller support is planned but not required in Phase 0 or 1.
- Do not hard-code keys in scripts. Use the Input Map.

### World structure

- Exteriors stream in chunks around the player. Do not build one giant open-world scene.
- Interiors are separate scenes entered through load doors.
- World time is global and continues across scene changes.
- Every persistent world object needs a stable save ID.
- Do not remove or rename a stable ID after content exists without a save migration.

---

## 8. Save system rules

### 8.1 Contract

Persistent objects join the `saveable` group and implement:

```gdscript
func get_save_id() -> StringName
func save_data() -> Dictionary
func load_data(data: Dictionary) -> void
```

`SaveManager` collects save data from saveable objects and writes it by ID.

### 8.2 Requirements

- Save format starts at **version 1** and includes a `version` field.
- Every format change requires a migration function and a round-trip test.
- Use JSON for v1 so saves are human-readable and debuggable.
- Write atomically: write to a temporary file, then rename.
- Save to `user://saves/slot_<n>/`.
- Save only persistent state. Do not save transient state such as current velocity, particle positions, or UI hover states.
- Never save `NodePath`s or scene file paths. Save stable IDs.
- Autosave on major transitions, rest/wait, and manual save. Never autosave every frame.
  *Phase 3 note:* only manual save from the pause menu exists so far. Autosave
  needs its own slot first so it cannot overwrite a manual save; it is deferred.
- Do not save from inside a physics callback. Defer to the next idle frame.
- Keep save work under 100 ms, or move it to a thread later.

### 8.3 What must eventually persist

- Player position, stats, inventory, equipment, and perks
- Quest states and objectives
- Opened containers and taken loot
- Defeated enemies and respawn timers
- NPC relationships, schedules, and current locations
- World time and weather
- Discovered locations and map markers
- Player-owned property and stored items

---

## 9. Input and collision conventions

### 9.1 Planned input actions

```text
move_forward, move_back, move_left, move_right
look_left, look_right, look_up, look_down   (or mouse motion)
jump, sprint, crouch
interact, attack, block, dodge
cast_spell, cast_anchor
toggle_camera
inventory, journal, map, pause
field_notes
quick_save, quick_load
```

Rules:

- All rebindable actions live in the Input Map.
- Use `Input.is_action_pressed()` / `Input.get_vector()`.
- Do not read raw keycodes in gameplay code.
- UI uses Godot's built-in `ui_*` actions.
- Default bindings are TBD; do not invent a final control scheme without approval.

### 9.2 Planned 3D collision layers

| Layer | Name | Purpose |
|---|---|---|
| 1 | `world` | Static level geometry |
| 2 | `player` | Player body |
| 3 | `enemy` | Hostile actors |
| 4 | `npc` | Friendly/neutral actors |
| 5 | `interactable` | Doors, chests, pickups |
| 6 | `projectile` | Arrows, spells |
| 7 | `trigger` | Scripted volumes |
| 8 | `water` | Water volumes |
| 9 | `camera_blocker` | Third-person camera collision |
| 10 | `debris` | Ragdolls, physics props |

Keep the layer meanings stable. Changing them later breaks scenes and masks.

---

## 10. Performance rules

### 10.1 Soft budgets

| Metric | Target |
|---|---|
| Frame time | 16.6 ms (60 FPS) |
| Gameplay logic | < 4 ms |
| Physics | < 4 ms |
| Rendering | < 8 ms |
| Draw calls | < 500 preferred, < 1000 hard |
| Active nodes per region | < 5000 soft cap |
| Shadow-casting lights nearby | 1–4 |
| AI repath interval | >= 0.25 s, staggered |

These are guidelines. Measure before optimizing.

### 10.2 Required habits

- No `get_node()`, `find_child()`, or group scans inside `_process` / `_physics_process`.
- Cache references with `@onready` or `@export`.
- Use `_process` only for continuous work. Use timers, signals, or a scheduler for everything else.
- Use `_physics_process` for movement and physics.
- Pool frequently spawned objects: projectiles, loot, VFX.
- Throttle AI and navigation updates; stagger agents across frames.
- Disable offscreen AI, animation, and audio with `VisibleOnScreenNotifier3D`.
- Use `visibility_range` for LOD and `MultiMeshInstance3D` for repeated props/foliage.
- Bake occlusion for interiors where appropriate.
- Load large scenes with `ResourceLoader.load_threaded_request()`, not blocking `load()`.
- Compress textures and enable mipmaps. Use appropriate import presets.
- Type your GDScript variables and function signatures.
- Use `StringName` for IDs and action names.
- Do not allocate dictionaries/arrays every frame in hot paths.
- Keep UI updates signal-driven; never rebuild UI every frame.
- Profile with **Debugger → Profiler** and **Monitors**. Use the F3 overlay during playtests.

### 10.3 Project-specific risks

- Forward+ is the most expensive renderer. Test the Mobile renderer early if low-end hardware matters.
- D3D12 is configured for Windows. Keep Vulkan as a fallback if driver issues appear.
- Jolt is fast, but thousands of static colliders still need simple shapes and spatial partitioning.
- `canvas_items` stretch scales UI, while 3D renders at native resolution. High-resolution displays cost more GPU.
- A large open world must stream. Never load all regions at once.

---

## 11. Testing and validation

The Godot CLI was not found on PATH during project setup. Use the editor's **F5**, or provide the executable path for headless checks.

### Manual smoke test

Before reporting a task complete:

1. Open the project in Godot 4.7.2.
2. Run the main scene with **F5**.
3. Check the **Output** panel for errors and warnings.
4. Check **Debugger → Monitors** for orphan nodes and rising memory.
5. Exercise the feature being changed.
6. Exercise the previous phase's core flow to catch regressions.
7. Save, quit, relaunch, and load if the change touches persistence.

### Phase 0 acceptance criteria

- Boot scene → main menu → test room works.
- New Game, Continue (disabled or functional), Settings, and Quit are present.
- Escape pauses and releases the mouse; resuming recaptures it.
- Settings persist after restart.
- F3 debug overlay shows FPS, position, and current game state.
- No errors or warnings in the Output panel.
- Git is initialized and `.godot/` is ignored.
- `icon.svg` exists or the reference is removed.

### Phase 1 acceptance criteria

- Walk, sprint, jump, and gravity feel stable.
- First/third-person toggle preserves position and look direction.
- Camera does not clip through walls in third person.
- Interaction prompt appears for a door and a chest.
- A door opens and a chest gives an item.
- Scene transition uses a fade/loading screen.
- Pause menu works during gameplay.

### Phase 2 acceptance criteria

- A chest puts its item into the player's inventory; the toast names the item.
- **I** opens an inventory that lists stacks; Equip/Use acts on the selection.
- Equipping the iron sword raises damage; equipping armor raises armor value.
- Left click swings, costs stamina, and damages an enemy in front of you.
- The enemy notices the player inside 6 m, chases, and hits in melee.
- Armor reduces incoming damage; the HUD bars follow health and stamina.
- Three swings with the equipped sword defeat the enemy.
- Drunk potions heal and are consumed.

### Phase 3 acceptance criteria

- Esc → **Save Game** writes a slot; **Load Game** restores the same moment.
- Reloading restores the player's position, health, stamina, inventory, and equipment.
- Opened chests, opened doors, and defeated enemies stay that way after loading.
- The HUD clock shows a day and time that matches the save.
- **Continue** on the main menu loads the newest save or autosave.
- A corrupt or future-version save is rejected without crashing.
- Chunks stream in and out of range without a hitch.
- **F5** quick saves and **F9** quick loads; an autosave never overwrites a
  manual save.
- Walking through the room's back door reaches the town exterior and the stone
  arch returns inside, keeping inventory and opened objects.
- The town's `Realm` node builds the surroundings in one scene: biome floors to
  the north, east, and south, roads, rivers, two lakes, the ocean, and the two
  outlying villages.
- Walking past the authored ground is survivable rather than fatal.

### Verification commands

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path . tests/phase0_smoke.tscn
Godot_v4.7.2-stable_win64_console.exe --headless --path . tests/phase1_smoke.tscn
Godot_v4.7.2-stable_win64_console.exe --headless --path . tests/phase2_smoke.tscn
Godot_v4.7.2-stable_win64_console.exe --headless --path . tests/phase3_smoke.tscn
Godot_v4.7.2-stable_win64_console.exe --headless --path . tests/gathering_smoke.tscn
Godot_v4.7.2-stable_win64_console.exe --headless --path . tests/magic_smoke.tscn
```

Each must print its own `PHASE0_SMOKE_OK` / `PHASE1_SMOKE_OK` / `PHASE2_SMOKE_OK` /
`PHASE3_SMOKE_OK`, and the content suites print `GATHERING_SMOKE_OK` /
`MAGIC_SMOKE_OK`. The magic suite builds a bare scene from the real player, HUD
and memory-stone scenes: it checks the Ledger, memory/silk/anchoring, the
memory-honey recipe, the HUD symbols, a contained Recall, a leaking Recall, the
refusal paths, and the save round-trip. This pass added **Anchor** (a tooth spent
for a held guard, its refusals, the HUD's held mark, a thin-silk Recall that does
not leak while anchored, and the guard lapsing) and the **four curricula**: the
Seamstress's five lessons in order, each reward, the dialogue speaker, the lesson
marker counting down and disappearing, the discovery at the end, a full bag
refusing the gift without marking the lesson, the retry once there is room, the
repeat line, one lesson driven from Thatch, Corin Vale and Silas Graye each, the
shared totals, and the curriculum surviving a `QuestLog` round-trip.
The Phase 1 test loads the real test room and drives the player: camera toggle,
camera collision, walk, sprint, jump, gravity, door, chest, HUD, fade overlay,
and pause. The Phase 2 test loads the same room and covers item definitions, the
item database, stacking and capacity, equip/unequip, health, stamina, chest loot
reaching the inventory, the inventory panel, enemy aggro and damage, armor
reduction, sword swings killing the enemy, and drinking a potion. The Phase 3
test covers the world clock, the version-1 save format, the slot model,
`newest_slot()` selection, quicksave and autosave isolation (temporarily backing
up and restoring slots 0 and 1), the saveable contract, a write/read/apply round
trip, corrupt and future-version saves, chunk streaming from fixtures,
`chunk_origin` placement, the room's exit gate, the HUD clock, the pause-menu
save/load buttons, and the town scene itself (a `Realm` node now supplies the
surroundings instead of a separate overworld scene).
The gathering suite grew to 299 checks: the atlas path and flower textures, the
realm's lanes, the dressed bench and its lantern, the well/bounty/garden payouts,
the opal and brooch, hidden-memory and village-lore flags, wading speed, the
minimap and a `WorldMap` round-trip, the four ambience files, day/night loop
switching, the river loop, the painted coin's transparency, the `field_notes`
action, `ExplorationLog` and `MovementStats` round-trips, and Field Notes
opening and closing. An earlier pass added rooms counted by scene (including the
"counted once" rule, an unlisted room's prettified title and the save
round-trip), a written line per place, all three bench kinds dressed differently
with their own lamp and tools, the calendar's rain and mist days matched against
the town's live weather, both regional ambience beds, the town's and the main
menu's music beds riding the `Music` bus, the ambience volume setting, the three
pause-menu sound rows, and Bell's counter (full price for a stranger, coins
taken, favor earned, a cheaper regular price, an empty purse, and a full bag
costing nothing). This pass added the Field Notes **lessons row**, and the three
new teachers in the town and their night placements (Thatch's beekeeper cottage
and Corin Vale's tooth house), including that Thatch's flower quest survives.

New `class_name` scripts are registered from `.godot/global_script_class_cache.cfg`,
which only the editor writes. After adding one, open the project in the editor
once (or run `--headless --editor --quit`), otherwise a headless test fails with
`Identifier "<ClassName>" not declared in the current scope`.

### Future automation

- Add GUT or gdUnit4 only with approval.
- Priority tests: save/load round-trip, save migrations, inventory add/remove, quest objective progression.
- Do not add a test framework before Phase 5 unless requested.

---

## 12. Roadmap and phase gates

| Phase | Goal | Effort | Status |
|---|---|---|---|
| 0 | Foundations: repo, folders, boot flow, services, input, pause, settings, debug | S | **Implemented — awaiting acceptance** |
| 1 | Walking skeleton: player, both cameras, interaction, doors/chests, transitions | M | **Implemented — awaiting acceptance** |
| 2 | Core RPG loop: items, inventory, equipment, stats, combat, one enemy, HUD | L | **Implemented — awaiting acceptance** |
| 3 | Persistence and world: save/load, chunks, time, persistent objects | L | **Implemented — awaiting acceptance** |
| 4 | Sandbox life: NPC schedules, dialogue, quests, shops, crafting | XL | **In progress — villagers, schedules, dialogue, two quests, café, multi-room interiors, continuous world; shops and crafting not started** |
| 5 | Content and UX: menus, character creation, keybinds, audio, localization | L | Not started |
| 6 | Performance and release: profiling, LOD, pooling, export, QA | M | Not started |
| 7 | Scale: more regions, quests, abilities, tests, tooling | Ongoing | Not started |

**Phase gate rule:** do not start the next phase until the current phase's acceptance criteria pass and the user explicitly approves.

The first playable target is a **vertical slice**: one room, one NPC, one chest, one sword, one quest, save/load, and a pause menu. If that loop is solid, the world can scale.

---

## 13. Definition of done

Every task must satisfy:

- The project runs and the changed feature works.
- No new errors or warnings in the Output panel.
- No regressions in earlier phases.
- Naming and folder conventions are followed.
- No unrelated files were changed.
- New architecture decisions are recorded in this file.
- The final report lists changed files and exact test steps.

### Required report format

1. **What changed** — one short paragraph.
2. **Why** — the reason and any tradeoffs.
3. **Files changed** — exact paths.
4. **How to test** — numbered steps.
5. **Known limitations** — anything unfinished or risky.
6. **Next step** — what should happen next, without starting it.

---

## 14. Working with the user

The user is a beginner. Adapt explanations accordingly:

- Explain **what** and **why**, not just **how**.
- Define jargon the first time it appears.
- Prefer small, working milestones over large unfinished systems.
- Give numbered, reproducible test steps.
- Do not dump huge diffs or hundreds of lines without context.
- Warn before any change that touches many files or existing work.
- Ask before architectural changes, new dependencies, or scope expansion.
- Never pretend something was tested if it was not.

---

## 15. Decision log

| Date | Decision |
|---|---|
| 2026-10-31 | Project is 3D. |
| 2026-10-31 | Design reference is Skyrim-style open-world sandbox RPG. |
| 2026-10-31 | First-person and third-person cameras, toggleable at runtime. |
| 2026-10-31 | Single-player only. No networking. |
| 2026-10-31 | GDScript with static typing; no C# for now. |
| 2026-10-31 | Forward+ renderer and Jolt Physics retained. |
| 2026-10-31 | Feature-first architecture with component composition and data-driven Resources. |
| 2026-10-31 | Six initial autoloads approved: Events, Game, SceneRouter, SaveManager, Settings, Debug. |
| 2026-10-31 | `toggle_camera` is bound to **V** by default. |
| 2026-10-31 | New games start in **first person**; V toggles to third person and back. |
| 2026-10-31 | Phase 0 foundations implemented; smoke test added at `tests/phase0_smoke.tscn`. |
| 2026-10-31 | One `Player` scene serves both perspectives; third person uses a `SpringArm3D` with a sphere shape. |
| 2026-10-31 | Interaction ray starts at the player's head and follows the active camera; reach is 3 m. |
| 2026-10-31 | The crosshair is hidden in third person because the player's body blocks it; the `[E]` prompt still shows. |
| 2026-10-31 | Doors and chests sit on collision layers `world` + `interactable` (mask value 17). |
| 2026-10-31 | The Phase 1 chest is a placeholder: it notifies the HUD but does not yet grant inventory items. |
| 2026-10-31 | Phase 1 implemented; smoke test added at `tests/phase1_smoke.tscn`. |
| 2026-10-31 | `AGENTS.md` created. |
| 2026-11-01 | Player body is a primitive humanoid placeholder (torso, head, arms, legs) under `Visual/Model`, animated by an `AnimationPlayer` with `idle`/`walk`/`run`/`jump`. Clips live in `player.tscn` and are selected by `player_controller.gd` from speed and airborne state; the animation only drives `Visual`, never the `Head` camera pivot. |
| 2026-11-01 | Godot Editor MCP addon (v2026.10.20.1) installed at `addons/godot_mcp/` and enabled; server registered project-scoped in `opencode.json`. Tool-only, no runtime dependency, no game code references it. |
| 2026-11-01 | `project.godot` lost its explicit `[audio] buses/default_bus_layout` line when Godot saved after the plugin was enabled. Harmless: the engine default is the same `res://default_bus_layout.tres`; all six buses verified intact by the Phase 0 smoke test. |
| 2026-11-01 | The Phase 1 door prompt assertion was made deterministic: the door swings -100 deg into the room, so it leaves the 3 m interaction ray mid-swing and a fixed-frame wait raced it. The prompt is now read immediately after `interact()`. |
| 2026-11-01 | Phase 2 uses one `ItemData` resource with `Kind` and `EquipSlot` enums instead of a class per item type; inventory and UI stay generic. Splitting into subclasses is deferred until abilities need it. |
| 2026-11-01 | Items are looked up through a static `ItemDatabase` class of preloaded resources. No autoload was added (the six approved services are unchanged); add new items to `data/items/` and to the table. |
| 2026-11-01 | Phase 2 implements stamina only. Magicka is deferred until spells exist so the HUD does not show a dead resource. |
| 2026-11-01 | Armor is a flat damage reduction (`maxf(damage - armor, 1.0)`), not a percentage. Percentage mitigation waits for the full stat system. |
| 2026-11-01 | Melee swings use a sphere sweep (2.4 m reach, 0.8 m radius) instead of a ray: a swing should be forgiving to aim and a ray can slip past a thin capsule. |
| 2026-11-01 | The inventory panel does not pause the game. It calls `player.set_ui_blocked(true)` and releases the mouse, so it cannot conflict with the pause menu. |
| 2026-11-01 | `player_combat.gd` lives beside `player_controller.gd` rather than inside it, so the controller stays about movement and cameras. `PlayerController` gained a `class_name` so the HUD and combat script can be typed instead of using `CharacterBody3D`. |
| 2026-11-01 | The player collision mask changed from `world` (1) to `world + enemy` (5) so the player body and the enemy collide; the enemy body uses layer `enemy` and mask `world + player` (3). |
| 2026-11-01 | Chests resolve their `loot_id` through `ItemDatabase` and call the interactor's `add_item()`. If the inventory is full the chest stays closed, so loot is never lost silently. Chest `loot_name` was removed in favour of the definition's `display_name`. |
| 2026-11-01 | Phase 2 implemented; smoke test added at `tests/phase2_smoke.tscn` (129 checks). |
| 2026-11-02 | Phase 3 implemented. Saves are version-1 JSON at `user://saves/slot_<n>/save.json`, written to a temp file and renamed into place. |
| 2026-11-02 | `WorldClock` is a static `class_name` service, not a seventh autoload: one world per process, and `Game` owns the decision to advance it. |
| 2026-11-02 | The player root is the aggregate saveable (`player`); components expose `save_data`/`load_data` and never write files. Chests, doors, and enemies carry an exported `save_id` set in the scene. |
| 2026-11-02 | A save taken at the instant of death reloads at 1 HP rather than leaving the player permanently dead. |
| 2026-11-02 | `Game.load_game()` reads the slot, reloads the recorded scene, then applies. Callers must not `await` it from a scene that the load replaces; the coroutine lives on the `Game` autoload instead. |
| 2026-11-02 | Chunk streaming is `ChunkManager` (`chunk_<x>_<z>.tscn`, threaded loads, 0.25 s timer). A missing file is remembered, not retried, so an absent chunk costs one check and no repeated I/O. |
| 2026-11-02 | Two save slots are enough for now: slot 0 is manual/quicksave, slot 1 is autosave. A separate autosave slot is what makes "autosave after every scene change" safe, because it can never overwrite a deliberate save. More slots wait for a save-slot UI. |
| 2026-11-02 | **F5** quicksaves slot 0 and **F9** quick loads, because a save system nobody can reach mid-playtest is not verifiable. Quick load picks the newest of the two slots rather than always slot 0. |
| 2026-11-02 | Autosave runs after a finished gameplay scene change (and after travel), never mid-frame. It is suppressed while `load_game()` or `travel_to()` is in flight, otherwise the intermediate state would be written over the destination. |
| 2026-11-02 | `Game.travel_to()` erases the outgoing player position/yaw/pitch from `world_state` and then records the arrival point, so an immediate autosave or quicksave in the new scene stores the spawn, not the old room's coordinates. |
| 2026-11-02 | `AreaGate` arms only after the player has been outside it. Without that rule, arriving inside a gate volume would immediately bounce the player back to the scene they just left. |
| 2026-11-02 | The exterior is its own `scenes/overworld.tscn` reached through the room's back door, not chunks bolted onto the interior. Interiors and exteriors stay separate scenes so the streaming system never has to reason about indoor geometry. |
| 2026-11-02 | Chunk content is a generated 3×3 meadow (32 m chunks, ground/rocks/trees) in `features/world/chunks/`. Placeholder content is generated by a throwaway script and deleted afterwards rather than hand-authored, so the layout stays reproducible and reviewable. |
| 2026-11-02 | The Phase 3 suite asserts the overworld's *existence and gate wiring* instead of `load()`ing it. Instantiating a second player and HUD inside the test process left resources alive at exit; the scene itself is verified by the headless boot check. |
| 2026-11-02 | Phase 3 smoke test added at `tests/phase3_smoke.tscn` (149 checks), with fixture chunks in `tests/fixtures/chunks/`. |
| 2026-11-03 | The exterior got four biomes inside Phase 3 rather than a new phase: plains (the original set, at the world origin), ice, desert, and ocean. Content, not architecture, so the phase gate stays closed. |
| 2026-11-03 | Biomes are separate chunk folders streamed by separate `ChunkManager` nodes with a `chunk_origin` offset, not one manager that switches sets. Adding a biome is then a folder plus a node, and the streaming code keeps no biome knowledge. |
| 2026-11-03 | The plains set keeps global chunk names (`chunk_-1_-1` … `chunk_1_1`) and a zero origin, so the committed Phase 3 content and its test did not have to move. Only the new folders use local `0…2` names. |
| 2026-11-03 | The ocean is wading-depth water over a sand floor rather than real swimming. A seabed 0.35 m down plus a translucent water sheet gives the biome its look without a water volume, breath meter, or swim state. |
| 2026-11-03 | `overworld.gd` teleports the player back to the spawn pad below `fall_limit`. The four biome quadrants do not tile an infinite plane, so the empty edge has to be survivable before the world can grow. |
| 2026-11-03 | Biome chunk scenes are generated by a throwaway `tools/generate_biomes.gd` (seeded per chunk coordinate) and the script is deleted. Same reasoning as the first meadow: reproducible layout, no generator left in the project. |
| 2026-11-06 | Movement feel: **Left Shift** crouches (the old shift `sprint` key is cleared), running is a double-tap of forward held to keep running, and holding jump hops continuously at 12 stamina per hop. Crouching changes speed and camera height only, never the collision capsule, so it cannot trap the player. |
| 2026-11-06 | Phase 4 content starts with one reusable `Npc` scene rather than a system per character: exported colours and accessories make each villager distinct, and one waypoint list makes Fern a wanderer. Villagers are placed in the town outside their homes for now; moving them indoors and giving them schedules waits for the interior/schedule pass. |
| 2026-11-06 | Villager talk is a one-line bark through `Events.notification_requested` (the existing HUD toast), not a dialogue panel. This keeps the NPC slice small and avoids inventing dialogue UI before the writing exists. |
| 2026-11-06 | The reference map is copied to `assets/maps/mycelgrove_hollow_map.png`. The original in `tests/` is left untouched; the copy is the one future work should be checked against. |
| 2026-11-06 | The map screen is one child of the HUD, not a node repeated per scene, so every gameplay scene gets **M** for free. It blocks the player like the inventory instead of pausing, and it consumes Esc while open so Esc closes the map rather than stacking the pause menu underneath. |
| 2026-11-06 | The map's "You are here" tag reuses the town generator's map-to-world conversion (`x = (px - 656) * 0.14`, `z = (py - 600) * 0.14`) in reverse. It only shows in `town.tscn`; the room, overworld, and interiors do not share that map. |
| 2026-11-06 | The four named villagers moved inside their own interiors (bakery, Rowan's house, yew cottage, beekeeper cottage). |
| 2026-11-06 | Day/night schedule: each of those four villagers has a home placement active 18:00–08:00 and a daytime placement active 08:00–18:00. Inactive placements hide and clear their collision layer rather than being freed, so there is no teleporting or scene spawning. Crossing midnight is handled by the window wrapping. Thatch adds a daytime waypoint loop between the Honeyed Way and the Hive Tower. |
| 2026-11-06 | Dialogue is a HUD-owned window fed by `Events.dialogue_requested(speaker, role, lines)`; `Npc.interact` is the only producer and no longer emits a toast. One line shows at a time so the panel stays small and readable, with **E**/**Space** to advance and **Esc** to close. It blocks the player like the inventory and suppresses the map and inventory while open. |
| 2026-11-07 | The 2D character art lives in `assets/from_2d/` (sprites, `frames/*.tres`, materials, source sheets). `Npc.sprite_frames` draws a villager as a camera-facing `AnimatedSprite3D` billboard scaled to 1.9 m instead of the primitive body; `sprite_texture` is the static fallback and the primitive stays if neither is set. Auntie Bell, Rowan, the Blind Seamstress, and Fern use frames in the town and in their interiors. Thatch has no 2D art yet, so he keeps the primitive body. |
| 2026-11-07 | Rowan's and the seamstress's crops carried an opaque dark backdrop from the source sheet, so new `rowan_cut.png` and `seamstress_cut.png` copies are flood-filled to transparency and the frames point at those. The original `rowan.png` / `seamstress.png` stay untouched. |
| 2026-11-07 | The player's third-person body is the Fern billboard (`Visual/Portrait`); the primitive `Visual/Model` parts are hidden rather than deleted so the locomotion clips and a future rigged model still have their targets. `player_controller.gd` already hides `Visual` in first person, so the billboard never blocks the first-person camera. |
| 2026-11-09 | The separate overworld is gone. `scenes/overworld.tscn`, `features/world/overworld.gd`, and the ice/desert/ocean chunk folders were deleted, and `scenes/town.tscn` grew a `Realm` node (`TownRealm`). One continuous place beats two scenes joined by a gate: the player never hits a load door just to see the forest, and the town can keep its own roads, river, and sky. `ChunkManager` stays in the project because the Phase 3 fixtures still exercise it. |
| 2026-11-09 | The world around the town is generated at runtime by `TownRealm`, not by regenerating `tools/build_town.gd` output. Regenerating the town would have rewritten `town.tscn` (39 interiors, villagers, gates, save ids). Content that grows around existing content should be additive. |
| 2026-11-09 | Two outlying villages (Willowmere by the west lake, Thornwake in the deep forest) are placed as house clusters inside the realm, not as separate scenes. The user's request for "other towns" left the count open; two is enough to prove the world is inhabited without inventing quest content for a third. **Superseded later the same day:** both were renamed and relocated — see the Ashfall/Thornridge rows below. |
| 2026-11-09 | Draw-call cost is controlled with `MultiMeshInstance3D` batches: far forest, ground art (rocks, mushrooms, flowers, ferns, stumps), reeds, and dead trees are batched, so a meadow of flowers is one draw call. Only roadside and village trees are `TownProp` with colliders. `TownParts.merge_children()` now also merges `TownRibbon` strips. The town dropped from 4485 to 2648 nodes and the realm from 514 to 238 children. |
| 2026-11-09 | The imported 2D testing house became the `hollow_house` layout, with upright billboard furniture and a chest that opts into the new sprite skin (`use_sprite`). The town's 39 doors already had interiors, so `hollow_house.tscn` currently has no door pointing at it; it is kept as the reference for the layout and the Guest encounter. |
| 2026-11-09 | Rowan's house is `rowan_manor` (13 × 9.5 m) and Auntie Bell's is `cafe` (14 × 10 m). Partitions are built from absolute door-gap coordinates (`_partition_z`/`_partition_x`) so a doorway can be lined up with a piece of furniture by reading one number. |
| 2026-11-09 | Bell's schedule moved: she is behind the café counter **08:00–18:00** and in the private back room at night, instead of the old reverse window. A shopkeeper should be present while the shop is open. Two scheduled customers (`mossy_villager` 08–13, `little_eli` 12–18) demonstrate "customers come and go" with the existing schedule system rather than a new crowd system. |
| 2026-11-09 | The café's private room is kept out of reach by architecture, not a lock: its only door is off the service aisle behind the counter. Locked doors need a key/lock system that does not exist yet. **Superseded later the same day:** the room now has a `LockedDoor` and the key is a quest reward — see below. |
| 2026-11-09 | `mossy_villager.png` carried an opaque dark backdrop. A corner flood-fill produced `mossy_villager_cut.png` and the frames resource points at it, matching the earlier Rowan/seamstress cut-outs. The original PNG is untouched. |
| 2026-11-09 | The two outlying villages were renamed and relocated: **Ashfall** at `(20, -300)` in the northern bog, and **Thornridge** at `(330, 30)` in the eastern rock hills (the spelling "Thornridge" was chosen over "Thorneidge"). The west lake stays as a plain lake named `WestLake`. Content is still built at runtime by `TownRealm`, not by regenerating the town. |
| 2026-11-09 | Villages are repainted patches of the region they sit in, not new biomes: Ashfall uses an ash-grey/bog-mud green over the arctic floor with pools, reeds, dead snags, and violet lanterns; Thornridge uses slate and rust over the desert floor with rock, thorn scrub, standing stones, and a dry gully with a low stone bridge on the EastRoad. Repainting keeps the world continuous and avoids a seventh and eighth biome floor. |
| 2026-11-09 | Ten `GradientTexture2D` cross-fade quads blend the region floors at their borders (one per border) instead of a shader. The gradient holds the source colour across the border and fades it out over the second half of the band. Cheap, visible in the editor, and it needs no material plumbing. |
| 2026-11-09 | Each village got three enterable interiors, reached through `AreaGate` nodes created at runtime under `Realm`. The town's authored `Gates` node is left alone, so `town.tscn` and its 39 interiors stay byte-identical. Only the first three houses per village get a gate and a pale stone sill; the rest stay scenery. |
| 2026-11-09 | Village villagers use the existing `Npc` scene with primitive bodies and no 2D frames: two per village on a 15 m wander ring. New art for four minor characters was not worth the pipeline cost, and the primitive body already reads at village distance. |
| 2026-11-09 | Village flags are drawn into an `ImageTexture` at runtime (`_banner_mesh` / `_banner_material` / `_ash_emblem` / `_thorn_emblem`) rather than shipped as PNGs. Symbol and palette live next to the village data, and no new import step is needed. The cloth faces the green and is merged only when a second mesh shares its material. |
| 2026-11-09 | The café's private back room now has a real `LockedDoor` at the service aisle. The key, `item.bakery_key`, is granted by Auntie Bell at the Sporebread turn-in through `QuestNpc.extra_reward_item`, is never consumed, and the door saves its `unlocked` state. A lock that needs a key is a better gate than furniture placement, and it teaches one item/reward/save loop without a new system. |
| 2026-11-09 | The storybook map grows village cards at runtime from `TownRealm.VILLAGES` instead of drawing them into the PNG. The map art stays the town plan; the roads-out-of-town cards carry name, mood, symbol, and flag swatches. Outside the map's world bounds the "You are here" tag hides and the footer names the nearest village. |
| 2026-11-09 | Village ground layers are stacked by explicit height: region floor `0.022`, rim rings `0.023-0.027`, village green top `0.030`, paths `0.048`, lane `0.052`, gully `0.042`, door sills `0.070`. The gully was invisible at first because it sat exactly at the green's top surface, so any new village ground must be placed against this stack. |
| 2026-11-11 | **Mana is the outsiders' word** for the Hollow's capacity for supernatural exchange, not a substance. Magic is borrowed (prepared honey = memory), contained (silk), anchored (teeth), and accounted for (the Ledger). Ordinary honey stays food; only prepared honey is spell fuel. |
| 2026-11-11 | The first magic slice is **Recall only**. Memory charge reuses the existing mana pool (`max_mana`, `mana_changed`, the save key `"mana"`) so old saves and the bed keep working; `get_memory()` / `spend_memory()` are the readable aliases. Silk and anchoring are new state beside it on `StatsComponent`. |
| 2026-11-11 | Silk is a **containment cap**, not a second mana pool: it is not spent by Recall and does not regenerate. A cast below 20 silk still succeeds but leaks 10 imbalance. A refused cast never consumes the honey dose. |
| 2026-11-11 | Teeth are **anchors**, not currency: `anchoring` is a small slot count (`max_anchoring = 3`) and a tooth is never the ordinary cost of a spell. Recall costs none. |
| 2026-11-11 | The **Ledger** is a static service (`class_name Ledger`, no autoload) saved in `world.ledger` with imbalance 0–100 and a debt dictionary. The HUD shows one word (Balanced / Thin / Watched), not a fourth bar. |
| 2026-11-11 | The memory stone's **E** interaction and the **R** key share one `SpellCaster.try_recall()` path, so there is one cost and one rule. The stone holds a title and a paragraph, is repeatable, and builds its visual in code. |
| 2026-11-11 | **R** is `cast_spell` in the Input Map. No existing action used physical key 82. |
| 2026-11-11 | Magic smoke test added at `tests/magic_smoke.tscn` (78 checks); `tests/gathering_smoke.gd` also asserts `Realm/CaveMemoryStone` and the player's SpellCaster. |
| 2026-11-11 | Building nameplates moved from the roof to a door-level `DoorPlate`. `owner_name` and `is_home` are exported on `TownBuilding`; an unowned home reads `Empty`. The player is **Rowan**; **Fern is an NPC**. The game stays single-player. |
| 2026-11-11 | The market vending machine is built from the `zones.txt` note: a dark cabinet with unlabelled selections, woken by **one** odd coin (a one-time key, consumed). It takes **sea glass and pale gemstones**, both mined in the Old Adit, and sells moss-covered rocks, small opals, mushrooms to plant, tiny sacks of dirt, faux ivory brooches and a gnome statue. **Teeth stay out**: they are anchors for magic, not pocket change. Payment is taken only after the goods fit in the bag, so a full inventory never eats sea glass. |
| 2026-11-11 | The odd coin sits in Rowan's own house rather than being handed out by an NPC, so the machine's key is discovered by looking around your own home (lore: "the strange one that's been in your family for years"). `QuestNpc` gift behaviour is untouched. |
| 2026-11-12 | Dirt and cobble lanes are cut from `Fantasy Village Path Tileset Atlas.png` into `path_dirt.png` / `path_cobble.png`. Lanes are **additive to the authored town**: `TownRealm._paths()` draws ribbons on the realm ground rather than regenerating `town.tscn`, so the 39 interiors, villagers, gates, and save ids stay byte-identical. |
| 2026-11-12 | Flower variety comes from three atlas path-edge clusters keyed to transparency, mixed with the original single flower in `_verge_flowers()`. Variety is a texture choice, not a new scatter system. |
| 2026-11-12 | The `WorldMap` is a static service (`class_name WorldMap`, no autoload), matching `WorldClock`/`QuestLog`. Fog is a dictionary of 16 m squares persisted in `world.map`; the minimap is one HUD child that redraws on the existing 0.5 s clock tick so it costs no per-frame draw. |
| 2026-11-12 | Rivers are **wading**, not walls (`RiverWade`, `speed_scale` 0.55). The river sheets have always been walkable, and blocking them would soft-lock anyone who fell in; slowing the player keeps bridges meaningful without that risk. Bridges may read as slightly heavy while wading, which is acceptable for a feel pass. |
| 2026-11-12 | Wells (`LoreWell`) and hidden memory stones pay **once** under a `QuestLog` flag, and refuse to burn the flag when nothing fits in the bag. Exploration rewards are lore first, loot second. |
| 2026-11-12 | The notice board's four bounties are **repeatable** and scale a small coin bonus every five completions, so foraging keeps a use after the quests end. |
| 2026-11-12 | The two vended trinkets became real consumables (`restore_silk`, `grant_anchoring`) instead of flavour items, so every vending-machine trade has a use. The opal mends torn silk; the faux ivory brooch grants one anchor slot — a lie the Hollow accepts. |
| 2026-11-12 | The crafting bench is dressed in code (a `Bench` node under the existing station) rather than imported as a model. The shipped box mesh is hidden, not deleted, so a future asset can replace the bench without touching the interaction code. |
| 2026-11-12 | `gathering_smoke` grew to 176 checks: path/flower textures, realm lanes, the bench, well payout, bounty payout, garden growth and harvest, opal/brooch use, hidden-memory flags, wading speed, the minimap node, and a `WorldMap` save round-trip. |
| 2026-11-12 | The workbench is dressed further rather than modelled: planks with gaps, splayed legs, a vice with a turning handle, a tool rail, a leaning saw, a lit lantern with one small `OmniLight3D`, and a stool. Still no art import, and the shipped box stays hidden so a real model can replace it later. |
| 2026-11-12 | The Odd Coin is drawn with Pillow (96 × 96, zig-zag silver rim, gold face, engraved spider, wear and a soft shadow) and the SVG icon was redrawn to match. The coin is the machine's identity, so it should not look like a generic token. |
| 2026-11-12 | `MovementStats` and `ExplorationLog` are static services (no autoload), saved as `world.movement` and `world.exploration`, matching `WorldClock`/`QuestLog`/`Ledger`/`WorldMap`. Field Notes only reads them. |
| 2026-11-12 | The exploration checklist uses **ground circles checked on the HUD's 0.5 s tick**, not `Area3D` triggers, and runs only in `res://scenes/town.tscn`. Interiors place the player near the origin, so counting there would falsely tick the market; named interiors wait for a separate design. |
| 2026-11-12 | Field Notes is bound to **C** (`field_notes`). Key 67 was unused by every other action. It blocks the player and releases the mouse like the inventory, hides the minimap, and closes on **Esc**. |
| 2026-11-12 | Ambience is **original synthesis**, not recordings: `wind_soft`, `night_hum`, `river_flow`, and `bell_distant` are generated from filtered noise and sine partials, so there is no licensing question and no imitation of an artist. Day is wind, night is a drone with crickets and an occasional bell. |
| 2026-11-12 | `AmbientAudio` is a plain node in `scenes/town.tscn`, not a seventh autoload. `looped_wav()` duplicates the stream and sets `loop_mode`/`loop_end` at runtime, so WAV import settings cannot break looping. River loops are one positional player per `RiverWade`, at the polyline centre with `max_distance` 85 m. |
| 2026-11-12 | The outlying villages got their own lore rather than being scenery: one well and two hidden memory stones each, all paying once under `QuestLog` flags. Ashfall's well pays silk and its memories pay silk and honey; Thornridge's pays stone and its memories pay a gemstone and silk. Leaving the Hollow is now worth the walk. |
| 2026-11-12 | `gathering_smoke` grew to 212 checks, adding village wells/memories, the four ambience files, day/night switching, the river loop, bench parts and light, coin transparency, the `field_notes` action, both new services' round-trips, and Field Notes open/close. |
| 2026-11-13 | Interiors join Field Notes **by scene path, not by position**. Every interior spawns the player near the origin, so a circle test would tick the market square on every entry; the room id is `room.<file_basename>`, which is stable, saveable, and needs no node in any of the 39 interiors. Titles come from a small `ROOM_TITLES` table with a camel-case prettify fallback, so a new interior works before anyone names it. |
| 2026-11-13 | A first visit speaks its written line through the existing dialogue window as the speaker **"Field Notes"**, falling back to the toast when a conversation is already open. One line per place, written down once: a checklist tick alone reads like a chore counter, and the Hollow's voice is the reward. |
| 2026-11-13 | Music is a **plain `MusicPlayer` node in each scene**, not an autoload. An autoload would survive scene changes and need cross-fade logic it does not have yet; a per-scene node dies with its scene, which is exactly right for a menu theme and a town theme, and it keeps the six approved services at six. Both loops are original synthesis. |
| 2026-11-13 | Weather is **derived from the calendar** (`Weather.kind_for_day(day)`, `posmod(day, 7)`), not stored in the save. An old save therefore loads into the weather that day always had, and no format version change was needed. Rain is atmosphere only: it never slows or damages the player. |
| 2026-11-13 | `Weather` never touches the sun. It hands a calm fog density to `FogSurge.set_base_density()` and lets the surge own the light and the fog fade, because two systems writing `fog_density` and `light_energy` behind each other's back is how a clear day turns black. |
| 2026-11-13 | Regional ambience is **one extra player inside `AmbientAudio`**, chosen by the player's position against the same north/south/east bands as the realm's floors, not a system per biome. The base day/night loop keeps running underneath, so a region only tints the place rather than replacing it. Rain trims the base loop by 6 dB so weather is heard through the wind. |
| 2026-11-13 | Bell's counter is `VendorCounter`, deliberately **separate from `LedgerShopPanel`**. The market panel sells randomised upgrades to anyone; a counter belongs to a person, has a fixed list, and bends its prices with that person's favor. Coins stay in `Progression` and goods stay in the inventory, so the counter owns no state and needs no save id. |
| 2026-11-13 | Benches share one frame and differ only in **`station_kind`** (`market`/`forge`/`loom`), so a player recognises a workbench anywhere while Ashfall's forge and the loom tower stop reading as copies. `_bench_lamp()` is shared and parameterised, so each bench has its own light. The loom is a working station (thread, prepared honey), not a prop. |
| 2026-11-13 | Sound sliders live in the **pause menu**, built in code above Resume, rather than a new settings screen. Pausing is where a player already is, and turning ambience down is the likeliest reason to open settings in a game this quiet. Building the rows in code leaves the shipped scene layout and every `%UniqueName` in it untouched. |
| 2026-11-13 | The world audit became a throwaway tool (run, then deleted) rather than a shipped test. It proved: 0 gates pointing at a missing scene, 0 buried props, 0 crammed building pairs (footprint overlap > 25% of 45 authored buildings), and 0 buildings standing in a river measured against the real `RiverWade` segment boxes. The 16 "floating" hits were all deliberate (buildings on plinths, pickups hovering at 0.36 m, a character's shoulders), so nothing was moved: an audit that invents fixes is worse than no audit. |
| 2026-11-13 | `gathering_smoke` grew to 279 checks, adding rooms and written lines, three bench kinds, the weather calendar, regional ambience, both music beds, the ambience volume and pause-menu sound rows, and Bell's counter. |
| 2026-11-13 | **Q1–Q5 answered** (recorded in `Shared_Lore/OPEN_QUESTIONS.md`). Fern is a **false child grown stable**, with the **First Child as the deeper origin**; Fern is not literally the breach, and whether they are the same being stays **deliberately unanswered**. The ancient Delay Protocol (`DESIGNATION ASSIGNED: FERN`) is the deeper layer. The Spider Mother may know, the Ledger holds fragments, Elsby suspected, nobody has the complete answer, and "whether the First Child was ever just one child" stays open. The 1890s fog and the 1974 Fog Surge are **two separate events**. Rowan is **27**; the game's year stays unset so no scene names a year. All of Fern's names (Thimble, Fern, Thistlewind, Between, Patch) are canon. Thimble and Fern are **one child**, and Thimble came first with Elsby, before Rowan and the current villagers. |
| 2026-11-13 | The first named teacher is the **Blind Seamstress**, not a new character. Canon already gives her the teacher's actions — she stirs honey clockwise to stabilise memory, adds a Threadkeeper's silk thread before use, and sometimes asks for a tooth deposit — so inventing a new sage would have contradicted the established cast. She is `MagicTeacher extends QuestNpc`, placed on the street by day and in her cottage at night; the subclass keeps her existing `quest.seamstress_thread` and its rewards untouched. |
| 2026-11-13 | Teaching is **one lesson per conversation**, stored as `QuestLog` flags (`teach.<teacher_id>.<n>`), so the curriculum is remembered across saves and both placements of the Seamstress share it. A lesson with a gift is **not** marked taught when the bag is full, matching the chest/quest rule that loot is never silently lost. Lessons reward the rule they teach (two memory-honey doses, 30 silk, one tooth anchor, 10 imbalance relief), so the teacher is a working introduction to the existing systems, not a lore-only panel. |
| 2026-11-13 | The teacher's last lesson states only what she **knows and does not know**: Fern is a false child grown stable, the First Child may be the deeper origin, the names are all filed under one open account, and "I know what Fern is not. I do not know what they are." Elsby is called **"a scout"** and never gendered, because Q6 is still open. No year is spoken; the 1890s fog and the 1974 Surge are named as two different hungers. |
| 2026-11-13 | `magic_smoke` grew from 78 to **102 checks** with the teacher: the five lessons in order, each reward, the dialogue speaker, the save flag, a full bag refusing the gift without marking the lesson, the retry, and the curriculum's `QuestLog` round-trip. `gathering_smoke` grew from 279 to **284** by asserting that the street Seamstress is a `MagicTeacher`, that her thread quest survived, that the whole curriculum is present, and that the cottage placement carries the same script. |
| 2026-11-13 | Every curriculum now lives in `features/magic/magic_lessons.gd` (`class_name MagicLessons`, a static service, no autoload). Lessons are content constants; progress stays in `QuestLog` flags. `curriculum` picks the lesson list and `teacher_id` namespaces the save flags, so a scene can reuse a list under a different id. Adding a teacher is one dictionary entry plus a script override. |
| 2026-11-13 | The three further teachers are **existing villagers**, not new characters: Thatch already keeps the hive (memory fuel), Corin Vale is the Toothkeeper (a tooth is a name), and Silas Graye is the Debt Enforcer (the Ledger records). Each curriculum is three lessons and rewards what it teaches (memory, prepared honey, silk, anchors, Ledger relief). Thatch and the Seamstress keep their quests because `MagicTeacher` extends `QuestNpc` and runs the quest conversation first. |
| 2026-11-13 | **Anchor** is the second spell and the first one that spends a tooth: one anchor plus 10 memory buys `anchor_guard_seconds` (60 s) in which `StatsComponent.can_contain()` is true, so a thin-silk Recall cannot leak. The guard is **transient and never saved** — a tooth buys a moment, not a permanent stat — and the HUD Anchors row reads `(held)` while it lasts. A second cast while one holds is refused so two teeth cannot be wasted. |
| 2026-11-13 | An unfinished teacher wears a floating `LessonMarker` ("3 lessons") and a finished teacher repeats one line instead of falling silent, so a player can tell who still has something to teach. Completing the Seamstress's five lessons unlocks `discovery.what_she_knows`, which states only what she knows and does not know. |
| 2026-11-13 | The `_seamstress` and `_office` layouts gained a usable bed through `_bed_body()`; the Seamstress and Corin Vale now sleep in their own rooms and the player can rest there. `_hive` stays a workplace, because Thatch sleeps in the beekeeper cottage. |
| 2026-11-13 | `magic_smoke` grew from 102 to **143 checks** (Anchor and its refusals, the held mark, a leak-free anchored Recall, the guard lapsing, the marker, the discovery, the repeat line, and one lesson from each new teacher) and `gathering_smoke` from 284 to **299** (the Field Notes lessons row, the three town teachers, and the two night placements). |
| 2026-11-14 | **The Ledger escalates.** `Ledger.get_escalation()` is a whole-number tier (0 balanced, 1 thin, 2 watched, 3 full) and `get_escalation_scale()` adds 25% per tier. A `Guest` reads it **once on arrival**, so its health, damage and detection harden, and a Guest marked `answers_the_ledger = false` is a fixed encounter that cannot drift. The HUD speaks one line per **rising** tier; relief is silent. This is the first mechanical consequence of imbalance; forest intrusion and debt-driven change are still later. |
| 2026-11-14 | **Lore decisions recorded** in `Shared_Lore/OPEN_QUESTIONS.md`: the Seamstress's royal arc is fully canon (Q7); the 2D sprite is the true Guest and the 3D lunging enemy is **not** it, with its own name still open (Q8); Fern's Whisperwings are **bonded, occasionally separated, never entirely lost** (Q9); **Mossy is the Little-Made**, a constructed friend, not a villager — the café's "Mossy Villager" is a naming collision to rename before Mossy is built (Q11); **Thornridge** is the game spelling (Q10); the **Hollow Oak** stands in the village centre with a pavilion, not on the map yet (Q29); the two projects are one world and 2D content is to be **moved into this project with nothing deleted** (Q30); the lore copies stay (Q31). Q6 (Elsby's pronoun) and Q12 (Briarwell's Kit) remain open. |
| 2026-11-14 | **Fog surges are dangerous** (user decision: both effects). `FogSurge._haunt()` runs in the hold phase only: it drains memory charge and frays silk, and sends one `guest.tscn` creature out of the mist every 7 s up to three. A summon is only placed on open ground — `_mist_spot()` raycasts the floor and rejects spots already inside a collider — so nothing ever steps out of a wall and stands there. `dangerous = false` restores the old atmosphere-only behaviour, because a setting that can only be changed by deleting code is not a setting. |
| 2026-11-14 | **Caves are procedural, but the Old Adit is not.** `mine_cave.tscn` keeps its fixed seams, its `gather.cave.*` save ids and its tests, because those are content people have already saved against. The new `wild_caves.tscn` is a different cave on every entry: nothing inside it is saveable, since a cave that changes shape must not remember what was mined in a shape that no longer exists. `spider_lair.tscn` reuses the generator with a **fixed** seed, because a character's home should not move between visits. |
| 2026-11-14 | The cave generator is **overlapping circles, not corridors**. Each chamber's wall ring skips arcs that fall inside a neighbour, so two overlapping circles leave a passage instead of a wall. One rule, no corridor authoring, and it is impossible to generate a sealed room or a hole into empty space. Wall blocks are left unrotated because `TownParts.collision()` only makes axis-aligned shapes; matching art and collision matters more than a jagged outline. |
| 2026-11-14 | **Cave enemies are Ghost Spiders; surface mist creatures stay the Guest.** The two silhouettes say different things (creeping thing vs. lunging thing), and the lore already separates them (Q8). Both caves use `ghost_spider.tscn`; the fog uses `guest.tscn`. |
| 2026-11-14 | The Spider Mother is **drawn as a half-spider** rather than given a second dialogue system: `SpiderMother extends QuestNpc` and overrides only `_build_model()`. Her dialogue, gift, quest lines, schedule and save data are ordinary `QuestNpc` behaviour. A subclass that changes the drawing cannot break the conversation. |
| 2026-11-14 | The Spider Mother **moved into a lair under the old houses**. Her `Villagers/SpiderMother` node was removed from `town.tscn` and she now stands in `spider_lair.tscn`; a `_spider_stair()` arch at `(-12, -46)` marks where she used to wait and holds the `AreaGate`. The town's ground is one solid slab, so the stair is an arch at ground level rather than a literal shaft: the gate at its mouth does the descending. |
| 2026-11-14 | **Ground lanes are one welded strip.** The old chain of boxes plus a square joint patch at every bend is what read as stamped tiles; `TownRibbon._build_strip()` now emits a single `ArrayMesh` with a mitred shared edge, a 3 m end taper and a ±7% width wobble. The user asked for **no asset change**, so the textures, triplanar projection and colour constants are untouched — only geometry. Ripples and water keep their old behaviour, with water at an even width. |
| 2026-11-14 | **Town villagers wander on generated rings.** `Npc.wander_radius` / `wander_center` / `wander_point_count` build a ring at load time, seeded from `hash(npc_name)`, so routes are stable across loads without ten hand-authored waypoint lists that would drift whenever a stall moved. Nine townsfolk walk the square; the four village folk keep authored rings around their own greens, because a villager from Ashfall must not wander into Thornridge. Fern and the scheduled indoor placements are unchanged. |
| 2026-11-14 | **Q27 answered: Mister Rabbit is alive in some way.** A stitched toy that breathes, is warm to the touch, and always ends up facing whoever is near. Nothing in the game explains it and Eli is never surprised, so the ambiguity Q27 asked for survives; only the "is it a prop" question is closed. Built as `StuffedRabbit extends StaticBody3D` (the root must be the collider, because the interaction ray checks the hit body for the `interactable` group) and placed beside Little Eli in the Garden Cottage. |
| 2026-11-14 | The cave bed is **synthesised**, like every other loop in the project: a low drone, a brown-noise breath, water drips and two far rumbles, 28 seconds long, with every sustained tone completing a whole number of cycles so the seam cannot click. `tools/make_cave_theme.py` is kept beside the WAV, matching `cut_generated_sprites.py`. |

## 16. Open questions

These are undecided. Do not silently choose an answer.

- Minimum target hardware and whether Steam Deck support matters.
- Final keybindings and controller support priority.
- Art style and placeholder asset pipeline.
- World scale: number of regions, approximate map size, interior count.
- Which sandbox systems are in scope: crafting, survival needs, horses, crime, factions, property ownership, marriage, modding.
- Dialogue presentation: text-only, voice-over, or hybrid.
- Localization languages and whether to localize from the start.
- Weather and seasons.
- Whether the game uses level scaling or fixed encounters.
