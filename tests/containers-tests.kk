module tests/containers-tests

import containers/map
import containers/set

fun main()
  // Basic insert/delete/member/find tests against known values.
  var s := (empty : set<int>)
  s := s.insert(1)
  s := s.insert(2)
  s := s.insert(3)
  s := s.insert(2)
  val m = s.member(2)
  val sz = s.size
  val lt = s.find-lt(2)
  val le = s.find-le(2)
  val gt = s.find-gt(2)
  val ge = s.find-ge(2)
  val valid = s.is-valid
  val lst = s.list

  if m != True then (1 / 0).println
  if sz != 3 then (1 / 0).println
  if lt != Just(1) then (1 / 0).println
  if le != Just(2) then (1 / 0).println
  if gt != Just(3) then (1 / 0).println
  if ge != Just(2) then (1 / 0).println
  if valid != True then (1 / 0).println
  if lst != [1, 2, 3] then (1 / 0).println

  // delete
  val s2 = s.delete(2)
  if s2.member(2) != False then (1 / 0).println
  if s2.size != 2 then (1 / 0).println
  if s2.is-valid != True then (1 / 0).println

  // map: values mapped, keys and shape preserved
  val m : map<int, string> = [(3, "c"), (1, "a"), (2, "b")].of-list/map
  val m2 = m.map fn(v) v ++ "!"
  if m2.list != [(1, "a!"), (2, "b!"), (3, "c!")] then (1 / 0).println
  if m2.is-valid != True then (1 / 0).println
  val m3 = m.map-with-key fn(k, v) k.show ++ v
  if m3.list != [(1, "1a"), (2, "2b"), (3, "3c")] then (1 / 0).println
  val m4 = m.bimap fn(k, v) (k * 10, v)
  if m4.list != [(10, "a"), (20, "b"), (30, "c")] then (1 / 0).println

  println("all property tests passed")