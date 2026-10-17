# Project configuration

The one file that holds what is specific to this project. Every skill reads its project facts from here.

## Project

- **Name:** The Shattering
- **Purpose:** A top-down 2D action RPG with souls-lite combat, set in the Broken World, a planet that stopped spinning. A solo project by KrisUni.
- **Regulated:** no.

## Repositories

Agents never merge.

| Repository | Role | Branch base and review base | PR target | Where commands run |
| --- | --- | --- | --- | --- |
| `KrisUni/the-shattering` | primary | `origin/main` | `main` | host |

## Branches, commits, and issue references

- **Branch name:** `<n>-<slug>`, created from `origin/main`. Linked branches (GraphQL `createLinkedBranch`) are unavailable from Claude sessions, so the branch is created with git and the PR links the issue.
- **Commit message:** `<verb> <what> (#<n>)`
- **Closing keyword:** the PR uses `Closes #<n>`.
- **Never commit directly to:** `main`. Work goes through a pull request.
- **Commit trailers:** none required.

## Design records

- **Glossary:** `CONTEXT.md` at the repository root, the one glossary for the whole game.
- **ADRs:** `docs/adr/`, named `ADR-XXXX-<slug>.md`.
- **Design process:** an ADR is written only for a decision that is hard to reverse or would surprise someone.

## Issue tracker

- **Tracker:** GitHub Issues via `gh`. GitHub GraphQL is unavailable from Claude sessions; use the REST API (`gh api repos/KrisUni/the-shattering/...`), including the sub-issue and issue-dependency endpoints.
- **Issue templates:** Task `.github/ISSUE_TEMPLATE/task.md`, Feature `.github/ISSUE_TEMPLATE/feature.md`. Both open with a plain-language Summary (Problem, Outcome).
- **Native issue types:** none (personal repository). Use the labels `task` and `feature`.
- **Hierarchy:** Tasks are sub-issues of their Feature. Blocking uses GitHub's issue dependencies.

### Metadata the planning skill sets

| Where | Field | Value when published | Default when not established |
| --- | --- | --- | --- |
| Issue | Label | `feature` or `task` | — |

**Fields the skills must never write:** assignees, milestones and any label other than `feature` and `task`. **Boards:** none.

## Pull requests

- **Template:** none; the body follows the shared WRITING.md guidance.
- **Title form:** as the commit message.

### Merge gates

| Gate | `the-shattering` |
| --- | --- |
| Required checks | none yet |
| Human approvals | the owner reviews and merges |
| Author's merge action | merge |

## Verification

Tests use GUT and run headless through `scripts/test.sh`, which does the first import pass on a fresh checkout. `GODOT` must point at a Godot 4.7 binary (it defaults to `godot` on PATH).

| Area | Guide | Narrow test | Full suite |
| --- | --- | --- | --- |
| game (repository root) | — | `scripts/test.sh res://test/test_<name>.gd` | `scripts/test.sh` |

**Commands that need the user's explicit approval before an agent runs them:** none yet.

**Expensive CI:** none.

## Project rules every change follows

- The game is built in Godot 4 with GDScript.
- Code, scenes and issues use the vocabulary of `CONTEXT.md`.
- Tuning numbers (costs, damage, timings, heights) live in data files, not in code, so they can be changed without touching logic.
- Art is placeholder until an art direction is chosen.
