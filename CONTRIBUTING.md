# Contributing & Multi-Agent Collaboration Guide

This repo is developed by a human owner plus multiple AI agents (Copilot CLI as
agent leader, plus cloud agents like Copilot coding agent / Codex). This guide
defines how we collaborate so work stays parallel-friendly and reviewable.

## Roles

- **Owner (human)** — sets product direction, makes final decisions, reviews PRs.
- **Agent Leader (Copilot CLI)** — discusses design with owner, breaks work
  down, files issues, dispatches tasks, reviews and merges PRs.
- **Worker agents** — pick up `agent-ready` task issues and produce one PR each.

## Workflow

1. **Design first.** Open a `📋 Design` issue. Discuss until acceptance criteria
   and approach are agreed.
2. **Break down.** Agent Leader files `🧩 Task` issues, one per PR-sized unit,
   each linked to the parent design issue.
3. **Dispatch.** Add the `agent-ready` label and (optionally) assign an agent.
   Each task should be independently executable.
4. **Implement.** Worker agent creates a branch, implements, opens a PR linked
   to the task issue (`Closes #N`).
5. **Review & merge.** CI must be green. Squash merge into `main`.

## Branch Naming

`<type>/<short-slug>` where type is one of:
`feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `design`.

Examples: `feat/pace-zones`, `fix/healthkit-launch-crash`,
`refactor/running-data-manager`.

## Commit Messages

Follow Conventional Commits:

```
<type>(<optional scope>): <short imperative summary>

<body explaining what and why, not how>

Co-authored-by: ...
```

Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `perf`, `build`,
`ci`, `revert`.

## PR Rules

- One PR per task issue. Keep PRs small and focused.
- Link the issue with `Closes #N`.
- CI (iOS build) **must pass** before merge.
- Use **squash merge** to keep `main` history linear.
- Don't mix unrelated changes.

## Labels

| Label | Meaning |
|---|---|
| `design` | Design discussion / epic |
| `task` | Executable subtask |
| `agent-ready` | Spec is complete; an agent can pick this up |
| `bug` | Defect |
| `blocked` | Cannot proceed; reason in comments |
| `needs-discussion` | Awaiting alignment before work starts |
| `in-review` | PR open, under review |

## Definition of Done (per task)

- Code merged to `main`
- CI green
- Linked issue auto-closed
- Behavior change reflected in `AGENTS.md` / docs if relevant
