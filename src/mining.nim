# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import ./proof_of_work, ./private/casting
import ttmath, random

let # NimVM cannot evaluate those at compile-time. So they are considered side-effects :/
  high_uint256 = 0.u256 - 1.u256
  half_max     = pow(2.u256, 255)

proc getBoundary(difficulty: uint64): UInt256 {.noInit, inline.} =

  # Boundary is 2^256/difficulty
  # We can't represent 2^256 as an uint256 so as a workaround we use:
  #
  # a mod b == (2 * a div 2) mod b
  #         == (2 * (a div 2) mod b) mod b
  #
  # if 2^256 mod b = 0: # b is even (and a power of two)
  #   result = 2^255 div (b div 2)
  # if 2^256 mod b != 0:
  #   result = high(uint256) div b

  # TODO: review/test

  let b = difficulty.u256
  let modulo = (2.u256 * (half_max mod b)) mod b

  if modulo == 0.u256:
    result = half_max div (b shr 1)
  else:
    result = high_uint256 div b

proc readUint256BE*(ba: ByteArrayBE[32]): UInt256 {.noSideEffect.}=
  ## Convert a big-endian array of Bytes to an UInt256 (in native host endianness)
  const N = 32
  for i in 0 ..< N:
    result = result shl 8 or ba[i].u256

proc isValid(nonce: uint64,
            boundary: UInt256,
            full_size: Natural,
            dataset: seq[Hash[512]],
            header: Hash[256]): bool {.noSideEffect.}=

  let candidate = hashimoto_full(full_size, dataset, header, nonce)
  result = readUint256BE(cast[ByteArrayBE[32]](candidate.value)) <= boundary

proc mine*(full_size: Natural, dataset: seq[Hash[512]], header: Hash[256], difficulty: uint64): uint64 =
  # Returns a valid nonce

  let target = difficulty.getBoundary
  randomize()                       # Start with a completely random seed
  result = uint64 random(high(int)) # TODO: Nim random does not work on uint64 range.
                                    #       Also random is deprecate and do not include the end of the range.

  while not result.isValid(target, full_size, dataset, header):
    inc(result) # we rely on uin overflow (mod 2^64) here.