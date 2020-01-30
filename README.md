# purescript-native-cpp-so
Example for creating shared objects with PureScript to C++.

The purpose of this repo is the elaboration of the build process
for a more complex Native C++ Purescript Application.
We use zephyr to find the module dependencies for the top level
entry points (applications and plugins). This entry points
are the only ones one has to specify in the makefile.

There is an plugin loading application (main) and
an plugin loading server application (server). 

## Features:

* ffi's are looked up in the ffi or src dir.
	we use the naming convention 'my-module.cpp'
	for the 'My.Module' purescript module
* linker options for ffi's are found in corresponding
	'my-module.lnk' files
* zephyr does dead code elimination so only needed
	ffi functions are pulled in
* Makefile for GNU Make and CMakeLists.txt for CMake	

## Issues:

* zephyr builds all output files anew for every run
	This would force a rebuild of all the following
	compilations. We tweak this in the zephyr.bash
	script, but should be handeld by zephyr.
	It should give us the list of dependent modules
	for groups of entry points, we simulate this now by
	calling it for the plugins and applications separatly.

# How to build?

```bash
# Install Git.
# Install Haskell Stack (https://docs.haskellstack.org/en/stable/README/).
# Install purescript@0.13 (https://github.com/purescript/purescript)
# Install spago           (https://github.com/spacchetti/spago)
# Install zephyr          (https://github.com/coot/zephyr)
# Install cmake / GNU make
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
```
## Using GNU Make
```bash

# build the main and the plugin 
make build

# run
# loading and executing the plugin directly
make run-main
# offer a service for loading plugins:
# in one terminal run
make run-server
# in an other on type
nc localhost 1031
l plugin 
c Plugin.add
c Plugin.add
```
## Using CMake
```

# configure the project
mkdir build
cd build
cmake ..
# build the main and the plugin 
make 
# run
LD_LIBRARY_PATH=. ./main
# see above
...
```
