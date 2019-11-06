# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import  math, endians,
        nimcrypto

import  ./private/[primes, conversion, functional, intmath]
export toHex, hexToByteArrayBE, hexToSeqBytesBE, toByteArrayBE # debug functions

# ###############################################################################
# Definitions

const
  REVISION* = 23                     # Based on spec revision 23
  WORD_BYTES = 4                     # bytes in word - in Nim we use 64 bits words # TODO check that
  DATASET_BYTES_INIT* = 2'u64^30       # bytes in dataset at genesis
  DATASET_BYTES_GROWTH* = 2'u64^23     # dataset growth per epoch
  CACHE_BYTES_INIT* = 2'u64^24         # bytes in cache at genesis
  CACHE_BYTES_GROWTH* = 2'u64^17       # cache growth per epoch
  CACHE_MULTIPLIER = 1024            # Size of the DAG relative to the cache
  EPOCH_LENGTH* = 30000              # blocks per epoch
  MIX_BYTES* = 128                   # width of mix
  HASH_BYTES* = 64                   # hash length in bytes
  DATASET_PARENTS* = 256             # number of parents of each dataset element
  CACHE_ROUNDS* = 3                  # number of rounds in cache production
  ACCESSES* = 64                     # number of accesses in hashimoto loop

# ###############################################################################
# Parameters

proc get_cache_size*(block_number: uint64): uint64 {.noSideEffect.}=
  result = CACHE_BYTES_INIT + CACHE_BYTES_GROWTH * (block_number div EPOCH_LENGTH)
  result -= HASH_BYTES
  while (let dm = divmod(result, HASH_BYTES);
        dm.rem == 0 and not dm.quot.isPrime):
        # In a static lang, checking that the result of a division is prime
        # means checking that remainder == 0 and quotient is prime
    result -= 2 * HASH_BYTES

proc get_data_size*(block_number: uint64): uint64 {.noSideEffect.}=
  result = DATASET_BYTES_INIT + DATASET_BYTES_GROWTH * (block_number div EPOCH_LENGTH)
  result -= MIX_BYTES
  while (let dm = divmod(result, MIX_BYTES);
        dm.rem == 0 and not dm.quot.isPrime):
    result -= 2 * MIX_BYTES

# ###############################################################################
# Fetch from lookup tables of 2048 epochs of data sizes and cache sizes
import ./data_sizes

proc get_datasize_lut*(block_number: Natural): uint64 {.noSideEffect, inline.} =
  data_sizes[block_number div EPOCH_LENGTH]

proc get_cachesize_lut*(block_number: Natural): uint64 {.noSideEffect, inline.} =
  cache_sizes[block_number div EPOCH_LENGTH]

# ###############################################################################
# Cache generation

proc mkcache*(cache_size: uint64, seed: MDigest[256]): seq[MDigest[512]] {.noSideEffect.}=

  # Cache size
  let n = int(cache_size div HASH_BYTES)

  # Sequentially produce the initial dataset
  result = newSeq[MDigest[512]](n)
  result[0] = keccak512.digest seed.data

  for i in 1 ..< n:
    result[i] = keccak512.digest result[i-1].data

  # Use a low-round version of randmemohash
  for _ in 0 ..< CACHE_ROUNDS:
    for i in 0 ..< n:
      let
        v = result[i].as_u32_words[0] mod n.uint32
        a = result[(i-1+n) mod n].data
        b = result[v.int].data
      result[i] = keccak512.digest zipMap(a, b, x xor y)

# ###############################################################################
# Data aggregation function

const FNV_PRIME = 0x01000193

proc fnv*[T: SomeUnsignedInt or Natural](v1, v2: T): uint32 {.inline, noSideEffect.}=

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

  # So casting to uint32 should do the modulo and masking just fine

  (v1.uint32 * FNV_PRIME) xor v2.uint32

# ###############################################################################
# Full dataset calculation

proc calc_dataset_item*(cache: seq[MDigest[512]], i: Natural): MDigest[512] {.noSideEffect, noInit.} =
  let n = cache.len
  const r: uint32 = HASH_BYTES div WORD_BYTES

  # Alias for the result value. Interpreted as an array of uint32 words
  var mix = cast[ptr array[16, uint32]](addr result)

  mix[] = cache[i mod n].as_u32_words
  when system.cpuEndian == littleEndian:
    mix[0] = mix[0] xor i.uint32
  else:
    mix[high(mix)] = mix[high(mix)] xor i.uint32
  result = keccak512.digest result.data

  # FNV with a lots of random cache nodes based on i
  for j in 0'u32 ..< DATASET_PARENTS:
    let cacheIndex = fnv(i.uint32 xor j, mix[j mod r])
    mix[] = zipMap(mix[], cache[int(cacheIndex mod n.uint32)].as_u32_words, fnv(x, y))

  result = keccak512.digest result.data

when defined(openmp):
  # Remove stacktraces when using OpenMP, heap alloc from strings will crash.
  {.push stacktrace: off.}
proc calc_dataset*(full_size: Natural, cache: seq[MDigest[512]]): seq[MDigest[512]] =

  result = newSeq[MDigest[512]](full_size div HASH_BYTES)
  for i in `||`(0, result.len - 1, "simd"):
    # OpenMP parallel loop
    result[i] = calc_dataset_item(cache, i)

when defined(openmp):
  # Remove stacktraces when using OpenMP, heap alloc from strings will crash.
  {.pop.}

# ###############################################################################
# Main loop

type HashimotoHash = tuple[mix_digest, value: MDigest[256]]

template hashimoto(header: MDigest[256],
              nonce: uint64,
              full_size: Natural,
              dataset_lookup_p: untyped,
              dataset_lookup_p1: untyped,
              result: var HashimotoHash
              ) =
  let
    n = uint32 full_size div HASH_BYTES
    w = uint32 MIX_BYTES div WORD_BYTES
    mixhashes = uint32 MIX_BYTES div HASH_BYTES

  assert full_size mod HASH_BYTES == 0
  assert MIX_BYTES mod HASH_BYTES == 0

  # combine header+nonce into a 64 byte seed
  {.pragma: align64, codegenDecl: "$# $# __attribute__((aligned(64)))".}
  var s{.align64, noInit.}: MDigest[512]
  let s_bytes = cast[ptr array[64, byte]](addr s)   # Alias to interpret s as a byte array
  let s_words = cast[ptr array[16, uint32]](addr s) # Alias to interpret s as an uint32 array

  s_bytes[][0..<32] = header.data                   # We first populate the first 40 bytes of s with the concatenation
                                                    # In template we need to dereference first otherwise it's not considered as var

  var nonceLE{.noInit.}: array[8, byte]             # the nonce should be concatenated with its LITTLE ENDIAN representation
  littleEndian64(addr nonceLE, unsafeAddr nonce)
  s_bytes[][32..<40] = nonceLE

  s = keccak_512.digest s_bytes[][0..<40]           # TODO: Does this slicing allocate a seq?

  # start the mix with replicated s
  assert MIX_BYTES div HASH_BYTES == 2
  var mix{.align64, noInit.}: array[32, uint32]
  mix[0..<16] = s_words[]
  mix[16..<32] = s_words[]

  # mix in random dataset nodes
  for i in 0'u32 ..< ACCESSES:
    let p{.inject.} = fnv(i xor s_words[0], mix[i mod w]) mod (n div mixhashes) * mixhashes
    let p1{.inject.} = p + 1

    # Unrolled: for j in range(MIX_BYTES / HASH_BYTES): => for j in 0 ..< 2
    var newdata{.noInit.}: type mix
    newdata[0..<16] = cast[array[16, uint32]](dataset_lookup_p)
    newdata[16..<32] = cast[array[16, uint32]](dataset_lookup_p1)

    mix = zipMap(mix, newdata, fnv(x, y))

  # compress mix
  # ⚠⚠ Warning ⚠⚠: Another bigEndian littleEndian issue?
  # It doesn't seem like the uint32 in cmix need to be changed to big endian
  # cmix is an alias to the result.mix_digest
  let cmix = cast[ptr array[8, uint32]](addr result.mix_digest)
  for i in countup(0, mix.len - 1, 4):
    cmix[i div 4] = mix[i].fnv(mix[i+1]).fnv(mix[i+2]).fnv(mix[i+3])

  var concat{.noInit.}: array[64 + 32, byte]
  concat[0..<64] = s_bytes[]
  concat[64..<96] = cast[array[32, byte]](result.mix_digest)
  result.value = keccak_256.digest concat

proc hashimoto_light*(full_size:Natural, cache: seq[MDigest[512]],
                      header: MDigest[256], nonce: uint64): HashimotoHash {.noSideEffect.} =

  hashimoto(header,
            nonce,
            full_size,
            calc_data_set_item(cache, p),
            calc_data_set_item(cache, p1),
            result)

proc hashimoto_full*(full_size:Natural, dataset: seq[MDigest[512]],
                    header: MDigest[256], nonce: uint64): HashimotoHash {.noSideEffect.} =
  # TODO spec mentions full_size but I don't think we need it (retrieve it from dataset.len)
  hashimoto(header,
            nonce,
            full_size,
            dataset[int(p)],
            dataset[int(p1)],
            result)
# ###############################################################################
# Defining the seed hash

proc get_seedhash*(block_number: uint64): MDigest[256] {.noSideEffect.} =
  for i in 0 ..< int(block_number div EPOCH_LENGTH):
    result = keccak256.digest result.data
