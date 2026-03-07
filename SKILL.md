---
name: changelog
description: Generate user-facing changelog entries from git commits with semantic versioning and daily grouping. Translates technical commits into clear, user-friendly descriptions for a TypeScript changelog data file. Use this skill when the user asks to update the changelog, document recent changes, prepare a release, or after finishing a series of commits. Also use when you detect significant work has been completed and changes should be logged — in that case, propose entries and ask for confirmation before writing.
argument-hint: "[--preview] [day|week|month|<N>d|--since-tag <tag>]"
---

# Changelog Generator

Generate **user-facing changelog entries** from git commits. Outputs structured TypeScript data that apps render in a "What's New" modal or similar UI.

## Core Behavior

- Read git commits since the last changelog entry
- Parse conventional commit prefixes to categorize changes
- Translate technical language into plain, user-friendly descriptions
- Calculate semantic version based on change impact
- Group all changes from the same day into one release
- Write structured TypeScript to the project's changelog data file
- **When auto-invoked (not triggered by user):** propose the entries and ask for confirmation before writing

## Step 1: Locate the Changelog

Search the project for the changelog data file. Check these locations in order:

1. `src/data/changelog.ts`
2. `data/changelog.ts`
3. Any `.ts` file containing `changelogReleases` (use grep)

If no changelog file exists, ask the user if they want to create one. If yes, create both the data file and type definitions (see "Creating a New Changelog" below).

## Step 2: Read the Last Entry

From the changelog data file, extract:
- **Last version** (e.g., `1.3.2`)
- **Last date** (e.g., `2025-10-19`)

These determine whether to INSERT a new release or UPDATE today's existing one.

## Step 3: Determine the Commit Range

**Default (no arguments):** Get commits since the last changelog date.

```bash
git log --since="LAST_DATE 00:00" --pretty=format:'%h|%as|%s' --no-merges --reverse
```

**With time argument:**
- `day` → `--since='1 day ago'`
- `week` → `--since='1 week ago'`
- `month` → `--since='1 month ago'`
- `<N>d` (e.g., `3d`) → `--since='N days ago'`
- `--since-tag <tag>` → commits since that git tag

If no commits are found: "No new commits since last changelog entry. You're all caught up!"

## Step 4: Daily Grouping (UPDATE vs INSERT)

**One release per day.** Compare the last entry's date with today:

- **Last date === today → UPDATE MODE**: Replace today's existing entry with a cumulative one containing all changes
- **Last date !== today → INSERT MODE**: Create a new entry at the beginning of the array

This prevents multiple releases on the same day and keeps the changelog clean.

## Step 5: Filter Commits

### Include (user-visible changes):

| Prefix | Change Type | Impact |
|--------|------------|--------|
| `feat:` | `feature` | `minor` |
| `fix:` | `fix` | `patch` |
| `perf:` | `improvement` | `patch` |
| `refactor:` (with user impact) | `improvement` | `patch` |
| `style:`, `ui:`, `design:` | `design` | `minor` |

### Exclude (not user-visible):

- `docs:` — documentation (unless user-facing help/guides)
- `test:` — test changes
- `chore:` — maintenance, dependencies
- `refactor:` — code restructuring (unless it changes user experience)
- `WIP:` — work in progress
- Merge commits
- `chore: auto-update` or similar automated commits
- File operation commits (`add files via upload`, `delete filename.ts`)

**Exception:** If an excluded commit has clear user-visible impact, include it.

## Step 6: Anti-Duplication

When multiple commits describe the same feature or change in the same release, consolidate them into a single entry.

**Detection rule:** If commit A introduces feature X, and commit B modifies/redesigns/fixes feature X in the same release, merge them into ONE entry describing the complete feature.

Example:
```
feat: Add dark mode toggle
fix: Fix dark mode not persisting
ui: Improve dark mode transition
→ ONE entry: "Dark mode with smooth transitions and persistent preferences"
```

## Step 7: Calculate Semantic Version

Parse the last version into MAJOR.MINOR.PATCH, then:

- **MAJOR bump** (`X+1.0.0`): Commit contains `BREAKING CHANGE` or uses `!:` (e.g., `feat!:`)
- **MINOR bump** (`X.Y+1.0`): Has `feat:`, `style:`, `ui:`, or `design:` commits
- **PATCH bump** (`X.Y.Z+1`): Only `fix:`, `perf:`, `refactor:` commits

In UPDATE MODE, version increments cumulatively from the existing today's version.

**Daily cumulative example:** Starting from v1.2.1:
- Morning: feat (→ v1.3.0) + Afternoon: fix (→ v1.3.1) + Evening: feat (→ v1.4.0)
- Result: Single release **v1.4.0** with all changes

## Step 8: Translate to User-Friendly Language

Users see this changelog in the app. Write for humans, not developers.

### Rules:
- Focus on what users **see, experience, or can do**
- Use past tense: "Added", "Fixed", "Improved"
- Target 10-20 words per description
- Be specific and concrete

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
→ "High-performance rendering for large photo collections"

fix: Resolve Zustand reactivity bug in cacheStore
→ "Fixed thumbnail synchronization for smoother loading"

perf: Optimize LRU cache eviction strategy
→ "Faster thumbnail loading with improved memory usage"

style: Update HeroUI Button design tokens
→ "Refreshed button design with modern styling"

feat: Implement JWT refresh token rotation
→ "Longer login sessions without interruptions"
```

## Step 9: Generate the Entry

### TypeScript structure:

```typescript
{
  version: 'X.Y.Z',
  date: 'YYYY-MM-DD',
  summary: 'Brief highlight of key changes',
  changes: [
    {
      type: 'feature',        // 'feature' | 'fix' | 'improvement' | 'design'
      description: '...',     // User-friendly description
      impact: 'minor'         // 'major' | 'minor' | 'patch'
    }
  ]
}
```

### Order changes by importance: Features → Improvements → Design → Fixes

### Summary generation:
- 2+ features → combine top two: "Dark mode and CSV export"
- 1 feature → use its description
- No features, has improvements/fixes → "Performance and stability improvements"
- Only design → "Design and visual improvements"

## Step 10: Write to File

### INSERT MODE (new day):
Add the new entry at the beginning of the `changelogReleases` array, right after the opening `[`.

### UPDATE MODE (same day):
Replace the first entry in the array (today's existing entry) with the new cumulative one.

### Validation before writing:
- TypeScript syntax is valid
- Version format is `X.Y.Z`
- Date format is `YYYY-MM-DD`
- All single quotes properly escaped in descriptions
- Change types are valid (`feature`, `fix`, `improvement`, `design`)

## Step 11: Output

### If `--preview` flag is set:
Show what would be written but do NOT modify any files. Display version calculation, changes, and summary.

### INSERT MODE output:
```
Changelog updated!

Mode: INSERT (new release)
Version: v1.4.0 (MINOR bump — new features)
Date: 2025-10-20
Summary: Grid zoom controls and faster thumbnail loading

Changes:
1. feature: Zoom controls to adjust photo card size
2. fix: Eliminated thumbnail flashing during navigation
3. design: Improved button spacing for cleaner layout

File updated: src/data/changelog.ts
```

### UPDATE MODE output:
```
Changelog updated!

Mode: UPDATE (merged into today's release)
Version: v1.4.1 (cumulative for today)
Date: 2025-10-20

Change diff:
+ ADDED: Fixed zoom button positioning
~ MERGED: "Grid zoom" + "Zoom fix" → consolidated entry
= KEPT: Improved button spacing for cleaner layout

File updated: src/data/changelog.ts
```

## Error Handling

- **No commits found:** "No new commits since last changelog entry. You're all caught up!"
- **All commits filtered:** "All recent commits are internal/automated. Nothing to add to the changelog."
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

## Impact Guidelines

### `minor` impact — notable changes users will notice:
- New features and capabilities
- Significant UI/UX improvements
- Major design changes

### `patch` impact — smaller changes:
- Bug fixes
- Minor polish and tweaks
- Performance improvements
- Small UI adjustments

### `major` impact — rare, breaking changes:
- Complete UI overhauls
- Removed features
- Fundamental workflow changes
