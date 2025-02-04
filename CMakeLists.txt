cmake_minimum_required(VERSION 3.11)
project(PrepareVMA)

# First, check if VMA_VULKAN_VERSION is already set in CMAKE_CXX_DEFINES
if(CMAKE_CXX_DEFINES)
  string(REGEX MATCH "VMA_VULKAN_VERSION=[0-9]+"
               VMA_VULKAN_VERSION_FROM_DEFINES "${CMAKE_CXX_DEFINES}")
  if(VMA_VULKAN_VERSION_FROM_DEFINES)
    string(REGEX REPLACE "VMA_VULKAN_VERSION=" "" VMA_VULKAN_VERSION
                         "${VMA_VULKAN_VERSION_FROM_DEFINES}")
  endif()
endif()

# If not set from defines, check if there's an option
if(NOT VMA_VULKAN_VERSION)
  set(VMA_VULKAN_VERSION
      ""
      CACHE STRING "Vulkan Memory Allocator Vulkan Version")
endif()

# If still not set, default to Vulkan version
if(NOT VMA_VULKAN_VERSION)
  if(Vulkan_VERSION)
    if(Vulkan_VERSION VERSION_GREATER_EQUAL "1.4")
      set(VMA_VULKAN_VERSION "1004000")
    elseif(Vulkan_VERSION VERSION_GREATER_EQUAL "1.3")
      set(VMA_VULKAN_VERSION "1003000")
    elseif(Vulkan_VERSION VERSION_GREATER_EQUAL "1.2")
      set(VMA_VULKAN_VERSION "1002000")
    elseif(Vulkan_VERSION VERSION_GREATER_EQUAL "1.1")
      set(VMA_VULKAN_VERSION "1001000")
    else()
      set(VMA_VULKAN_VERSION "1000000")
    endif()
  endif()
endif()

# Print out the version for verification
message(STATUS "VMA_VULKAN_VERSION: ${VMA_VULKAN_VERSION}")

# Ensures everything uses the same static runtime
if(MSVC)
  add_compile_options($<$<CONFIG:>:/MT> $<$<CONFIG:Debug>:/MT>
                      $<$<CONFIG:Release>:/MT>)
endif()

find_package(Vulkan REQUIRED)

# For managing external dependencies
include(FetchContent)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(VMA_VERSION "v3.2.0")

message(STATUS "Fetching VulkanMemoryAllocator ${VMA_VERSION}")
FetchContent_Declare(
  vma
  GIT_REPOSITORY
    https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator.git
  GIT_TAG ${VMA_VERSION})

FetchContent_GetProperties(vma)
if(NOT vma_POPULATED)
  FetchContent_Populate(vma)
endif()

# cmake-format: off
# Create the implementation file
file(WRITE ${CMAKE_BINARY_DIR}/vk_mem_alloc.cpp
"#define VMA_STATIC_VULKAN_FUNCTIONS 0
#define VMA_DYNAMIC_VULKAN_FUNCTIONS 0
#define VMA_IMPLEMENTATION
#include \"vk_mem_alloc.h\"
")
# cmake-format: on

# Create the VMA library
add_library(vma STATIC ${CMAKE_BINARY_DIR}/vk_mem_alloc.cpp
                       ${vma_SOURCE_DIR}/include/vk_mem_alloc.h)

# Set include directories and compile definitions
target_include_directories(vma PUBLIC ${vma_SOURCE_DIR}/include
                                      ${Vulkan_INCLUDE_DIR})
target_link_libraries(vma PUBLIC Vulkan::Vulkan)

# Set VMA_VULKAN_VERSION based on the determined version
target_compile_definitions(vma PUBLIC VMA_VULKAN_VERSION=${VMA_VULKAN_VERSION})

# Determine platform and architecture for library naming
if(WIN32)
  set(OS_NAME "windows")
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64")
    set(ARCH_NAME "arm64")
  else()
    set(ARCH_NAME "x64")
  endif()
  set(LIB_EXTENSION "lib")
elseif(APPLE)
  set(OS_NAME "darwin")
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64")
    set(ARCH_NAME "arm64")
  else()
    set(ARCH_NAME "x64")
  endif()
  set(LIB_EXTENSION "a")
elseif(UNIX)
  set(OS_NAME "linux")
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
    set(ARCH_NAME "arm64")
  else()
    set(ARCH_NAME "x64")
  endif()
  set(LIB_EXTENSION "a")
else()
  message(FATAL_ERROR "Unsupported operating system")
endif()

# Set the target platform name to match Odin's foreign block pattern
set(TARGET_PLATFORM "vma_${OS_NAME}_${ARCH_NAME}.${LIB_EXTENSION}")

# Copy the built library to the desired location
add_custom_command(
  TARGET vma
  POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:vma>
          ${CMAKE_SOURCE_DIR}/${TARGET_PLATFORM}
  COMMENT "Copying VMA library ${TARGET_PLATFORM}")
