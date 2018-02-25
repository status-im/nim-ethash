# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import keccak_tiny

type U512* = array[16, uint32]
  ## A very simple type alias to `xor` Hash[512] with normal integers
  ## and be able to do sha3_512 which only accepts arrays

  # TODO delete this

proc toU512*(x: Natural): U512 {.inline, noSideEffect.}=
  when system.cpuEndian == littleEndian:
    result[0] = x.uint32
  else:
    result[result.high] = x.uint32

proc toU512*(x: Hash[512]): U512 {.inline, noSideEffect, noInit.}=
  cast[type result](x)

proc `xor`*(x, y: U512): U512 {.inline, noSideEffect, noInit.}=
  for i in 0 ..< result.len:
    {.unroll: 4.}
    result[i] = x[i] xor y[i]

proc toHash512*(x: U512): Hash[512] {.inline, noSideEffect, noInit.}=
  cast[type result](x)


# ### Hex conversion


type ByteArrayBE*[N: static[int]] = array[N, byte]
  ## A byte array that stores bytes in big-endian order

proc readHexChar(c: char): byte {.noSideEffect.}=
  ## Converts an hex char to a byte
  case c
  of '0'..'9': result = byte(ord(c) - ord('0'))
  of 'a'..'f': result = byte(ord(c) - ord('a') + 10)
  of 'A'..'F': result = byte(ord(c) - ord('A') + 10)
  else:
    raise newException(ValueError, $c & "is not a hexademical character")

proc hexToByteArrayBE*[N: static[int]](hexStr: string): ByteArrayBE[N] {.noSideEffect, noInit.}=
  ## Read an hex string and store it in a Byte Array in Big-Endian order
  var i = 0
  if hexStr[i] == '0' and (hexStr[i+1] == 'x' or hexStr[i+1] == 'X'):
    inc(i, 2) # Ignore 0x and 0X prefix

  assert hexStr.len - i == 2*N

  while i < N:
    result[i] = hexStr[2*i].readHexChar shl 4 or hexStr[2*i+1].readHexChar
    inc(i)

proc hexToSeqBytesBE*(hexStr: string): seq[byte] {.noSideEffect.}=
  ## Read an hex string and store it in a sequence of bytes in Big-Endian order
  var i = 0
  if hexStr[i] == '0' and (hexStr[i+1] == 'x' or hexStr[i+1] == 'X'):
    inc(i, 2) # Ignore 0x and 0X prefix

  let N = (hexStr.len - i) div 2

  result = newSeq[byte](N)
  while i < N:
    result[i] = hexStr[2*i].readHexChar shl 4 or hexStr[2*i+1].readHexChar
    inc(i)

proc toHex*[N: static[int]](ba: ByteArrayBE[N]): string {.noSideEffect.}=
  ## Convert a big-endian byte array to its hex representation
  ## Output is in lowercase
  ##

  const hexChars = "0123456789abcdef"

  result = newString(2*N)
  for i in 0 ..< N:
    result[2*i] = hexChars[int ba[i] shr 4 and 0xF]
    result[2*i+1] = hexChars[int ba[i] and 0xF]

proc toHex*(ba: seq[byte]): string {.noSideEffect, noInit.}=
  ## Convert a big-endian byte sequence to its hex representation
  ## Output is in lowercase
  ##

  let N = ba.len
  const hexChars = "0123456789abcdef"

  result = newString(2*N)
  for i in 0 ..< N:
    # you can index an array with byte/uint8 but not a seq :/
    result[2*i] = hexChars[int ba[i] shr 4 and 0xF]
    result[2*i+1] = hexChars[int ba[i] and 0xF]

proc toByteArrayBE*[T: SomeInteger](num: T): ByteArrayBE[T.sizeof] {.noSideEffect, noInit, inline.}=
  ## Convert an int (in native host endianness) to a big-endian byte array
  # Note: only works on devel

  when system.cpuEndian == bigEndian:
    cast[type result](num)
  else:
    # Theoretically this works for both big or little endian
    # but in case of bigEndian, casting is much faster.
    const N = T.sizeof
    for i in 0 ..< N:
      result[i] = byte(num shr T((N-1-i) * 8))

proc toByteArrayBE*(x: U512): ByteArrayBE[64] {.inline, noSideEffect, noInit.}=
  cast[type result](x)

proc toByteArrayBE*[N: static[int]](x: Hash[N]): ByteArrayBE[N div 8] {.inline, noSideEffect, noInit.}=
  cast[type result](x)