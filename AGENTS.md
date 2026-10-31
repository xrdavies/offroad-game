# AGENTS.md

## Git workflow

- Use Conventional Commits, such as `feat:`, `fix:`, `refactor:`, `docs:`, and `chore:`.
- Keep each commit focused on one coherent change; organize related code before committing.
- Import resources first, then run `tests/smoke.gd`; never run an import and its dependent runtime check concurrently.
- Inspect real rendered captures when changing models, materials, lighting, UI, or maps. A successful process exit alone is not visual verification.
- Push verified commits promptly to the configured remote.
- If no remote is configured, do not invent one; report the blocker before pushing.
- Do not commit generated Godot state, local build output, logs, or machine-specific files.

## Project hygiene

- Keep the implementation focused and prefer existing Godot APIs and project conventions.
- Avoid adding dependencies unless the current project cannot meet the requirement without one.
- Commit `.uid` and `.import` files with the resources they describe; ignore only `.godot/` and local build output.
- Keep editable generation sources and asset provenance alongside art and audio. Do not describe a development build as release-ready without the acceptance evidence in `docs/ACCEPTANCE.md`.
