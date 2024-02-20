mode = ScriptMode.Verbose

packageName   = "ethash"
version       = "0.0.1"
author        = "Status Research & Development GmbH"
description   = "A Nim implementation of Ethash, the Ethereum proof-of-work hashing function"
license       = "Apache License 2.0"
srcDir        = "src"

### Dependencies

requires "nim >= 1.6.0", "nimcrypto >= 0.1.0"

proc test(name: string, args: string) =
  if not dirExists "build":
    mkDir "build"
  exec "nim c --styleCheck:usages --styleCheck:error --outdir:./build/ " & args & " --run tests/" & name & ".nim"
  if (NimMajor, NimMinor) > (1, 6):
    exec "nim c --styleCheck:usages --styleCheck:error --mm:refc --outdir:./build/ " & args & " --run tests/" & name & ".nim"

task test, "Run Proof-of-Work tests (without mining)":
  test "all_tests", ""

task testRelease, "test release mode":
  test "all_tests", "-d:release"

task test_mining, "Run Proof-of-Work and mining tests (test in release mode + OpenMP + march=native)":
  test "all_tests", "-d:release -d:openmp -d:march_native -d:ethash_mining"
