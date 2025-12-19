# Package Information
version = "0.1.0"
author = "Lothar Joeckel"
description = "Simple TUI for Nim"
license = "MIT"
srcDir = "."
requires "nim >= 2.2.4"

task globaleditor, "Run GlobalEditor example":
    exec "nim c -r ./nimtui/examples/globaleditor.nim"
task formeditor, "Run FormEditor example":
    exec "nim c -r ./nimtui/examples/formeditor.nim"
