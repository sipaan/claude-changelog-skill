# Changelog Skill for Claude Code

A Claude Code skill that generates user-facing changelog entries from git commits. It translates technical commit messages into clear, plain-language descriptions and outputs structured TypeScript data for in-app "What's New" modals.

## What It Does

- Parses git commits using conventional commit prefixes (`feat:`, `fix:`, `perf:`, `style:`, etc.)
- Translates technical language into user-friendly descriptions
- Calculates semantic versioning (MAJOR.MINOR.PATCH) automatically
- Groups all changes from the same day into one release (daily grouping)
- Detects INSERT mode (new release) vs UPDATE mode (same-day merge)
- Creates changelog type definitions and data file for new projects
- Supports `--preview` to see changes without writing

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
  version: '1.4.0',
  date: '2025-10-20',
  summary: 'High-performance photo rendering and visual improvements',
  changes: [
    {
      type: 'feature',
      description: 'High-performance rendering for large photo collections',
      impact: 'minor'
    },
    {
      type: 'fix',
      description: 'Fixed thumbnail synchronization for smoother loading',
      impact: 'patch'
    },
    {
      type: 'design',
      description: 'Refreshed button design with modern styling',
      impact: 'minor'
    }
  ]
}
```

Notice how component names (`PhotoGrid`), library names (`TanStack Virtual`, `Zustand`, `HeroUI`), and implementation details (`reactivity bug`, `cacheStore`) are translated into plain language.

## Installation

### Option 1: Clone into your Claude skills directory

```bash
# Clone the repo
git clone https://github.com/sipaan/claude-changelog-skill.git

# Copy the skill to your Claude skills directory
mkdir -p ~/.claude/skills/changelog
cp claude-changelog-skill/SKILL.md ~/.claude/skills/changelog/SKILL.md
```

### Option 2: Direct download

```bash
mkdir -p ~/.claude/skills/changelog
curl -o ~/.claude/skills/changelog/SKILL.md \
  https://raw.githubusercontent.com/sipaan/claude-changelog-skill/main/SKILL.md
```

### Option 3: Symlink (for easy updates)

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

1. **Locates** the changelog data file (`src/data/changelog.ts` or similar)
2. **Reads** the last entry to determine version and date
3. **Gets** git commits since the last entry
4. **Filters** out non-user-facing commits (docs, tests, chores)
5. **Consolidates** related commits (anti-duplication)
6. **Calculates** the new semantic version based on change types
7. **Translates** technical commit messages to user-friendly language
8. **Writes** the entry — either inserting a new release or updating today's existing one

## Daily Grouping

The skill enforces **one release per day**. If you run `/changelog` multiple times on the same day, it merges all changes into a single release with a cumulatively calculated version:

```
Morning:  feat commit  → v1.3.0
Afternoon: fix commit  → v1.3.1
Evening:  feat commit  → v1.4.0
Result: Single release v1.4.0 with all 3 changes
```

## New Project Setup

If no changelog file exists, the skill creates:

- `src/types/changelog.ts` — Type definitions
- `src/data/changelog.ts` — Data file with the first entry

It adapts import paths to match your project's `tsconfig.json` path aliases.

## Requirements

- [Claude Code](https://claude.ai/code) CLI
- A git repository with commit history
- TypeScript project (for the output format)

## License

MIT
