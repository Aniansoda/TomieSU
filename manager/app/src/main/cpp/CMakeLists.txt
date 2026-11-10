
# For more information about using CMake with Android Studio, read the
# documentation: https://d.android.com/studio/projects/add-native-code.html

# Sets the minimum version of CMake required to build the native library.
cmake_minimum_required(VERSION 3.18.1)

project("tomiesu")

# The prefab `cxx` module ships libc++ built as LLVM 21 LTO bitcode, which the
# aarch64-host linker (LLVM 18) cannot read. Link the prebuilt shared C++ runtime
# from the NDK sysroot instead; it is a real ELF, not bitcode.
# Map the public ABI name to the NDK sysroot triple.
if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(CXX_TRIPLE "aarch64-linux-android")
elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
    set(CXX_TRIPLE "arm-linux-androideabi")
elseif(ANDROID_ABI STREQUAL "x86")
    set(CXX_TRIPLE "i686-linux-android")
elseif(ANDROID_ABI STREQUAL "x86_64")
    set(CXX_TRIPLE "x86_64-linux-android")
else()
    set(CXX_TRIPLE "${ANDROID_ABI}")
endif()
set(CXX_RUNTIME "${CMAKE_ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${CXX_TRIPLE}/libc++_shared.so")
link_libraries("${CXX_RUNTIME}")
include_directories(SYSTEM "${CMAKE_ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/c++/v1")

add_library(tomiesu
        SHARED
        jni.cc
        ksu.cc
        )

target_include_directories(tomiesu PRIVATE . "${CMAKE_CURRENT_SOURCE_DIR}/../../../../..")

find_library(log-lib log)

target_link_libraries(tomiesu ${log-lib})

add_library(adbroot SHARED adbroot.cc)
target_link_libraries(adbroot ${log-lib})
