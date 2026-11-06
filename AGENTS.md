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
| Current phase | **Phase 4 — Sandbox life** (started: five town villagers placed) |
| Project state | Phases 0–3 implemented; Phase 4 has begun with NPCs in Mycelgrove Hollow. Quests, dialogue, and schedules are still deferred. |

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
- `scenes/overworld.tscn` — the first exterior: sun, sky, a spawn pad, a stone
  return arch, four biome chunk managers, and the player. Reached through the
  room's back door. `overworld.gd` puts the player back on the spawn pad if they
  walk or fall below `fall_limit`, so the empty edge of the world is survivable.
- `features/world/chunks/` — the **plains** 3×3 set at the world origin (32 m
  chunks, grass, trees, rocks), reached through the back door.
- `features/world/chunks/ice/`, `desert/`, `ocean/` — three more generated 3×3
  sets placed through `chunk_origin`: ice to the north (`-1, -4`), desert to the
  north-east (`2, -4`), ocean to the east (`2, -1`). Each set uses its own ground
  colour and signature props (ice pillars and dead trees, cacti and dry shrubs,
  shallow water and sandbars). The ocean seabed sits 0.35 m below the other
  biomes, so the player wades instead of needing a swimming system.
- `scenes/test_room.tscn` — door, three chests, and the enemy carry stable save
  ids; the back door has a threshold pad and an `ExitGate` to the overworld.
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
- The four named villagers follow a simple day/night schedule. From **08:00 to
  18:00** they are outside their homes in the town; from **18:00 to 08:00** they
  are inside the bakery, Rowan's house, the yew cottage, and the beekeeper
  cottage. Each villager is authored twice — one home placement and one daytime
  placement — and `npc.gd` hides the inactive one from `WorldClock`, so nothing
  teleports between scenes. **Thatch** walks the Honeyed Way past the Hive Tower
  during the day. **Fern** has no home and wanders the main street at all hours.
- `assets/maps/mycelgrove_hollow_map.png` — the storybook reference map, kept in
  the project so future town work is checked against it.
- `features/ui/map_screen.tscn` + `map_screen.gd` — the full-screen storybook
  map on **M** (Esc also closes). It is a child of the HUD, so every gameplay
  scene gets it; it blocks the player like the inventory and does not pause.
  In the town it draws a "You are here" tag from the player's world position.
- `features/dialogue/dialogue_window.tscn` + `dialogue_window.gd` — the
  storybook conversation panel. A villager emits
  `Events.dialogue_requested(speaker, role, lines)`; the HUD-owned window shows
  one line at a time, **E** or **Space** advances, and **Esc** closes. It blocks
  the player like the inventory, and the map and inventory stay closed while it
  is open.

Still deferred: quests, shops, crafting, blended biome edges, and spells.

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
toggle_camera
inventory, journal, map, pause
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
- Walking through the room's back door reaches the exterior and the stone arch
  returns inside, keeping inventory and opened objects.
- The exterior shows four distinct biomes: plains around the spawn, ice to the
  north, desert to the north-east, and a shallow ocean to the east.
- Walking off the authored world drops the player back on the spawn pad instead
  of losing them.

### Verification commands

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path . tests/phase0_smoke.tscn
Godot_v4.7.2-stable_win64_console.exe --headless --path . tests/phase1_smoke.tscn
Godot_v4.7.2-stable_win64_console.exe --headless --path . tests/phase2_smoke.tscn
Godot_v4.7.2-stable_win64_console.exe --headless --path . tests/phase3_smoke.tscn
```

Each must print its own `PHASE0_SMOKE_OK` / `PHASE1_SMOKE_OK` / `PHASE2_SMOKE_OK` /
`PHASE3_SMOKE_OK`.
The Phase 1 test loads the real test room and drives the player: camera toggle,
camera collision, walk, sprint, jump, gravity, door, chest, HUD, fade overlay,
and pause. The Phase 2 test loads the same room and covers item definitions, the
item database, stacking and capacity, equip/unequip, health, stamina, chest loot
reaching the inventory, the inventory panel, enemy aggro and damage, armor
reduction, sword swings killing the enemy, and drinking a potion. The Phase 3
test covers the world clock, the version-1 save format, the slot model,
`newest_slot()` selection, quicksave and autosave isolation (temporarily backing
up and restoring slots 0 and 1), the saveable contract, a write/read/apply round
trip, corrupt and future-version saves, chunk streaming from fixtures and the
real chunk set, the room's exit gate, the HUD clock, and the pause-menu
save/load buttons. The biome checks confirm each biome folder holds a full 3×3
set, that `chunk_origin`/`chunk_to_world()` place it in world space, and that
each biome's chunks carry walkable ground and their signature scenery.

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
| 4 | Sandbox life: NPC schedules, dialogue, quests, shops, crafting | XL | Not started |
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
