# purescript-native-cpp-so
Example for creating shared objects with PureScript to C++.

# How to build?

```bash
# Install Git.
# Install Haskell Stack (https://docs.haskellstack.org/en/stable/README/).
# Install purescript@0.13
# Install spago
# Install zephyr

cd 

# Install PureScript Native "extern C" variant (master branch)

git clone https://git@github.com:freylax/purescript-native.git
cd purescript-native
stack install

cd

# Update path for PureScript Native compiler pscpp.

export PATH="${PATH}:${HOME}/.local/bin"

# clone this repo

git clone https://git@github.com:freylax/purescript-native-cpp-so.git

cd purescript-native-cpp-so

# fetch the ffi and gnumake standard lib
git submodule init
git submodule update

# build the main and the plugin
make build

# run
make run-main

