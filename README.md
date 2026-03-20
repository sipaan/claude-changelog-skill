# Changelog Skill for Claude Code

A Claude Code skill that generates user-facing changelog entries from git commits. Uses a **hybrid architecture**: a deterministic bash script handles mechanical work (commit range, filtering, version calculation), Claude handles creative work (translation, consolidation, summary).

## What It Does

- Parses git commits using conventional commit prefixes (`feat:`, `fix:`, `perf:`, `style:`, etc.)
- Translates technical language into user-friendly descriptions
- Uses calendar versioning (YYYY.MM.DD) — version is always today's date
- Groups all changes from the same day into one release (daily grouping)
- Detects INSERT mode (new release) vs UPDATE mode (same-day merge)
- **Preserves manual edits** when updating today's entry (merge strategy)
- **Cross-release deduplication** prevents entries from appearing in multiple releases
- Creates changelog type definitions and data file for new projects
- Sorts changes by category priority (Feature > Design > Improvement > Fix)
- Supports `--preview` to see changes without writing

## Architecture

```
changelog-prep.sh (deterministic)     SKILL.md (Claude)
+----------------------------+        +----------------------------+
| 1. Auto-detect changelog   |        | 1. Run prep script         |
| 2. Find commit SHA boundary| stdout | 2. Review borderline commits|
| 3. Filter by prefix        | -----> | 3. Translate to English    |
| 4. CalVer version (today)  |        | 4. Consolidate duplicates  |
| 5. INSERT vs UPDATE mode   |        | 5. Cross-release dedup     |
| 6. Output manifest         |        | 6. Merge existing (UPDATE) |
+----------------------------+        | 7. Write changelog.ts      |
                                      +----------------------------+
```

**Why hybrid?** The previous all-prompt approach had a critical bug: it used date-based commit ranges (`--since="LAST_DATE 00:00"`) which re-fetched commits already processed into the previous release. The script uses the exact commit SHA that last modified the changelog file as the boundary, making it impossible to produce duplicates.

## Example

Given these git commits:

```
feat: Add TanStack Virtual to PhotoGrid component
fix: Resolve Zustand reactivity bug in cacheStore
style: Update HeroUI Button design tokens
```

The skill generates:

```typescript
{
  version: '2025.10.20',
  date: '2025-10-20',
  summary: 'High-performance photo rendering and visual improvements',
  changes: [
    {
      type: 'feature',
      description: 'High-performance rendering for large photo collections',
      impact: 'minor'
    },
    {
      type: 'design',
      description: 'Refreshed button design with modern styling',
      impact: 'minor'
    },
    {
      type: 'fix',
      description: 'Fixed thumbnail synchronization for smoother loading',
      impact: 'patch'
    }
  ]
}
```

Notice how component names (`PhotoGrid`), library names (`TanStack Virtual`, `Zustand`, `HeroUI`), and implementation details (`reactivity bug`, `cacheStore`) are translated into plain language.

## Installation

### Option 1: Clone into your Claude skills directory

```bash
git clone https://github.com/sipaan/claude-changelog-skill.git

# Copy both the skill and the script
mkdir -p ~/.claude/skills/changelog
cp claude-changelog-skill/SKILL.md ~/.claude/skills/changelog/SKILL.md
cp claude-changelog-skill/changelog-prep.sh ~/.claude/skills/changelog/changelog-prep.sh
chmod +x ~/.claude/skills/changelog/changelog-prep.sh
```

### Option 2: Symlink (for easy updates)

```bash
git clone https://github.com/sipaan/claude-changelog-skill.git ~/claude-changelog-skill
mkdir -p ~/.claude/skills
ln -s ~/claude-changelog-skill ~/.claude/skills/changelog
```

On Windows, use `mklink /D` instead of `ln -s`.

## Usage

### Manual invocation

```
/changelog                          # Auto-detect range from last entry
/changelog --preview                # Preview without writing
/changelog week                     # Changes from last 7 days
/changelog 3d                       # Changes from last 3 days
/changelog --since-tag v1.0.0       # Changes since a git tag
```

### Auto-invocation

The skill also triggers automatically when Claude detects significant work has been completed. In that case, it proposes entries and asks for confirmation before writing.

### Testing the script directly

```bash
bash ~/.claude/skills/changelog/changelog-prep.sh
bash ~/.claude/skills/changelog/changelog-prep.sh --preview
bash ~/.claude/skills/changelog/changelog-prep.sh week
```

## Output Format

The skill outputs TypeScript data using these types:

```typescript
type ChangeType = 'feature' | 'fix' | 'improvement' | 'design'
type ChangeImpact = 'major' | 'minor' | 'patch'

interface ChangelogChange {
  type: ChangeType
  description: string
  impact: ChangeImpact
}

interface ChangelogRelease {
  version: string
  date: string
  summary: string
  changes: ChangelogChange[]
}
```

## How It Works

### Prep Script (deterministic)

1. **Locates** the changelog data file (`src/data/changelog.ts` or similar)
2. **Reads** the last entry to determine version and date
3. **Finds** the commit SHA boundary (the last commit that modified the changelog file)
4. **Gets** git commits after that exact boundary point
5. **Filters** into INCLUDED (auto-include) and REVIEW (needs Claude's judgment)
6. **Sets** version to today's date in CalVer format (YYYY.MM.DD)
7. **Outputs** a structured manifest to stdout

### Claude (creative)

1. **Runs** the prep script and reads the manifest
2. **Reviews** borderline commits (`refactor:` etc.) for user-visible impact
3. **Translates** technical commit messages to user-friendly language
4. **Consolidates** related commits into single entries
5. **Deduplicates** against the previous release's entries
6. **Merges** with existing entries in UPDATE mode (preserves manual edits)
7. **Writes** the entry to the changelog file

## Commit Boundary

The script uses the **last commit that modified the changelog file** as the anchor point:

```bash
# Find the anchor
SHA=$(git log -1 --format=%H -- changelog.ts)

# Get only truly new commits
git log $SHA..HEAD --no-merges
```

This is immune to date-overlap issues. If the changelog was updated twice on the same day, only commits after the most recent update are picked up.

## Daily Grouping

The skill enforces **one release per day**. If you run `/changelog` multiple times on the same day, it merges all changes into a single release with a cumulatively calculated version:

```
Morning:  feat commit  -> v2026.03.20
Afternoon: fix commit  -> v2026.03.20 (merged)
Evening:  feat commit  -> v2026.03.20 (merged)
Result: Single release v2026.03.20 with all 3 changes
```

In UPDATE mode, manual edits to existing entries are preserved.

## New Project Setup

If no changelog file exists, the skill creates:

- `src/types/changelog.ts` - Type definitions
- `src/data/changelog.ts` - Data file with the first entry

It adapts import paths to match your project's `tsconfig.json` path aliases.

## Requirements

- [Claude Code](https://claude.ai/code) CLI
- A git repository with commit history
- TypeScript project (for the output format)
- Bash (included with Git on Windows)

## License

MIT
