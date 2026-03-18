---
name: changelog
description: Generate user-facing changelog entries from git commits with semantic versioning and daily grouping. Translates technical commits into clear, user-friendly descriptions for a TypeScript changelog data file. Use this skill when the user asks to update the changelog, document recent changes, prepare a release, or after finishing a series of commits. Also use when you detect significant work has been completed and changes should be logged - in that case, propose entries and ask for confirmation before writing.
argument-hint: "[--preview] [day|week|month|<N>d|--since-tag <tag>]"
---

# Changelog Generator

Generate **user-facing changelog entries** from git commits. Uses a hybrid architecture: a deterministic bash script handles mechanical work (commit range, filtering, version calculation), Claude handles creative work (translation, consolidation, summary).

## Architecture

```
changelog-prep.sh (deterministic)    SKILL.md (Claude)
┌──────────────────────────┐         ┌──────────────────────────┐
│ Commit boundary (SHA)    │         │ Translate to plain English│
│ Filter by prefix         │ ─────>  │ Consolidate duplicates   │
│ Calculate version        │ stdout  │ Cross-release dedup      │
│ INSERT vs UPDATE mode    │         │ Merge existing (UPDATE)  │
│ Structured manifest      │         │ Write changelog.ts       │
└──────────────────────────┘         └──────────────────────────┘
```

## Step 1: Run the Prep Script

Run the `changelog-prep.sh` script located in the same directory as this skill file. Pass through any user-provided arguments.

```bash
bash <skill-directory>/changelog-prep.sh [arguments]
```

Parse the manifest output. The format is:
```
CHANGELOG_FILE=<path>
MODE=INSERT|UPDATE
LAST_VERSION=X.Y.Z
NEW_VERSION=X.Y.Z
BUMP=major|minor|patch
TODAY=YYYY-MM-DD
LAST_DATE=YYYY-MM-DD
BOUNDARY_SHA=<sha>
PREVIEW=true|false
===INCLUDED===
<hash>|<date>|<commit message>
...
===REVIEW===
<hash>|<date>|<commit message>
...
===END===
```

**If the output starts with `ERROR=`:** Display the error message to the user and stop.

## Step 2: Review Borderline Commits

The REVIEW section contains `refactor:` commits that may or may not be user-visible.

For each commit in REVIEW:
- **Does it change what users see or experience?** (e.g., faster loading, different layout, changed behavior)
- If yes: include it as type `improvement`
- If no: discard it (internal restructuring only)

## Step 3: Translate to User-Friendly Language

Users see this changelog in the app. Write for humans, not developers.

### Rules:
- Focus on what users **see, experience, or can do**
- Use past tense: "Added", "Fixed", "Improved"
- Target 10-20 words per description
- Be specific and concrete

### Commit prefix to change type mapping:
| Prefix | Change Type |
|--------|------------|
| `feat:` | `feature` |
| `fix:` | `fix` |
| `perf:` | `improvement` |
| `refactor:` (user-visible) | `improvement` |
| `style:`, `ui:`, `design:` | `design` |

### DO NOT mention:
- Component names (e.g., `PhotoGrid`, `UserModal`, `Sidebar`)
- Libraries or frameworks (e.g., `React`, `HeroUI`, `Zustand`, `TanStack`)
- Implementation details (e.g., `LRU cache`, `IndexedDB`, `hook architecture`)
- Developer jargon (e.g., `refactor`, `cleanup`, `optimize architecture`)
- File names or code structure
- Internal measurements unless user-facing

### Translation examples:

```
feat: Add TanStack Virtual to PhotoGrid component
-> "High-performance rendering for large photo collections"

fix: Resolve Zustand reactivity bug in cacheStore
-> "Fixed thumbnail synchronization for smoother loading"

perf: Optimize LRU cache eviction strategy
-> "Faster thumbnail loading with improved memory usage"

style: Update HeroUI Button design tokens
-> "Refreshed button design with modern styling"

feat: Implement JWT refresh token rotation
-> "Longer login sessions without interruptions"
```

## Step 4: Anti-Duplication (Within Release)

When multiple commits describe the same feature or change, consolidate them into a single entry.

**Detection rule:** If commit A introduces feature X, and commit B modifies/redesigns/fixes feature X, merge them into ONE entry describing the complete feature.

Example:
```
feat: Add dark mode toggle
fix: Fix dark mode not persisting
ui: Improve dark mode transition
-> ONE entry: "Dark mode with smooth transitions and persistent preferences"
```

## Step 5: Cross-Release Deduplication

**CRITICAL: This prevents the duplicate bug.**

Read the **previous release's** entries from the changelog file. For each candidate new entry, check if it describes the same user-visible change as an existing entry in the prior release.

If a candidate is semantically the same as a previous release entry: **exclude it**.

This catches edge cases where commits straddle changelog updates on the same day. The prep script's commit-SHA boundary prevents most duplicates, but this is the safety net.

## Step 6: Merge Logic (UPDATE Mode Only)

When `MODE=UPDATE`, today's entry already exists in the changelog. Preserve manual edits:

1. Read the existing today's entry from the changelog file
2. For each existing entry, try to match it to a commit in the INCLUDED list (by semantic similarity - does the existing description correspond to this commit?)
3. **Matched entries:** keep the existing description (the user may have hand-edited it)
4. **Unmatched existing entries:** preserve as-is (these are manual additions)
5. **New commits with no matching existing entry:** translate and add as new entries
6. Sort the final list by priority: feature -> design -> improvement -> fix

In INSERT mode, skip this step entirely - just use the translated entries.

## Step 7: Impact Classification

Each change needs an `impact` field:

### `minor` impact - notable changes users will notice:
- New features and capabilities
- Significant UI/UX improvements
- Major design changes

### `patch` impact - smaller changes:
- Bug fixes
- Minor polish and tweaks
- Performance improvements
- Small UI adjustments

### `major` impact - rare, breaking changes:
- Complete UI overhauls
- Removed features
- Fundamental workflow changes

## Step 8: Generate Summary

- 2+ features: combine top two - "Dark mode and CSV export"
- 1 feature: use its description
- No features, has improvements/fixes: "Performance and stability improvements"
- Only design: "Design and visual improvements"

## Step 9: Order Changes by Priority

Changes within each release **must** be sorted:

1. **feature** - New capabilities (highest priority)
2. **design** - Visual/UX redesigns
3. **improvement** - Enhancements to existing features
4. **fix** - Bug fixes (lowest priority)

## Step 10: Generate TypeScript Entry

```typescript
{
  version: 'X.Y.Z',       // NEW_VERSION from manifest
  date: 'YYYY-MM-DD',     // TODAY from manifest
  summary: '...',          // From Step 8
  changes: [
    {
      type: 'feature',        // 'feature' | 'fix' | 'improvement' | 'design'
      description: '...',     // User-friendly description from Step 3
      impact: 'minor'         // 'major' | 'minor' | 'patch'
    }
  ]
}
```

## Step 11: Write to File

### If `PREVIEW=true`:
Show what would be written but do NOT modify any files. Display version calculation, mode, changes, and summary.

### INSERT MODE (new day):
Add the new entry at the beginning of the `changelogReleases` array, right after the opening `[`.

### UPDATE MODE (same day):
Replace the first entry in the array (today's existing entry) with the merged result from Step 6.

### Validation before writing:
- TypeScript syntax is valid
- Version format is `X.Y.Z`
- Date format is `YYYY-MM-DD`
- All single quotes properly escaped in descriptions
- Change types are valid (`feature`, `fix`, `improvement`, `design`)

## Step 12: Output

### INSERT MODE output:
```
Changelog updated!

Mode: INSERT (new release)
Version: vX.Y.Z (BUMP_TYPE bump - reason)
Date: YYYY-MM-DD
Summary: ...

Changes:
1. type: description
2. type: description

File updated: <path>
```

### UPDATE MODE output:
```
Changelog updated!

Mode: UPDATE (merged into today's release)
Version: vX.Y.Z (cumulative for today)
Date: YYYY-MM-DD

Change diff:
+ ADDED: new entries from recent commits
~ MERGED: consolidated entries
= KEPT: preserved manual edits

File updated: <path>
```

## Error Handling

- **Script returns `ERROR=`:** Display the message directly to the user
- **Can't parse version:** "Could not parse the last version number. Please check the changelog format."
- **No changelog file:** "No changelog file found. Would you like me to create one?"

## Creating a New Changelog

When a project has no changelog, create these files:

### 1. Type definitions (`src/types/changelog.ts` or add to existing types):

```typescript
export type ChangeType = 'feature' | 'fix' | 'improvement' | 'design'
export type ChangeImpact = 'major' | 'minor' | 'patch'

export interface ChangelogChange {
  type: ChangeType
  description: string
  impact: ChangeImpact
}

export interface ChangelogRelease {
  version: string
  date: string
  summary: string
  changes: ChangelogChange[]
}
```

### 2. Data file (`src/data/changelog.ts`):

```typescript
import type { ChangelogRelease } from '@/types/changelog'

export const changelogReleases: ChangelogRelease[] = []
```

Adapt the import path to match the project's path alias conventions (check `tsconfig.json` for `paths` or `baseUrl`).

After creating the files, proceed with generating the first changelog entry.
