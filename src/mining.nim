# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import ./proof_of_work, ./private/conversion
import endians, random, math, nimcrypto

proc mulCarry(a, b: uint64): tuple[carry, unit: uint64] =
  ## Multiplication in extended precision
  ## Returns a tuple of carry and unit that satisfies
  ## a * b = carry * 2^64 + unit
  ##
  ## Note, we work in base 2^64
  ##   - 2^32 * 2^32 = 1 * 2^64 --> carry of 1
  ##   - 2^33 * 2^33 = 2^66 = 2^2 * 2^64 = 4 * 2^64 --> carry of 4
  ##
  ## This is similar in base 10 to
  ##   - 2 * 5 = 1 * 10 --> carry of 1
  ##   - 8 * 5 = 4 * 10 --> carry of 4

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
  let
    a_lo = a and hi32
    a_hi = a shr 32
    b_lo = b and hi32
    b_hi = b shr 32

  # Case 1: z0 = a_lo * b_lo
  # It cannot overflow
    z0 = a_lo * b_lo

  # Case 2: z1 = a_lo * b_hi + a_hi * b_lo
    lohi = a_lo * b_hi
    hilo = a_hi * b_lo
    z1 = lohi + hilo

  # Case 3: z2 = carry + a_hi * b_hi
    z2 = (z1 < lohi).uint64 + (a_hi * b_hi)

  # Finally
  # result.unit is always equal to (a * b) mod 2^64
  # result.carry is (a * b) div 2^64 (provided a and b < 2^64)
  result.unit = z1 shl 32
  result.unit += z0
  result.carry = (result.unit < z0).uint64 + z2 + z1 shr 32

proc isValid(nonce: uint64,
            difficulty: uint64,
            full_size: Natural,
            dataset: seq[MDigest[512]],
            header: MDigest[256]): bool {.noSideEffect.}=
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
  # We multiply the lowest power, keep track of the carry
  # Multiply next power, add the previous carry, get a new carry
  # We check if the very last carry is 0

  # First we convert the Hash[256] to an array of 4 uint64 and then
  # only consider the most significant
  let hash_qwords = cast[ptr array[4, uint64]](candidate_hash.value.unsafeAddr)
  var
    unit = 0'u64
    carry = 0'u64

  template doMulCarry() =
    let prev_carry = carry
    (carry, unit) = mulCarry(difficulty, hash_qwords[i])

    # Add the previous carry, if it overflows add one to the next carry
    unit += prev_carry
    carry += (unit < prev_carry).uint64

  when system.cpuEndian == littleEndian:
    for i in countdown(3, 0):
      {.unroll: 4.}
      doMulCarry()

  else:
    for i in 0 .. 3:
      {.unroll: 4.}
      doMulCarry()

  result = carry == 0

# const High_uint64 = not 0'u64 # TODO: Nim random does not work on uint64 range.

proc mine*(full_size: Natural, dataset: seq[MDigest[512]], header: MDigest[256], difficulty: uint64): uint64 =
  # Returns a valid nonce

  randomize()                       # Start with a completely random seed
  result = uint64 rand(high(int))   # TODO: Nim rand does not work on uint64 range.

  while not result.isValid(difficulty, full_size, dataset, header):
    inc(result) # we rely on uint overflow (mod 2^64) here.
