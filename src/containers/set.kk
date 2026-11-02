module set

import wbt

infixl 75 (\\)

// A set of values a.
abstract struct set<a>
    tree : tree<a>

fun one/tree-op(s : set<a>, f : (wbt/tree<a>) -> e wbt/tree<b>) : e set<b>
    s.tree.f.Set

fun two/tree-op(s1 : set<a>, s2 : set<b>, f : (wbt/tree<a>, wbt/tree<b>) -> e wbt/tree<c>) : e set<c>
    f(s1.tree, s2.tree).Set

fun three/tree-op(s1 : set<a>, s2 : set<b>, s3 : set<c>, f : (wbt/tree<a>, wbt/tree<b>, wbt/tree<c>) -> e wbt/tree<d>) : e set<d>
    f(s1.tree, s2.tree, s3.tree).Set

// The empty set `{}` / `empty`.
pub val empty = empty.Set

// Construct `set\<a>` from `list\<a>`. Requires a `?cmp` on `a`.
pub fun list/set(xs : list<a>, ?cmp : (a, a) -> e order) : e set<a>
    xs.tree.Set

// Convert from `set\<a>` into `list\<a>` in ascending order.
pub fun list(s : set<a>) : list<a>
    s.tree.list

fun list-op(s : set<a>, f : list<a> -> e list<b>, ?cmp : (b, b) -> e order) : e set<b>
    s.list.f.set

// String representation of `set\<a>`. Uses `list/show`.
//
// ```koka
// fun example()
//   [1, 4, 2, 3, 5].set.show.print
//   // ^ prints: set([1,2,3,4,5])
// ```
pub fun show(s : set<a>, ?a/show : a -> string) : string
    "set(" ++ s.list.show() ++ ")"

// Set equality. Requires `?(==)` on `a`.
pub fun eq(s1 : set<a>, s2 : set<a>, ?a/(==) : (a, a) -> e bool) : e bool
    s1.tree == s2.tree

// Set equality operator. Requires `?(==)` on `a`.
pub fun (==)(x : set<a>, y : set<a>, ?a/(==) : (a, a) -> e bool) : e bool
    eq(x, y)

// Set ordering. require `?cmp` on `a`.
pub fun cmp(s1 : set<a>, s2 : set<a>, ?a/cmp : (a, a) -> e order) : e order
    cmp(s1.list, s2.list)

// Construct a singleton set `{x}`.
pub fun single(x : a) : set<a>
    x.single.Set

// Calculate the power set of a set: the set of all its subsets.
//
// ```koka
// fun example()
//   [1, 2].set.powerset.println
//   // ^ prints: set([set([]),set([1]),set([2]),set([1,2])])
// ```
pub fun powerset(s : set<a>, ?cmp : (a, a) -> e order) : e set<set<a>>
    s.list.powerset.foldl(empty) fn(z, xs)
        z.insert(xs.set)

// Generate all subsets of a list as a list of lists. Not guaranteed to be ordered.
//
// ```koka
// fun example()
//   [1, 2].powerset.println
//   // ^ prints: [[],[1],[2],[1,2]]
// ```
pub fun list/powerset(xs : list<a>) : list<list<a>>
    match xs
        Nil -> Cons(Nil, Nil)
        Cons(x, xx) ->
            val rest = powerset(xx)
            rest ++ rest.map(Cons(x, _))

// Removes duplicate elements from a list. In particular, it keeps
// only the first occurrence of each element.
pub fun list/unique(xs : list<a>, ?cmp : (a, a) -> e order) : e list<a>
    xs.set.list

// Insert an element `x` of type `a` into a `set\<a>`. If the set already
// contains an element equal to the given value, it is replaced with the new
// value. Requires `?cmp` on `a`.
//
// ```koka
// fun example()
//   [1, 2, 3].set.insert(4).println // prints: set([1,2,3,4])
//   [1, 2, 3].set.insert(2).println // prints: set([1,2,3])
// ```
pub fun insert(s : set<a>, x : a, ?cmp : (a, a) -> e order) : e set<a>
    s.tree-op(insert(x, _))

pub fun insert-with(s : set<a>, x : a, f : (a, a) -> e a, ?cmp : (a, a) -> e order) : e set<a>
    s.tree-op(insert-with(x, _, f))

// Flipped version of `insert`.
//
// ```koka
// fun example()
//   4.insert'([1, 2, 3].set).println // prints: set([1,2,3,4])
//   2.insert'([1, 2, 3].set).println // prints: set([1,2,3])
// ```
pub fun insert'(x : a, s : set<a>, ?cmp : (a, a) -> e order) : e set<a>
    insert(s, x)

// Delete an element from a set. If the set doesn't contain an element equal to
// the given value, it is ignored. Requires `?cmp` on `a`.
//
// ```koka
// fun example()
//   [1, 2, 3].set.delete(2).println // prints: set([1,3])
//   [1, 2, 3].set.delete(4).println // prints: set([1,2,3])
// ```
pub fun delete(s : set<a>, x : a, ?cmp : (a, a) -> e order) : e set<a>
    s.tree-op(delete(x, _))

// Is the element in the set?
pub fun member(s : set<a>, x : b, ?cmp : (b, a) -> e order) : e bool
    x.member(s.tree)

// Check if the set `s` has the element `x`.
pub fun has(s : set<a>, x : b, ?cmp : (b, a) -> e order) : e bool
    member(s, x)

// Pop an element from the set. Returns `Nothing` if the element is not a member
// of the set. Otherwise returns `Just` the set with the element removed.
//
// ```koka
// fun example()
//   [1, 2, 3].set.pop(2).println // prints: Just(set([1,3]))
//   [1, 2, 3].set.pop(4).println // prints: Nothing
// ```
pub fun pop(s : set<a>, x : a, ?cmp : (a, a) -> e order) : e maybe<set<a>>
    if s.has(x) then Just(s.delete(x)) else Nothing

// Return the maximum element of the set, or `Nothing` if empty.
//
// ```koka
// fun example()
//   [1, 5, 3].set.maximum.println  // prints: Just(5)
//   [].set.maximum.println         // prints: Nothing
// ```
pub fun maximum(s : set<a>, ?cmp : (a, a) -> e order) : e maybe<a>
    s.tree.maximum

// Return the minimum element of the set, or `Nothing` if empty.
//
// ```koka
// fun example()
//   [1, 5, 3].set.minimum.println  // prints: Just(1)
//   [].set.minimum.println         // prints: Nothing
// ```
pub fun minimum(s : set<a>, ?cmp : (a, a) -> e order) : e maybe<a>
    s.tree.minimum

// Find largest element smaller than the given one.
//
// ```koka
// fun example()
//   [6, 7].set.find-lt(6).println // prints: Nothing
//   [6, 7].set.find-lt(7).println // prints: Just(6)
// ```
pub fun find-lt(s : set<a>, x : b, ?cmp : (a, b) -> e order) : e maybe<a>
    s.tree.find-lt(x)

// Find largest element smaller than or equal to the given one.
//
// ```koka
// fun example()
//   [6, 7].set.find-le(6).println // prints: Just(6)
//   [6, 7].set.find-le(7).println // prints: Just(6)
// ```
pub fun find-le(s : set<a>, x : b, ?cmp : (a, b) -> e order) : e maybe<a>
    s.tree.find-le(x)

// Find smallest element greater than the given one.
//
// ```koka
// fun example()
//   [6, 7].set.find-gt(6).println // prints: Just(7)
//   [6, 7].set.find-gt(7).println // prints: Nothing
// ```
pub fun find-gt(s : set<a>, x : b, ?cmp : (a, b) -> e order) : e maybe<a>
    s.tree.find-gt(x)

// Find smallest element greater than or equal to the given one.
//
// ```koka
// fun example()
//   [6, 7].set.find-ge(6).println // prints: Just(7)
//   [6, 7].set.find-ge(7).println // prints: Just(7)
// ```
pub fun find-ge(s : set<a>, x : b, ?cmp : (a, b) -> e order) : e maybe<a>
    s.tree.find-ge(x)

// Is this set empty?
pub fun is-empty(s : set<a>) : bool
    s.tree.is-empty

// The number of element is the set.
pub fun size(s : set<a>) : int
    s.tree.size

// The union of two sets, preferring the first set when equal elements are
// encountered.
pub fun union(s1 : set<a>, s2 : set<a>, ?cmp : (a, a) -> e order) : e set<a>
    tree-op(s1, s2, union(_, _))

pub fun union-with(s1 : set<a>, s2 : set<a>, f : (left : a, right : a) -> e a, ?cmp : (a, a) -> e order) : e set<a>
    tree-op(s1, s2, union-with(_, _, f))

// Set append operator using `union`.
pub fun (++)(s1 : set<a>, s2 : set<a>, ?cmp : (a, a) -> e order) : e set<a>
    union(s1, s2)

// Set other append operator using `union`.
pub fun (+)(s1 : set<a>, s2 : set<a>, ?cmp : (a, a) -> e order) : e set<a>
    union(s1, s2)

// `s1.is-subset-of(s2)` indicates whether s1 is a subset of s2.
pub fun is-subset-of(s1 : set<a>, s2 : set<a>, ?cmp : (a, a) -> e order) : e bool
    union(s1, s2) == s2 // todo: refactor

// `s1.is-proper-subset-of(s2)` indicates whether s1 is a proper subset of s2.
pub fun is-proper-subset-of(s1 : set<a>, s2 : set<a>, ?cmp : (a, a) -> e order) : e bool
    s1 != s2
    && s1.is-subset-of(s2)

// The union of the sets in a list.
pub fun unions(ss : list<set<a>>, ?cmp : (a, a) -> e order) : e set<a>
    ss.foldl(empty, union(_, _))

// Fold a set from the left, i.e. `foldl([1,2].set,0,(+)) == (0+1)+2`.
// Since `foldl` is tail recursive, it is preferred over `foldr` when using an
// associative function `f`
pub fun foldl(s : set<a>, z : b, f : (b, a) -> e b) : e b
    s.list.foldl(z, f)

// Fold a set from the right, i.e. `foldr([1,2].set,0,(+)) == 1+(2+0)`.
// Note, `foldr` is less efficient than `foldl` as it reverses the
// list representation first.
pub fun foldr(s : set<a>, z : b, f : (a, b) -> e b) : e b
    s.list.foldr(z, f)

// Flatten the set (e.g. concatenate them) using `union`.
pub fun flatten(ss : set<set<a>>, ?cmp : (a, a) -> e order) : e set<a>
    ss.foldl(empty, union(_, _))

// Difference of two sets. Return elements of the first set not existing in the
// second set.
//
// ```koka
// fun example()
//   difference([6, 7].set, [6, 9].set).println
//   // ^ prints: set([7])
// ```
pub fun difference(s1 : set<a>, s2 : set<a>, ?cmp : (a, a) -> e order) : e set<a>
    s2.foldl(s1, _.delete(_))

// The operator for the difference of two sets.
pub fun (\\)(s1 : set<a>, s2 : set<a>, ?cmp : (a, a) -> e order) : e set<a>
    difference(s1,s2)

// The other operator for the difference of two sets.
pub fun (-)(s1 : set<a>, s2 : set<a>, ?cmp : (a, a) -> e order) : e set<a>
    difference(s1,s2)

// The intersection of two sets. Elements of the result come from the first
// set, so for example
//
// ```koka
// type ab { A; B; }
// fun cmp(a : ab, b : ab) Eq
// fun (==)(a : ab, b : ab) True
// fun show(x : ab) match x {A -> "A"; B -> "B"}
// fun example()
//   intersection([A].set, [B].set).show.println // prints: set([A])
//   intersection([B].set, [A].set).show.println // prints: set([B])
// ```
pub fun intersection(s1 : set<a>, s2 : set<a>, ?cmp : (a, a) -> e order) : e set<a>
    s1.foldl(empty) fn(z, x) if s2.has(x) then z.insert(x) else z

// The intersection of a series of sets. Intersections are performed left-to-right.
pub fun intersections(ss : list<set<a>>, ?cmp : (a, a) -> e order) : e set<a>
    ss.foldl(empty, intersection(_, _))

// Check whether two sets are disjoint (i.e., their intersection is empty).
//
// ```koka
// fun example()
//   disjoint([2,4,6  ].set, [1,3    ].set).println  // prints: True
//   disjoint([2,4,6,8].set, [2,3,5,7].set).println  // prints: False
//   disjoint([1,2    ].set, [1,2,3,4].set).println  // prints: False
//   disjoint([       ].set, [       ].set).println  // prints: True
// ```
pub fun disjoint(s1 : set<a>, s2 : set<a>, ?cmp : (a, a) -> e order) : e bool
    intersection(s1, s2).is-empty

// The symmetric difference of two sets. The result contains elements that
// appear in exactly one of the two sets.
//
// ```koka
// fun example()
//   symmetric-difference([0,2,4,6].set, [0,3,6,9].set).println
//   // ^ prints: set([2,3,4,9])
// ```
pub fun symmetric-difference(s1 : set<a>, s2 : set<a>, ?cmp : (a, a) -> e order) : e set<a>
    s1.foldl(empty, fn(z, x) if s2.has(x) then z else z.insert(x)) ++
    s2.foldl(empty, fn(z, x) if s1.has(x) then z else z.insert(x))

// Invoke `f` for each element of a set
pub fun foreach(s : set<a>, f : a -> e ()) : e ()
    s.list.foreach(f)

// Calculate the Cartesian product of two sets.
//
// ```koka
// fun example()
//   cartesian-product([1,2].set, ['a','b'].set).println
//   // ^ prints: set([(1,'a'),(1,'b'),(2,'a'),(2,'b')])
// ```
pub fun cartesian-product(
    s1 : set<a>, s2 : set<b>,
    ?a/cmp : (a, a) -> e order,
    ?b/cmp : (b, b) -> e order
) : e set<(a, b)>
    var res := set/empty
    s1.foreach fn(a) s2.foreach fn(b)
        res := res.insert((a, b))
    res

// `map(s, f)` is the set obtained by applying `f` to each element of `s`.
//
// It's worth noting that the size of the result may be smaller if,
// for some (x,y), x != y && f x == f y
pub fun map(s : set<a>, f : a -> e b, ?cmp : (b, b) -> e order) : e set<b>
    s.list-op(_.map(f))

// Lexicographical ordering of `either`.
pub fun either/cmp(e1 : either<a, b>, e2 : either<a, b>, ?a/cmp : (a, a) -> e order, ?b/cmp : (b, b) -> e order) : e order
    match (e1, e2)
        (Left(x), Left(y)) -> cmp(x, y)
        (Left(), _) -> Lt
        (Right(x), Right(y)) -> cmp(x, y)
        (Right(), _) -> Gt

// Calculate the disjoint union of two sets.
//
// ```koka
// fun example()
//   disjoint-union([1,2].set, ["hi","bye"].set).println
//   // ^ prints: set([Left(1),Left(2),Right("bye"),Right("hi")])
// ```
pub fun disjoint-union(s1 : set<a>, s2 : set<b>, ?a/cmp : (a, a) -> e order, ?b/cmp : (b, b) -> e order) : e set<either<a, b>>
    s1.map(_.Left) ++
    s2.map(_.Right)

// Retain only those elements of a set that satisfy the given predicate `pred`.
// For example: `filter([1,2,3].set,is-odd) == set([1,3])`
pub fun filter(s : set<a>, f : a -> e bool, ?cmp : (a, a) -> e order) : e set<a>
    s.foldl(empty) fn(z, x) if f(x) then z.insert(x) else z

pub fun filter'(s : set<a>, f : a -> e bool, ?cmp : (a, a) -> e order) : e set<a>
    var res := set/empty
    s.foreach fn(a) if f(a) then res := res.insert(a)
    res

// Take while a predicate on the elements holds. The user is responsible for
// ensuring that for all elements j and k in the set, j < k ==> p j >= p k. See
// note at `span-antitone`.
pub fun take-while-antitone(s : set<a>, p : a -> e bool, ?cmp : (a, a) -> e order) : e set<a>
    s.list-op(_.take-while(p))

// Drop while a predicate on the elements holds. The user is responsible for
// ensuring that for all elements j and k in the set, j < k ==> p j >= p k. See
// note at `span-antitone`.
pub fun drop-while-antitone(s : set<a>, p : a -> e bool, ?cmp : (a, a) -> e order) : e set<a>
    s.list-op(_.drop-while(p))

// Divide a set at the point where a predicate on the elements stops holding.
// The user is responsible for ensuring that for all elements j and k in the
// set, j < k ==> p j >= p k.
//
// NOTE: if p is not actually antitone, then `span-antitone` will split the set at
// some unspecified point where the predicate switches from holding to not
// holding (where the predicate is seen to hold before the first element and to
// fail after the last element).
pub fun span-antitone(s : set<a>, f : a -> e bool, ?cmp : (a, a) -> e order) : e (set<a>, set<a>)
    (s.take-while-antitone(f), s.drop-while-antitone(f))

// Map elements and collect the Just results.
pub fun list/map-maybe(xs : list<a>, f : a -> e maybe<b>) : e list<b>
    match xs
        Nil -> Nil
        Cons(x, xx) -> match f(x)
            Just(b) -> Cons(b, xx.map-maybe(f))
            Nothing -> xx.map-maybe(f)

// Map elements and collect the Just results.
pub fun map-maybe(s : set<a>, f : a -> e maybe<b>, ?cmp : (b, b) -> e order) : e set<b>
    s.list-op(_.map-maybe(f))

// Partition the set into two sets, one with all elements that satisfy the
// predicate and one with all elements that don't satisfy the predicate. See
// also `split`.
//
// ```koka
// fun example()
//   list(1,10).set.partition(_.is-even).println
//   // ^ prints: (set([2,4,6,8,10]),set([1,3,5,7,9]))
// ```
pub fun partition(s : set<a>, p : a -> e bool, ?cmp : (a, a) -> e order) : e (set<a>, set<a>)
    val (a, b) = s.list.partition(p)
    (a.set, b.set)

// The expression `split(set, x)` is a pair `(set1,set2)` where `set1`
// comprises the elements of set less than `x` and `set2` comprises the
// elements of set greater than `x`.
pub fun split(s : set<a>, x : a, ?cmp : (a, a) -> e order) : e (set<a>, set<a>)
    ( s.take-while-antitone(_< x)
    , s.drop-while-antitone(_<= x))

// Performs a `split` but also returns whether the pivot element was found in
// the original set.
pub fun split-member(s : set<a>, x : a, ?cmp : (a, a) -> e order) : e (set<a>, bool, set<a>)
    ( s.take-while-antitone(_< x)
    , s.member(x)
    , s.drop-while-antitone(_<= x))

// Returns the index of the first element where `pred` holds, or `-1` if no
// such element exists.
pub fun index-of(s : set<a>, p : a -> e bool) : e int
    s.list.index-of(p)

// Get (zero-based) element `i`  of a set. Return a `:maybe` type.
pub fun @index(s : set<a>, i : int) : maybe<a>
    s.list.@index(i)

// Get (zero-based) element `ix`  of a set. Return a `:maybe` type.
// See also `@index` for C-like indexing `s[ix]`.
pub fun at(s : set<a>, ix : int) : maybe<a>
    s[ix]

// Delete the element at index `i`, i.e. by its zero-based index in the sorted
// sequence of elements. If the index is out of range (less than zero, greater
// or equal to size of the set), returns `Nothing`.
pub fun delete-at(s : set<a>, i : int, ?cmp : (a, a) -> e order) : e maybe<set<a>>
    s[i].map(s.delete(_))

// Take a given number of elements in order, beginning with the smallest ones.
pub fun take(s : set<a>, n : int = 0, ?cmp : (a, a) -> e order) : e set<a>
    s.list-op(_.take(n))

// Drop a given number of elements in order, beginning with the smallest ones.
pub fun drop(s : set<a>, n : int = 0, ?cmp : (a, a) -> e order) : e set<a>
    s.list-op(_.drop(n))

// Split a set at a particular index.
pub fun split-at(s : set<a>, n : int, ?cmp : (a, a) -> e order) : e (set<a>, set<a>)
    (s.take(n), s.drop(n))

// Delete the minimal element. Returns `Nothing` if the set is empty.
pub fun delete-min(s : set<a>, ?cmp : (a, a) -> e order) : e maybe<set<a>>
    s.delete-at(0)

// Delete the maximal element. Returns `Nothing` if the set is empty.
pub fun delete-max(s : set<a>, ?cmp : (a, a) -> e order) : e maybe<set<a>>
    s.delete-at(s.size - 1)

fun maybe/map2(ma : maybe<a>, mb : maybe<b>, f : (a, b) -> e c) : e maybe<c>
    match ma
        Just(a) -> match mb
            Just(b) -> Just(f(a, b))
            _ -> Nothing
        _ -> Nothing

fun maybe/zip(ma : maybe<a>, mb : maybe<b>) : maybe<(a, b)>
    map2(ma, mb, (_, _))

// Retrieves the maximal key of the set, and the set stripped of that element,
// or `Nothing` if passed an empty set.
pub fun max-view(s : set<a>, ?cmp : (a, a) -> e order) : e maybe<(a, set<a>)>
    zip(s.maximum, s.delete-max)

// Retrieves the minimal key of the set, and the set stripped of that element,
// or `Nothing` if passed an empty set.
pub fun min-view(s : set<a>, ?cmp : (a, a) -> e order) : e maybe<(a, set<a>)>
    zip(s.minimum, s.delete-min)

// Show the tree that implements the set.
pub fun show-tree(s : set<a>, ?show : a -> e string) : e string
    s.tree.pretty

// Test if the internal set structure is valid.
pub fun is-valid(s : set<a>)
    s.tree.is-valid
