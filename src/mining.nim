# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import ./proof_of_work, ./private/casting
import endians, random, math

proc willMulOverflow(a, b: uint64): bool {.noSideEffect.}=
  # Returns true if a * b overflows
  #         false otherwise

  # We assume a <= b
  if a > b:
    return willMulOverflow(b, a)

  # See https://en.wikipedia.org/wiki/Karatsuba_algorithm
  # For our representation, it is similar to school grade multiplication
  # Consider hi and lo as if they were digits
  # i.e.
  #      a = a_hi * 2^32 + a_lo
  #      b = b_hi * 2^32 + b_lo
  #
  #     15   b
  # X   12   a
  # ------
  #     10   lo*lo -> z0
  #     2    hi*lo -> z1
  #     5    lo*hi -> z1
  #    10    hi*hi -- z2
  # ------
  #    180

  const hi32 = high(uint32).uint64

  # Case 1: Check if a_hi != 0
  #   covers "a_hi * b_hi" and "a_hi * b_lo"
  if a > hi32:
    # both are bigger than 2^32 and will overflow
    # remember a < b
    return true

  # Case 2: check if a_lo * b_hi overflows
  # Note:
  #   - a_lo = a (no a_hi following case 1)
  #   - b_hi = b shr 32

  let z1 = a * (b shr 32)
  if z1 > hi32:
    return true

  # Lastly we add z1 and z0 while checking for overflow
  # Note: b_low = b and high(uint32)
  # We have mul(a, b) = z1 * 2^32 + z0

  # If a + b overflows, the result is lower than a
  let z0 = a * (b and hi32)
  let carry_test = z1 shl 32

  result = carry_test + z0 < carry_test

proc isValid(nonce: uint64,
            difficulty: uint64,
            full_size: Natural,
            dataset: seq[Hash[512]],
            header: Hash[256]): bool {.noSideEffect.}=
  # Boundary is 2^256/difficulty
  # A valid nonce will have: hashimoto < 2^256/difficulty
  # We can't represent 2^256 as an uint256 so as a workaround we use:
  # difficulty * hashimoto <= 2^256 - 1
  # i.e we only need to test that hashimoto * difficulty doesn't overflow uint256

  # First run the hashimoto with the candidate nonce
  let candidate_hash = hashimoto_full(full_size, dataset, header, nonce)

  # Now check if the multiplication of both would overflow

  # We are now in the following case in base 2^64 instead of base 10
  #   1234   hashimoto  1 * (2^64)^3 + 2 * (2^64)^2 + 3 * (2^64)^1 + 4
  # X    5   difficulty 5
  # ------
  # ......
  #
  # Overflow occurs only if "1 * 5" overflows 2^64

  # First we convert the Hash[256] to an array of 4 uint64 and then
  # only consider the most significant
  let hash_qwords = cast[array[4, uint64]](candidate_hash.value)
  var hi_hash: uint64

  when system.cpuEndian == littleEndian:
    littleEndian64(hi_hash.addr, hash_qwords[3].unsafeAddr)
  else:
    littleEndian64(hi_hash.addr, hash_qwords[0].unsafeAddr)

  result = not willMulOverflow(hi_hash, difficulty)

proc mine*(full_size: Natural, dataset: seq[Hash[512]], header: Hash[256], difficulty: uint64): uint64 =
  # Returns a valid nonce

  randomize()                       # Start with a completely random seed
  result = uint64 random(high(int)) # TODO: Nim random does not work on uint64 range.
                                    #       Also random is deprecate and do not include the end of the range.

  while not result.isValid(difficulty, full_size, dataset, header):
    inc(result) # we rely on uin overflow (mod 2^64) here.
