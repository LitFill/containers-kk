# containers-kk — Performance Improvement Plan

Snapshot: 2026-11-23 · version 0.3.0

## Current bottlenecks

### 1. Union/intersection/difference use list folds → O(n log m)

- `union(t1, t2)`: `t1.list.foldl(t2, insert')` — O(|t1| log |t2|)
- `intersection(s1, s2)`: `s1.foldl(empty) fn(z,x) if s2.has(x) then z.insert(x) else z` — O(|s1| log |s2|)
- `difference(s1, s2)`: `s2.foldl(s1, _.delete(_))` — O(|s2| log |s1|)

For large sets (100k+ elements), this is the dominant cost.

### 2. maximum/minimum traverse whole tree → O(n)

- `tree.list.last` / `tree.list.head` — O(n) time, O(n) allocation
- Should be O(log n) via direct tree traversal

### 3. foldl/foldr convert to list first → O(n) allocation

- `s.list.foldl(z, f)` — allocates full list, then folds
- Direct tree fold would be O(n) time, O(log n) space

### 4. is-subset-of does unnecessary union → O(n log m)

- `union(s1, s2) == s2` — builds full union then compares
- Direct subset check would be O(m log n) or better

## Implementation status

### Phase 1: split-max ✓
- Added `split-max(tree)` to `wbt.kk`

### Phase 2: maximum/minimum ✓
- Fixed `maximum`/`minimum` to be O(log n) instead of O(n)
- Now traverses tree directly instead of converting to list

### Phase 3: tree-direct foldl/foldr ✓
- Added `tree-foldl` and `tree-foldr` to `wbt.kk`
- Updated `set.kk` to use tree-direct folds
- `map.kk` automatically benefits (uses `set.foldl`/`set.foldr`)

### Phase 4: Join-based set algebra (partial)
- Attempted join-based union/intersection/difference
- Hit effect issues with recursive implementations
- Simplified to fold-based versions using tree-direct foldl
- **Result**: ~6% improvement (2.43s vs 2.57s)
- **Future work**: Resolve effect issues to get O(m log(n/m + 1)) complexity

### Phase 5: is-subset-of ✓
- Direct subset check without building union
- O(m log n) instead of O(n log m)

### Phase 6: Benchmark ✓
- Added `tests/bench.kk` with union/intersection/difference/max/min/fold benchmarks

## Remaining work

### Join-based set algebra (high impact)
The current fold-based union/intersection/difference are O(n log m).
Join-based versions would be O(m log(n/m + 1)).

**Blockers**: Effect type issues with recursive implementations.

**Approach**: 
1. Implement join-based union in wbt.kk
2. Resolve effect issues (may need explicit effect annotations)
3. Implement join-based intersection and difference
4. Benchmark and verify correctness

### Additional optimizations
- `union-with` still uses list fold
- `flatten` and `unions` could use join-based merge
- Memory allocation reduction in hot paths