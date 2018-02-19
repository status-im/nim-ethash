# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import keccak_tiny

type U512* = array[8, uint64]
  ## A very simple type alias to `xor` Hash[512] with normal integers
  ## and be able to do sha3_512 which only accepts arrays

proc toU512*(x: Natural): U512 {.inline, noSideEffect.}=
  when system.cpuEndian == littleEndian:
    result[0] = x.uint64
  else:
    result[result.high] = x.uint64

proc toU512*(x: Hash[512]): U512 {.inline, noSideEffect, noInit.}=
  cast[type result](x)

proc `xor`*(x, y: U512): U512 {.inline, noSideEffect, noInit.}=
  for i in 0 ..< result.len:
    {.unroll: 8.}
    result[i] = x[i] xor y[i]

proc toHash512*(x: U512): Hash[512] {.inline, noSideEffect, noInit.}=
  cast[type result](x)

# proc asByteArray*[T: not (ref|ptr|string)](data: T): array[sizeof(T), byte] =
#   ## Cast stack allocated types to an array of byte
#   cast[type result](data)

# proc asByteArray*(data: Hash[512]): array[64, byte] =
#   ## Workaround: Nim cannot evaluate size of arrays
#   ## https://github.com/nim-lang/Nim/issues/5802
#   cast[type result](data)