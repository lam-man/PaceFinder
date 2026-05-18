# AGENTS.md

## Project Overview

PaceFinder is an iOS mobility health app written in Swift. The workspace is organized around UIKit/AppDelegate-era app structure with feature code grouped into folders such as `Models`, `Data`, `Interface`, `Main View Controllers`, `Cells`, `Utilities`, and `Supporting Files`.

## User Background

- The user is a programmer and understands software development workflow, but is still new to iOS app development details.
- Do not assume the user already knows iOS-specific constraints such as root navigation wiring, scene lifecycle, HealthKit authorization flow, entitlements, provisioning, or storyboard/controller coupling.
- When a request touches iOS-specific behavior, explain the hidden dependencies and implementation risks before making broad code changes.

## Collaboration Workflow

- Act as the agent lead, not a blind executor. Evaluate whether the requested product change is technically feasible before editing code.
- Translate business requests into an implementation plan that identifies dependencies, risks, and the minimum safe change set.
- For broad product changes, present the practical solution first, then execute in phases. Do not jump straight into deleting or rewriting large areas.
- If there are multiple viable approaches, or if a request has hidden consequences, pause and confirm the direction before proceeding.
- Prefer incremental delivery: change one flow at a time, verify it, then move to the next step.
- When the user requests removal of old app surfaces, explicitly check what those surfaces currently provide before deleting them. Demo UI may still contain required navigation, authorization, onboarding, or data entry points.

## Change Safety Checklist

- Before removing screens or controllers, trace whether they still own any required capability such as navigation, permission prompts, HealthKit authorization, onboarding, or root app entry.
- Treat navigation structure as critical app infrastructure. Do not remove tab bars, navigation controllers, root view controller wiring, or storyboard entry points without first replacing their behavior.
- Treat authorization surfaces as critical app infrastructure. A page that looks disposable may still be the place where HealthKit or other required permissions are triggered.
- Preserve entitlements, signing, bundle identifier, HealthKit capability, and real-device data access unless the task explicitly changes them.
- When replacing a feature, keep the old working path intact until the new path is verified.
- After each meaningful deletion or replacement step, run a build and report exactly what still works, what changed, and what remains risky.

## Working Guidelines

- Read the nearby Swift files before editing so changes follow the existing controller, model, and utility patterns.
- Keep changes scoped to the requested behavior. Avoid broad refactors unless the task specifically calls for them.
- Preserve user work in the git tree. Do not revert files or branches unless explicitly asked.
- Prefer small, readable Swift changes over introducing new abstractions prematurely.
- Use existing app assets, storyboards, nibs, and interface files when they already support the requested behavior.

## Subagent Workflow

- The main agent is responsible for product reasoning, feasibility checks, and the overall plan. Do not delegate away the up-front architecture and risk assessment.
- Use explorer agents first for read-only dependency checks when a requested change may affect authorization, navigation, or other shared infrastructure.
- Only assign worker agents small, well-scoped tasks with disjoint file ownership after the plan is clear.
- Do not ask worker agents to perform broad destructive cleanup without a verified dependency map and a clear rollback point.
- After each implemented part, build the app before starting the next part when feasible, and report the result immediately.

## Verification

- When possible, build or run the relevant iOS target after code changes.
- If a full build is not available from the current environment, verify with targeted static checks and clearly report what was not run.
- For UI changes, inspect the relevant view/controller flow and confirm layout behavior for small and large device sizes when feasible.

## Git Notes

- The default branch in this local repository is `main`; there is no local `master` branch.
- Use `codex/` as the default branch prefix for agent-created work branches.
