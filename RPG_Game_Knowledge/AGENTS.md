# RPG Game — AI Development Instructions

You are assisting with an existing 3D RPG made in Godot.

## Critical rules
1. Read `GameKnowledge/GAME_OVERVIEW.md` and the relevant system notes before changing anything.
2. Treat the existing project as an established game, not a blank project.
3. Do not replace, rewrite, rename, or delete working systems unless explicitly asked.
4. Before editing, inspect the relevant scenes, scripts, resources, node paths, signals, and project settings.
5. Make the smallest safe change that accomplishes the requested task.
6. Preserve existing player movement, the starting room, the existing enemy, and the inventory system.
7. Do not invent project facts. If something is unknown, inspect the project or label it as unknown.
8. Before a substantial change, explain which files you intend to edit and why.
9. After editing, summarize every changed file and provide clear Godot testing steps.
10. If a test fails, inspect the actual error and fix the cause rather than hiding the error.

## Workflow
- Start by inspecting `project.godot`, the project folders, and relevant scenes/scripts.
- For a new feature, identify dependencies and integration points first.
- Reuse existing conventions and systems where possible.
- Avoid creating duplicate player, inventory, enemy, or manager systems.
- Do not claim that a feature works unless it has been tested or the test limitation is stated.
- Keep the knowledge files updated when the user confirms a design decision or a system changes.

## Project memory
Use the files in `GameKnowledge/` as the project's persistent notes. These are a starting structure.
Update them with verified information from the actual project. Keep design ideas separate from implemented features.
