cmake_minimum_required(VERSION 3.22)
project(myapp C CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(RingExtensions)

# Workaround for large file support on some Android ABIs
if((ANDROID_ABI STREQUAL "armeabi-v7a" OR ANDROID_ABI STREQUAL "x86") AND ANDROID_PLATFORM_LEVEL LESS 24)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -U_FILE_OFFSET_BITS")
endif()

# ============================================================================
# Ring Language (build from source)
# ============================================================================
set(RING_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ring")
if(NOT EXISTS "${RING_DIR}/src")
    message(FATAL_ERROR "Ring sources not found! Expected at ${RING_DIR}/src")
endif()

file(GLOB RING_SOURCES ${RING_DIR}/src/*.c)
list(FILTER RING_SOURCES EXCLUDE REGEX ".*/ext\\.c$")

add_library(ring STATIC ${RING_SOURCES})
target_include_directories(ring PUBLIC "${RING_DIR}/include")
target_link_libraries(ring PUBLIC android log)

# ============================================================================
# Main Application
# ============================================================================
add_library(main SHARED
    main.c
    ${CMAKE_SOURCE_DIR}/../../build/gen/ringappcode.c
)

target_include_directories(main PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/../../build/gen
    ${RING_DIR}/include
)

target_link_libraries(main PRIVATE
    ring
    android
    log
)

# Generated ring_vm_extension() + every src/cpp/ext/* source.
# tinycthread.c is #included by ring_threads.c, never compiled alone.
set(RING_EXT_EXCLUDE tinycthread.c)
ring_target_add_extensions(main)

# ============================================================================
# Third-party: libcurl (static) + wolfSSL (static)
# ============================================================================
set(THIRDPARTY_DIR "${CMAKE_CURRENT_SOURCE_DIR}/thirdparty")
set(CURL_TAG "curl-8_22_0")
set(WOLFSSL_TAG "v5.9.2-stable")

set(BUILD_SHARED_LIBS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# wolfSSL 5.9: no examples/tests, system CA certs on (Android supported).
# Self-contained repo, no submodules needed.
set(WOLFSSL_DIR "${THIRDPARTY_DIR}/wolfssl")
if(NOT EXISTS "${WOLFSSL_DIR}/CMakeLists.txt")
  message(STATUS "Cloning wolfSSL ${WOLFSSL_TAG} to ${WOLFSSL_DIR}...")
  execute_process(
    COMMAND git clone --branch ${WOLFSSL_TAG} --depth 1 https://github.com/wolfSSL/wolfssl.git "${WOLFSSL_DIR}"
    RESULT_VARIABLE _wolfssl_clone_res)
  if(NOT _wolfssl_clone_res EQUAL 0)
    message(FATAL_ERROR "Failed to clone wolfSSL ${WOLFSSL_TAG}")
  endif()
endif()
set(WOLFSSL_EXAMPLES no)
set(WOLFSSL_CRYPT_TESTS no)
set(WOLFSSL_SYS_CA_CERTS yes)
# Required by curl's wolfSSL backend (X509_STORE and friends).
set(WOLFSSL_OPENSSLEXTRA yes)
add_subdirectory("${WOLFSSL_DIR}" "${CMAKE_BINARY_DIR}/wolfssl" EXCLUDE_FROM_ALL)

target_include_directories(main PRIVATE "${WOLFSSL_DIR}" "${CMAKE_BINARY_DIR}/wolfssl")
target_link_libraries(main PRIVATE wolfssl)

# Point curl's FindWolfSSL at the in-tree target: the pre-seeded name
# survives its find module, and the lib need not exist yet at configure.
set(WOLFSSL_INCLUDE_DIR "${WOLFSSL_DIR}")
set(WOLFSSL_LIBRARY wolfssl)

# libcurl 8.22
set(CURL_DIR "${THIRDPARTY_DIR}/curl")
if(NOT EXISTS "${CURL_DIR}/CMakeLists.txt")
  message(STATUS "Cloning libcurl ${CURL_TAG} to ${CURL_DIR}...")
  execute_process(
    COMMAND git clone --branch ${CURL_TAG} --depth 1 https://github.com/curl/curl.git "${CURL_DIR}"
    RESULT_VARIABLE _curl_clone_res)
  if(NOT _curl_clone_res EQUAL 0)
    message(FATAL_ERROR "Failed to clone libcurl ${CURL_TAG}")
  endif()
endif()
set(BUILD_CURL_EXE OFF)
set(BUILD_LIBCURL_DOCS OFF)
set(BUILD_MISC_DOCS OFF)
set(CURL_DISABLE_INSTALL ON)
set(CURL_USE_WOLFSSL ON)
set(CURL_CA_NATIVE ON)
set(CURL_BROTLI OFF)
set(CURL_ZSTD OFF)
set(USE_NGHTTP2 OFF)
set(CURL_DISABLE_LDAP ON)
set(USE_LIBIDN2 OFF)
set(CURL_USE_LIBPSL OFF)
set(CURL_USE_LIBSSH2 OFF)
add_subdirectory("${CURL_DIR}" "${CMAKE_BINARY_DIR}/curl" EXCLUDE_FROM_ALL)

target_link_libraries(main PRIVATE CURL::libcurl)

# Glaze
set(GLAZE_DIR "${THIRDPARTY_DIR}/glaze")
set(GLAZE_TAG "v7.5.0")
if(NOT EXISTS "${GLAZE_DIR}/CMakeLists.txt")
  message(STATUS "Cloning Glaze ${GLAZE_TAG} to ${GLAZE_DIR}...")
  execute_process(
    COMMAND git clone --branch ${GLAZE_TAG} --depth 1 https://github.com/stephenberry/glaze.git "${GLAZE_DIR}"
    RESULT_VARIABLE _glaze_clone_res)
  if(NOT _glaze_clone_res EQUAL 0)
    message(FATAL_ERROR "Failed to clone Glaze ${GLAZE_TAG}")
  endif()
endif()
target_include_directories(main PRIVATE "${GLAZE_DIR}/include")

# Glaze requires C++23 
set_target_properties(main PROPERTIES
  CXX_STANDARD 23
  CXX_STANDARD_REQUIRED ON)

# SQLite: threadsafe, no loadable extensions (static mobile embed).
set_source_files_properties(
  "${CMAKE_CURRENT_SOURCE_DIR}/ext/sqlite/sqlite3.c" PROPERTIES
  COMPILE_DEFINITIONS "SQLITE_THREADSAFE=1;SQLITE_OMIT_LOAD_EXTENSION=1")

# ============================================================================
# WebView
# ============================================================================
set(WEBVIEW_DIR "${THIRDPARTY_DIR}/webview")
set(WEBVIEW_TAG "v1.6.1")
if(NOT EXISTS "${WEBVIEW_DIR}/CMakeLists.txt")
    message(STATUS "Cloning ring_webview ${WEBVIEW_TAG} to ${WEBVIEW_DIR}...")
    execute_process(
        COMMAND git clone --branch ${WEBVIEW_TAG} --depth 1 --recurse-submodules https://github.com/ysdragon/webview.git "${WEBVIEW_DIR}"
        RESULT_VARIABLE _clone_res
    )
    if(NOT _clone_res EQUAL 0)
        message(FATAL_ERROR "Failed to clone ring_webview ${WEBVIEW_TAG}")
    endif()
endif()
add_subdirectory("${WEBVIEW_DIR}" "${CMAKE_BINARY_DIR}/ring_webview")

target_link_libraries(main PRIVATE ring_webview_android)