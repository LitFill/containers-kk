# containers-kk — Performance Improvements

Snapshot: 2026-11-23 · version 0.4.0

## Delivered (correct, measured)

Benchmark `tests/bench.kk` (union/intersection/difference/max/min/fold over a
100k-element set), wall clock for the whole program:

| Version | Time |
| --- | --- |
| Original (list-fold set algebra, `list.last/head` max/min) | 2.57s |
| `union` join-based; `intersection`/`difference` still folds | 1.82s |
| All three join-based, `set` delegating to `wbt` (this change) | 1.31s |

49% wall-clock improvement over the original, plus asymptotically better
max/min, subset and set algebra.

### What changed

1. **Join-based set algebra** (`wbt.kk`): `union`/`intersection`/`difference`
   now use `split` + `link`/`merge` (the "Just Join" technique), giving
   O(m log(n/m+1)) instead of O(n log m). The classic `combine` is preserved
   as `glue` (used only by `delete`, where subtrees are within the balance
   ratio); `combine` is now an alias of `merge`.
2. **`set.kk` delegates to it**: `union`, `intersection` and `difference` are
   now `tree-op(..., wbt/<op>(_, _))` instead of list folds. The qualified
   name matters: `set` and `map` define their own `union`, `intersection`,
   `difference` and `split`, and an unqualified call would be ambiguous.
3. **Tree-direct `foldl`/`foldr`** (`wbt.kk`): fold the tree directly instead
   of `s.list.foldl(...)`. Avoids materialising the whole list.
4. **O(log n) `maximum`/`minimum`** (`wbt.kk`): walk down the right/left spine
   instead of `tree.list.last`/`tree.list.head`.
5. **`is-subset-of`** (`set.kk`): direct `all (∈ s2)` check instead of
   `union(s1,s2) == s2`.
6. **`split-max`** (`wbt.kk`): the single max-splitting primitive. `del-max`
   was an exact duplicate of it and is gone; `glue` calls `split-max`.
7. **Tests**: `tests/bench.kk` (benchmark) and `tests/verify.kk` (property
   tests: union/intersection/difference against a sorted-list reference, plus
   `link`/`merge` over every size pair drawn from `[0,1,2,3,5,8,13,100,1000]`
   under both `afp/params` and `hirayama/params'`). Both run in `nix flake
   check`; `tests/link-test.kk` was a print-only subset of the new join checks
   and has been removed.

### Bugs fixed

- **`maximum`**: was matching `Node(x, Leaf, _)` (the *minimum* pattern),
  returning the root for nodes with an empty left but non-empty right. Fixed
  to `Node(x, _, Leaf)`.
- **`insert-with`**: recursive calls used `x.insert(l)` instead of
  `insert-with(x, l, f)`, so `f` was only applied at the root. Fixed.

## Why link/merge instead of fixing combine

`combine` is the classic *glue* operation — valid only when both trees are
already within the balance ratio, i.e. when they are the two children of a
valid node. `delete` meets that precondition; a top-level `union` of two
arbitrary sets does not, which is why a single "more general" rotation is the
wrong fix: one rotation is the correct tool exactly when the imbalance is
bounded, and `glue` is the right tool exactly when the sizes are.

The standard answer (Adams 1993, Hirai–Yamamoto 2011, Blelloch et al. "Just
Join") is to keep the rotations as they are and add a descending `link`/`merge`
that walks down the spine of the heavier tree until the sizes are comparable,
then rebuilds on the way back up, doing at most one rebalance per level. Each
step then has bounded imbalance, so the existing `balance-*` are sufficient.

## Balance parameters

`afp/params` (Δ=2.5, Γ=1.4) is the default. `hirayama/params'` (Δ=3, Γ=2) is
also exported. The join checks in `tests/verify.kk` run under both, which is
the empirical answer to "is the Just Join range satisfied here" — the proof in
Blelloch et al. covers a range of α and both parameter sets sit inside the
range we exercise.

## Other future work

- `union-with` still uses a list fold; it can now go join-based the same way
  `union` does (`split` at the pivot, recurse, `link`, combining with `f`).
- `flatten` / `unions` could stream instead of fold.
- Reduce allocation in `insert`/`delete` hot paths.
- `wbt/eq` (structural) is unused by `set` — document or drop.