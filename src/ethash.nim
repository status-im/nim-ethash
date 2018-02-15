# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import  math, sequtils,
        number_theory, # Not on nimble yet: https://github.com/numforge/number-theory
        keccak_tiny,
        zero_functional

import  ./private/[primes, bytes]

# TODO: Switching from default int to uint64
# Note: array/seq indexing requires an Ordinal, uint64 are not.
# So to index arrays/seq we would need to cast uint64 to int anyway ...

# ###############################################################################
# Definitions

const
  WORD_BYTES = 4                    # bytes in word
  DATASET_BYTES_INIT = 2^30         # bytes in dataset at genesis
  DATASET_BYTES_GROWTH = 2^23       # dataset growth per epoch
  CACHE_BYTES_INIT = 2^24           # bytes in cache at genesis
  CACHE_BYTES_GROWTH = 2^17         # cache growth per epoch
  CACHE_MULTIPLIER=1024             # Size of the DAG relative to the cache
  EPOCH_LENGTH = 30000              # blocks per epoch
  MIX_BYTES = 128                   # width of mix
  HASH_BYTES = 64                   # hash length in bytes
  DATASET_PARENTS = 256             # number of parents of each dataset element
  CACHE_ROUNDS = 3                  # number of rounds in cache production
  ACCESSES = 64                     # number of accesses in hashimoto loop

# ###############################################################################
# Parameters

proc get_cache_size(block_number: Natural): int {.noSideEffect.}=
  result = CACHE_BYTES_INIT + CACHE_BYTES_GROWTH * (block_number div EPOCH_LENGTH)
  result -= HASH_BYTES
  while (let dm = divmod(result, HASH_BYTES);
          dm.rem == 0 and dm.quot.isPrime):
        # In a static lang, checking that the result of a division is prime
        # Means checking that reminder == 0 and quotient is prime
    result -= 2 * HASH_BYTES

proc get_full_size(block_number: Natural): int {.noSideEffect.}=
  result = DATASET_BYTES_INIT + DATASET_BYTES_GROWTH * (block_number div EPOCH_LENGTH)
  result -= MIX_BYTES
  while (let dm = divmod(result, MIX_BYTES);
          dm.rem == 0 and dm.quot.isPrime):
    result -= 2 * MIX_BYTES

# ###############################################################################
# Cache generation

proc mkcache(cache_size, seed: int): seq[Hash[512]] {.noSideEffect.}=

  let n = cache_size div HASH_BYTES

  # Sequentially produce the initial dataset
  result = newSeq[Hash[512]](n)
  result[0] = sha3_512 seed.asByteArray # TODO: spec is unclear if we interpret integers as array of bytes

  for i in 1 ..< n:
    result[i] = sha3_512 result[i-1].asByteArray

  # Use a low-round version of randmemohash
  for _ in 0 ..< CACHE_ROUNDS:
    for i in 0 ..< n:
      let
        v = asByteArray(result[i])[0].int mod n
        a = result[(i-1+n) mod n].asByteArray
        b = result[v].asByteArray
      result[i] = sha3_512 zip(a, b)-->map(it[0] xor it[1])

# ###############################################################################
# Data aggregation function

const FNV_PRIME = 0x01000193

proc fnv[T: SomeUnsignedInt or Natural](v1, v2: T): T =

  # Original formula is ((v1 * FNV_PRIME) xor v2) mod 2^32
  # However contrary to Python and depending on the type T,
  # in Nim (v1 * FNV_PRIME) can overflow
  # We can't do 2^32 with an int (only 2^32-1)
  # and in general (a xor b) mod c != (a mod c) xor (b mod c)
  #
  # Thankfully
  # We know that:
  #   - (a xor b) and c == (a and c) xor (b and c)
  #   - for powers of 2: a mod 2^p == a and (2^p - 1)
  #   - 2^32 - 1 == high(uint32)

  const mask: T = 2^32 - 1

  mulmod(v1 and mask, FNV_PRIME.T, (2^32).T) xor (v2 and mask)


# ###############################################################################
when isMainModule:
  echo get_full_size(100000)
  let a = sha3_512 1234.asByteArray

  echo a


  echo zip([0, 1, 2, 3], [10, 20, 30, 40]) --> map(it[0] * it[1]) # [0, 20, 60, 120]

  echo zip(a.asByteArray, a.asByteArray) --> map(it[0] xor it[1])