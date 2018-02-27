packageName   = "ethash"
version       = "0.0.1"
author        = "Status Research & Development GmbH"
description   = "A Nim implementation of Ethash, the Ethereum proof-of-work hashing function"
license       = "Apache License 2.0"
srcDir        = "src"

### Dependencies

requires "nim >= 0.17.2", "keccak_tiny >= 0.1.0", "ttmath > 0.2.0" # ttmath with exposed table field is required for mining only

proc test(name: string, lang: string = "c") =
  if not dirExists "build":
    mkDir "build"
  if not dirExists "nimcache":
    mkDir "nimcache"
  --run
  --nimcache: "nimcache"
  switch("out", ("./build/" & name))
  setCommand lang, "tests/" & name & ".nim"

task test, "Run Proof-of-Work tests (without mining)":
  test "all_tests"

task test_mining, "Run Proof-of-Work and mining tests (test in release mode)":
  switch("define", "release")
  switch("define", "ethash_mining")
  test "all_tests", "cpp"

