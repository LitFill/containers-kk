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

## Plan

### Phase 1: Add split-max (supporting change)
- Add `split-max(tree)` to `wbt.kk` — mirror of `split-min`

### Phase 2: Fix maximum/minimum (quick win)
- Replace `tree.list.last`/`tree.list.head` with direct tree traversal
- O(log n) instead of O(n)

### Phase 3: Tree-direct foldl/foldr
- Add `foldl`/`foldr` to `wbt.kk` that work directly on tree structure
- Update `set.kk` and `map.kk` to use them

### Phase 4: Join-based set algebra (highest impact)
- Implement join-based `union`, `intersection`, `difference` in `wbt.kk`
- O(m log(n/m + 1)) instead of O(n log m)
- Uses `combine`, `split-min`, `split-max` that already exist

### Phase 5: Optimize is-subset-of
- Direct subset check without building union

### Phase 6: Benchmark and measure
- Add benchmark suite comparing old vs new implementations
- Measure speedup on large sets (100k, 500k, 1M elements)

## Implementation order
1. split-max (5 min)
2. maximum/minimum (10 min)
3. foldl/foldr (20 min)
4. union/intersection/difference (1-2 hours)
5. is-subset-of (15 min)
6. Benchmarks (30 min)