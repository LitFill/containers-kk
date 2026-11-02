module map

import set

// A Map from keys `:k` to values `:v`.
abstract struct map<k, v>
    set : set<(k, v)>

// Compare tuples based only on the fst element.
pub fun kv/cmp(
    (k1, _) : (k, v),
    (k2, _) : (k, v),
    ?cmp  : (k, k) -> e order
) : e order { cmp(k1, k2) }

pub fun k/cmp(
    k1 : k, (k2, _) : (k, v),
    ?k/cmp  : (k, k) -> e order
) : e order { k/cmp(k1, k2) }

pub fun l/cmp(
    (k1, _) : (k, v), k2 : k,
    ?k/cmp  : (k, k) -> e order
) : e order { k/cmp(k1, k2) }

// Build a map from a list of key/value pairs. If the list contains more than
// one value for the same key, the last value for the key is retained.
//
// ```koka
// fun example()
//   ([].map : map<int, string>).println        // prints: map([])
//   [(6, "a"), (7, "b"), (6, "c")].map.println // prints: map([(6,"c"),(7,"b")])
//   [(6, "c"), (7, "b"), (6, "a")].map.println // prints: map([(6,"a"),(7,"b")])
// ```
pub fun list/map(kvs : list<(k, v)>, ?cmp : (k, k) -> e order) : e map<k, v>
    kvs.set.Map

// Build a map from a list of key/value pairs with a combining function.
//
// ```koka
// fun example()
//   ([].map-with(_++_) : map<int, string>).println              // prints: map([])
//   [(6,"a"), (6,"b"), (7,"x"), (6,"c")].map-with(_++_).println // prints: map([(6,"abc"),(7,"x")])
// ```
pub fun list/map-with(
    kvs    : list<(k, v)>,
    f      : (v, v) -> e v,
    ?k/cmp : (k, k) -> e order
) : e map<k, v>
    kvs.foldl(empty) fn(z, (k, v)) z.insert-with(k, v, f)

// Build a map from a list of key/value pairs with a combining function that
// depends on the key.
//
// ```koka
// fun f(k : int, old : string, new : string) k.show++":"++new++"|"++old
// fun example()
//   [].map-with-key(f).println // prints: map([])
//   [(6,"a"), (6,"b"), (7,"b"), (7,"a"), (6,"c")].map-with-key(f).println
//   // ^ prints: map([(6,"6:c|6:b|a"),(7,"a")])
// ```
pub fun list/map-with-key(
    kvs    : list<(k, v)>,
    f      : (k, v, v) -> e v,
    ?k/cmp : (k, k) -> e order
) : e map<k, v>
    kvs.foldl(empty) fn(z, (k, v)) z.insert-with-key(k, v, f)

// Build a map from a list of key/value pairs with a combining function. The
// result is equivalent to performing an upsert for every key/value in the
// list.
//
// ```koka
// fun f(x : string, m : maybe<string>) m.maybe(x, x ++ _)
// fun example()
//     [(6,"a"),(6,"b"),(7,"c"),(7,"d"),(6,"e")].map-upsert(f).show.println
//     // ^ prints: map([(6,"eba"),(7,"dc")])
// ```
pub fun list/map-upsert(
    kvs    : list<(k, v)>,
    f      : (v, maybe<w>) -> e w,
    ?k/cmp : (k, k) -> e order
) : e map<k, w>
    kvs.foldl(empty) fn(z, (k, v)) z.upsert(k, f(v, _))

// Build a map from a set of key/value pairs.
pub fun set/map(kvs : set<(k, v)>, ?cmp : (k, k) -> e order) : e map<k, v>
    kvs.Map

// Build a map from a Set of keys and a function which for each key computes
// its value.
//
// ```koka
// fun example()
//     [6, 7].set.map("a".repeat(_)).println
//     // ^ prints: map([(6,"aaaaaa"),(7,"aaaaaaa")])
// ```
pub fun set/function/map(
    s : set<k>, f : k -> e v,
    ?k/cmp : (k, k) -> e order
) : e map<k, v>
    s.foldl(empty) fn(z, k) z.insert(k, f(k))

// Build a map from a `set` of keys and a function which for each key
// optionally computes its value.
//
// ```koka
// fun example()
//     list(1, 5).set.map-optionally fn(k) if k.is-even then Just("a".repeat(k)) else Nothing
//     // ^ map([(2,"aa"),(4,"aaaa")])
// ```
pub fun set/map-optionally(
    s : set<k>, f : k -> e maybe<v>,
    ?k/cmp : (k, k) -> e order
) : e map<k, v>
    s.foldl(empty) fn(z, k) f(k).maybe(z, z.insert(k, _))

// Convert the map to a list of key/value pairs.
pub fun list(m : map<k, v>) : list<(k, v)>
    m.set.list

// Default Show instance for map. Requires show for the keys and values.
pub fun show(
    m       : map<k, v>,
    ?k/show : k -> e string,
    ?v/show : v -> e string
) : e string
    "map(" ++ m.list.show() ++ ")"

// Default Eq instance for map. Requires Ord on the keys and Eq on the values.
pub fun eq(
    m : map<k, v>, n : map<k, v>,
    ?k/cmp  : (k, k) -> e order,
    ?v/(==) : (v, v) -> e bool
) : e bool { m.set == n.set }

// Check wether two maps are equal. Requires Ord on the keys and Eq on the values.
pub fun (==) (m, n, ?k/cmp, ?v/(==)) map/eq(m, n)

// The empty map `{}` / `empty`.
pub val empty = Map(empty)

// Construct a singleton map `{key => value}`.
pub fun single(key : k, value : v) : map<k, v>
    Map(single((key, value)))

fun one/set-op(m : map<k, v>, f : set<(k, v)> -> e set<(k, v)>) : e map<k, v>
    m.set.f.Map

fun two/set-op(
    m : map<k, v>, n : map<k, v>,
    f : (set<(k, v)>, set<(k, v)>) -> e set<(k, v)>
) : e map<k, v> { f(m.set, n.set).Map }

// Insert a new key and value in the map. If the key is already present in the
// map, the associated value is replaced with the supplied value.
//
// ```koka
// fun example()
//     [(6, "a"), (7, "b")].map.insert(6, "x").println // prints: map([(6,"x"),(7,"b")])
//     [(6, "a"), (7, "b")].map.insert(9, "x").println // prints: map([(6,"a"),(7,"b"),(9,"x")])
//     empty.insert(6, "x").println                    // prints: map([(6,"x")])
// ```
pub fun insert(
    m    : map<k, v>,
    key  : k, value : v,
    ?cmp : (k, k) -> e order
) : e map<k, v>
    m.set-op(_.insert((key, value)))

// Insert a new (key, value) in the map. If the key is already present in the
// map, the associated value is replaced with the supplied value.
//
// ```koka
// fun example()
//     [(6, "a"), (7, "b")].map.insert((6, "x")).println // prints: map([(6,"x"),(7,"b")])
// ```
pub fun pair/insert(
    m    : map<k, v>,
    pair : (k, v),
    ?cmp : (k, k) -> e order
) : e map<k, v>
    m.set-op(_.insert(pair))

// Insert with a function, combining new value and old value. `insert-with(m,
// key, value)` will insert the pair `(key, value)` into `m` if `key` does not
// exist in the map. If the key does exist, the function will insert the pair
// `(key, f(old, new))`.
//
// ```koka
// fun example()
//     [(6, "a"), (7, "b")].map.insert-with(6, "xxx", _++_).println // prints: map([(6,"axxx"),(7,"b")])
//     [(6, "a"), (7, "b")].map.insert-with(9, "xxx", _++_).println // prints: map([(6,"a"),(7,"b"),(9,"xxx")])
// ```
pub fun insert-with(
    m : map<k, v>,
    key : k, value : v,
    f : (old : v, new : v) -> e v,
    ?cmp : (k, k) -> e order
) : e map<k, v>
    m.set-op fn(s) s.insert-with((key, value)) fn((_k1, v1), (k2, v2))
        (k2, f(v1, v2))

// Insert with a function, combining key, new value and old value.
// `insert-with-key(m, key, value, f)` will insert the pair `(key, value)` into
// `m` if `key` does not exist in the map. If the key does exist, the function
// will insert the pair `(key, f(key, old, new))`. Note that the key passed to
// `f` is the same key passed to insert-with-key.
//
// ```koka
// fun f(key : int, old : string, new : string) key.show++":"++new++"|"++old
// fun example()
//     [(6, "a"), (7, "b")].map.insert-with-key(6, "xxx", f).println // prints: map([(6,"6:xxx|a"),(7,"b")])
//     [(6, "a"), (7, "b")].map.insert-with-key(9, "xxx", f).println // prints: map([(6,"a"),(7,"b"),(9,"xxx")])
// ```
pub fun insert-with-key(
    m    : map<k, v>,
    key  : k, value : v,
    f    : (k, old : v, new : v) -> e v,
    ?cmp : (k, k) -> e order
) : e map<k, v>
    m.set-op fn(s) s.insert-with((key, value)) fn((_k1, v1), (k2, v2))
        (k2, f(key, v1, v2))

// Combines insert operation with old value retrieval. The expression
// `insert-lookup-with-key(m, k, x, f)` returns a pair where the first element
// is equal to `m.lookup(k)` and the second element equal to
// `insert-with-key(m, k, x, f)`.
//
// ```koka
// fun f(key : int, old : string, new : string) key.show++":"++new++"|"++old
// fun example()
//     [(6, "a"), (7, "b")].map.insert-lookup-with-key(6, "xxx", f).println // prints: (Just("a"),map([(6,"6:xxx|a"),(7,"b")]))
//     [(6, "a"), (7, "b")].map.insert-lookup-with-key(9, "xxx", f).println // prints: (Nothing,map([(6,"a"),(7,"b"),(9,"xxx")]))
// ```
pub fun insert-lookup-with-key(
    m    : map<k, v>,
    key  : k, value : v,
    f    : (k, old : v, new : v) -> e v,
    ?cmp : (k, k) -> e order
) : e (maybe<v>, map<k, v>)
    (m[key], m.insert-with-key(key, value, f))

// Combines insert operation with old value retrieval. The expression
// `insert-lookup(m, k, x)` returns a pair where the first element is equal to
// `m.lookup(k)` and the second element equal to `insert(m, k, x)`.
//
// ```koka
// fun example()
//     [(6, "a"), (7, "b")].map.insert-lookup(6, "xxx").println // prints: (Just("a"),map([(6,"xxx"),(7,"b")]))
//     [(6, "a"), (7, "b")].map.insert-lookup(9, "xxx").println // prints: (Nothing,map([(6,"a"),(7,"b"),(9,"xxx")]))
// ```
pub fun insert-lookup(
    m    : map<k, v>,
    k    : k, v : v,
    ?cmp : (k, k) -> e order
) : e (maybe<v>, map<k, v>)
    m.insert-lookup-with-key(k, v) fn(_k, _old, new) new

// Update the value at a key or insert a value if the key is not in the map.
//
// ```koka
// fun f(m : maybe<int>) : int { m.maybe(1, _+ 1) }
// fun example()
//     [("a", 6), ("b", 7)].map.upsert("a", f).println // prints: map([("a",7),("b",7)])
//     [("a", 6), ("b", 7)].map.upsert("c", f).println // prints: map([("a",6),("b",7),("c",1)])
// ```
pub fun upsert(
    m : map<k, v>, key : k,
    f : maybe<v> -> e v,
    ?cmp : (k, k) -> e order
) : e map<k, v>
    m.insert(key, m.lookup(key).f)

// Look up the value at a key in the map. Returns the corresponding value as
// `Just(value)`, or `Nothing` if the key isn't in the map. See `@index` for
// `map[key]` syntax.
pub fun lookup(m : map<k, v>, key : k, ?cmp : (k, k) -> e order) : e maybe<v>
    m.list.lookup(_ == key)

pub fun @index(m : map<k, v>, key : k, ?cmp : (k, k) -> e order) : e maybe<v>
    m.lookup(key)

// Returns the value at `key` or the default value `def` when the key is not in
// the map.
pub fun default/lookup(
    m    : map<k, v>,
    key  : k, def : v,
    ?cmp : (k, k) -> e order
) : e v { m[key].default(def) }

// Delete a key and its value from the map. When the key is not a member of the
// map, the original map is returned.
//
// ```koka
// fun example()
//     [(6, "a"), (7, "b")].map.delete(6).println // prints: map([(7,"b")])
//     [(6, "a"), (7, "b")].map.delete(9).println // prints: map([(6,"a"),(7,"b")])
// ```
pub fun delete(m : map<k, v>, key : k, ?cmp : (k, k) -> e order) : e map<k, v>
    with v <- m[key].maybe(m)
    m.set-op(_.delete((key, v)))

// Pop an entry from the map. Returns `Nothing` if the key is not in the map.
// Otherwise returns `Just` the value at the key and a map with the entry
// removed.
//
// ```koka
// fun example()
//     [(6, "a"), (7, "b")].map.pop(6).println // prints: Just(("a",map([(7,"b")])))
//     [(6, "a"), (7, "b")].map.pop(9).println // prints: Nothing
// ```
pub fun pop(
    m : map<k, v>, key : k,
    ?cmp : (k, k) -> e order
) : e maybe<(v, map<k, v>)>
    with v <- m.lookup(key).maybe(Nothing)
    (v, m.delete(key)).Just

// Update a value at a specific key with the result of the provided function.
// When the key is not a member of the map, the original map is returned.
//
// ```koka
// fun example()
//     [(6, "a"), (7, "b")].map.adjust(6, "new " ++_).println // prints: map([(6,"new a"),(7,"b")])
//     [(6, "a"), (7, "b")].map.adjust(9, "new " ++_).println // prints: map([(6,"a"),(7,"b")])
// ```
pub fun adjust(
    m      : map<k, v>, key : k,
    f      : v -> e v,
    ?k/cmp : (k, k) -> e order
) : e map<k, v>
    with v <- m.lookup(key).maybe(m)
    m.insert(key, f(v))

// Adjust a value at a specific key. When the key is not a member of the map,
// the original map is returned.
//
// ```koka
// fun example()
//     [(6, "a"), (7, "b")].map.adjust-with-key(6, _.show++":new "++_).println
//     // ^ prints: map([(6,"6:new a"),(7,"b")])
//     [(6, "a"), (7, "b")].map.adjust-with-key(9, _.show++":new "++_).println
//     // ^ prints: map([(6,"a"),(7,"b")])
// ```
pub fun adjust-with-key(
    m : map<k, v>, key : k,
    f : (k, v) -> e v,
    ?k/cmp : (k, k) -> e order
) : e map<k, v>
    with v <- m.lookup(key).maybe(m)
    m.insert(key, f(key, v))

// Updates the value `v` at `key` (if it is in the map). If `f(v)` returns
// `Nothing`, the element is deleted. If it is `Just(w)`, the key is bound to
// the new value `w`.
//
// ```koka
// fun f(v : string) if v == "a" then Just("aaa") else Nothing
// fun example()
//     [(6, "a"), (7, "b")].map.update(6, f).println // prints: map([(6,"aaa"),(7,"b")])
//     [(6, "a"), (7, "b")].map.update(9, f).println // prints: map([(6,"a"),(7,"b")])
//     [(6, "a"), (7, "b")].map.update(7, f).println // prints: map([(6,"a")])
// ```
pub fun update(
    m : map<k, v>, key : k,
    f : v -> e maybe<v>,
    ?k/cmp : (k, k) -> e order
) : e map<k, v>
    with v <- m.lookup(key).maybe(m)
    with w <- f(v).maybe(m.delete(key))
    m.insert(key, w)

// Updates the value `v` at `key` (if it is in the map). If `f(key, v)` is
// `Nothing`, the element is deleted. If it is `Just(y)`, the key is bound to
// the new value `w`.
//
// ```koka
// fun f(k : int, v : string) if v == "a" then Just(k.show++":aaa") else Nothing
// fun example()
//     [(6, "a"), (7, "b")].map.update-with-key(6, f).println // prints: map([(6,"6:aaa"),(7,"b")])
//     [(6, "a"), (7, "b")].map.update-with-key(9, f).println // prints: map([(6,"a"),(7,"b")])
//     [(6, "a"), (7, "b")].map.update-with-key(7, f).println // prints: map([(6,"a")])
// ```
pub fun update-with-key(
    m : map<k, v>, key : k,
    f : (k, v) -> e maybe<v>,
    ?k/cmp : (k, k) -> e order
) : e map<k, v>
    with v <- m.lookup(key).maybe(m)
    with w <- f(key, v).maybe(m.delete(key))
    m.insert(key, w)

// Alters the value `v` at `key`, or absence thereof.
// `alter` can be used to insert, delete, or update a value in a map.
// In short : `alter(m, k, f)[k] == f(m[k])`.
//
// ```koka
// fun f(_m : maybe<string>) Nothing
// fun g(_m : maybe<string>) Just("c")
// fun example()
//     [(6, "a"), (7, "b")].map.alter(6, f).println // prints: map([(7,"b")])
//     [(6, "a"), (7, "b")].map.alter(9, f).println // prints: map([(6,"a"),(7,"b")])
//     [(6, "a"), (7, "b")].map.alter(7, g).println // prints: map([(6,"a"),(7,"c")])
//     [(6, "a"), (7, "b")].map.alter(9, g).println // prints: map([(6,"a"),(7,"b"),(9,"c")])
// ```
pub fun alter(
    m : map<k, v>, key : k,
    f : maybe<v> -> e maybe<v>,
    ?k/cmp : (k, k) -> e order
) : e map<k, v>
    m[key].f.maybe(m.delete(key), m.insert(key, _))

// Is the key a member of the map?
pub fun member(key : k, m : map<k, v>, ?cmp : (k, k) -> e order) : e bool
    m.set.has(key)

// Does the map has the key?
pub fun has(m : map<k, v>, key : k, ?cmp : (k, k) -> e order) : e bool
    m.set.has(key)

// Find largest element smaller than the given one.
//
// ```koka
// fun example()
//     [(6, "a"), (7, "b")].map.find-lt(6).println // prints: Nothing
//     [(6, "a"), (7, "b")].map.find-lt(7).println // prints: Just((6,"a"))
// ```
pub fun find-lt(m : map<k, v>, key : k, ?cmp : (k, k) -> e order) : e maybe<(k, v)>
    m.set.find-lt(key)

// Find largest element smaller than or equal to the given one.
//
// ```koka
// fun example()
//     [(6, "a"), (7, "b")].map.find-le(6).println // prints: Just((6,"a"))
//     [(6, "a"), (7, "b")].map.find-le(7).println // prints: Just((6,"a"))
// ```
pub fun find-le(m : map<k, v>, key : k, ?cmp : (k, k) -> e order) : e maybe<(k, v)>
    m.set.find-le(key)

// Find smallest element greater than the given one.
//
// ```koka
// fun example()
//     [(6, "a"), (7, "b")].map.find-gt(6).println // prints: Just((7,"b"))
//     [(6, "a"), (7, "b")].map.find-gt(7).println // prints: Nothing
// ```
pub fun find-gt(m : map<k, v>, key : k, ?cmp : (k, k) -> e order) : e maybe<(k, v)>
    m.set.find-gt(key)

// Find smallest element greater than or equal to the given one.
//
// ```koka
// fun example()
//     [(6, "a"), (7, "b")].map.find-ge(6).println // prints: Just((7,"b"))
//     [(6, "a"), (7, "b")].map.find-ge(7).println // prints: Just((7,"b"))
// ```
pub fun find-ge(m : map<k, v>, key : k, ?cmp : (k, k) -> e order) : e maybe<(k, v)>
    m.set.find-ge(key)

// Is the map empty?
pub fun is-empty(m : map<k, v>) : bool
    m.set.is-empty

// The number of elements in the map.
pub fun size(m : map<k, v>) : int
    m.set.size

// Takes the left-biased union of `m` and `n`. It prefers `m` when duplicate
// keys are encountered.
//
// ```koka
// fun example()
//     union([(6, "a"), (7, "b")].map, [(6, "x"), (9, "y")].map).println
//     // ^ prints: map([(6,"a"),(7,"b"),(9,"y")])
// ```
pub fun union(m : map<k, v>, n : map<k, v>, ?cmp : (k, k) -> e order) : e map<k, v>
    set-op(m, n, union)

// Union with a combining function.
//
// ```koka
// fun example()
//     union-with([(6, "a"), (7, "b")].map, [(6, "x"), (9, "y")].map, _++_).println
//     // ^ prints: map([(6,"ax"),(7,"b"),(9,"y")])
// ```
pub fun union-with(
    m    : map<k, v>, n : map<k, v>,
    f    : (left : v, right : v) -> e v,
    ?cmp : (k, k) -> e order
) : e map<k, v>
    set-op(m, n, union-with(_, _) fn((k1, v1), (_k2, v2)) (k1, f(v1, v2)))

// Union with a combining function that depends on the key.
//
// ```koka
// fun example()
//     union-with-key([(6, "a"), (7, "b")].map, [(6, "x"), (9, "y")].map, _.show++_++_).println
//     // ^ prints: map([(6,"6ax"),(7,"b"),(9,"y")])
// ```
pub fun union-with-key(
    m    : map<k, v>, n : map<k, v>,
    f    : (key : k, left : v, right : v) -> e v,
    ?cmp : (k, k) -> e order
) : e map<k, v>
    set-op(m, n, union-with(_, _) fn((k1, v1), (_k2, v2)) (k1, f(k1, v1, v2)))

// The union of a list of maps, by `foldl`-ing `union` on `empty` .
pub fun unions(ms : list<map<k, v>>, ?cmp : (k, k) -> e order) : e map<k, v>
    ms.foldl(empty, union)

// The union of a list of maps, with a combining operation.
pub fun unions-with(ms : list<map<k, v>>, f : (v, v) -> e v, ?cmp : (k, k) -> e order) : e map<k, v>
    ms.foldl(empty, union-with(_, _, f))

// Difference of two maps. Return elements of the first map not existing in the
// second map.
//
// ```koka
// fun example()
//     difference([(6, "a"), (7, "b")].map, [(6, "x"), (9, "y")].map).println
//     // ^ prints: map([(7,"b")])
// ```
pub fun difference(m : map<k, v>, n : map<k, v>, ?cmp : (k, k) -> e order) : e map<k, v>
    set-op(m, n, difference)

// The operator for the difference of two maps.
pub fun (\\)(m : map<k, v>, n : map<k, v>, ?cmp : (k, k) -> e order) : e map<k, v>
    difference(m, n)

// The other operator for the difference of two maps.
pub fun (-)(m : map<k, v>, n : map<k, v>, ?cmp : (k, k) -> e order) : e map<k, v>
    difference(m, n)

// Difference with a combining function. When two equal keys are encountered,
// the combining function is applied to the values of these keys. If it returns
// `Nothing`, the element is discarded (proper set difference). If it returns
// `Just(w)`, the element is updated with a new value `w`.
//
// ```koka
// fun f(l : string, r : string) if l == "b" then Just(l++":"++r) else Nothing
// fun example()
//     difference-with([(6, "a"), (7, "b")].map, [(6, "x"), (7, "y"), (9, "z")].map, f).println
//     // ^ prints: map([(7,"b:y")])
// ```
pub fun difference-with(
    m    : map<k, v>, n : map<k, w>,
    f    : (v, w) -> e maybe<v>,
    ?cmp : (k, k) -> e order
) : e map<k, v>
    n.foldl-with-key(m) fn(z, k, w) z.update(k) fn(v) f(v, w)

// Difference with a combining function that depends on the key. When two equal
// keys are encountered, the combining function is applied to the values of
// these keys. If it returns `Nothing`, the element is discarded (proper set
// difference). If it returns `Just(w)`, the element is updated with a new
// value `w`.
//
// ```koka
// fun f(k : int, l : string, r : string)
//     if l == "b" then Just(k.show++"="++l++":"++r) else Nothing
// fun example()
//     difference-with-key([(6, "a"), (7, "b")].map, [(6, "x"), (7, "y"), (9, "z")].map, f).println
//     // ^ prints: map([(7,"7=b:y")])
// ```
pub fun difference-with-key(m : map<k, v>, n : map<k, w>, f : (k, v, w) -> e maybe<v>, ?cmp : (k, k) -> e order) : e map<k, v>
    n.foldl-with-key(m) fn(z, k, w) z.update(k) fn(v) f(k, v, w)

// Intersection of two maps. Return data in the first map for the keys existing
// in both maps.
//
// ```koka
// fun example()
//     intersection([(6, "a"), (7, "b")].map, [(6, "x"), (9, "y")].map).println
//     // ^ prints: map([(6,"a")])
// ```
pub fun intersection(m : map<k, v>, n : map<k, w>, ?cmp : (k, k) -> e order) : e map<k, v>
    m.foldl-with-key(empty) fn(z, k, v) if n.has(k) then z.insert(k, v) else z

// Intersection with a combining function.
//
// ```koka
// fun example()
//     intersection-with([(6, "a"), (7, "b")].map, [(6, "x"), (9, "y")].map, _++_).println
//     // ^ prints: map([(6,"ax")])
// ```
pub fun intersection-with(
    m    : map<k, v>, n : map<k, w>,
    f    : (v, w) -> e u,
    ?cmp : (k, k) -> e order
) : e map<k, u>
    m.foldl-with-key(empty) fn(z, k, v) n[k].maybe(z) fn(w) z.insert(k, f(v, w))

// Intersection with a combining function that depends on the key.
//
// ```koka
// fun example()
//     intersection-with([(6, "a"), (7, "b")].map, [(6, "x"), (9, "y")].map, _.show++_++_).println
//     // ^ prints: map([(6,"6ax")])
// ```
pub fun intersection-with-key(
    m    : map<k, v>, n : map<k, w>,
    f    : (k, v, w) -> e u,
    ?cmp : (k, k) -> e order
) : e map<k, u>
    m.foldl-with-key(empty) fn(z, k, v) n[k].maybe(z) fn(w)
        z.insert(k, f(k, v, w))

// The symmetric difference of two maps. The result contains entries whose keys
// appear in exactly one of the two maps.
//
// ```koka
// fun example()
//     symmetric-difference( [(0,'q'),(2,'b'),(4,'w'),(6,'o')].map
//                         , [(0,'e'),(3,'r'),(6,'t'),(9,'s')].map).println
//     // ^ prints: map([(2,'b'),(4,'w')])
// ```
pub fun symmetric-difference(
    m    : map<k, v>, n : map<k, v>,
    ?cmp : (k, k) -> e order
) :  e map<k, v>
    m.foldl-with-key(empty) fn(z, k, v)
        if n.has(k).not then z.insert(k, v) else z

// Check whether the key sets of two maps are disjoint (i.e., their
// `intersection` is empty).
//
// ```koka
// fun example()
//     disjoint([(6, "a"), (7, "b")].map, [(6, "x"), (9, "y")].map).println // prints: False
//     disjoint([(6, "a"), (7, "b")].map, [(3, 'x'), (9, 'y')].map).println // prints: True
//     disjoint(empty : map<int, string>, empty : map<int, bool>).println   // prints: True
// ```
pub fun disjoint(m : map<k, v>, n : map<k, w>, ?cmp : (k, k) -> e order) : e bool
    m.intersection(n).is-empty

fun set/fmap(s : set<a>, f : a -> e b, ?cmp : (b, b) -> e order) : e set<b>
    set/map(s, f)

// Given maps `bc` and `ab`, relate the keys of `ab` to the values of `bc`, by
// using the values of `ab` as keys for lookups in `bc`.
//
// ```koka
// fun example()
//     compose([('a', "A"), ('b', "B")].map, [(1,'a'),(2,'b'),(3,'z')].map).println
//     // ^ prints: map([(1,"A"),(2,"B")])
// ```
pub fun compose(
    bc : map<b, c>, ab : map<a, b>,
    ?a/cmp : (a, a) -> e order,
    ?b/cmp : (b, b) -> e order
) : e map<a, c>
    ab.foldl-with-key(empty) fn(z, a, b) bc[b].maybe(z, z.insert(a, _))

fun tuple2/first((a, b) : (a, b), f : a -> e c) : e (c, b)
    (f(a), b)

fun tuple2/second((a, b) : (a, b), f : b -> e c) : e (a, c)
    (a, f(b))

// Map a function over all values in the map.
pub fun map(m : map<k, v>, f : v -> e w, ?cmp : (k, k) -> e order) : e map<k, w>
    m.set.fmap(_.second(f)).Map

// Other name for `map`.
pub fun fmap(m : map<k, v>, f : v -> e w, ?cmp : (k, k) -> e order) : e map<k, w>
    m.map(f)

// Map a function that depends on the key over all values in the map.
pub fun map-with-key(m : map<k, v>, f : (k, v) -> e w, ?cmp : (k, k) -> e order) : e map<k, w>
    m.set.fmap(fn((k, v)) (k, f(k, v))).Map

// Thread an accumulating argument through the map in ascending order of keys.
//
// ```koka
// fun example()
//     map-accum([(6, "a"), (7, "b")].map, "Everything: ", fn(a, b) (a ++ b, b ++ "X")).println
//     // ^ prints: ("Everything: ab",map([(6,"aX"),(7,"bX")]))
// ```
pub fun map-accum(
    m : map<k, v>, z : a,
    f : (a, v) -> e (a, w),
    ?cmp : (k, k) -> e order
) : e (a, map<k, w>)
    m.foldl-with-key((z, empty)) fn((x, y), k, v)
        val (x', w) = f(x, v)
        (x', y.insert(k, w))

// Thread an accumulating argument through the map in ascending order of keys
// using a function that depends on the key.
//
// ```koka
// fun example()
//     map-accum-with-key([(6, "a"), (7, "b")].map, "Everything: ",
//                        fn(a, k, b) (a++b, k.show++b++"X")).println
//     // ^ prints: ("Everything: ab",map([(6,"6aX"),(7,"7bX")]))
// ```
pub fun map-accum-with-key(
    m : map<k, v>, z : a,
    f : (a, k, v) -> e (a, w),
    ?cmp : (k, k) -> e order
) : e (a, map<k, w>)
    m.foldl-with-key((z, empty)) fn((x, y), k, v)
        val (x', w) = f(x, k, v)
        (x', y.insert(k, w))

// `map-keys(m, f)` is the map obtained by applying `f` to each key of `m`. The
// size of the result may be smaller if `f` maps two or more distinct keys to
// the same new key. In this case the value at the greatest of the original
// keys is retained.
//
// ```koka
// fun example()
//     map-keys([(6, "a"), (7, "b")].map, _+ 1).println    // prints: map([(7,"a"),(8,"b")])
//     map-keys([(6, "a"), (7, "b")].map, fn(_) 2).println // prints: map([(2,"b")])
// ```
pub fun map-keys(m : map<k1, v>, f : k1 -> e k2, ?cmp : (k2, k2) -> e order) : e map<k2, v>
    m.foldl-with-key(empty) fn(z, k, v) z.insert(f(k), v)

// `map-keys-with(m, c, f)` is the map obtained by applying `f` to each key of
// `m`. The size of the result may be smaller if `f` maps two or more distinct
// keys to the same new key. In this case the associated values will be
// combined using `c`. The value at the greater of the two original keys is
// used as the first argument to `c`.
//
// ```koka
// fun example()
//     map-keys-with([(6, "a"), (7, "b")].map, fn(x:string,y)x++y, _+ 1).println
//     // ^ prints: map([(7,"a"),(8,"b")])
//     map-keys-with([(6, "a"), (7, "b")].map, fn(x:string,y)x++y, fn(_) 2).println
//     // ^ prints: map([(2,"ba")])
// ```
pub fun map-keys-with(
    m : map<k1, v>,
    c : (v, v) -> e v,
    f : k1 -> e k2,
    ?cmp : (k2, k2) -> e order
) : e map<k2, v>
    m.foldl-with-key(empty) fn(z, k, v) match z[f(k)]
        Nothing -> z.insert(f(k), v)
        Just(w) -> z.insert(f(k), c(v, w))

// Map over keys and values with a function `f` that is monotonically strictly
// increasing in the keys. That is, for keys `kx` and `ky` and values `x` and
// `y`, if `kx < ky` then `fst(f(kx, x)) < fst(f(ky, y))`.
pub fun bimap(m : map<k, v>, f : (k, v) -> e (l, w), ?cmp : (l, l) -> e order) : e map<l, w>
    m.foldl-with-key(empty) fn(z, k, v)
        val (l, w) = f(k, v)
        z.insert(l, w)

// Fold a map from the left.
// Since `foldl` is tail recursive, it is preferred over `foldr` when using an
// associative function `f`
pub fun foldl(m : map<k, v>, z : a, f : (a, v) -> e a) : e a
    m.set.foldl(z, fn(a, (_k, v)) f(a, v))

// Fold a map from the left with a function that depends on the key.
pub fun foldl-with-key(m : map<k, v>, z : a, f : (a, k, v) -> e a) : e a
    m.set.foldl(z) fn(a, (k, v)) f(a, k, v)

// Fold a map from the right.
// Note, `foldr` is less efficient than `foldl` as it reverses the
// list representation first.
pub fun foldr(m : map<k, v>, z : a, f : (v, a) -> e a) : e a
    m.set.foldr(z) fn((_k, v), a) f(v, a)

// Fold a map from the right with a function that depends on the key.
pub fun foldr-with-key(m : map<k, v>, z : a, f : (k, v, a) -> e a) : e a
    m.set.foldr(z) fn((k, v), a) f(k, v, a)

// Return all elements of the map in the ascending order of their keys.
pub fun elems(m : map<k, v>) : list<v>
    m.list.map(_.snd)

// Return all elements of the map in the ascending order of their keys.
pub fun values(m : map<k, v>) : list<v>
    m.list.map(_.snd)

// Return all keys of the map in ascending order.
pub fun keys(m : map<k, v>) : list<k>
    m.list.map(_.fst)

// Alias to `map/list`.
pub fun assocs(m : map<k, v>) : list<(k, v)>
    m.list

// The set of all keys of the map.
pub fun key-set(m : map<k, v>, ?cmp : (k, k) -> e order) : e set<k>
    m.set.map(_.fst)

// Retain only those pairs of a map that satisfy the given predicate on the values.
pub fun filter(m : map<k, v>, p : v -> e bool, ?cmp : (k, k) -> e order) : e map<k, v>
    m.set-op(_.filter(_.snd.p))

// Retain only those pairs of a map that satisfy the given predicate on the keys.
pub fun filter-keys(m : map<k, v>, p : k -> e bool, ?cmp : (k, k) -> e order) : e map<k, v>
    m.set-op(_.filter(_.fst.p))

// Retain only those pairs of a map that satisfy the given predicate on the them.
pub fun filter-with-keys(m : map<k, v>, p : (k, v) -> e bool, ?cmp : (k, k) -> e order) : e map<k, v>
    m.set-op(_.filter(fn((k, v)) p(k, v)))

// Restrict a map to only those keys found in a set.
pub fun restrict-keys(m : map<k, v>, s : set<k>, ?cmp : (k, k) -> e order) : e map<k, v>
    filter-keys(m, s.member(_))

// Remove all keys in a set from a map.
pub fun without-keys(m : map<k, v>, s : set<k>, ?cmp : (k, k) -> e order) : e map<k, v>
    filter-keys(m, s.member(_).not)

// Partition the map according to a predicate on the values. The first map
// contains all elements that satisfy the predicate, the second all elements
// that fail the predicate. See also `split`.
//
// ```koka
// fun example()
//     partition([(6, "a"), (7, "b")].map, _> "a").println // prints: (map([(7,"b")]),map([(6,"a")]))
//     partition([(6, "a"), (7, "b")].map, _< "x").println // prints: (map([(6,"a"),(7,"b")]),map([]))
//     partition([(6, "a"), (7, "b")].map, _> "x").println // prints: (map([]),map([(6,"a"),(7,"b")]))
// ```
pub fun partition(m : map<k, v>, p : v -> e bool, ?cmp : (k, k) -> e order) : e (map<k, v>, map<k, v>)
    val (a, b) = m.set.partition(_.snd.p)
    (a.Map, b.Map)

// Partition the map according to a predicate on the pairs. The first map
// contains all elements that satisfy the predicate, the second all elements
// that fail the predicate. See also `split`.
//
// ```koka
// fun example()
//     partition-with-key([(6, "a"), (7, "b")].map, _> "a").println // prints: (map([(7,"b")]),map([(6,"a")]))
//     partition-with-key([(6, "a"), (7, "b")].map, _< "x").println // prints: (map([(6,"a"),(7,"b")]),map([]))
//     partition-with-key([(6, "a"), (7, "b")].map, _> "x").println // prints: (map([]),map([(6,"a"),(7,"b")]))
// ```
pub fun partition-with-key(m : map<k, v>, p : (k, v) -> e bool, ?cmp : (k, k) -> e order) : e (map<k, v>, map<k, v>)
    val (a, b) = m.set.partition fn((k, v)) p(k, v)
    (a.Map, b.Map)

// Take while a predicate on the keys holds. The user is responsible for
// ensuring that for all keys `j` and `k` in the map, `j < k ==> p j >= p k`.
// See note at `span-antitone`.
pub fun take-while-antitone(m : map<k, v>, p : k -> e bool, ?cmp : (k, k) -> e order) : e map<k, v>
    m.set-op(_.take-while-antitone(_.fst.p))

// Drop while a predicate on the keys holds. The user is responsible for
// ensuring that for all keys `j` and `k` in the map, `j < k ==> p j >= p k`.
// See note at `span-antitone`.
pub fun drop-while-antitone(m : map<k, v>, p : k -> e bool, ?cmp : (k, k) -> e order) : e map<k, v>
    m.set-op(_.drop-while-antitone(_.fst.p))

// Divide a map at the point where a predicate on the keys stops holding. The
// user is responsible for ensuring that for all keys `j` and `k` in the map, `j < k
// ==> p j >= p k`.
// Note: if p is not actually antitone, then spanAntitone will split the map at
// some unspecified point where the predicate switches from holding to not
// holding (where the predicate is seen to hold before the first key and to
// fail after the last key).
pub fun span-antitone(m : map<k, v>, p : k -> e bool, ?cmp : (k, k) -> e order) : e (map<k, v>, map<k, v>)
    val (a, b) = m.set.span-antitone(_.fst.p)
    (a.Map, b.Map)

// Map values and collect the `Just` results.
//
// ```koka
// fun f(v : char) : <> maybe<string> if v == 'a' then Just("aaa") else Nothing
// fun example()
//     map-maybe([(6, 'a'), (7, 'b')].map, f).println // prints: map([(6,"aaa")])
// ```
pub fun map-maybe(m : map<k, v>, f : v -> e maybe<w>, ?cmp : (k, k) -> e order) : e map<k, w>
    m.set
     .map-maybe(fn((k, v)) f(v).maybe(Nothing, (k, _).Just))
     .Map

// Map values and collect the `Just` results using a function that also depends
// on the keys.
//
// ```koka
// fun f(k : int, v : char) : <> maybe<string> if v == 'a' then Just(k.show++"aaa") else Nothing
// fun example()
//     map-maybe-with-key([(6, 'a'), (7, 'b')].map, f).println // prints: map([(6,"6aaa")])
// ```
pub fun map-maybe-with-key(m : map<k, v>, f : (k, v) -> e maybe<w>, ?cmp : (k, k) -> e order) : e map<k, w>
    m.set
     .map-maybe(fn((k, v)) f(k, v).maybe(Nothing, (k, _).Just))
     .Map

// Map values and separate the `Left` and `Right` results.
//
// ```koka
// fun f(v : string) : either<string, string>
//     if v < "c" then Left(v) else Right(v)
// fun example()
//     map-either([(6, "a"), (7, "b"), (9, "x"), (13, "z")].map, f).println
//     // ^ prints: (map([(6,"a"),(7,"b")]),map([(9,"x"),(13,"z")]))
//     map-either([(6, "a"), (7, "b"), (9, "x"), (13, "z")].map,
//                fn(v) : _ either<string, string> Right(v)).println
//     // ^ prints: (map([]),map([(6,"a"),(7,"b"),(9,"x"),(13,"z")]))
// ```
pub fun map-either(m : map<k, v>, f : v -> e either<l, r>, ?cmp : (k, k) -> e order) : e (map<k, l>, map<k, r>)
    m.map(f).foldl-with-key((empty, empty)) fn((ls, rs), k, ev) match ev
        Left(v)  -> (ls.insert(k, v), rs)
        Right(v) -> (ls, rs.insert(k, v))

// Map keys/values and separate the Left and Right results.
//
// ```koka
// fun f(k : int, v : string) : either<int, string>
//     if k > 8 then Left(k * 2) else Right(v ++ v)
// fun example()
//     map-either-with-key([(6, "a"), (7, "b"), (9, "x"), (13, "z")].map, f).println
//     // ^ prints: (map([(9,18),(13,26)]),map([(6,"aa"),(7,"bb")]))
// ```
pub fun map-either-with-key(m : map<k, v>, f : (k, v) -> e either<l, r>, ?cmp : (k, k) -> e order) : e (map<k, l>, map<k, r>)
    m.map-with-key(f).foldl-with-key((empty, empty)) fn((ls, rs), k, ev) match ev
        Left(v)  -> (ls.insert(k, v), rs)
        Right(v) -> (ls, rs.insert(k, v))

// `split(m, k)` returns a pair `(map1,map2)` where the keys in `map1` are
// smaller than `k` and the keys in `map2` larger than `k`. Any key equal to
// `k` is found in neither `map1` nor `map2`.
//
// ```koka
// fun example()
//     val m = [(6, "a"), (7, "b"), (9, "x"), (13, "z")].map
//     m.split(4).println  // prints: (map([]),map([(6,"a"),(7,"b"),(9,"x"),(13,"z")]))
//     m.split(7).println  // prints: (map([(6,"a")]),map([(9,"x"),(13,"z")]))
//     m.split(8).println  // prints: (map([(6,"a"),(7,"b")]),map([(9,"x"),(13,"z")]))
//     m.split(20).println // prints: (map([(6,"a"),(7,"b"),(9,"x"),(13,"z")]),map([]))
// ```
pub fun split(m : map<k, v>, key : k, ?cmp : (k, k) -> e order) : e (map<k, v>, map<k, v>)
    m.filter-keys(_!= key).span-antitone(_< key)

// `split-lookup(m, k)` splits a map just like `split` but also returns `m.lookup(k)`.
//
// ```koka
// fun example()
//     val m = [(6, "a"), (7, "b"), (9, "x"), (13, "z")].map
//     m.split-lookup(4).println  // prints: (map([]),Nothing,map([(6,"a"),(7,"b"),(9,"x"),(13,"z")]))
//     m.split-lookup(7).println  // prints: (map([(6,"a")]),Just("b"),map([(9,"x"),(13,"z")]))
//     m.split-lookup(8).println  // prints: (map([(6,"a"),(7,"b")]),Nothing,map([(9,"x"),(13,"z")]))
//     m.split-lookup(20).println // prints: (map([(6,"a"),(7,"b"),(9,"x"),(13,"z")]),Nothing,map([]))
// ```
pub fun split-lookup(m : map<k, v>, key : k, ?cmp : (k, k) -> e order) : e (map<k, v>, maybe<v>, map<k, v>)
    val (l, r) = m.split(key)
    (l, m[key], r)

// `is-submap-of(m, n)` returns `True` if all keys in m are in tree n, and when
// `(==)` on `v` returns 'True' when applied to their respective values. For
// example, the following expressions are all 'True':
//
// ```koka
// val true = is-submap-of([('a',1)].map,         [('a',1),('b',2)].map, _==_)
// val true = is-submap-of([('a',1)].map,         [('a',1),('b',2)].map, _<=_)
// val true = is-submap-of([('a',1),('b',2)].map, [('a',1),('b',2)].map, _==_)
// ```
//
// But the following are all 'False':
//
// ```koka
// val false = is-submap-of([('a',2)].map,         [('a',1),('b',2)].map, _==_)
// val false = is-submap-of([('a',1)].map,         [('a',1),('b',2)].map, _<_)
// val false = is-submap-of([('a',1),('b',2)].map, [('a',1)].map, _==_)
// ```
//
// Note that `is-submap-of(m, n, fn(_, _) True)` tests whether all the keys in
// `m` are also keys in `m`.
pub fun is-submap-of(m : map<k, v>, n : map<k, v>, ?v/(==) : (v, v) -> e bool, ?k/cmp : (k, k) -> e order) : e bool
    m.keys.all fn(k) n.has(k) && m[k] == n[k]

// Is this a proper submap? (ie. a submap but not equal). See `is-submap-of`.
pub fun is-proper-submap-of(m : map<k, v>, n : map<k, v>, ?v/(==) : (v, v) -> e bool, ?k/cmp : (k, k) -> e order) : e bool
    m != n && m.is-submap-of(n)

// Returns the index of the first element where `pred` on the key holds, or
// `-1` if no such element exists.
pub fun index-of(m : map<k, v>, p : k -> e bool, ?cmp : (k, k) -> e order) : e int
    m.set.index-of(_.fst.p)

// Update the element at index. Returns `Nothing` when an invalid index is
// used.
pub fun update-at(m : map<k, v>, ix : int, f : v -> e maybe<v>, ?cmp : (k, k) -> e order) : e maybe<map<k, v>>
    m.set[ix].map fn((k, _v)) m.update(k, f)

// Update the element at index using a funvtions that depends on the key.
// Returns `Nothing` when an invalid index is used.
pub fun update-with-key-at(m : map<k, v>, ix : int, f : (k, v) -> e maybe<v>, ?cmp : (k, k) -> e order) : e maybe<map<k, v>>
    m.set[ix].map fn((k, _v)) m.update-with-key(k, f)

// Delete the element at index. Returns `Nothing` when an invalid index is
// used.
pub fun delete-at(m : map<k, v>, ix : int, ?cmp : (k, k) -> e order) : e maybe<map<k, v>>
    m.update-at(ix) fn(_) Nothing

// Take a given number of elements in order, beginning with the smallest keys.
pub fun take(m : map<k, v>, n : int, ?cmp : (k, k) -> e order) : e map<k, v>
    m.set-op(_.take(n))

// Drop a given number of elements in order, beginning with the smallest keys.
pub fun drop(m : map<k, v>, n : int, ?cmp : (k, k) -> e order) : e map<k, v>
    m.set-op(_.drop(n))

//  Split a map at a particular index.
pub fun split-at(m : map<k, v>, n : int, ?cmp : (k, k) -> e order) : e (map<k, v>, map<k, v>)
    (m.take(n), m.drop(n))

// Return the element of the map with the minimum key, or `Nothing` if empty.
pub fun minimum(m : map<k, v>, ?cmp : (k, k) -> e order) : e maybe<(k, v)>
    m.set.minimum

// Return the element of the map with the maximum key, or `Nothing` if empty.
pub fun maximum(m : map<k, v>, ?cmp : (k, k) -> e order) : e maybe<(k, v)>
    m.set.maximum

// Delete the element with the minimal key. Returns `Nothing` if the set is
// empty.
pub fun delete-min(m : map<k, v>, ?cmp : (k, k) -> e order) : e maybe<map<k, v>>
    m.set.delete-min.map(Map)

// Delete the element with the maximal key. Returns `Nothing` if the set is
// empty.
pub fun delete-max(m : map<k, v>, ?cmp : (k, k) -> e order) : e maybe<map<k, v>>
    m.set.delete-max.map(Map)

// Update the element at the minimal key. Returns `Nothing` when an invalid
// index is used.
pub fun update-min(m : map<k, v>, f : v -> e maybe<v>, ?cmp : (k, k) -> e order) : e map<k, v>
    m.update-at(0, f).default(m)

// Update the element at the minimal key using a function that depends on the
// key. Returns `Nothing` when an invalid index is used.
pub fun update-min-with-key(m : map<k, v>, f : (k, v) -> e maybe<v>, ?cmp : (k, k) -> e order) : e map<k, v>
    m.update-with-key-at(0, f).default(m)

// Update the element at the maximal key. Returns `Nothing` when an invalid
// index is used.
pub fun update-max(m : map<k, v>, f : v -> e maybe<v>, ?cmp : (k, k) -> e order) : e map<k, v>
    m.update-at(m.size - 1, f).default(m)

// Update the element at the maximal key using a function that depends on the
// key. Returns `Nothing` when an invalid index is used.
pub fun update-max-with-key(m : map<k, v>, f : (k, v) -> e maybe<v>, ?cmp : (k, k) -> e order) : e map<k, v>
    m.update-with-key-at(m.size - 1, f).default(m)

fun maybe/map2(ma : maybe<a>, mb : maybe<b>, f : (a, b) -> e c) : e maybe<c>
    match ma
        Just(a) -> match mb
            Just(b) -> Just(f(a, b))
            _ -> Nothing
        _ -> Nothing

// Retrieves the element with the maximal key of the map, and the map stripped
// of that element, or `Nothing` if passed an empty map.
pub fun max-view(m : map<k, v>, ?cmp : (k, k) -> e order) : e maybe<(v, map<k, v>)>
    map2(m.maximum, m.delete-max, (_.snd, _))

// Retrieves the pair with the maximal key of the map, and the map stripped
// of that element, or `Nothing` if passed an empty map.
pub fun max-view-with-key(m : map<k, v>, ?cmp : (k, k) -> e order) : e maybe<((k, v), map<k, v>)>
    map2(m.maximum, m.delete-max, (_, _))

// Retrieves the element with the minimal key of the map, and the map stripped
// of that element, or `Nothing` if passed an empty map.
pub fun min(m : map<k, v>, ?cmp : (k, k) -> e order) : e maybe<(v, map<k, v>)>
    map2(m.minimum, m.delete-min, (_.snd, _))

// Retrieves the pair with the minimal key of the map, and the map stripped
// of that element, or `Nothing` if passed an empty map.
pub fun min-with-key(m : map<k, v>, ?cmp : (k, k) -> e order) : e maybe<((k, v), map<k, v>)>
    map2(m.minimum, m.delete-min, (_, _))

// Show the tree that implements the map.
pub fun show-tree(m : map<k, v>, ?k/show : k -> e string, ?v/show : v -> e string) : e string
    m.set.show-tree

// Test if the internal map structure is valid.
pub fun is-valid(m : map<k, v>) : bool
    m.set.is-valid
