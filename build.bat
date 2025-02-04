@echo off
setlocal enabledelayedexpansion

where /Q cl.exe || (
	set __VSCMD_ARG_NO_LOGO=1
	for /f "tokens=*" %%i in ('"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath') do set VS=%%i
	if "!VS!" equ "" (
		echo ERROR: Visual Studio installation not found
		exit /b 1
	)
	call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" amd64 || exit /b 1
)

rem Check if the Vulkan minor version is provided as the first argument
if not "%~1"=="" (
    set VULKAN_VERSION_MINOR=%~1
    echo Using provided Vulkan minor version: %VULKAN_VERSION_MINOR%
) else (
    rem Attempt to detect the installed Vulkan version from the environment
    if defined VULKAN_SDK (
        rem Extract the version from the VULKAN_SDK path (e.g., "C:\VulkanSDK\1.4.304.0")
        for /f "tokens=3 delims=\" %%i in ("%VULKAN_SDK%") do set SDK_FOLDER=%%i
        for /f "tokens=1,2,3,4 delims=." %%a in ("!SDK_FOLDER!") do (
            set VULKAN_VERSION_MINOR=%%b
        )
    ) else (
        echo No Vulkan version provided and VULKAN_SDK not found, defaulting to 1000000
        set VMA_VULKAN_VERSION=1000000
    )
)

rem Construct the VMA_VULKAN_VERSION
if defined VULKAN_VERSION_MINOR (
	if "!VULKAN_VERSION_MINOR!" geq "4" (
		set VMA_VULKAN_VERSION=1004000
	) else if "!VULKAN_VERSION_MINOR!" geq "3" (
		set VMA_VULKAN_VERSION=1003000
	) else if "!VULKAN_VERSION_MINOR!" geq "2" (
		set VMA_VULKAN_VERSION=1002000
	) else if "!VULKAN_VERSION_MINOR!" geq "1" (
		set VMA_VULKAN_VERSION=1001000
	) else (
		set VMA_VULKAN_VERSION=1000000
	)
) else (
	echo Unable to detect Vulkan version from VULKAN_SDK, defaulting to 1000000
	set VMA_VULKAN_VERSION=1000000
)

rem Print out the version for verification
echo VMA_VULKAN_VERSION: !VMA_VULKAN_VERSION!

rem Set the VMA version
set VMA_VERSION=v3.2.0

where /Q git.exe || (
	echo Error: Ensure git is installed and added to your PATH.
    exit /b 1
)

set BUILD_DIR="build"

if not exist "%BUILD_DIR%" (
	mkdir "%BUILD_DIR%"
)

set "VMA_GIT_PATH=%BUILD_DIR%\VulkanMemoryAllocator"
if not exist "%VMA_GIT_PATH%" (
	rem Fetch VulkanMemoryAllocator
	echo Fetching VulkanMemoryAllocator %VMA_VERSION%
	call git clone https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator.git -b %VMA_VERSION% %VMA_GIT_PATH%
)

rem Create the implementation file
echo #define VMA_VULKAN_VERSION %VMA_VULKAN_VERSION% > "%BUILD_DIR%\vk_mem_alloc.cpp"
echo #define VMA_STATIC_VULKAN_FUNCTIONS 0 >> "%BUILD_DIR%\vk_mem_alloc.cpp"
echo #define VMA_DYNAMIC_VULKAN_FUNCTIONS 0 >> "%BUILD_DIR%\vk_mem_alloc.cpp"
echo #define VMA_IMPLEMENTATION >> "%BUILD_DIR%\vk_mem_alloc.cpp"
echo #include "vk_mem_alloc.h" >> "%BUILD_DIR%\vk_mem_alloc.cpp"

rem Ensure everything uses the same static runtime
set CXXFLAGS=/MT /O1 /DNDEBUG

rem Determine platform and architecture for library naming
set OS_NAME=windows
if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
    set ARCH_NAME=arm64
) else (
    set ARCH_NAME=x64
)
set LIB_EXTENSION=lib

rem Set the target platform name to match Odin's foreign block pattern
set TARGET_PLATFORM=vma_%OS_NAME%_%ARCH_NAME%.%LIB_EXTENSION%

rem Compile the VMA library
call cl /c /I "%VMA_GIT_PATH%\include" /I "%VULKAN_SDK%\Include" %CXXFLAGS% /Fo"%BUILD_DIR%\\" "%BUILD_DIR%\vk_mem_alloc.cpp"
call lib "%BUILD_DIR%\vk_mem_alloc.obj" /OUT:%TARGET_PLATFORM%

echo Done. Library copied to %TARGET_PLATFORM%

endlocal
