# Mark variables as used so cmake doesn't complain about them
mark_as_advanced(CMAKE_TOOLCHAIN_FILE)

# This is a backport of CMAKE_TRY_COMPILE_PLATFORM_VARIABLES to cmake 3.0
get_property( _CMAKE_IN_TRY_COMPILE GLOBAL PROPERTY IN_TRY_COMPILE )
if( _CMAKE_IN_TRY_COMPILE )
    include( "${CMAKE_CURRENT_SOURCE_DIR}/../vcpkg.config.cmake" OPTIONAL )
endif()

if(VCPKG_CHAINLOAD_TOOLCHAIN_FILE)
    include("${VCPKG_CHAINLOAD_TOOLCHAIN_FILE}")
endif()

if(VCPKG_TOOLCHAIN)
    return()
endif()

if(VCPKG_TARGET_TRIPLET)
elseif(CMAKE_GENERATOR_PLATFORM MATCHES "^[Ww][Ii][Nn]32$")
    set(_VCPKG_TARGET_TRIPLET_ARCH x86)
elseif(CMAKE_GENERATOR_PLATFORM MATCHES "^[Xx]64$")
    set(_VCPKG_TARGET_TRIPLET_ARCH x64)
elseif(CMAKE_GENERATOR_PLATFORM MATCHES "^[Aa][Rr][Mm]$")
    set(_VCPKG_TARGET_TRIPLET_ARCH arm)
elseif(CMAKE_GENERATOR_PLATFORM MATCHES "^[Aa][Rr][Mm]64$")
    set(_VCPKG_TARGET_TRIPLET_ARCH arm64)
else()
    if(CMAKE_GENERATOR MATCHES "^Visual Studio 14 2015 Win64$")
        set(_VCPKG_TARGET_TRIPLET_ARCH x64)
    elseif(CMAKE_GENERATOR MATCHES "^Visual Studio 14 2015 ARM$")
        set(_VCPKG_TARGET_TRIPLET_ARCH arm)
    elseif(CMAKE_GENERATOR MATCHES "^Visual Studio 14 2015$")
        set(_VCPKG_TARGET_TRIPLET_ARCH x86)
    elseif(CMAKE_GENERATOR MATCHES "^Visual Studio 15 2017 Win64$")
        set(_VCPKG_TARGET_TRIPLET_ARCH x64)
    elseif(CMAKE_GENERATOR MATCHES "^Visual Studio 15 2017 ARM$")
        set(_VCPKG_TARGET_TRIPLET_ARCH arm)
    elseif(CMAKE_GENERATOR MATCHES "^Visual Studio 15 2017$")
        set(_VCPKG_TARGET_TRIPLET_ARCH x86)
    else()
        find_program(_VCPKG_CL cl)
        if(_VCPKG_CL MATCHES "amd64/cl.exe$" OR _VCPKG_CL MATCHES "x64/cl.exe$")
            set(_VCPKG_TARGET_TRIPLET_ARCH x64)
        elseif(_VCPKG_CL MATCHES "arm/cl.exe$")
            set(_VCPKG_TARGET_TRIPLET_ARCH arm)
        elseif(_VCPKG_CL MATCHES "arm64/cl.exe$")
            set(_VCPKG_TARGET_TRIPLET_ARCH arm64)            
        elseif(_VCPKG_CL MATCHES "bin/cl.exe$" OR _VCPKG_CL MATCHES "x86/cl.exe$")
            set(_VCPKG_TARGET_TRIPLET_ARCH x86)
        elseif(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "x86_64")
            set(_VCPKG_TARGET_TRIPLET_ARCH x64)
        else()
            message(FATAL_ERROR "Unable to determine target architecture.")
        endif()
    endif()
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "WindowsStore" OR CMAKE_SYSTEM_NAME STREQUAL "WindowsPhone")
    set(_VCPKG_TARGET_TRIPLET_PLAT uwp)
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
    set(_VCPKG_TARGET_TRIPLET_PLAT linux)
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    set(_VCPKG_TARGET_TRIPLET_PLAT windows)
endif()

set(VCPKG_TARGET_TRIPLET ${_VCPKG_TARGET_TRIPLET_ARCH}-${_VCPKG_TARGET_TRIPLET_PLAT} CACHE STRING "Vcpkg target triplet (ex. x86-windows)")
set(_VCPKG_TOOLCHAIN_DIR ${CMAKE_CURRENT_LIST_DIR})

if(NOT DEFINED _VCPKG_ROOT_DIR)
    # Detect .vcpkg-root to figure VCPKG_ROOT_DIR
    set(_VCPKG_ROOT_DIR_CANDIDATE ${CMAKE_CURRENT_LIST_DIR})
    while(IS_DIRECTORY ${_VCPKG_ROOT_DIR_CANDIDATE} AND NOT EXISTS "${_VCPKG_ROOT_DIR_CANDIDATE}/.vcpkg-root")
        get_filename_component(_VCPKG_ROOT_DIR_TEMP ${_VCPKG_ROOT_DIR_CANDIDATE} DIRECTORY)
        if (_VCPKG_ROOT_DIR_TEMP STREQUAL _VCPKG_ROOT_DIR_CANDIDATE) # If unchanged, we have reached the root of the drive
            message(FATAL_ERROR "Could not find .vcpkg-root")
        else()
            SET(_VCPKG_ROOT_DIR_CANDIDATE ${_VCPKG_ROOT_DIR_TEMP})
        endif()
    endwhile()
    set(_VCPKG_ROOT_DIR ${_VCPKG_ROOT_DIR_CANDIDATE} CACHE INTERNAL "Vcpkg root directory")
endif()
set(_VCPKG_INSTALLED_DIR ${_VCPKG_ROOT_DIR}/installed)

if(CMAKE_BUILD_TYPE MATCHES "^Debug$" OR NOT DEFINED CMAKE_BUILD_TYPE)
    list(APPEND CMAKE_PREFIX_PATH
        ${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/debug
    )
    list(APPEND CMAKE_LIBRARY_PATH
        ${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/debug/lib/manual-link
    )
    list(APPEND CMAKE_FIND_ROOT_PATH
        ${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/debug
    )
endif()
list(APPEND CMAKE_PREFIX_PATH
    ${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}
)
list(APPEND CMAKE_FIND_ROOT_PATH
    ${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}
)
list(APPEND CMAKE_LIBRARY_PATH
    ${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/lib/manual-link
)

if (NOT DEFINED CMAKE_SYSTEM_VERSION AND _VCPKG_TARGET_TRIPLET_PLAT MATCHES "windows|uwp")
    include(${_VCPKG_ROOT_DIR}/scripts/cmake/vcpkg_get_windows_sdk.cmake)
    # This is used as an implicit parameter for vcpkg_get_windows_sdk
    set(VCPKG_ROOT_DIR ${_VCPKG_ROOT_DIR})
    vcpkg_get_windows_sdk(WINDOWS_SDK_VERSION)
    unset(VCPKG_ROOT_DIR)
    set(CMAKE_SYSTEM_VERSION ${WINDOWS_SDK_VERSION} CACHE STRING "Windows SDK version")
    message(STATUS "Found Windows SDK ${WINDOWS_SDK_VERSION}")
endif()

file(TO_CMAKE_PATH "$ENV{PROGRAMFILES}" _programfiles)
set(CMAKE_SYSTEM_IGNORE_PATH
    "${_programfiles}/OpenSSL"
    "${_programfiles}/OpenSSL-Win32"
    "${_programfiles}/OpenSSL-Win64"
    "${_programfiles}/OpenSSL-Win32/lib/VC"
    "${_programfiles}/OpenSSL-Win64/lib/VC"
    "${_programfiles}/OpenSSL-Win32/lib/VC/static"
    "${_programfiles}/OpenSSL-Win64/lib/VC/static"
    "C:/OpenSSL/"
    "C:/OpenSSL-Win32/"
    "C:/OpenSSL-Win64/"
    "C:/OpenSSL-Win32/lib/VC"
    "C:/OpenSSL-Win64/lib/VC"
    "C:/OpenSSL-Win32/lib/VC/static"
    "C:/OpenSSL-Win64/lib/VC/static"
)

list(APPEND CMAKE_PROGRAM_PATH ${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/tools)
file(GLOB _VCPKG_TOOLS_DIRS ${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/tools/*)
foreach(_VCPKG_TOOLS_DIR ${_VCPKG_TOOLS_DIRS})
    if(IS_DIRECTORY ${_VCPKG_TOOLS_DIR})
        list(APPEND CMAKE_PROGRAM_PATH ${_VCPKG_TOOLS_DIR})
    endif()
endforeach()

option(VCPKG_APPLOCAL_DEPS "Automatically copy dependencies into the output directory for executables." ON)
function(add_executable name)
    _add_executable(${ARGV})
    list(FIND ARGV "IMPORTED" IMPORTED_IDX)
    list(FIND ARGV "ALIAS" ALIAS_IDX)
    if(IMPORTED_IDX EQUAL -1 AND ALIAS_IDX EQUAL -1)
        if(VCPKG_APPLOCAL_DEPS AND _VCPKG_TARGET_TRIPLET_PLAT MATCHES "windows|uwp")
            add_custom_command(TARGET ${name} POST_BUILD
                COMMAND powershell -noprofile -executionpolicy Bypass -file ${_VCPKG_TOOLCHAIN_DIR}/msbuild/applocal.ps1
                    -targetBinary $<TARGET_FILE:${name}>
                    -installedDir "${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}$<$<CONFIG:Debug>:/debug>/bin"
                    -OutVariable out
            )
        endif()
        set_target_properties(${name} PROPERTIES VS_USER_PROPS do_not_import_user.props)
        set_target_properties(${name} PROPERTIES VS_GLOBAL_VcpkgEnabled false)
    endif()
endfunction()

function(add_library name)
    _add_library(${ARGV})
    list(FIND ARGV "IMPORTED" IMPORTED_IDX)
    list(FIND ARGV "INTERFACE" INTERFACE_IDX)
    list(FIND ARGV "ALIAS" ALIAS_IDX)
    if(IMPORTED_IDX EQUAL -1 AND INTERFACE_IDX EQUAL -1 AND ALIAS_IDX EQUAL -1)
        set_target_properties(${name} PROPERTIES VS_USER_PROPS do_not_import_user.props)
        set_target_properties(${name} PROPERTIES VS_GLOBAL_VcpkgEnabled false)
    endif()
endfunction()

macro(find_package name)
    if("${name}" STREQUAL "Boost")
        set(_Boost_USE_STATIC_LIBS ${Boost_USE_STATIC_LIBS})
        set(_Boost_USE_MULTITHREADED ${Boost_USE_MULTITHREADED})
        set(_Boost_USE_STATIC_RUNTIME ${Boost_USE_STATIC_RUNTIME})
        set(_Boost_COMPILER ${Boost_COMPILER})
        unset(Boost_USE_STATIC_LIBS)
        unset(Boost_USE_MULTITHREADED)
        unset(Boost_USE_STATIC_RUNTIME)
        set(Boost_COMPILER "-vc140")
        _find_package(${ARGV})
        if(NOT Boost_FOUND)
            set(Boost_USE_STATIC_LIBS ${_Boost_USE_STATIC_LIBS})
            set(Boost_USE_MULTITHREADED ${_Boost_USE_MULTITHREADED})
            set(Boost_USE_STATIC_RUNTIME ${_Boost_USE_STATIC_RUNTIME})
            set(Boost_COMPILER ${_Boost_COMPILER})
            _find_package(${ARGV})
        endif()
    elseif("${name}" STREQUAL "ICU")
        function(_vcpkg_find_in_list)
            list(FIND ARGV "COMPONENTS" COMPONENTS_IDX)
            set(COMPONENTS_IDX ${COMPONENTS_IDX} PARENT_SCOPE)
        endfunction()
        _vcpkg_find_in_list(${ARGV})
        if(NOT COMPONENTS_IDX EQUAL -1)
            _find_package(${ARGV} COMPONENTS data)
        else()
            _find_package(${ARGV})
        endif()
    elseif("${name}" STREQUAL "TIFF")
        _find_package(${ARGV})
        find_package(LibLZMA)
        if(TARGET TIFF::TIFF)
            set_property(TARGET TIFF::TIFF APPEND PROPERTY INTERFACE_LINK_LIBRARIES ${LIBLZMA_LIBRARIES})
        endif()
        if(TIFF_LIBRARIES)
            list(APPEND TIFF_LIBRARIES ${LIBLZMA_LIBRARIES})
        endif()
    elseif("${name}" STREQUAL "Freetype")
        _find_package(${ARGV})
        find_package(ZLIB)
        find_package(PNG)
        find_package(BZip2)
        if(TARGET Freetype::Freetype)
            set_property(TARGET Freetype::Freetype APPEND PROPERTY INTERFACE_LINK_LIBRARIES BZip2::BZip2 PNG::PNG ZLIB::ZLIB)
        endif()
        if(FREETYPE_LIBRARIES)
            list(APPEND FREETYPE_LIBRARIES ${BZIP2_LIBRARIES} ${PNG_LIBRARIES} ${ZLIB_LIBRARIES})
        endif()
    elseif("${name}" STREQUAL "tinyxml2")
        _find_package(${ARGV})
        if(TARGET tinyxml2_static AND NOT TARGET tinyxml2)
            add_library(tinyxml2 INTERFACE IMPORTED)
            set_target_properties(tinyxml2 PROPERTIES INTERFACE_LINK_LIBRARIES "tinyxml2_static")
        endif()
    else()
        _find_package(${ARGV})
    endif()
endmacro()

set(VCPKG_TOOLCHAIN ON)
set(_UNUSED ${CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION})
set(_UNUSED ${CMAKE_EXPORT_NO_PACKAGE_REGISTRY})
set(_UNUSED ${CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY})
set(_UNUSED ${CMAKE_FIND_PACKAGE_NO_SYSTEM_PACKAGE_REGISTRY})
set(_UNUSED ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP})

if(NOT _CMAKE_IN_TRY_COMPILE)
    file(TO_CMAKE_PATH "${VCPKG_CHAINLOAD_TOOLCHAIN_FILE}" _chainload_file)
    file(TO_CMAKE_PATH "${_VCPKG_ROOT_DIR}" _root_dir)
    file(WRITE "${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/vcpkg.config.cmake"
        "set(VCPKG_TARGET_TRIPLET \"${VCPKG_TARGET_TRIPLET}\" CACHE STRING \"\")\n"
        "set(VCPKG_APPLOCAL_DEPS \"${VCPKG_APPLOCAL_DEPS}\" CACHE STRING \"\")\n"
        "set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE \"${_chainload_file}\" CACHE STRING \"\")\n"
        "set(_VCPKG_ROOT_DIR \"${_root_dir}\" CACHE STRING \"\")\n"
        )
endif()
