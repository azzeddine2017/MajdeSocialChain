# RingExtensions.cmake — generate ring_vm_extension() from src/cpp/ext/
#
# Drop any Ring extension C/C++ source under src/cpp/ext/ (flat or nested,
# e.g. ext/sqlite/sqlite3.c). Per file:
#   helper  (no init)            -> compiled as-is
#   RING_LIBINIT                 -> generated copy, init auto-renamed to
#                                    ring_<name>() (extern "C" for C++
#                                    files), declared/called from
#                                    ring_vm_extension()
#   defines ring_<name>() itself -> compiled as-is, declared and called
#
# Name rule: sanitized basename without a leading ring_, re-prefixed:
#   ext/sqlite/ring_vmsqlite.c -> ring_vmsqlite()
#   ext/webview.c              -> ring_webview()
#   ext/my-ext.c               -> ring_my_ext()
#
# Usage (in src/cpp/CMakeLists.txt):
#   list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
#   include(RingExtensions)
#   ring_target_add_extensions(main)
#
# Notes:
# - New files are picked up automatically (GLOB_RECURSE CONFIGURE_DEPENDS).
# - Basenames must be unique across ext/ (generated copies share one dir).
# - Sources #included by other ext files are compiled twice: list their
#   basenames in RING_EXT_EXCLUDE, e.g. set(RING_EXT_EXCLUDE tinycthread.c)
#   because ring_threads.c already #includes tinycthread/tinycthread.c.
# - At most one RING_LIBINIT per file; more is a FATAL_ERROR.
# - Projects with C++ sources in ext/ must enable CXX in project(),
#   e.g. project(myapp C CXX). enable_language() cannot be used here:
#   called inside a function it only takes effect in function scope.
# - A C++ standard (e.g. C++23) goes on the consuming TARGET
#   (set_target_properties), not per source file: renamed sources compile
#   from generated copies under build/, so source paths would miss.
# - Upstream Ring ext.c must be excluded from the ring static lib to avoid
#   a duplicate ring_vm_extension(); do it next to the RING_SOURCES glob:
#     list(FILTER RING_SOURCES EXCLUDE REGEX ".*/ext\\.c$")
# - RING_LIBINIT used to mean a global ringlib_init(), which collides when
#   vendored twice. The generated rename fixes that per file, but two
#   copies of the same binding still collide on their other symbols.
#   Vendor each binding once.

set(_RING_EXTENSIONS_MODULE_DIR "${CMAKE_CURRENT_LIST_DIR}")

function(ring_target_add_extensions target)
  if(NOT DEFINED RING_EXT_DIR)
    set(RING_EXT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ext")
  endif()
  if(NOT DEFINED RING_EXT_TEMPLATE)
    set(RING_EXT_TEMPLATE "${_RING_EXTENSIONS_MODULE_DIR}/ext.c.in")
  endif()

  file(GLOB_RECURSE _ext_src CONFIGURE_DEPENDS
    "${RING_EXT_DIR}/*.c"
    "${RING_EXT_DIR}/*.cpp"
    "${RING_EXT_DIR}/*.cxx"
    "${RING_EXT_DIR}/*.cc")

  foreach(_x IN LISTS RING_EXT_EXCLUDE)
    list(FILTER _ext_src EXCLUDE REGEX "/${_x}$")
  endforeach()

  if(NOT _ext_src)
    message(STATUS "RingExtensions: no sources under ${RING_EXT_DIR}")
  endif()

  set(_seen_names "")
  set(_decls "")
  set(_calls "")
  set(_gen_srcs "")
  set(_inc_dirs "")

  foreach(_f IN LISTS _ext_src)
    get_filename_component(_fname "${_f}" NAME)
    get_filename_component(_we "${_f}" NAME_WE)
    get_filename_component(_dir "${_f}" DIRECTORY)
    file(RELATIVE_PATH _rel "${RING_EXT_DIR}" "${_f}")
    list(APPEND _inc_dirs "${_dir}")

    # Basenames must be unique: generated copies share one flat dir.
    if(_fname IN_LIST _seen_names)
      message(FATAL_ERROR "RingExtensions: duplicate basename ${_fname} under ${RING_EXT_DIR}. Basenames must be unique.")
    endif()
    list(APPEND _seen_names "${_fname}")

    # ring_<name>: sanitize, drop a leading ring_, re-add it.
    string(MAKE_C_IDENTIFIER "${_we}" _ident)
    string(REGEX REPLACE "^ring_" "" _base "${_ident}")
    set(_fn "ring_${_base}")

    # C++ without CXX enabled is a hard error (see header note).
    if(_f MATCHES "\\.(cpp|cxx|cc)$" AND NOT CMAKE_CXX_COMPILER)
      message(FATAL_ERROR "RingExtensions: ${_fname} needs CXX. Add CXX to project(), e.g. project(myapp C CXX).")
    endif()

    # Line-anchored: ignores mentions inside comments and strings.
    file(STRINGS "${_f}" _libinit_hits REGEX "^[ 	]*RING_LIBINIT([^_A-Za-z0-9]|$)")
    list(LENGTH _libinit_hits _n_libinit)

    set(_register FALSE)
    if(_n_libinit GREATER 1)
      message(FATAL_ERROR "RingExtensions: ${_fname} holds ${_n_libinit} RING_LIBINIT blocks. Split it so each file holds at most one.")
    elseif(_n_libinit EQUAL 1)
      # Automated rename: RING_LIBINIT is `RING_API void ringlib_init(...)`.
      # Line-anchored so mentions inside comments are left alone.
      # C++ files get extern "C" so the init keeps C linkage, matching the
      # extern declaration in generated ext.c. RING_API is dropped there:
      # it expands to plain extern, which would duplicate the specifier.
      if(_f MATCHES "\\.(cpp|cxx|cc)$")
        set(_newinit "extern \"C\" void ${_fn}(RingState *pRingState) /* auto-renamed from RING_LIBINIT */")
      else()
        set(_newinit "RING_API void ${_fn}(RingState *pRingState) /* auto-renamed from RING_LIBINIT */")
      endif()
      file(READ "${_f}" _content)
      string(REGEX REPLACE "^([ 	]*)RING_LIBINIT"
        "\\1${_newinit}"
        _content "${_content}")
      string(REGEX REPLACE "\n([ 	]*)RING_LIBINIT"
        "\n\\1${_newinit}"
        _content "${_content}")
      set(_gen "${CMAKE_CURRENT_BINARY_DIR}/gen/ext/${_fname}")
      file(GENERATE OUTPUT "${_gen}" CONTENT "${_content}")
      list(APPEND _gen_srcs "${_gen}")
      set(_register TRUE)
      message(STATUS "RingExtensions: ${_rel} -> ${_fn}() [RING_LIBINIT renamed]")
    else()
      # Direct definition (e.g. ext/webview.c) or plain helper library.
      file(STRINGS "${_f}" _direct_hits REGEX "void[ 	]+${_fn}[ 	]*\\(" LIMIT_COUNT 1)
      list(APPEND _gen_srcs "${_f}")
      if(_direct_hits)
        set(_register TRUE)
        message(STATUS "RingExtensions: ${_rel} -> ${_fn}() [direct]")
      endif()
    endif()

    if(_register)
      string(APPEND _decls "extern void ${_fn}(RingState *pRingState);\n")
      string(APPEND _calls "\t${_fn}(pRingState); /* ${_rel} */\n")
    endif()
  endforeach()

  set(RING_EXT_DECLS "${_decls}")
  set(RING_EXT_CALLS "${_calls}")
  set(_out "${CMAKE_CURRENT_BINARY_DIR}/gen/ext.c")
  configure_file("${RING_EXT_TEMPLATE}" "${_out}" @ONLY)

  target_sources(${target} PRIVATE "${_out}" ${_gen_srcs})
  if(_inc_dirs)
    list(REMOVE_DUPLICATES _inc_dirs)
    target_include_directories(${target} PRIVATE ${_inc_dirs})
  endif()

  set(RING_EXT_GENERATED_C "${_out}" PARENT_SCOPE)
endfunction()
