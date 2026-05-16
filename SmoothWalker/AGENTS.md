# AGENTS.md

## Project Overview

SmoothWalker is an iOS mobility health app written in Swift. The workspace is organized around UIKit/AppDelegate-era app structure with feature code grouped into folders such as `Models`, `Data`, `Interface`, `Main View Controllers`, `Cells`, `Utilities`, and `Supporting Files`.

## Working Guidelines

- Read the nearby Swift files before editing so changes follow the existing controller, model, and utility patterns.
- Keep changes scoped to the requested behavior. Avoid broad refactors unless the task specifically calls for them.
- Preserve user work in the git tree. Do not revert files or branches unless explicitly asked.
- Prefer small, readable Swift changes over introducing new abstractions prematurely.
- Use existing app assets, storyboards, nibs, and interface files when they already support the requested behavior.

## Verification

- When possible, build or run the relevant iOS target after code changes.
- If a full build is not available from the current environment, verify with targeted static checks and clearly report what was not run.
- For UI changes, inspect the relevant view/controller flow and confirm layout behavior for small and large device sizes when feasible.

## Git Notes

- The default branch in this local repository is `main`; there is no local `master` branch.
- Use `codex/` as the default branch prefix for agent-created work branches.
