# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import  math, sequtils, algorithm,
        keccak_tiny

import  ./private/[primes, casting, functional, intmath, concat]
export toHex, hexToSeqBytesBE

# TODO: Switching from default int to uint64
# Note: array/seq indexing requires an Ordinal, uint64 are not.
# So to index arrays/seq we would need to cast uint64 to int anyway ...

# ###############################################################################
# Definitions

const
  REVISION* = 23                     # Based on spec revision 23
  WORD_BYTES = 4                     # bytes in word - in Nim we use 64 bits words # TODO check that
  DATASET_BYTES_INIT* = 2'u^30       # bytes in dataset at genesis
  DATASET_BYTES_GROWTH* = 2'u^23     # dataset growth per epoch
  CACHE_BYTES_INIT* = 2'u^24         # bytes in cache at genesis
  CACHE_BYTES_GROWTH* = 2'u^17       # cache growth per epoch
  CACHE_MULTIPLIER=1024              # Size of the DAG relative to the cache
  EPOCH_LENGTH* = 30000              # blocks per epoch
  MIX_BYTES* = 128                   # width of mix
  HASH_BYTES* = 64                   # hash length in bytes
  DATASET_PARENTS* = 256             # number of parents of each dataset element
  CACHE_ROUNDS* = 3                  # number of rounds in cache production
  ACCESSES* = 64                     # number of accesses in hashimoto loop

  # MAGIC_NUM ?
  # MAGIC_NUM_SIZE ?

# ###############################################################################
# Parameters

proc get_cache_size*(block_number: uint): uint {.noSideEffect.}=
  result = CACHE_BYTES_INIT + CACHE_BYTES_GROWTH * (block_number div EPOCH_LENGTH)
  result -= HASH_BYTES
  while (let dm = divmod(result, HASH_BYTES);
        dm.rem == 0 and not dm.quot.isPrime):
        # In a static lang, checking that the result of a division is prime
        # Means checking that reminder == 0 and quotient is prime
    result -= 2 * HASH_BYTES

proc get_data_size*(block_number: uint): uint {.noSideEffect.}=
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

proc mkcache*(cache_size: int, seed: seq[byte]): seq[Hash[512]] {.noSideEffect.}=

  # The starting cache size is a set of 524288 64-byte values

  let n = cache_size div HASH_BYTES

  # Sequentially produce the initial dataset
  result = newSeq[Hash[512]](n)
  result[0] = keccak512 seed

  for i in 1 ..< n:
    result[i] = keccak512 result[i-1].toU512

  # Use a low-round version of randmemohash
  for _ in 0 ..< CACHE_ROUNDS:
    for i in 0 ..< n:
      let
        v = result[i].toU512[0] mod n.uint32
        a = result[(i-1+n) mod n].toU512
        b = result[v.int].toU512
      result[i] = keccak512 zipMap(a, b, x xor y)

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


  # # mulmod(v1 and mask, FNV_PRIME.T, (2^32).T) xor (v2 and mask)
  # Casting to uint32 should do the modulo and masking just fine

  (v1.uint32 * FNV_PRIME) xor v2.uint32

# ###############################################################################
# Full dataset calculation

proc calc_dataset_item(cache: seq[Hash[512]], i: Natural): Hash[512] {.noSideEffect, noInit.} =
  # TODO review WORD_BYTES
  # TODO use uint32 instead of uint64
  # and mix[0] should be uint32

  let n = cache.len
  const r = HASH_BYTES div WORD_BYTES

  # Initialize the mix, it's a reference to a cache item that we will modify in-place
  var mix = cast[ptr U512](unsafeAddr cache[i mod n])
  when system.cpuEndian == littleEndian:
    mix[0] = mix[0] xor i.uint32
  else:
    mix[high(mix)] = mix[high(0)] xor i.uint32
  mix[] = toU512 keccak512 mix[]

  # FNV with a lots of random cache nodes based on i
  # TODO: we use FNV with word size 64 bit while ethash implementation is using 32 bit words
  #       tests needed
  for j in 0'u32 ..< DATASET_PARENTS:
    let cache_index = fnv(i.uint32 xor j, mix[j mod r])
    mix[] = zipMap(mix[], cache[cache_index.int mod n].toU512, fnv(x, y))

  result = keccak512 mix[]

proc calc_dataset(full_size: Natural, cache: seq[Hash[512]]): seq[Hash[512]] {.noSideEffect.} =

  result = newSeq[Hash[512]](full_size div HASH_BYTES)

  for i, hash in result.mpairs:
    hash = calc_dataset_item(cache, i)

# ###############################################################################
# Main loop

type HashimotoHash = tuple[mix_digest: array[4, uint32], result: Hash[256]]
type DatasetLookup = proc(i: Natural): Hash[512] {.noSideEffect.}

proc initMix(s: U512): array[MIX_BYTES div HASH_BYTES * 512 div 32, uint32] {.noInit, noSideEffect,inline.}=

  # Create an array of size s copied (MIX_BYTES div HASH_BYTES) times
  # Array is flattened to uint32 words

  var mix: array[MIX_BYTES div HASH_BYTES, U512]
  mix.fill(s)

  result = cast[type result](mix)

proc hashimoto(header: Hash[256],
              nonce: uint64,
              fullsize: Natural,
              dataset_lookup: DatasetLookup
              ): HashimotoHash {.noInit, noSideEffect.}=
  let
    n = uint32 full_size div HASH_BYTES # check div operator, in spec it's Python true division
    w = uint32 MIX_BYTES div WORD_BYTES # TODO: review word bytes: uint32 vs uint64
    mixhashes = uint32 MIX_BYTES div HASH_BYTES
    # combine header+nonce into a 64 byte seed
    s = concat_hash(header, nonce).toU512

  # start the mix with replicated s
  var mix = initMix(s)

  # mix in random dataset nodes
  for i in 0'u32 ..< ACCESSES:
    let p = fnv(i xor s[0], mix[i mod w]) mod (n div mixhashes) * mixhashes
    var newdata{.noInit.}: type mix
    for j in 0'u32 ..< MIX_BYTES div HASH_BYTES:
      let dlu = dataset_lookup(p + j).toU512
      for k, val in dlu:
        newdata[j + k] = val
      mix = zipMap(mix, newdata, fnv(x, y))

  # compress mix (aka result.mix_digest)
  for i in 0 ..< 4:
    let idx = i*4
    result.mix_digest[i] = mix[idx].fnv(mix[idx+1]).fnv(mix[idx+2]).fnv(mix[idx+3])

  result.result = keccak256 concat_hash(s, result.mix_digest)


proc hashimoto_light(full_size:Natural, cache: seq[Hash[512]],
                    header: Hash[256], nonce: uint64): HashimotoHash {.noSideEffect, inline.} =

  let light: DatasetLookup = proc(x: Natural): Hash[512] = calc_data_set_item(cache, x)
  hashimoto(header,
            nonce,
            full_size,
            light)

proc hashimoto_full(full_size:Natural, dataset: seq[Hash[512]],
                    header: Hash[256], nonce: uint64): HashimotoHash {.noSideEffect, inline.} =

  let full: DatasetLookup = proc(x: Natural): Hash[512] = dataset[x]
  hashimoto(header,
            nonce,
            full_size,
            full)

# ###############################################################################
