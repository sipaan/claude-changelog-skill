---
name: changelog
description: Generate user-facing changelog entries from git commits with calendar versioning (YYYY.MM.DD) and daily grouping. Translates technical commits into clear, user-friendly descriptions for a TypeScript changelog data file. Use this skill when the user asks to update the changelog, document recent changes, prepare a release, or after finishing a series of commits. Also use when you detect significant work has been completed and changes should be logged - in that case, propose entries and ask for confirmation before writing.
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
│ CalVer version (today)   │ stdout  │ Cross-release dedup      │
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
LAST_VERSION=YYYY.MM.DD
NEW_VERSION=YYYY.MM.DD
IMPACT=major|minor|patch
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
- **Write factual changelog statements, not feature specs.** State what changed and what it does. Cut implementation details that don't help the reader understand the change. If the benefit is obvious from the statement, don't spell it out.
- Pattern: `[Subject] [verb] [what changed]` - target 10-20 words
- Be specific and concrete
- Trim filler words - every word should earn its place
- Don't cram multiple changes into one entry - if two things changed, make two entries

### Commit prefix to change type mapping:
| Prefix | Change Type |
|--------|------------|
| `feat:` | `feature` (but see Feature History Check below) |
| `fix:` | `fix` |
| `perf:` | `improvement` |
| `refactor:` (user-visible) | `improvement` |
| `style:`, `ui:`, `design:` | `design` |

### Feature Classification Gate (overrides prefix mapping)

Before checking history, ask a threshold question for every `feat:` commit:

**"Could the user already do or see this before this commit?"**

- If **yes, but in a different place**: type is `design` (relocation, not new capability)
- If **yes, but with different parameters/timing**: type is `improvement` (tuning, not new capability)
- If **no, this is genuinely new**: proceed to History Check below

Examples of relocation → `design`:
```
feat: move kept/binned counts to sidebar
-> Counts already existed in the topbar. This is `design` (relocated UI element).

feat: add export button to navbar
-> If export already existed elsewhere, this is `design`. If export is brand new, it's `feature`.
```

Examples of tuning → `improvement`:
```
feat: more frequent milestones and longer display time
-> Milestones already existed. Changing frequency/duration is `improvement`.

feat: increase recent folders limit from 5 to 10
-> Recent folders already existed. Expanding a limit is `improvement`.
```

### Feature History Check (further override for remaining `feature` entries)

After the Classification Gate, for any commits still typed as `feature`, read ALL prior releases in the changelog file (not just the previous one). Check if the same capability already appears as a `feature` entry in ANY prior release.

**Match by topic, not exact wording.** Extract the core noun/capability (e.g., "compare mode", "export", "recent folders", "badges") and search for it across all prior `feature` entries.

- If a prior release already logged the same capability as `feature`: **downgrade to `improvement`**. The new commit enhances an existing feature, it doesn't introduce one.
- If no prior release mentions this capability: keep as `feature`.

Examples:
```
Prior release has: "Compare mode in lightbox - view two photos side-by-side"
New commit: "feat: Lightroom-style compare mode with per-panel controls"
-> Type becomes `improvement`, not `feature` (compare mode already existed)

Prior release has: "Recent folders - switch between 5 folders from the welcome page"
New commit: "feat: Folder picker dropdown in navbar with 10 recent folders"
-> Type becomes `improvement` (recent folders already existed, now more accessible)

No prior release mentions "Quick Cull" or "Tinder mode"
New commit: "feat: Add Quick Cull for forced-decision photo culling"
-> Stays `feature` (genuinely new capability)
```

This check applies regardless of how far back the prior release is - a feature introduced months ago is still not "new" when enhanced today.

### DO NOT use:
- Em dashes (—). Use a regular hyphen-minus (-) instead for separators in descriptions

### DO NOT mention:
- Component names (e.g., `PhotoGrid`, `UserModal`, `Sidebar`)
- Libraries or frameworks (e.g., `React`, `HeroUI`, `Zustand`, `TanStack`)
- Implementation details (e.g., `LRU cache`, `IndexedDB`, `hook architecture`)
- Developer jargon (e.g., `refactor`, `cleanup`, `optimize architecture`)
- File names or code structure
- Internal measurements unless user-facing

### Translation examples:

**Stripping developer language:**
```
feat: Add TanStack Virtual to PhotoGrid component
-> "High-performance rendering for large photo collections"

fix: Resolve Zustand reactivity bug in cacheStore
-> "Fixed thumbnail synchronization for smoother loading"

perf: Optimize LRU cache eviction strategy
-> "Faster thumbnail loading with improved memory usage"
```

**Writing style - avoid feature specs and marketing copy:**
```
Feature spec (avoid):  "Confirmation screen before bulk date repairs showing which photos will be changed"
Marketing copy (avoid): "See exactly which photos will be affected before running a bulk repair"
Changelog statement:    "Bulk date repair shows a preview of affected photos before applying"

Feature spec (avoid):  "Adaptive info panel shows parsed dates, file info, and export preview instead of empty fields for non-camera photos"
Changelog statement:    "Info panel shows parsed dates and file info for non-camera photos instead of empty fields"

Too verbose (avoid):   "Photos from WhatsApp and other apps now recover their time from the file modified date, or use the filename sequence number to keep the correct order"
Changelog statement:    "WhatsApp and app photos now recover their time for correct gallery order"

Laundry list (avoid):  "Compare mode upgraded to Lightroom-style layout with per-panel star ratings, Keep/Bin buttons, EXIF metadata, Swap (X key), and multi-undo support"
Changelog statement:    "Compare mode upgraded to Lightroom-style layout with independent controls per panel"

Too wordy (avoid):     "Thumbnails no longer silently disappear when background cache maintenance runs during loading"
Changelog statement:    "Thumbnails no longer disappear during background cache maintenance"
```

## Step 4: Anti-Duplication (Within Release)

When multiple commits describe the same feature or change, consolidate them into a single entry.

**Rule 1 - Same feature, multiple commits:** If commit A introduces feature X, and commit B modifies/redesigns/fixes feature X, merge them into ONE entry describing the complete feature.

Example:
```
feat: Add dark mode toggle
fix: Fix dark mode not persisting
ui: Improve dark mode transition
-> ONE entry: "Dark mode with smooth transitions and persistent preferences"
```

**Rule 2 - Detail of a larger entry:** If an entry describes a minor UI placement or sub-detail of a bigger entry in the same release, absorb it into the parent entry rather than listing it separately. A standalone entry should describe a capability the user would independently care about.

Example:
```
feat: Smart Export with date-based organization and file renaming
feat: Export button in the top navigation bar for quick access
-> ONE entry: The nav button is just where the export feature lives, not a separate capability. Absorb into the Smart Export entry.

feat: Smart Export with date-based organization
feat: Reusable export profiles for one-click exports
-> TWO entries: Export profiles are a distinct capability users would independently value.
```

**Rule 3 - Same-day design of a new feature:** If a feature is introduced AND its design is polished on the same day, the design entry is part of the feature's initial release. Do not list a separate `design` entry for it. Only list `design` entries for redesigns of previously shipped features.

## Step 5: Cross-Release Deduplication

**CRITICAL: This prevents the duplicate bug.**

Read **ALL existing releases** from the changelog file. For each candidate new entry, check if it describes the same user-visible change as an existing entry in ANY prior release.

If a candidate is semantically the same as a previous release entry: **exclude it**.

This catches two cases:
1. Commits that straddle changelog updates on the same day (the prep script's SHA boundary prevents most, but this is the safety net).
2. Features that were developed across multiple sessions/days - if the same capability was already logged in a release from days or weeks ago, don't log it again.

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

Each change needs an `impact` field for **display ordering** (not version bumping — CalVer versions are always today's date):

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
  version: 'YYYY.MM.DD',    // NEW_VERSION from manifest (today's date)
  date: 'YYYY-MM-DD',       // TODAY from manifest
  summary: '...',            // From Step 8
  changes: [
    {
      type: 'feature',        // 'feature' | 'fix' | 'improvement' | 'design'
      description: '...',     // User-friendly description from Step 3
      impact: 'minor'         // 'major' | 'minor' | 'patch' (display ordering)
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
- Version format matches `YYYY.MM.DD` (regex: `^\d{4}\.\d{2}\.\d{2}$`)
- Date format is `YYYY-MM-DD`
- All single quotes properly escaped in descriptions
- Change types are valid (`feature`, `fix`, `improvement`, `design`)

## Step 12: Output

### INSERT MODE output:
```
Changelog updated!

Mode: INSERT (new release)
Version: vYYYY.MM.DD
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
Version: vYYYY.MM.DD
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
