# GPLv3 license
# Nim wrapper for libethash
# As this is linking to GPLv3, do not use in production

{.compile: "internal.c".}
{.compile: "sha3.c".}
{.compile: "io_posix.c".}
{.compile: "io.c".}

const
  ETHASH_REVISION* = 23
  ETHASH_DATASET_BYTES_INIT* = 1073741824
  ETHASH_DATASET_BYTES_GROWTH* = 8388608
  ETHASH_CACHE_BYTES_INIT* = 1073741824
  ETHASH_CACHE_BYTES_GROWTH* = 131072
  ETHASH_EPOCH_LENGTH* = 30000
  ETHASH_MIX_BYTES* = 128
  ETHASH_HASH_BYTES* = 64
  ETHASH_DATASET_PARENTS* = 256
  ETHASH_CACHE_ROUNDS* = 3
  ETHASH_ACCESSES* = 64
  ETHASH_DAG_MAGIC_NUM_SIZE* = 8
  ETHASH_DAG_MAGIC_NUM* = 0xFEE1DEADBADDCAFE'i64

const
  ENABLE_SSE* = 0

const
  NODE_WORDS* = (64 div 4)
  MIX_WORDS* = (ETHASH_MIX_BYTES div 4)
  MIX_NODES* = (MIX_WORDS div NODE_WORDS)

type
  ethash_h256_t* {.bycopy.} = object
    b*: array[32, uint8]
  node* {.bycopy, importc.} = object {.union.}
    bytes*{.importc.}: array[NODE_WORDS * 4, uint8]
    words*{.importc.}: array[NODE_WORDS, uint32]
    double_words*{.importc.}: array[NODE_WORDS div 2, uint64]

  ethash_callback_t* {.importc.}= proc (a2: cuint): cint
  ethash_return_value_t* {.bycopy.} = object
    result*: ethash_h256_t
    mix_hash*: ethash_h256_t
    success*: bool

  ethash_light* {.bycopy.} = object
    cache*: pointer
    cache_size*: uint64
    block_number*: uint64

  ethash_light_t {.importc.}= ptr ethash_light

  ethash_full* {.bycopy.} = object
    file*{.importc.}: ptr FILE
    file_size*{.importc.}: uint64
    data*{.importc.}: ptr node

  ethash_full_t {.importc.}= ptr ethash_full

proc ethash_h256_get*(hash: ptr ethash_h256_t; i: cuint): uint8 {.inline, importc.} =
  return hash.b[i]

proc ethash_h256_set*(hash: ptr ethash_h256_t; i: cuint; v: uint8) {.inline, importc.} =
  hash.b[i] = v

proc ethash_h256_reset*(hash: ptr ethash_h256_t) {.inline, importc.} =
  hash[] = ethash_h256_t()

## *
##   Difficulty quick check for POW preverification
## 
##  @param header_hash      The hash of the header
##  @param nonce            The block's nonce
##  @param mix_hash         The mix digest hash
##  @param boundary         The boundary is defined as (2^256 / difficulty)
##  @return                 true for succesful pre-verification and false otherwise
## 

proc ethash_quick_check_difficulty*(header_hash: ptr ethash_h256_t; nonce: uint64;
                                   mix_hash: ptr ethash_h256_t;
                                   boundary: ptr ethash_h256_t): bool {.importc.}

## *
##  Allocate and initialize a new ethash_light handler. Internal version
## 
##  @param cache_size    The size of the cache in bytes
##  @param seed          Block seedhash to be used during the computation of the
##                       cache nodes
##  @return              Newly allocated ethash_light handler or NULL in case of
##                       ERRNOMEM or invalid parameters used for @ref ethash_compute_cache_nodes()
## 

proc ethash_light_new_internal*(cache_size: uint64; seed: ptr ethash_h256_t): ethash_light_t {.importc.}
## *
##  Calculate the light client data. Internal version.
## 
##  @param light          The light client handler
##  @param full_size      The size of the full data in bytes.
##  @param header_hash    The header hash to pack into the mix
##  @param nonce          The nonce to pack into the mix
##  @return               The resulting hash.
## 

proc ethash_light_new*(block_number: uint64): ethash_light_t {.importc.}

proc ethash_light_compute_internal*(light: ethash_light_t; full_size: uint64;
                                   header_hash: ethash_h256_t; nonce: uint64): ethash_return_value_t {.importc.}

## *
##  Allocate and initialize a new ethash_full handler. Internal version.
## 
##  @param dirname        The directory in which to put the DAG file.
##  @param seedhash       The seed hash of the block. Used in the DAG file naming.
##  @param full_size      The size of the full data in bytes.
##  @param cache          A cache object to use that was allocated with @ref ethash_cache_new().
##                        Iff this function succeeds the ethash_full_t will take memory
##                        memory ownership of the cache and free it at deletion. If
##                        not then the user still has to handle freeing of the cache himself.
##  @param callback       A callback function with signature of @ref ethash_callback_t
##                        It accepts an unsigned with which a progress of DAG calculation
##                        can be displayed. If all goes well the callback should return 0.
##                        If a non-zero value is returned then DAG generation will stop.
##  @return               Newly allocated ethash_full handler or NULL in case of
##                        ERRNOMEM or invalid parameters used for @ref ethash_compute_full_data()
## 

proc ethash_full_new_internal*(dirname: cstring; seed_hash: ethash_h256_t;
                              full_size: uint64; light: ethash_light_t;
                              callback: ethash_callback_t): ethash_full_t {.importc.}
proc ethash_calculate_dag_item*(ret: ptr node; node_index: uint32;
                               cache: ethash_light_t){.importc.}
proc ethash_quick_hash*(return_hash: ptr ethash_h256_t;
                       header_hash: ptr ethash_h256_t; nonce: uint64;
                       mix_hash: ptr ethash_h256_t){.importc.}
proc ethash_get_datasize*(block_number: uint64): uint64 {.importc.}
proc ethash_get_cachesize*(block_number: uint64): uint64 {.importc.}
## *
##  Compute the memory data for a full node's memory
## 
##  @param mem         A pointer to an ethash full's memory
##  @param full_size   The size of the full data in bytes
##  @param cache       A cache object to use in the calculation
##  @param callback    The callback function. Check @ref ethash_full_new() for details.
##  @return            true if all went fine and false for invalid parameters
## 

proc ethash_compute_full_data*(mem: pointer; full_size: uint64;
                              light: ethash_light_t; callback: ethash_callback_t): bool {.importc.}