# From https://github.com/numforge/number-theory/
# MIT Licence
# Copyright (c) 2016 Mamy Ratsimbazafy

# ########### Number of bits to represent a number

# Compiler defined const: https://github.com/nim-lang/Nim/wiki/Consts-defined-by-the-compiler
const withBuiltins = defined(gcc) or defined(clang)

when withBuiltins:
  when not defined(windows):
    proc builtin_clz(n: cuint): cint {.importc: "__builtin_clz", nodecl.}
    proc builtin_clz(n: culong): cint {.importc: "__builtin_clzl", nodecl.}
    proc builtin_clz(n: culonglong): cint {.importc: "__builtin_clzll", nodecl.}
    type TbuiltinSupported = cuint or culong or culonglong
      ## Count Leading Zero with optimized builtins routines from GCC/Clang
      ## Warning ⚠: if n = 0, clz is undefined
  else:
    proc builtin_clz(n: culong): cint {.importc: "__builtin_clzl", nodecl.}
    proc builtin_clz(n: culonglong): cint {.importc: "__builtin_clzll", nodecl.}
    type TbuiltinSupported = culong or culonglong

proc bit_length*[T: SomeInteger](n: T): T =
  ## Calculates how many bits are necessary to represent the number

  when withBuiltins and T is TbuiltinSupported:
    result = if n == T(0): 0                    # Removing this branch would make divmod 4x faster :/
             else: T.sizeof * 8 - builtin_clz(n)

  else:
    var x = n
    while x != T(0):
      x = x shr 1
      inc(result)

# ########### Integer math

proc isqrt*[T: SomeInteger](n: T):  T =
  ## Integer square root, return the biggest squarable number under n
  ## Computation via Newton method
  result = n
  var y = (2.T shl ((n.bit_length() + 1) shr 1)) - 1
  while y < result:
    result = y
    y = (result + n div result) shr 1


# ############ Efficient divmod

type
  ldiv_t {.bycopy, importc: "ldiv_t", header:"<stdlib.h>".} = object
    quot: clong               ##  quotient
    rem: clong                ##  remainder

  lldiv_t {.bycopy, importc: "lldiv_t", header:"<stdlib.h>".} = object
    quot: clonglong
    rem: clonglong

proc ldiv(a, b: clong): ldiv_t {.importc: "ldiv", header: "<stdlib.h>".}
proc lldiv(a, b: clonglong): lldiv_t {.importc: "lldiv", header: "<stdlib.h>".}

proc divmod*(a, b: int32): tuple[quot, rem: clong] {.inline, noSideEffect, noInit.}=
  ## Compute quotient and reminder of integer division in a single intrinsics operation
  # TODO: changing clong to int32 poses an issue for some reason
  cast[type result](ldiv(a,b))

proc divmod*(a, b: int64): tuple[quot, rem: int64] {.inline, noSideEffect, noInit.}=
  ## Compute quotient and reminder of integer division in a single intrinsicsoperation
  cast[type result](lldiv(a,b))

proc divmod*[T: SomeUnsignedInt](a, b: T): tuple[quot, rem: T] {.inline, noSideEffect, noInit.}=
  # There is no single instruction for unsigned ints
  # Hopefully the compiler does its work properly
  (a div b, a mod b)
