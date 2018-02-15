# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import  math, number_theory # https://github.com/numforge/number-theory

import  ./private/primes

# TODO: consider switching from default int to uint64
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


when isMainModule:
  echo get_full_size(100000)