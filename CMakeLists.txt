cmake_minimum_required(VERSION 3.10)
# set the project name
project(pssobuild)

# set( x "")
# set( a A B C )
# set( b D E F )

# function( foo l) 
# foreach( i ${l} )
# message( "i=(${i})" )
# endforeach()
# endfunction()
# foo( "${x};${a};${b}" )
# foo( "${x}${a}${b}" )
# foo( "${x} ${a} ${b}" )

# the top level modules
# which create executables
# with names in lowercase of modulenames
set( EXEC_ENTRY_MOD Main Server )
# the top level modules
# which create plugins
# with names in lowercase of modulnames
set( SO_ENTRY_MOD Plugin )

###
set( PURS_DIR ${CMAKE_CURRENT_LIST_DIR} )
set( BUILD_DIR ${CMAKE_CURRENT_BINARY_DIR} )

# specify the C++ standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED True)

string(REPLACE ";" "," EXEC_ENTRY_MOD_ "${EXEC_ENTRY_MOD}")
string(REPLACE ";" "," SO_ENTRY_MOD_ "${SO_ENTRY_MOD}")

set( SPAGO_BUILD_COMMAND_MAKE 
  spago build
  -u '--codegen corefn -o output/purs'
  -t './zephyr.bash ${EXEC_ENTRY_MOD_} ${SO_ENTRY_MOD_}'
  -t 'pscpp output/dce/*/corefn.json'
  )

set( SPAGO_BUILD_COMMAND_CMAKE
  spago build
  -u " --codegen corefn -o output/purs "
  -t " ./zephyr.bash ${EXEC_ENTRY_MOD_} ${SO_ENTRY_MOD_} "
  -t " pscpp output/dce/*/corefn.json "
  )
# message( STATUS ${SPAGO_BUILD_COMMAND_CMAKE} )

execute_process(
  COMMAND ${SPAGO_BUILD_COMMAND_CMAKE}
  WORKING_DIRECTORY ${PURS_DIR}
  )

# Module to lower case >> '.'->'-', lower case
function( modtolc l ret )
  set( r "" )
  foreach( m ${l} )
    string( TOLOWER ${m} v )
    string( REPLACE . - v_ ${v} )
    list( APPEND r ${v_} )
  endforeach()
  set( ${ret} ${r} PARENT_SCOPE )
endfunction()

# Module to underline >> '.'->'_'
function( modtoul l ret )
  set( r "" )
  foreach( m ${l} )
    string( REPLACE . _ v ${m} )
    list( APPEND r ${v} )
  endforeach()
  set( ${ret} ${r} PARENT_SCOPE )
endfunction()

# filter out given files $(1) by Modules $(2) 
function( filtermod fs ms ret)
  set( r "")
  foreach( f ${fs})
    get_filename_component( f_ ${f} NAME_WE )
    foreach( m ${ms})
      if( "${m}" STREQUAL "${f_}" )
	list( APPEND r ${f} )
	break()
      endif()
    endforeach()
  endforeach()
  set( ${ret} ${r} PARENT_SCOPE)
endfunction()

function( modfrompurs f ret )
  set( re "module[ \t\n\r]+([a-zA-Z0-9\.]+)")
  file(STRINGS ${f} mod REGEX ${re} )
  if(${mod} MATCHES ${re})
    set( ${ret} ${CMAKE_MATCH_1} PARENT_SCOPE)
  else()
    set( ${ret} "" PARENT_SCOPE)
  endif()
endfunction()

# filter out given purs files by modules
function( filterpurs fs ms ret)
  set( r "")
  foreach( f ${fs})
    modfrompurs( ${f} mod)
    foreach( m ${ms})
      if( "${m}" STREQUAL "${mod}" )
	list( APPEND r ${f} )
	break()
      endif()
    endforeach()
  endforeach()
  set( ${ret} ${r} PARENT_SCOPE)
endfunction()

# modules which are truely needed
file( GLOB USED_MOD LIST_DIRECTORIES true CONFIGURE_DEPENDS
  RELATIVE ${PURS_DIR}/output/dce
  ${PURS_DIR}/output/dce/*
  )
# modules which are used for executables
file( GLOB EXEC_MOD LIST_DIRECTORIES true CONFIGURE_DEPENDS
  RELATIVE ${PURS_DIR}/output/dce-exec
  ${PURS_DIR}/output/dce-exec/*
  )
# modules which are used for plugins
file( GLOB SO_MOD LIST_DIRECTORIES true CONFIGURE_DEPENDS
  RELATIVE ${PURS_DIR}/output/dce-so
  ${PURS_DIR}/output/dce-so/*
  )
# filter m out from s and save to r
function(filter_out m s r)
  set( r_ "")
  foreach( s_ ${s})
    set( notin TRUE )
    foreach( m_ ${m})
      if( "${m_}" STREQUAL "${s_}" )
	set( notin FALSE)
	break()
      endif()
    endforeach()
    if( notin )
      list( APPEND r_ ${s_} )
    endif()
  endforeach()
  set( ${r} ${r_} PARENT_SCOPE )
endfunction()
# in the executable lib goes all what is in the
# executables without the entry modules
# message( STATUS "EXEC_MOD=${EXEC_MOD}" )
filter_out( "${EXEC_ENTRY_MOD}" "${EXEC_MOD}" EXEC_LIB_MOD)
# in the shared object lib the entries and all what is
# in EXEC_LIB is removed
filter_out( "${SO_ENTRY_MOD};${EXEC_LIB_MOD}" "${SO_MOD}" SO_LIB_MOD)
#message( "EXEC_LIB_MOD=${EXEC_LIB_MOD}" )
#message( "SO_LIB_MOD=${SO_LIB_MOD}" )

# all ffi sources are in ffi dir 
file( GLOB_RECURSE FFIDIR_SRCS
  LIST_DIRECTORIES false CONFIGURE_DEPENDS
  ${PURS_DIR}/ffi/*.cpp
  )
# all ffi sources which are in src dir
file( GLOB_RECURSE FFISRC_SRCS
  LIST_DIRECTORIES false CONFIGURE_DEPENDS
  ${PURS_DIR}/src/*.cpp
  )
# purescript runtime
set( PRT_SRCS output/cpp/runtime/purescript.cpp )
# linker options
file( GLOB_RECURSE FFISRC_LNKS
  LIST_DIRECTORIES false CONFIGURE_DEPENDS
  ${PURS_DIR}/src/*.lnk
  )
file( GLOB_RECURSE FFIDIR_LNKS
  LIST_DIRECTORIES false CONFIGURE_DEPENDS
  ${PURS_DIR}/ffi/*.lnk
  )

# all purescript sources which are in the src dir
file(
  GLOB_RECURSE PURS_SRCS
  LIST_DIRECTORIES false CONFIGURE_DEPENDS
  ${PURS_DIR}/src/*.purs
  )

modtoul( "${USED_MOD}" USED_MODUL ) # modules underlined
#message( "USED_MOD=${USED_MOD}" )
#message( "USED_MODUL=${USED_MODUL}" )

# used purescript srcs 
filterpurs( "${PURS_SRCS}" "${USED_MOD}" USED_PURS )
#message( STATUS "USED_PURS=${USED_PURS}" )
# purescript compiled cpp
set( USED_PSC "")
foreach( m ${USED_MODUL})
  set( f ${PURS_DIR}/output/cpp/modules/${m}.cpp)
  if( EXISTS ${f} )
    list( APPEND USED_PSC ${f} )
  else()
    #message( does not exists: ${f} ) 
  endif()
endforeach()
#message( STATUS "USED_PSC=${USED_PSC}" )

# for one module there can be either an file in PSC_SRCS
# or in FFI_SRCS or in both
function( cpp_for_mod MODS RET )
  modtolc( "${MODS}" MODSLC ) # modules lowercase
  modtoul( "${MODS}" MODSUL ) # modules underlined
  filtermod( "${USED_PSC}" "${MODSUL}" PSC )
  filtermod( "${FFIDIR_SRCS};${FFISRC_SRCS}" "${MODSLC}" FFI )
  set( ${RET} "${PSC};${FFI}" PARENT_SCOPE )
  #message( STATUS cpp_for "${MODS}" "PSC=${PSC}" "FFI=${FFI}" )
endfunction()

# linker options for modules
function( lnk_for_mod MODS RET )
  set( R "")
  modtolc( "${MODS}" MODSLC )
  filtermod( "${FFIDIR_LNKS};${FFISRC_LNKS}" "${MODSLC}" LNKS )
  foreach( LNK ${LNKS} )
    file( READ ${LNK} OPT )
    list( APPEND R ${OPT} )
  endforeach()
  list( REMOVE_DUPLICATES R )
  set( ${RET} "${R}" PARENT_SCOPE )
endfunction()

include_directories(
  ${PURS_DIR}/output/cpp/runtime
  ${PURS_DIR}/output/cpp/modules
  )

# create dependency mapping to
# purs files in src from corresponding cpp
set( USED_PSC_SRC "")
foreach( p ${USED_PURS})
  modfrompurs( ${p} mod )
  modtoul( ${mod} modul )
  set( cpp ${PURS_DIR}/output/cpp/modules/${modul}.cpp)
  if( EXISTS ${cpp} )
    list( APPEND USED_PSC_SRC ${cpp}) 
    add_custom_command( 
      OUTPUT ${cpp}
      COMMAND ${SPAGO_BUILD_COMMAND_MAKE}
      DEPENDS ${p}
      WORKING_DIRECTORY ${PURS_DIR}
      COMMENT "PURS (${mod}) -> CPP"
      #VERBATIM
      # using VERBATIM will screw up quotes!!!!
      )
  endif()
endforeach()
add_custom_target(spago DEPENDS ${USED_PSC_SRC} )

## libraries
cpp_for_mod( "${EXEC_LIB_MOD}" EXEC_LIB_CPP )
lnk_for_mod( "${EXEC_LIB_MOD}" EXEC_LIB_LNK )
add_library( psexec SHARED ${EXEC_LIB_CPP} ${PRT_SRCS} )
target_link_libraries( psexec PUBLIC ${EXEC_LIB_LNK} )
#add_dependencies( psexec spago )
#message( STATUS "EXEC_LIB_CPP=${EXEC_LIB_CPP}" )
#message( STATUS "EXEC_LIB_LNK=${EXEC_LIB_LNK}" )

if( SO_LIB_MOD )
  cpp_for_mod( "${SO_LIB_MOD}" SO_LIB_CPP )
  lnk_for_mod( "${SO_LIB_MOD}" SO_LIB_LNK )
  add_library( psso SHARED ${SO_LIB_CPP} )
  target_link_libraries( psexec PUBLIC ${SO_LIB_LNK} )
  #add_dependencies( psso spago )
  #message( STATUS "SO_LIB_CPP=${SO_LIB_CPP}" )
  #message( STATUS "SO_LIB_LNK=${SO_LIB_LNK}" )
endif()


## plugins
foreach( EMOD ${SO_ENTRY_MOD} )
  modtolc( ${EMOD} NAME )
  cpp_for_mod( ${EMOD} CPP )
  lnk_for_mod( ${EMOD} LNK )
  #message( STATUS plugin: "EMOD=${EMOD} CPP=${CPP}" )
  add_library( ${NAME} MODULE ${CPP} )
  set_target_properties( ${NAME} PROPERTIES PREFIX "")
  if( LNK )
    target_link_libraries( ${NAME} PUBLIC ${LNK} )
  endif()
  if( SO_LIB_MOD )
    target_link_libraries( ${NAME} -L${BUILD_DIR} -lpsso )
  endif()
  #add_dependencies( ${NAME} spago )
endforeach()

## executables
foreach( EMOD ${EXEC_ENTRY_MOD} )
  modtolc( "${EMOD}" NAME )
  cpp_for_mod( "${EMOD}" CPP )
  lnk_for_mod( "${EMOD}" LNK )
  add_executable( ${NAME} ${CPP} )
  if( LNK )
    target_link_libraries( ${NAME} PUBLIC ${LNK} )
  endif()
  target_link_libraries( ${NAME} -L${BUILD_DIR} -lpsexec )
  #message( STATUS exec: "EMOD=${EMOD} CPP=${CPP}" )
  #add_dependencies( ${NAME} spago )
endforeach()
