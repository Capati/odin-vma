#!/bin/bash

get_vulkan_minor_version() {
    local full_version=""
    local minor_version=""

    # Try vulkaninfo first
    if command -v vulkaninfo >/dev/null 2>&1; then
        full_version=$(vulkaninfo 2>/dev/null | grep "Vulkan Instance Version:" | awk '{print $4}')
        if [ -n "$full_version" ]; then
            # Extract minor version from format like 1.3.xxx
            minor_version=$(echo "$full_version" | cut -d'.' -f2)
            echo "$minor_version"
            return 0
        fi
    fi

    # Check VULKAN_SDK path
    if [ -n "${VULKAN_SDK}" ] && [ -d "${VULKAN_SDK}" ]; then
        if [ -f "${VULKAN_SDK}/version.txt" ]; then
            full_version=$(cat "${VULKAN_SDK}/version.txt")
            minor_version=$(echo "$full_version" | cut -d'.' -f2)
            echo "$minor_version"
            return 0
        fi
    fi

    echo "0"
    return 1
}

VULKAN_MINOR_VERSION=3

# Check if the Vulkan minor version is provided as the first argument
if [ -n "$1" ]; then
    VULKAN_MINOR_VERSION=$1
    echo "Using provided Vulkan minor version: $VULKAN_MINOR_VERSION"
else
	VULKAN_MINOR_VERSION=$(get_vulkan_minor_version)
fi

# Construct the VMA_VULKAN_VERSION
if [ -n "$VULKAN_MINOR_VERSION" ]; then
    if [ "$VULKAN_MINOR_VERSION" -ge 4 ]; then
        VMA_VULKAN_VERSION=1004000
    elif [ "$VULKAN_MINOR_VERSION" -ge 3 ]; then
        VMA_VULKAN_VERSION=1003000
    elif [ "$VULKAN_MINOR_VERSION" -ge 2 ]; then
        VMA_VULKAN_VERSION=1002000
    elif [ "$VULKAN_MINOR_VERSION" -ge 1 ]; then
        VMA_VULKAN_VERSION=1001000
    else
        VMA_VULKAN_VERSION=1000000
    fi
else
    echo "Unable to detect Vulkan version from VULKAN_SDK, defaulting to 1000000"
    VMA_VULKAN_VERSION=1000000
fi

# Print out the version for verification
echo "VMA_VULKAN_VERSION: $VMA_VULKAN_VERSION"

# Set the VMA version
VMA_VERSION="v3.2.1"

# Check if git is available
if ! command -v git &> /dev/null; then
    echo "Error: Ensure git is installed and added to your PATH."
    exit 1
fi

BUILD_DIR="./build"

# Check if the build directory exists, create if not
if [ ! -d "$BUILD_DIR" ]; then
	mkdir "$BUILD_DIR"
fi

# Set the VMA Git path
VMA_GIT_PATH="$BUILD_DIR/VulkanMemoryAllocator"
if [ ! -d "$VMA_GIT_PATH" ]; then
	# Fetch VulkanMemoryAllocator
	echo "Fetching VulkanMemoryAllocator $VMA_VERSION"
	git clone https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator.git -b "$VMA_VERSION" "$VMA_GIT_PATH"
fi

# Create the implementation file
echo "#define VMA_VULKAN_VERSION $VMA_VULKAN_VERSION" > "./$BUILD_DIR/vk_mem_alloc.cpp"
echo "#define VMA_STATIC_VULKAN_FUNCTIONS 0" >> "./$BUILD_DIR/vk_mem_alloc.cpp"
echo "#define VMA_DYNAMIC_VULKAN_FUNCTIONS 0" >> "./$BUILD_DIR/vk_mem_alloc.cpp"
echo "#define VMA_IMPLEMENTATION" >> "./$BUILD_DIR/vk_mem_alloc.cpp"
echo "#include \"vk_mem_alloc.h\"" >> "./$BUILD_DIR/vk_mem_alloc.cpp"

# Compiler flags
CXXFLAGS="-O1 -DNDEBUG"

# Determine platform and architecture for library naming
OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH_NAME=$(uname -m)
if [ "$ARCH_NAME" == "aarch64" ]; then
    ARCH_NAME="arm64"
else
    ARCH_NAME="x64"
fi
LIB_EXTENSION="a"

# Set the target platform name to match Odin's foreign block pattern
TARGET_PLATFORM="vma_${OS_NAME}_${ARCH_NAME}.${LIB_EXTENSION}"

# Compile the VMA library
echo "Compiling VulkanMemoryAllocator..."
g++ -c \
	-I "$VMA_GIT_PATH/include" \
	-I "$VULKAN_SDK/include" \
	$CXXFLAGS "$BUILD_DIR/vk_mem_alloc.cpp" \
	-o "$BUILD_DIR/vk_mem_alloc.o"
if [ $? -ne 0 ]; then
    echo "Compilation failed."
    exit 1
fi

# Create a static library
echo "Creating static library..."
ar rcs "$TARGET_PLATFORM" "$BUILD_DIR/vk_mem_alloc.o"
if [ $? -ne 0 ]; then
    echo "Library creation failed."
    exit 1
fi

echo "Done. Library created as $TARGET_PLATFORM"
