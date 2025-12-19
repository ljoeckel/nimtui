# NimScript configuration and tasks for this repo
switch("nimcache", ".nimcache")

import std/[os, strformat, strutils]

const testDir = "examples"

task example, "Compile and run all examples":
  withDir(testDir):
    for kind, path in walkDir("."):
      if kind == pcFile and path.endsWith(".nim") and not path.endsWith("config.nims"):
        let name = splitFile(path).name
        echo fmt"[nimtui] Running {path}"
        exec fmt"nim c -r {path}"

task testTsan, "Compile and run all tests in tests/":
  putEnv("TSAN_OPTIONS", "suppressions=tests/tsan.ignore")
  exec fmt"nim c -r tests/tmultiThreads.nim"