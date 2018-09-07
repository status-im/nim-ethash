packageName   = "ethash"
version       = "0.0.1"
author        = "Status Research & Development GmbH"
description   = "A Nim implementation of Ethash, the Ethereum proof-of-work hashing function"
license       = "Apache License 2.0"
srcDir        = "src"

### Dependencies

requires "nim >= 0.18.0", "nimcrypto >= 0.1.0"

proc test(name: string, lang: string = "c") =
  if not dirExists "build":
    mkDir "build"
  --run
  switch("out", ("./build/" & name))
  setCommand lang, "tests/" & name & ".nim"

task test, "Run Proof-of-Work tests (without mining)":
  test "all_tests"

task testRelease, "test release mode":
  switch("define", "release")
  testTask()

task test_mining, "Run Proof-of-Work and mining tests (test in release mode + OpenMP + march=native)":
  switch("define", "release")
  switch("define", "openmp")
  switch("define", "march_native")
  switch("define", "ethash_mining")
  test "all_tests"
