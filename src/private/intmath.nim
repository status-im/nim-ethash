# From https://github.com/numforge/number-theory/
# MIT Licence
# Copyright (c) 2016 Mamy Ratsimbazafy


proc isOdd*[T: SomeInteger](i: T): bool {.inline, noSideEffect.} =
  (i and 1.T) != 0

# ############

type
  ldiv_t {.bycopy, importc: "ldiv_t", header:"<stdlib.h>".} = object
    quot: clong               ##  quotient
    rem: clong                ##  remainder

  lldiv_t {.bycopy, importc: "lldiv_t", header:"<stdlib.h>".} = object
    quot: clonglong
    rem: clonglong

proc ldiv(a, b: clong): ldiv_t {.importc: "ldiv", header: "<stdlib.h>".}
proc lldiv(a, b: clonglong): lldiv_t {.importc: "lldiv", header: "<stdlib.h>".}

proc divmod*(a, b: int32): tuple[quot, rem: clong] {.inline.}=
  ## Compute quotient and reminder of integer division in a single intrinsics operation
  # TODO: changing clong to int32 poses an issue for some reason
  cast[type result](ldiv(a,b))

proc divmod*(a, b: int64): tuple[quot, rem: int64] {.inline.}=
  ## Compute quotient and reminder of integer division in a single intrinsicsoperation
  cast[type result](lldiv(a,b))

proc divmod*[T: SomeUnsignedInt](a, b: T): tuple[quot, rem: T] {.inline.}=
  # There is no single instruction for unsigned ints
  # Hopefully the compiler does its work properly
  (a div b, a mod b)

# ############

proc addmod*[T: SomeInteger](a, b, m: T): T =
  ## Modular addition

  let a_m = if a < m: a
            else: a mod m
  if b == 0.T:
    return a_m
  let b_m = if b < m: b
            else: b mod m

  # We don't do a + b to avoid overflows
  # But we know that m at least is inferior to biggest T

  let b_from_m = m - b_m
  if a_m >= b_from_m:
    return a_m - b_from_m
  return m - b_from_m + a_m

proc doublemod[T: SomeInteger](a, m: T): T {.inline.}=
  ## double a modulo m. assume a < m
  result = a
  if a >= m - a:
    result -= m
  result += a

proc mulmod*[T: SomeInteger](a, b, m: T): T =
  ## Modular multiplication

  var a_m = a mod m
  var b_m = b mod m
  if b_m > a_m:
    swap(a_m, b_m)
  while b_m > 0.T:
    if b_m.isOdd:
      result = addmod(result, a_m, m)
    a_m = doublemod(a_m, m)
    b_m = b_m shr 1