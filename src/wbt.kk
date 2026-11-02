module wbt

import std/core/unsafe

fun invariant(msg) : a
    with unsafe-total
    throw(msg)

abstract type tree<a>
    Leaf
    Node
        value: a
        left:  tree<a>
        right: tree<a>
        size:  int

fun (%^)(str: string, repls: list<string>): string
    list(1, repls.length)
    .map("%" ++ _.show)
    .zip(repls)
    .foldl(str) fn(z, (ix, x))
        z.replace-all(ix, x)

pub fun show(tree: tree<a>, ?a/show: a -> e string): e string
    match tree
        Leaf -> "Leaf"
        Node(x, l, r, s) ->
            "Node(value=%1, left=%2, right=%3, size=%4)"%^[
                x.show,
                l.show(), r.show(),
                s.show
            ]

pub fun pretty-by(tree: tree<a>, f: (a, int) -> e string): e string
    fun go(t: tree<a>, up: string, here: string, down: string, g: (a, int) -> e string): e list<string>
        match t
            Leaf -> []
            Node(x, l, r, s) ->
                go(r, up ++ "    ", up ++ "┌── ", up ++ "│   ", g)
                ++ [here ++ g(x, s)]
                ++ go(l, down ++ "│   ", down ++ "└── ", down ++ "    ", g)
    match tree
        Leaf -> "(kosong)"
        _    -> go(tree, "", "", "", f).join("\n")

pub fun pretty(tree: tree<a>, ?a/show: a -> e string): e string
    tree.pretty-by fn(x, _) x.show

pub fun pretty-sized(tree: tree<a>, ?a/show: a -> e string): e string
    tree.pretty-by fn(x, s) x.show ++ " [size=" ++ s.show ++ "]"

pub fun eq(t1: tree<a>, t2: tree<a>, ?a/(==): (a, a) -> e bool): e bool
    match t1
        Leaf -> match t2
            Leaf -> True
            Node(_) -> False
        Node(v1, l1, r1, s1) -> match t2
            Leaf -> False
            Node(v2, l2, r2, s2) ->
                s1 == s2
                && v1 == v2
                && eq(l1, l2)
                && eq(r1, r2)

pub fun (==)(t1, t2, ?a/(==))
    eq(t1, t2)

pub fun size(tree: tree<a>): int
    match tree
        Leaf -> 0
        Node(size = s) -> s

pub fun weight(tree) tree.size + 1

pub fun node(value: a, left: tree<a> = Leaf, right: tree<a> = Leaf): tree<a>
    Node( value, left, right
        , size = 1 + left.size + right.size)

pub fun single(value: a): tree<a>
    node(value, Leaf, Leaf)

// :: Tree a -> a -> Tree a -> a -> Tree a -> Tree a
fun rot1-left(a, x, b, y, c)
    y.node(left=x.node(a, b), right=c)

fun rot1-right(a, x, b, y, c)
    x.node(left=a, right=y.node(b, c))

fun rot2(a, x, b, z, c)
    match b
        Node(y, b1, b2, _) -> y.node(left=x.node(a, b1), right=z.node(b2, c))
        Leaf -> invariant("rot2: argument b should not be a Leaf")

pub struct params
    delta1: int
    delta2: int
    gamma1: int
    gamma2: int

pub fun params/show(pa__derived_show : params)
  "Params("
  ++ "delta1=" ++ pa__derived_show.delta1.show ++ ", "
  ++ "delta2=" ++ pa__derived_show.delta2.show ++ ", "
  ++ "gamma1=" ++ pa__derived_show.gamma1.show ++ ", "
  ++ "gamma2=" ++ pa__derived_show.gamma2.show
  ++ ")"

pub fun param/is-valid(Params(d1, d2, g1, g2): params): bool
    d1 * 2 < d2 * 9                                                   // <Delta> < 4.5
    && g1 * d2 + g2 * d2 <= g2 * d1                                   // <Gamma> + 1 <= <Delta>
    && g1 * d1 >= g2 * (d1 + d2)                                      // <Gamma> >= (<Delta>+1)/<Delta>
    && (not(5 * d2 <= 2 * d1 && d1 < 3 * d2)     || g1 * 2 <= g2 * 3) // 2.5 <= <Delta> < 3
    && (not(3 * d2 <= d1     && 2 * d1 < 7 * d2) || g1 * 2 <= g2 * 4) // 3   <= <Delta> < 3.5
    && (not(7 * d2 <= 2 * d1 && d1 < 4 * d2)     || g1 * 3 <= g2 * 4) // 3.5 <= <Delta> < 4
    && (not(4 * d2 <= d1     && 2 * d1 < 9 * d2) || g1 * 3 <= g2 * 5) // 4   <= <Delta> < 4.5

pub val afp/params      = Params(25, 10, 14, 10)
pub val hirayama/params' = Params( 3,  1,  2,  1)

pub fun balanced1(t1, t2, ?params)
    params.delta1 * t1.weight
    >= params.delta2 * t2.weight

pub fun needs-double-rot(t1, t2, ?params)
    params.gamma2 * t1.weight
    >= params.gamma1 * t2.weight

pub fun is-valid(tree: tree<a>, ?params: params): bool
    match tree
        Leaf -> True
        Node(left=l, size=n, right=r) ->
            n == 1 + l.size + r.size
            && balanced1(l, r)
            && balanced1(r, l)
            && l.is-valid()
            && r.is-valid()

pub fun rotate-left(x, a, z, ?params)
    match z
        Node(y, b, c) ->
            if needs-double-rot(b, c)
            then rot2(a, x, b, y, c)
            else rot1-left(a, x, b, y, c)
        Leaf -> invariant("rotate-left: the left subtree (z) should not be a Leaf")

pub fun balance-left(x, l, r, ?params)
    if balanced1(l, r)
    then x.node(l, r)
    else rotate-left(x, l, r)

pub fun rotate-right(y, z, c, ?params)
    match z
        Node(x, a, b) ->
            if needs-double-rot(b, a)
            then rot2(a, x, b, y, c)
            else rot1-right(a, x, b, y, c)
        Leaf -> invariant("rotate-right: the right subtree (z) should not be a Leaf")

pub fun balance-right(x, l, r, ?params)
    if balanced1(r, l)
    then node(x, l, r)
    else rotate-right(x, l, r)

pub val empty = Leaf

pub fun member(x : b, tree : tree<a>, ?cmp : (b, a) -> e order) : e bool
    match tree
        Leaf -> False
        Node(y, l, r) -> match cmp(x, y)
            Lt -> x.member(l)
            Gt -> x.member(r)
            Eq -> True

pub fun insert(x: a, tree: tree<a>, ?cmp: (a, a) -> e order, ?params): e tree<a>
    match tree
        Leaf -> node(x)
        Node(y, l, r) -> match cmp(x, y)
            Lt -> y.balance-right(x.insert(l), r)
            Gt -> y.balance-left(l, x.insert(r))
            Eq -> x.node(l, r)

pub fun insert'(tree: tree<a>, x: a, ?cmp: (a, a) -> e order, ?params): e tree<a>
    insert(x, tree)

pub fun insert-with(x: a, tree: tree<a>, f : (old : a, new : a) -> e a, ?cmp: (a, a) -> e order, ?params): e tree<a>
    match tree
        Leaf -> node(x)
        Node(y, l, r) -> match cmp(x, y)
            Lt -> y.balance-right(x.insert(l), r)
            Gt -> y.balance-left(l, x.insert(r))
            Eq -> f(y, x).node(l, r)

pub fun split-min(tree, ?params)
    match tree
        Leaf -> invariant("split-min: found a Leaf")
        Node(x, Leaf, r) -> (x, r)
        Node(x, l, r) ->
            val (x', l') = split-min(l)
            (x', balance-left(x, l', r))

pub fun del-max(tree, ?params)
    match tree
        Leaf -> invariant("del-max: found a Leaf")
        Node(x, l, Leaf) -> (x, l)
        Node(x, l, r) ->
            val (x', r') = del-max(r)
            (x', balance-right(x, l, r'))

pub fun combine(t1: tree<a>, t2: tree<a>, ?params): tree<a>
    if   t1.is-leaf         then t2
    elif t2.is-leaf         then t1
    elif t1.size > t2.size
    then val (x, l) = del-max(t1)   in balance-left(x,  l,  t2)
    else val (x, r) = split-min(t2) in balance-right(x, t1, r)

pub fun union(t1 : tree<a>, t2 : tree<a>, ?cmp : (a, a) -> e order, ?params : params) : e tree<a>
    t1.list.foldl(t2, insert'(_, _))

pub fun union-with(
    t1 : tree<a>, t2 : tree<a>,
    f  : (left : a, right : a) -> e a,
    ?cmp : (a, a) -> e order, ?params : params
) : e tree<a>
    t2.list.foldl(t1) fn(z, x) insert-with(x, z, f)

pub fun delete(x, tree, ?cmp, ?params)
    match tree
        Leaf -> Leaf
        Node(y, l, r) -> match cmp(x, y)
            Lt -> balance-left(y, delete(x, l), r)
            Gt -> balance-right(y, l, delete(x, r))
            Eq -> combine(l, r)

pub fun list(tree)
    fun go(t, acc) match t
        Leaf -> acc
        Node(x, l, r) -> go(l, Cons(x, go(r, acc)))
    go(tree, Nil)

pub fun list/tree(xs, ?cmp, ?params)
    xs.foldl(Leaf) fn(z, x)
        x.insert(z)

pub fun height(tree)
    match tree
        Leaf -> 0
        Node(left=l, right=r) -> 1 + max(l.height, r.height)

// balanced1R :: Rational -> Tree a -> Tree a -> Bool
// balanced1R d t1 t2 = fromInteger (size1 t1) <= d * fromInteger (size1 t2)
//
// -- | Isabelle: @WBT0.wbt@ (dengan <Delta> real).
// validR :: Rational -> Tree a -> Bool
// validR _ Leaf = True
// validR d (Node l _ _ r) =
//   balanced1R d l r && balanced1R d r l && validR d l && validR d r
//
// -- | <alpha> = 1/(<Delta>+1)
// alpha :: Rational -> Rational
// alpha d = 1 / (d + 1)
//
// -- | Batas atas tinggi: log2(size1 t) / log2(1 + 1/<Delta>).
// heightBound :: Rational -> Tree a -> Double
// heightBound d t =
//   logBase 2 (fromInteger (size1 t)) / logBase 2 (1 + 1 / fromRational d)

pub fun is-complete(tree)
    match tree
        Leaf -> True
        Node(left=l, right=r) -> l.height == r.height && l.is-complete && r.is-complete

pub fun map-monotonic(tree, f)
    match tree
        Leaf -> Leaf
        Node(x, l, r, s) -> Node(f(x), l.map-monotonic(f), r.map-monotonic(f), s)

pub fun maximum(tree : tree<a>) : maybe<a>
    tree.list.last

pub fun minimum(tree : tree<a>) : maybe<a>
    tree.list.head

pub fun find-lt(tree : tree<a>, x : b, ?cmp : (a, b) -> e order) : e maybe<a>
    match tree
        Leaf -> Nothing
        Node(a, l, r) ->
            if a < x
            then find-lt(r, x) || Just(a)
            else find-lt(l, x)

pub fun find-le(tree : tree<a>, x : b, ?cmp : (a, b) -> e order) : e maybe<a>
    match tree
        Leaf -> Nothing
        Node(a, l, r) ->
            if a <= x
            then find-lt(r, x) || Just(a)
            else find-lt(l, x)

pub fun find-gt(tree : tree<a>, x : b, ?cmp : (a, b) -> e order) : e maybe<a>
    match tree
        Leaf -> Nothing
        Node(a, l, r) ->
            if a > x
            then find-gt(l, x) || Just(a)
            else find-gt(r, x)

pub fun find-ge(tree : tree<a>, x : b, ?cmp : (a, b) -> e order) : e maybe<a>
    match tree
        Leaf -> Nothing
        Node(a, l, r) ->
            if a >= x
            then find-gt(l, x) || Just(a)
            else find-gt(r, x)

pub fun is-empty(t : tree<a>) : bool
    t.is-leaf

// Heterogenous Eq and Ord

// Generic heterogenous inequality
fun default/het/(!=)(x : a, y : b, ?(==) : (a, b) -> e bool ) : e bool
  not(x==y)

// Generic heterogenous equality if `cmp` exists
fun default/het/(==)(x : a, y : b, ?cmp : (a, b) -> e order ) : e bool
  match cmp(x,y)
    Eq -> True
    _  -> False

// Generic heterogenous greater than
fun default/het/(>)(x : a, y : b, ?cmp : (a, b) -> e order ) : e bool
  cmp(x,y) == Gt

// Generic heterogenous lower than
fun default/het/(<)(x : a, y : b, ?cmp : (a, b) -> e order ) : e bool
  cmp(x,y) == Lt

// Generic heterogenous greater than or equal
fun default/het/(>=)(x : a, y : b, ?cmp : (a, b) -> e order ) : e bool
  not(x < y)

// Generic heterogenous lower than or equal
fun default/het/(<=)(x : a, y : b, ?cmp : (a, b) -> e order ) : e bool
  not(x > y)

fun either/cmp(
    e1 : either<a, b>,
    e2 : either<a, b>,
    ?a/cmp : (a, a) -> e order,
    ?b/cmp : (b, b) -> e order
) : e maybe<order>
    match (e1, e2)
        (Left(x),  Left(y))  -> Just(cmp(x, y))
        (Right(x), Right(y)) -> Just(cmp(x, y))
        _ -> Nothing
