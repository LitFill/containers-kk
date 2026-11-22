# containers-kk — Performance Improvements

Snapshot: 2026-11-23 · version 0.3.0

## Delivered (correct, measured)

Benchmark `tests/bench.kk` (union/intersection/difference/max/min/fold over a
100k-element set):

| Version | Time |
| --- | --- |
| Original (list-fold set algebra, `list.last/head` max/min) | 2.57s |
| This change (join-based set algebra, O(log n) max/min, direct subset) | 1.83s |

29% wall-clock improvement, plus asymptotically better max/min and subset.

### What changed

1. **Join-based set algebra** (`wbt.kk`): `union`/`intersection`/`difference`
   now use `split` + `link`/`merge` (the "Just Join" technique), giving
   O(m log(n/m+1)) instead of O(n log m). The classic `combine` is preserved
   as `glue` (used only by `delete`, where subtrees are within the balance
   ratio); `combine` is now an alias of `merge`.
2. **Tree-direct `foldl`/`foldr`** (`wbt.kk`): fold the tree directly instead
   of `s.list.foldl(...)`. Avoids materialising the whole list.
3. **O(log n) `maximum`/`minimum`** (`wbt.kk`): walk down the right/left spine
   instead of `tree.list.last`/`tree.list.head`.
4. **`is-subset-of`** (`set.kk`): direct `all (∈ s2)` check instead of
   `union(s1,s2) == s2`.
5. **`split-max`** (`wbt.kk`): mirror of `split-min`.
6. **Tests**: `tests/bench.kk` (benchmark), `tests/verify.kk` (property test
   of union/intersection/difference against a sorted-list reference),
   `tests/link-test.kk` (direct link/merge test on extreme size ratios).

### Bugs fixed

- **`maximum`**: was matching `Node(x, Leaf, _)` (the *minimum* pattern),
  returning the root for nodes with an empty left but non-empty right. Fixed
  to `Node(x, _, Leaf)`.
- **`insert-with`**: recursive calls used `x.insert(l)` instead of
  `insert-with(x, l, f)`, so `f` was only applied at the root. Fixed.

## Why link/merge instead of fixing combine

`combine` is the classic *glue* operation — valid only when both trees are
already within the balance ratio (siblings of a valid node). Making the single
rotation "more general" is the wrong move; a single rotation is the correct
tool when the imbalance is bounded.

The standard answer (Adams 1993, Hirai–Yamamoto 2011, Blelloch et al. "Just
Join") is to keep the rotations as they are and add a descending `link`/`merge`
that walks down the spine of the heavier tree until the sizes are comparable,
then rebuilds on the way back up, doing at most one rebalance per level. Each
step then has bounded imbalance, so the existing `balance-*` are sufficient.

## Other future work

- `union-with` still uses a list fold.
- `flatten` / `unions` could stream instead of fold.
- Reduce allocation in `insert`/`delete` hot paths.
- `wbt/eq` (structural) is now unused by `set` — document or drop.