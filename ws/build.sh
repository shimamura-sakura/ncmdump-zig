#!/bin/sh

set -ue

EXTRA="-fsingle-threaded -flto -OReleaseFast -fstrip"

zig build-lib main.zig -target wasm32-freestanding -mcpu bleeding_edge -dynamic -rdynamic $EXTRA "$@"

wasm-opt -all -O4 main.wasm -o main.wasm
