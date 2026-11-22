# containers-kk — Performance Improvements

Snapshot: 2026-11-23 · version 0.3.0

## Delivered (correct, measured)

Benchmark `tests/bench.kk` (union/intersection/difference/max/min/fold over a
100k-element set):

| Version | Time |
| --- | --- |
| Original (list-fold set algebra, `list.last/head` max/min) | 2.57s |
| This change (tree-direct foldl, O(log n) max/min, direct subset) | 2.43s |

~6% wall-clock improvement, plus asymptotically better max/min and subset.

### What changed

1. **Tree-direct `foldl`/`foldr`** (`wbt.kk`): fold the tree directly instead
   of `s.list.foldl(...)`. Avoids materialising the whole list (O(n) allocation
   → O(log n)). `set.kk` `foldl`/`foldr` now call these; `map.kk` inherits it.
2. **O(log n) `maximum`/`minimum`** (`wbt.kk`): were `tree.list.last` /
   `tree.list.head` (O(n)); now walk down the right/left spine.
3. **`is-subset-of`** (`set.kk`): direct `all (∈ s2)` check instead of
   `union(s1,s2) == s2`, so no union is built (O(m log n), one tree traversal).
4. **`split-max`** (`wbt.kk`): mirror of the existing `split-min`.
5. **Benchmark** (`tests/bench.kk`) and **correctness test**
   (`tests/verify.kk`): property-checks union/intersection/difference against a
   sorted-list reference over 50 random cases (also checks `is-valid`).

## Join-based set algebra — attempted, blocked

A join-based `union`/`intersection`/`difference` would be O(m log(n/m+1)) vs
the current O(n log m). It was implemented and benchmarked at **1.8s** — but
that version produced **structurally invalid trees** (correct elements, wrong
shape), so it was rejected.

### Root cause (pre-existing library limitation)

`combine` joins two trees (all of t1 < all of t2) with a **single rotation**
(`balance-left` / `balance-right`). That is enough for `insert`/`delete`, whose
imbalance is always one level, but NOT for `combine` of trees whose sizes
differ arbitrarily:

```
combine(mk(1), mk(13))  -> not is-valid
balance-left(x, 1-node, split-min-shape-12-node) -> not is-valid
balance-left(x, 1-node, mk(12))                  -> is-valid      (same sizes, different shape)
```

A correct `balance-left` must produce a valid tree for **any** valid input; this
one depends on the input shape. So `combine` is only safe when the two trees are
within the balance ratio, which join-based set algebra does not guarantee.

### What a fix requires

Make `balance-left`/`balance-right` (or `combine`) a full rebalance that
restores the weight invariant for arbitrary size ratios — i.e. reimplement the
WBT balance/join, not a single rotation. That is a change to the library's core
balancing (used by every operation) and must be done carefully with its own
correctness proof and tests. Until then the fold-based set algebra above is the
correct choice.

### Other future work
- `union-with` still uses a list fold.
- `flatten` / `unions` could stream instead of fold.
- Reduce allocation in `insert`/`delete` hot paths.
- `wbt/eq` (structural) is now unused by `set` — document or drop.