# AGENTS.md

## Git workflow

- Use Conventional Commits, such as `feat:`, `fix:`, `refactor:`, `docs:`, and `chore:`.
- Keep each commit focused on one coherent change; organize related code before committing.
- Run the relevant Godot headless checks before committing.
- Push verified commits promptly to the configured remote.
- If no remote is configured, do not invent one; report the blocker before pushing.
- Do not commit generated Godot state, local build output, logs, or machine-specific files.

## Project hygiene

- Keep the prototype small and prefer existing Godot APIs and project conventions.
- Avoid adding dependencies unless the current project cannot meet the requirement without one.
