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
| Current phase | **Phase 1 — Walking Skeleton** (implemented; awaiting user acceptance) |
| Project state | Phase 0 and Phase 1 implemented; combat and RPG systems are planned. |

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

Phase 0 and Phase 1 are implemented and validated with Godot 4.7.2:

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
- `features/interaction/chest.tscn` — one-shot chest; grants a placeholder item.
- `features/ui/hud.tscn` — crosshair, `[E]` interaction prompt, item toast.
- `SceneRouter` fades to black and back around scene changes.

Still deferred: saving, inventory, combat, quests, NPC schedules, and streaming.
The chest does not yet move items into an inventory; that is Phase 2.

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

### Verification commands

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path . tests/phase0_smoke.tscn
Godot_v4.7.2-stable_win64_console.exe --headless --path . tests/phase1_smoke.tscn
```

Both must print `PHASE0_SMOKE_OK` / `PHASE1_SMOKE_OK`. The Phase 1 test loads the
real test room and drives the player: camera toggle, camera collision, walk,
sprint, jump, gravity, door, chest, HUD, fade overlay, and pause.

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
| 2 | Core RPG loop: items, inventory, equipment, stats, combat, one enemy, HUD | L | Not started |
| 3 | Persistence and world: save/load, chunks, time, persistent objects | L | Not started |
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
