# purescript-native-cpp-so
Example for creating shared objects with PureScript to C++.

# How to build?

```bash
# Install Git.
# Install Haskell Stack (https://docs.haskellstack.org/en/stable/README/).
# Install purescript@0.13 and psc-package

cd 

# Install PureScript Native "extern C" variant (master branch)

git clone https://git@github.com:freylax/purescript-native.git
cd purescript-native
stack install

cd

# Update path for PureScript Native compiler pscpp.

export PATH="${PATH}:${HOME}/.local/bin"

# Download and install the FFI exports with extern "C" functions.

git clone https://git@github.com:freylax/purescript-native-cpp-ffi.git

# clone this repo

git clone https://git@github.com:freylax/purescript-native-cpp-so.git

# install the ffi
cp -nr purescript-native-cpp-ffi/. purescript-native-cpp-so/ffi/

cd purescript-native-cpp-so
# Install the PureScript dependencies.
psc-package install

# build the example
make release

# run
make run

