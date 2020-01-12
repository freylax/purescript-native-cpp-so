# use the gnu make standard library
include gmsl/gmsl

# The entry modules give the lowercase names for the
# executables and shared objects
# Executable Entry Modules
# mapping of executable names to entry modul name
$(call set,Executables,main,Main)
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
# linker options
FFI_LNKS=$(call rwildcard,src/,*.lnk)
# modules which are truely needed
# USED_MOD=$(notdir $(wildcard output/dce/*))
modules=$(notdir $(wildcard output/$1/*))
EXEC_MOD=$(call set_create,$(call modules,dce-exec))
SO_MOD=$(call set_create,$(call modules,dce-so))
ALL_MOD=$(call set_create,$(call modules,dce))
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

USED_MODLC=$(call modtolc,$(USED_MOD))
# ffi cpp
USED_FFI=$(call filtermod,$(FFI_SRCS),$(USED_MODLC))
# purescript compiled cpp
USED_PSC=$(foreach m,$(call modtoul,$(USED_MOD)),output/cpp/modules/$(m).cpp)
USED_CPP=$(USED_FFI) $(USED_PSC) $(wildcard output/cpp/runtime/*.cpp)
CPP_PSRT=$(wildcard output/cpp/runtime/*.cpp)

# get the cpp files for the given modules
cpp_for_mod=$(foreach m,$(call modtoul,$1),output/cpp/modules/$m.cpp) \
            $(call filtermod,$(FFI_SRCS),$(call modtolc,$1))
o_for_mod=$(patsubst %.cpp,%.o,$(call cpp_for_mod,$1))
lnk_for_mod=$(call set_create,\
              $(foreach f,\
                 $(call filtermod,$(FFI_LNKS),$(call modtolc,$1)),$(shell $(cat) $f)))

# commands passed to spago..
# set the timestamps of dce/* files to the ones of the coresponding files in purs/*
DCE_TOUCH=-t '(cd output/dce;for d in *; do touch $$d/corefn.json -r ../purs/$$d/corefn.json; done)'
# call zephyr $1 are the entry point modules, $2 is the destination dir
# clear dest dir before
dce_zephyr=\
  -t 'rm -fr output/$2/*'\
  -t 'zephyr $1 -g corefn -i output/purs -o output/$2'
DCE_ZEPHYR=\
 $(call dce_zephyr,$(EXEC_ENTRY_MOD) $(SO_ENTRY_MOD),dce) $(DCE_TOUCH)\
 $(if $(SO_ENTRY_MOD),\
    $(call dce_zephyr,$(EXEC_ENTRY_MOD),dce-exec)\
    $(call dce_zephyr,$(SO_ENTRY_MOD),dce-so)\
  )

# purs -> corefn -> dead code elimination -> cpp
#
# we set the timestamp of the dce files to the ones in purs
# because these are the logical correct ones, otherwise
# we would rebuild the generated sources evry time
.PHONY: codegen
codegen:
	@echo "codegen" 
	@spago build -u '--codegen corefn -o output/purs' \
                     $(DCE_ZEPHYR) \
                     -t 'pscpp output/dce/*/corefn.json'


ALL_OBJ = $(call o_for_mod,$(ALL_MOD)) $(CPP_PSRT:.cpp=.o)
ALL_DEP = $(ALL_OBJ:.o=.d)

-include $(ALL_DEP)

%.o: %.cpp
	@echo "Creating" $@ "(C++)"
	@$(CXX) $(CXXFLAGS) $(INCLUDES) -MMD -MP -c -fPIC -o $@ $< 

EXEC_LIB_NAME = psexec
SO_LIB_NAME = psso
EXEC_LIB = $(BIN_DIR)/lib$(EXEC_LIB_NAME).so
SO_LIB = $(BIN_DIR)/lib$(SO_LIB_NAME).so

$(EXEC_LIB): $(call o_for_mod,$(EXEC_LIB_MOD)) $(CPP_PSRT:.cpp=.o)
	@echo "build shared lib:" $@
	@mkdir -p $(BIN_DIR)
	@$(CXX) $^ -o $@ -shared \
           $(call lnk_for_mod,$(EXEC_LIB_MOD))


define PluginRule
$(BIN_DIR)/$1.so: $(call o_for_mod,$2)
	@echo "Creating" $$@ "(C++)"
	@$(CXX) $(CXXFLAGS) $(INCLUDES) -MMD -MP \
           $(call lnk_for_mod,$2) -shared -fPIC -o $$@ $$< 
endef

define ExecutableRule
$(BIN_DIR)/$1: $(call o_for_mod,$2) $(EXEC_LIB)
	@echo "Linking" $$@ " from " $$^
	@mkdir -p $(BIN_DIR)
	@$(CXX) $$^ -o $$@ -L$(BIN_DIR)/ \
          -l$(EXEC_LIB_NAME) $(LDFLAGS) \
          $(call lnk_for_mod,$2) 
endef

applyRule=$(foreach k,$(call keys,$1),$(eval $(call $2,$k,$(call get,$1,$k))))

$(call applyRule,Plugins,PluginRule)
$(call applyRule,Executables,ExecutableRule)

define BuildRule
build: codegen \
       $(foreach k,$(call keys,Plugins),$(BIN_DIR)/$k.so) \
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
clean-obj:
	@-rm -f $(ALL_OBJ) $(ALL_DEP)
