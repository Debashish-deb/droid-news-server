# New Feed Category Plan

## Goal

Show the home feed in four mutually exclusive categories:

1. `national`
2. `international`
3. `sports`
4. `entertainment`

Each article must land in exactly one category, so the same article never
appears in more than one home tab.

## Current Implementation

The app now uses `assets/new-feed-category.json` as the taxonomy source for
tag-driven classification during sync.

### Category rules

- `sports`: any article with sports tags or strong sports keywords.
- `entertainment`: any article with entertainment tags or strong
  entertainment keywords.
- `national`: Bangladesh-focused article that is not sports or entertainment.
- `international`: non-Bangladesh article that is not sports or entertainment.

### Source of truth

- Feed ingest is broad.
- Articles are deduplicated by URL before storage.
- Classification happens once per article during sync.
- The stored `category` field is the canonical home category.
- Home tabs read only from those canonical categories.

## Taxonomy usage

The taxonomy file currently powers:

- Bangladesh location and organization matching
- Sports term matching
- Entertainment term matching
- Topic and format tag extraction

The current database schema still stores only the final `category`, not the
full matched tag list. Tags are computed at ingest time and can be persisted in
a later schema update if needed.

## Why this is the right intermediate step

- It removes cross-category duplicates immediately.
- It keeps runtime filtering cheap because the UI reads preclassified rows.
- It lets the taxonomy evolve without changing the home screen contract.
- It leaves room for ML later without blocking the deterministic release path.

## Future improvements

### 1. Persist tags

Add a tags column or side table so search, personalization, and analytics can
reuse matched taxonomy data directly.

### 2. Expand taxonomy

Add:

- explicit global geography markers
- political parties and institutions outside Bangladesh
- more sports and entertainment personalities
- source-level hints for noisy feeds

### 3. Hybrid ML labeling

Later, ML can suggest:

- missing tags
- better entity resolution
- confidence overrides for ambiguous stories

The ML layer should remain advisory until it is measured against the current
rule-based output.
