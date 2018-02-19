# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import keccak_tiny

type U512* = array[8, uint64]
  ## A very simple type alias to `xor` Hash[512] with normal integers
  ## and be able to do sha3_512 which only accepts arrays

proc toU512*(x: Natural): U512 {.inline, noSideEffect.}=
  when system.cpuEndian == littleEndian:
    result[0] = x.uint64
  else:
    result[result.high] = x.uint64

proc toU512*(x: Hash[512]): U512 {.inline, noSideEffect, noInit.}=
  cast[type result](x)

proc `xor`*(x, y: U512): U512 {.inline, noSideEffect, noInit.}=
  for i in 0 ..< result.len:
    {.unroll: 8.}
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

proc toHex*(ba: seq[byte]): string {.noSideEffect, noInit.}=
  ## Convert a big-endian byte-array to its hex representation
  ## Output is in lowercase
  ##
  ## Warning ⚠: Do not use toHex for hex representation of Public Keys
  ##   Use the ``serialize`` proc:
  ##     - PublicKey is actually 2 separate numbers corresponding to coordinate on elliptic curve
  ##     - It is resistant against timing attack

  let N = ba.len
  const hexChars = "0123456789abcdef"

  result = newString(2*N)
  for i in 0 ..< N:
    # you can index an array with byte/uint8 but not a seq :/
    result[2*i] = hexChars[int ba[i] shr 4 and 0xF]
    result[2*i+1] = hexChars[int ba[i] and 0xF]