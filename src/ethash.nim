# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import  math, sequtils, algorithm,
        keccak_tiny

import  ./private/[primes, casting, functional, intmath]
export toHex, hexToByteArrayBE, hexToSeqBytesBE, toByteArrayBE
export keccak_tiny

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

proc mkcache*(cache_size: uint64, seed: Hash[256]): seq[Hash[512]] {.noSideEffect.}=

  # The starting cache size is a set of 524288 64-byte values

  let n = int(cache_size div HASH_BYTES)

  # Sequentially produce the initial dataset
  result = newSeq[Hash[512]](n)
  result[0] = keccak512 seed.toByteArrayBE

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

proc calc_dataset_item*(cache: seq[Hash[512]], i: Natural): Hash[512] {.noSideEffect, noInit.} =
  # TODO review WORD_BYTES
  # TODO use uint32 instead of uint64
  # and mix[0] should be uint32

  let n = cache.len
  const r: uint32 = HASH_BYTES div WORD_BYTES

  var mix = cast[U512](cache[i mod n])
  when system.cpuEndian == littleEndian:
    mix[0] = mix[0] xor i.uint32
  else:
    mix[high(mix)] = mix[high(0)] xor i.uint32
  mix = toU512 keccak512 mix

  # FNV with a lots of random cache nodes based on i
  for j in 0'u32 ..< DATASET_PARENTS:
    let cache_index = fnv(i.uint32 xor j, mix[j mod r])
    mix = zipMap(mix, cache[cache_index.int mod n].toU512, fnv(x, y))

  result = keccak512 mix

proc calc_dataset*(full_size: Natural, cache: seq[Hash[512]]): seq[Hash[512]] {.noSideEffect.} =

  result = newSeq[Hash[512]](full_size div HASH_BYTES)

  for i, hash in result.mpairs:
    hash = calc_dataset_item(cache, i)

# ###############################################################################
# Main loop

type HashimotoHash = tuple[mix_digest: Hash[256], value: Hash[256]]
  # TODO use Hash as a result type
type DatasetLookup = proc(i: Natural): Hash[512] {.noSideEffect.}

proc hashimoto(header: Hash[256],
              nonce: uint64,
              full_size: Natural,
              dataset_lookup: DatasetLookup
              ): HashimotoHash {.noInit, noSideEffect.}=
  let
    n = uint32 full_size div HASH_BYTES
    w = uint32 MIX_BYTES div WORD_BYTES
    mixhashes = uint32 MIX_BYTES div HASH_BYTES

  assert full_size mod HASH_BYTES == 0
  assert MIX_BYTES mod HASH_BYTES == 0

  # combine header+nonce into a 64 byte seed
  var s{.noInit.}: Hash[512]
  let s_bytes = cast[ptr array[64, byte]](addr s)   # Alias for to interpret s as a byte array
  let s_words = cast[ptr array[16, uint32]](addr s) # Alias for to interpret s as an uint32 array

  s_bytes[0..<32] = header.toByteArrayBE            # We first populate the first 40 bytes of s with the concatenation
  s_bytes[32..<40] = nonce.toByteArrayBE

  s = keccak_512 s_bytes[0..<40]                    # TODO: Does this allocate a seq?

  # start the mix with replicated s
  assert MIX_BYTES div HASH_BYTES == 2
  var mix{.noInit.}: array[32, uint32]
  mix[0..<16] = s_words[]
  mix[16..<32] = s_words[]

  # mix in random dataset nodes
  for i in 0'u32 ..< ACCESSES:
    let p = fnv(i xor s_words[0], mix[i mod w]) mod (n div mixhashes) * mixhashes

    # Unrolled: for j in range(MIX_BYTES / HASH_BYTES): => for j in 0 ..< 2
    var newdata{.noInit.}: type mix
    newdata[0..<16] = cast[array[16, uint32]](dataset_lookup(p))
    newdata[16..<32] = cast[array[16, uint32]](dataset_lookup(p+1))

    mix = zipMap(mix, newdata, fnv(x, y))

  # compress mix
  var cmix{.noInit.}: array[8, uint32]
  for i in countup(0, mix.len - 1, 4):
    cmix[i div 4] = mix[i].fnv(mix[i+1]).fnv(mix[i+2]).fnv(mix[i+3])

  # result.mix_digest = cast[Hash[256]](
  #   mapArray(cmix, x.toByteArrayBE) # Each uint32 must be changed to Big endian
  #   )
  result.mix_digest = cast[Hash[256]](cmix)

  var concat{.noInit.}: array[64 + 32, byte]
  concat[0..<64] = s_bytes[]
  concat[64..<96] = cast[array[32, byte]](cmix)
  result.value = keccak_256(concat)

proc hashimoto_light*(full_size:Natural, cache: seq[Hash[512]],
                      header: Hash[256], nonce: uint64): HashimotoHash {.noSideEffect, inline.} =

  let light: DatasetLookup = proc(x: Natural): Hash[512] = calc_data_set_item(cache, x)
  hashimoto(header,
            nonce,
            full_size,
            light)

proc hashimoto_full*(full_size:Natural, dataset: seq[Hash[512]],
                    header: Hash[256], nonce: uint64): HashimotoHash {.noSideEffect, inline.} =
  # TODO spec mentions full_size but I don't think we need it (retrieve it from dataset.len)
  let full: DatasetLookup = proc(x: Natural): Hash[512] = dataset[x]
  hashimoto(header,
            nonce,
            full_size,
            full)

# ###############################################################################
# Defining the seed hash

proc get_seedhash*(block_number: uint64): Hash[256] {.noSideEffect.} =
  # uint64 are not Ordinal :/
  for i in 0 ..< int(block_number div EPOCH_LENGTH):
    result = keccak256 result.toByteArrayBE