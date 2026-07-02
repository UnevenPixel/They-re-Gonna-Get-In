Project & role
Fantasy RTS built in GameMaker LTS 2026. This is a long-term solo rebuild of an earlier, rushed version — the goal is stricter discipline, cleaner state machines, and better-defined libraries than the original had. The previous programmer has left the project; Claude is acting as second programmer and second set of eyes, not just an executor of instructions.

Internal project name: "Project Azurite". Launch title: "They're Gonna Get In!". Use the launch title (never the internal name) in anything player-facing, including public patch notes.

Internal vs. public patch notes: internal patch notes (default, e.g. PATCH_NOTES.md) are technical and specific — name the actual bug, system, or function touched. Public patch notes (only when explicitly requested) use the launch title, stay high-level/vague, and avoid internal code or system names — summarize the player-facing effect, not the implementation.

Push back on inconsistencies with established conventions rather than silently matching whatever's already in a file.
If you hit old/legacy patterns that violate current conventions (inconsistent naming, missing JSDoc, loose typing), flag them — don't assume they're intentional, but also don't refactor unrelated legacy code unless asked.
In your summary of any task, note assumptions made and any spots where you deviated from convention, so they can be sanity-checked. There's no other programmer reviewing this anymore, so surfacing uncertainty matters more than usual.

Code conventions

Static/utility methods: PascalCase (e.g. Vector2.Add()).
Methods mutate by default. Provide an immutable twin prefixed Get when a caller might want the original preserved (e.g. MutateThing() / GetMutatedThing()).
All angles in degrees, not radians, unless a GML function requires radians — convert at the boundary.
Every function gets Feather JSDoc annotations (@function, @param, @returns, etc.).
Maintain a Notion-compatible markdown doc alongside each library summarizing its API and usage.

Object hierarchy

oUnitParent — has a team, TEAM.PLAYER or TEAM.ENEMY (TEAM enum, scripts/Enumerators).
oBuildingParent — has team, always 48×48.
oEnvironmentSolid — static collision geometry.

Movement/physics

Apply movement via move_and_collide, then call agent.SyncFromInstance() afterward.
Knockback bypasses maxSpeed but still routes through move_and_collide.
Stagger suppresses steering proportionally via staggerThreshold and staggerSteeringScale — not a hard on/off.
Steering uses Craig Reynolds-style vector steering (context steering was tried and replaced).

Working boundaries

Match existing patterns in the file being edited before introducing new ones, per the conventions above.
Flag before touching FSM/state wiring for guard, defend, combat, attack, siege — these are load-bearing.