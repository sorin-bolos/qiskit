#!/usr/bin/env bash

git clone https://github.com/emscripten-core/emsdk.git
cd emsdk

pyodide config get emscripten_version # shoud be 3.1.58

./emsdk install 3.1.58
./emsdk activate 3.1.58
source emsdk_env.sh

cd ..

rustup target add wasm32-unknown-emscripten

export CARGO_BUILD_TARGET=wasm32-unknown-emscripten

cargo tree -p qiskit-accelerate --depth 1 | grep rustworkx-core #make sure to use local rustworkx-core

source /mnt/c/repositories/sorin-qiskit/emsdk/emsdk_env.sh # in case activation of 3.1.58 didn't work and the version is still >=4.0.6
hash -r # reset the hash table to ensure the new emsdk is used

emcc --version # should be 3.1.58
pyodide --version
pyodide config get emscripten_version # should be 3.1.58
emcc --version


rustup toolchain install nightly
rustup target add wasm32-unknown-emscripten --toolchain nightly
rustup override set nightly

which -a wasm-opt
wasm-opt --version #probably not found or 117

# if wasm-opt is not found or version < 102, install it
# install cmake to build wasm-opt
sudo apt update && sudo apt install cmake make gcc g++
cd emsdk
./emsdk install binaryen-main-64bit
which -a wasm-opt
wasm-opt --version
export PATH="/mnt/c/repositories/sorin-qiskit/emsdk/binaryen/main_64bit_binaryen/bin:$PATH"
cd ..
hash -r
EMCC_DEBUG=1 emcc -v 2>&1 | grep wasm-opt
EMCC_DEBUG=1 emcc -v 2>&1 | grep wasm-opt | head -1 # probably will have no output

pyodide build
