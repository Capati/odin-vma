#!/bin/bash

# Check if the Vulkan minor version is provided as the first argument
if [ -n "$1" ]; then
    VULKAN_VERSION_MINOR=$1
    echo "Using provided Vulkan minor version: $VULKAN_VERSION_MINOR"
else
    # Attempt to detect the installed Vulkan version from the environment
    if [ -n "$VULKAN_SDK" ]; then
        # Extract the version from the VULKAN_SDK path (e.g., "/VulkanSDK/1.4.304.0")
        SDK_FOLDER=$(basename "$VULKAN_SDK")
        IFS='.' read -r -a VERSION_PARTS <<< "$SDK_FOLDER"
        VULKAN_VERSION_MINOR=${VERSION_PARTS[1]}
    else
        echo "No Vulkan version provided and VULKAN_SDK not found, defaulting to 1000000"
        VMA_VULKAN_VERSION=1000000
    fi
fi

# Construct the VMA_VULKAN_VERSION
if [ -n "$VULKAN_VERSION_MINOR" ]; then
    if [ "$VULKAN_VERSION_MINOR" -ge 4 ]; then
        VMA_VULKAN_VERSION=1004000
    elif [ "$VULKAN_VERSION_MINOR" -ge 3 ]; then
        VMA_VULKAN_VERSION=1003000
    elif [ "$VULKAN_VERSION_MINOR" -ge 2 ]; then
        VMA_VULKAN_VERSION=1002000
    elif [ "$VULKAN_VERSION_MINOR" -ge 1 ]; then
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
VMA_VERSION="v3.2.0"

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
echo "#define VMA_STATIC_VULKAN_FUNCTIONS 0" > "./$BUILD_DIR/vk_mem_alloc.cpp"
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
g++ -c -I "$VMA_GIT_PATH/include" -I "$VULKAN_SDK/include" $CXXFLAGS "$BUILD_DIR/vk_mem_alloc.cpp" -o "$BUILD_DIR/vk_mem_alloc.o"
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
