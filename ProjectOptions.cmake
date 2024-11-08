include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(first_template_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(first_template_setup_options)
  option(first_template_ENABLE_HARDENING "Enable hardening" ON)
  option(first_template_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    first_template_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    first_template_ENABLE_HARDENING
    OFF)

  first_template_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR first_template_PACKAGING_MAINTAINER_MODE)
    option(first_template_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(first_template_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(first_template_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(first_template_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(first_template_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(first_template_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(first_template_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(first_template_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(first_template_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(first_template_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(first_template_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(first_template_ENABLE_PCH "Enable precompiled headers" OFF)
    option(first_template_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(first_template_ENABLE_IPO "Enable IPO/LTO" ON)
    option(first_template_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(first_template_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(first_template_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(first_template_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(first_template_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(first_template_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(first_template_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(first_template_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(first_template_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(first_template_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(first_template_ENABLE_PCH "Enable precompiled headers" OFF)
    option(first_template_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      first_template_ENABLE_IPO
      first_template_WARNINGS_AS_ERRORS
      first_template_ENABLE_USER_LINKER
      first_template_ENABLE_SANITIZER_ADDRESS
      first_template_ENABLE_SANITIZER_LEAK
      first_template_ENABLE_SANITIZER_UNDEFINED
      first_template_ENABLE_SANITIZER_THREAD
      first_template_ENABLE_SANITIZER_MEMORY
      first_template_ENABLE_UNITY_BUILD
      first_template_ENABLE_CLANG_TIDY
      first_template_ENABLE_CPPCHECK
      first_template_ENABLE_COVERAGE
      first_template_ENABLE_PCH
      first_template_ENABLE_CACHE)
  endif()

  first_template_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (first_template_ENABLE_SANITIZER_ADDRESS OR first_template_ENABLE_SANITIZER_THREAD OR first_template_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(first_template_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(first_template_global_options)
  if(first_template_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    first_template_enable_ipo()
  endif()

  first_template_supports_sanitizers()

  if(first_template_ENABLE_HARDENING AND first_template_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR first_template_ENABLE_SANITIZER_UNDEFINED
       OR first_template_ENABLE_SANITIZER_ADDRESS
       OR first_template_ENABLE_SANITIZER_THREAD
       OR first_template_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${first_template_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${first_template_ENABLE_SANITIZER_UNDEFINED}")
    first_template_enable_hardening(first_template_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(first_template_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(first_template_warnings INTERFACE)
  add_library(first_template_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  first_template_set_project_warnings(
    first_template_warnings
    ${first_template_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(first_template_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    first_template_configure_linker(first_template_options)
  endif()

  include(cmake/Sanitizers.cmake)
  first_template_enable_sanitizers(
    first_template_options
    ${first_template_ENABLE_SANITIZER_ADDRESS}
    ${first_template_ENABLE_SANITIZER_LEAK}
    ${first_template_ENABLE_SANITIZER_UNDEFINED}
    ${first_template_ENABLE_SANITIZER_THREAD}
    ${first_template_ENABLE_SANITIZER_MEMORY})

  set_target_properties(first_template_options PROPERTIES UNITY_BUILD ${first_template_ENABLE_UNITY_BUILD})

  if(first_template_ENABLE_PCH)
    target_precompile_headers(
      first_template_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(first_template_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    first_template_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(first_template_ENABLE_CLANG_TIDY)
    first_template_enable_clang_tidy(first_template_options ${first_template_WARNINGS_AS_ERRORS})
  endif()

  if(first_template_ENABLE_CPPCHECK)
    first_template_enable_cppcheck(${first_template_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(first_template_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    first_template_enable_coverage(first_template_options)
  endif()

  if(first_template_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(first_template_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(first_template_ENABLE_HARDENING AND NOT first_template_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR first_template_ENABLE_SANITIZER_UNDEFINED
       OR first_template_ENABLE_SANITIZER_ADDRESS
       OR first_template_ENABLE_SANITIZER_THREAD
       OR first_template_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    first_template_enable_hardening(first_template_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
