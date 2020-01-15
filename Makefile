# use the gnu make standard library
include gmsl/gmsl

# The entry modules give the lowercase names for the
# executables and shared objects
# Executable Entry Modules
# mapping of executable names to entry modul name
$(call set,Executables,main,Main)
$(call set,Executables,server,Server)
# mapping of plugin names to plugin modul name
$(call set,Plugins,plugin,Plugin)

# get the values of the associative array
values=$(foreach i,$(call keys,$1),$(call get,$1,$i))
EXEC_ENTRY_MOD := $(call values,Executables)
# Shared Object Entry Modules (Plugins)
SO_ENTRY_MOD := $(call values,Plugins)

BIN_DIR := output/bin
INCLUDES:= -I output/cpp/runtime -I output/cpp/modules
DEBUG   := "-DDEBUG -g -O3"
RELEASE := "-DNDEBUG -O3"

CXXVERSION = $(shell $(CXX) --version)
ifneq (,$(findstring g++,$(CXXVERSION)))
  PSCPPFLAGS += "--ucns"
endif

override CXXFLAGS += --std=c++11
# debugging makefile, view contents of variable 
print-%:
	@echo '$($*)'
cat := $(if $(filter $(OS),Windows_NT),type,cat)
## Not all environments support globstar (** dir pattern)
rwildcard=$(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2))
# all ffi sources are in ffi dir and src
FFI_SRCS=$(foreach d,$(wildcard ffi/*),$(wildcard $d/*.cpp)) \
          $(call rwildcard,src/,*.cpp)
# purescript transpiled modules
PCC_SRCS=$(wildcard output/cpp/modules/*.cpp)
# purescript runtime
PRT_SRCS=$(wildcard output/cpp/runtime/*.cpp)

# linker options
FFI_LNKS:=$(call rwildcard,src/,*.lnk)
# modules which are truely needed
modules=$(notdir $(wildcard output/$1/*))
EXEC_MOD=$(call set_create,$(call modules,dce-exec))
SO_MOD=$(call set_create,$(call modules,dce-so))
# what goes into the libraries
# in the executable lib goes all what is in the
# executables without the entry modules
EXEC_LIB_MOD=$(filter-out $(EXEC_ENTRY_MOD),$(EXEC_MOD))
# in the shared object lib the entries and all what is
# in EXEC_LIB is removed
SO_LIB_MOD=$(filter-out $(SO_ENTRY_MOD) $(EXEC_LIB_MOD),$(SO_MOD))
# Module to lower case >> '.'->'-', lower case
modtolc=$(foreach m,$(1),$(subst .,-,$(call lc,$(m))))
# Module to underline >> '.'->'_'
modtoul=$(foreach m,$(1),$(subst .,_,$(m)))
# filter out given files $(1) by Modules $(2) 
filtermod=$(strip $(foreach f,$(1),$(if $(filter $(basename $(notdir $(f))),$(2)),$(f))))

# object files for given modules
# for one module there can be either an file in PSC_SRCS
# or in FFI_SRCS or in both
o_for_mod=$(patsubst %.cpp,%.o,\
             $(patsubst output/cpp/%,output/obj/%,\
               $(call filtermod,$(PCC_SRCS),$(call modtoul,$1))) \
             $(addprefix output/obj/,\
               $(call filtermod,$(FFI_SRCS),$(call modtolc,$1))) )

PRT_O=$(patsubst %.cpp,%.o,\
             $(patsubst output/cpp/%,output/obj/%,$(PRT_SRCS)))

# linker options for modules 
lnk_for_mod=$(call set_create,\
              $(foreach f,\
                 $(call filtermod,$(FFI_LNKS),$(call modtolc,$1)),$(shell $(cat) $f)))

# purs -> corefn -> dead code elimination -> cpp
#
.PHONY: codegen
codegen:
	@echo "codegen" 
	@spago build -u '--codegen corefn -o output/purs' \
                     -t './zephyr.bash "$(EXEC_ENTRY_MOD)" "$(SO_ENTRY_MOD)"' \
                     -t 'pscpp output/dce/*/corefn.json'

# include dependicies
-include $(call rwildcard,output/obj/,*.d)

define ObjectRule
$2/%.o: $1/%.cpp
	@echo "Creating" $$@ "(C++)"
	@mkdir -p $$(dir $$@)
	@$$(CXX) $$(CXXFLAGS) $$(INCLUDES) -MMD -MP -c -fPIC -o $$@ $$<
endef

# the three different soures for objects
$(eval $(call ObjectRule,output/cpp,output/obj))
$(eval $(call ObjectRule,ffi,output/obj/ffi))
$(eval $(call ObjectRule,src,output/obj/src))

EXEC_LIB_NAME = psexec
SO_LIB_NAME = psso
EXEC_LIB = $(BIN_DIR)/lib$(EXEC_LIB_NAME).so
SO_LIB = $(BIN_DIR)/lib$(SO_LIB_NAME).so

define LibRule
$1: $(call o_for_mod,$2) $3
	@echo "build shared lib:" $$@
	@mkdir -p $$(dir $$@)
	@$(CXX) $$^ -o $$@ -shared \
           $(call lnk_for_mod,$2)
endef

$(eval $(call LibRule,$(EXEC_LIB),$(EXEC_LIB_MOD),$(PRT_O)))  
$(if $(SO_LIB_MOD),$(eval $(call LibRule,$(SO_LIB),$(SO_LIB_MOD),)))

define PluginRule
$(BIN_DIR)/$1.so: $(call o_for_mod,$2) $(if $(SO_LIB_MOD),$(SO_LIB))
	@echo "Creating" $$@ "(C++)"
	@mkdir -p $$(dir $$@)
	@$(CXX) $(CXXFLAGS) $(INCLUDES) -MMD -MP \
           -L$(BIN_DIR) \
           $(if $(SO_LIB_MOD),-l$(SO_LIB_NAME)) \
           $(call lnk_for_mod,$2) -shared -fPIC -o $$@ $$< 
endef
## $(info $(call PluginRule,plugin,Plugin))
define ExecutableRule
$(BIN_DIR)/$1: $(call o_for_mod,$2) $(EXEC_LIB) 
	@echo "Linking" $$@ " from " $$^
	@mkdir -p $$(dir $$@)
	@$(CXX) $$^ -o $$@ -L$(BIN_DIR)/ \
          -l$(EXEC_LIB_NAME) $(LDFLAGS) \
          $(call lnk_for_mod,$2) 
endef

applyRule=$(foreach k,$(call keys,$1),$(eval $(call $2,$k,$(call get,$1,$k))))

$(call applyRule,Plugins,PluginRule)
$(call applyRule,Executables,ExecutableRule)

debug: codegen
	@$(MAKE) -s build CXXFLAGS+=$(DEBUG)

define BuildRule
build: $(foreach k,$(call keys,Plugins),$(BIN_DIR)/$k.so) \
       $(foreach k,$(call keys,Executables),$(BIN_DIR)/$k) 
endef

$(eval $(BuildRule))

.PHONY: run-%
run-%:
	@LD_LIBRARY_PATH=$$(pwd)/$(BIN_DIR) $(BIN_DIR)/$* $(ARGS)


clean-%:
	@-rm -rf output/$*
clean:
	@-rm -rf output
