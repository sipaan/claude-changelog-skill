# Migration Guide: SemVer to CalVer

Migrate your project's changelog from semantic versioning (`1.4.0`) to calendar versioning (`2025.10.20`).

## Prerequisites

- You're already using this changelog skill (SKILL.md + changelog-prep.sh)
- Your changelog data file has `version` and `date` fields on each release entry

## Overview

| Before (SemVer) | After (CalVer) |
|---|---|
| `version: '1.4.0'` | `version: '2025.10.20'` |
| Version bumped by change type | Version is always today's date |
| `BUMP` field in manifest | `IMPACT` field in manifest |

CalVer is simpler: the version **is** the date. No more deciding between major/minor/patch bumps. The `impact` field stays in the data for display ordering (sorting features above fixes), but no longer drives the version number.

## Step-by-Step

### 1. Update skill files

Copy the latest SKILL.md and changelog-prep.sh from this repo into your project's skill directory (typically `.claude/skills/changelog/`).

```bash
# From your project root
cp <path-to-this-repo>/SKILL.md .claude/skills/changelog/SKILL.md
cp <path-to-this-repo>/changelog-prep.sh .claude/skills/changelog/changelog-prep.sh
```

### 2. Convert existing version strings

For each entry in your changelog data file, replace the `version` value with the CalVer equivalent derived from its `date` field.

**Conversion rule:** take the `date` value (`YYYY-MM-DD`), replace hyphens with dots.

Example:
```typescript
// Before
{ version: '1.4.0', date: '2025-10-19', ... }
{ version: '1.3.2', date: '2025-10-15', ... }

// After
{ version: '2025.10.19', date: '2025-10-19', ... }
{ version: '2025.10.15', date: '2025-10-15', ... }
```

**Verify:** every `version` field should now match its `date` field (dots vs hyphens). The daily-grouping rule means all dates should already be unique — no collisions.

### 3. Update changelog file header comments

If your changelog file has comments referencing SemVer, update them:

```typescript
// Before
/**
 * Each release follows semantic versioning (MAJOR.MINOR.PATCH).
 * - MAJOR: Breaking changes
 * - MINOR: New features
 * - PATCH: Bug fixes
 */

// After
/**
 * Each release uses calendar versioning (YYYY.MM.DD).
 * - Version is always the release date (with leading zeros)
 * - Impact field controls display ordering (not versioning)
 */
```

### 4. Update type definition comments (if applicable)

If your `ChangeImpact` type has a doc comment about version bumping, update it:

```typescript
/**
 * Impact level for display ordering within a release.
 * Does NOT affect versioning (CalVer versions are date-based).
 * Used to sort high-impact changes to the top of each release.
 */
export type ChangeImpact = 'major' | 'minor' | 'patch'
```

### 5. Update project documentation

Search your project for references to "semantic versioning", "MAJOR.MINOR.PATCH", or "version bump" in relation to the changelog. Common locations:

- `CLAUDE.md` or project instructions
- `README.md`
- Any CI/CD configuration that parses changelog versions

Replace with "calendar versioning (YYYY.MM.DD)" or "version is always today's date".

### 6. Verify

Run the following checks:

```bash
# 1. Build passes (if TypeScript)
npm run typecheck && npm run build

# 2. Prep script outputs CalVer
bash .claude/skills/changelog/changelog-prep.sh --preview
# Should show: NEW_VERSION=YYYY.MM.DD and IMPACT= (not BUMP=)

# 3. No stale SemVer references in skill files
grep -r "X.Y.Z\|BUMP=" .claude/skills/changelog/
# Should return nothing
```

### 7. Commit

```bash
git add -A
git commit -m "feat: migrate changelog from SemVer to CalVer (YYYY.MM.DD)"
```

## FAQ

**Why CalVer instead of SemVer?**
For app changelogs (not libraries), SemVer's major/minor/patch distinction adds friction without value. Users care about *when* something changed, not whether it was a "minor" or "patch" release. CalVer makes the version self-documenting.

**What happens to the `impact` field?**
It stays. It's used to sort changes within a release (features first, fixes last). It just no longer affects the version number.

**What if I update the changelog twice in one day?**
Same as before — UPDATE mode merges changes into the existing entry for that date. The version stays the same since it's just today's date.

**Do I need to change `package.json` version?**
Only if you were syncing it with the changelog version. For private apps, pin it to `1.0.0` and forget it. For published npm packages, keep `package.json` on its own SemVer track.

**What about git tags?**
If you tag releases, your tags would change from `v1.4.0` to `v2025.10.20`. The `--since-tag` argument in the prep script works with any tag format.
