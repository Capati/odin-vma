newoption {
    trigger = "vk-version",
    value = "VERSION",
    description = "Choose a specif Vulkan version to target",
    allowed = {
       { "4", "1004000" },
       { "3", "1003000" },
       { "2", "1002000" },
       { "1", "1001000" },
       { "0", "1000000" },
    },
    default = "1"
}

-- Check Premake version
if _PREMAKE_VERSION < "5.0" then
    error("This script requires Premake 5.0 or later.")
end

-- Constants and options
VMA_VERSION = "v3.2.1"
VULKAN_HEADERS_VERSION = "v1.4.307"

-- Utility functions
local redirectNul = (os.host() == "windows") and ">nul 2>&1" or ">/dev/null 2>&1"

local function hasCommand(cmd)
    return os.execute(cmd .. " " .. redirectNul)
end

local function getOsAndArchitecture()
    local osName = os.host()
    local arch
    if osName == "windows" then
        local procArch =
            os.getenv("PROCESSOR_ARCHITEW6432") or os.getenv("PROCESSOR_ARCHITECTURE") or "x86"
        procArch = procArch:lower()
        arch = ({ amd64 = "x86_64", arm64 = "ARM64", x86 = "x86" })[procArch] or "x86"
    else
        local unameArch = os.outputof("uname -m") or ""
        arch = ({
            x86_64 = "x86_64",
            aarch64 = "ARM64",
            arm64 = "ARM64",
            i386 = "x86",
            i686 = "x86"
        })[unameArch:lower()] or (os.is64bit() and "x86_64" or "x86")
    end
    return osName, arch
end

-- Setup functions
local function setupDirectories()
    BUILD_DIR = path.getabsolute("./build")
    DEPS_DIR = path.join(BUILD_DIR, "deps")
    os.mkdir(BUILD_DIR)
    os.mkdir(DEPS_DIR)
end

local function downloadDependencies()
    if not hasCommand("git --version") then
        error("Git is required but not found. Please install it.")
    end

    VMA_DIR = path.join(DEPS_DIR, "vma")
    VULKAN_HEADERS_DIR = path.join(DEPS_DIR, "vulkan_headers")

    local function cloneRepo(repoName, repoDir, repoUrl, repoVersion)
        -- Ignore already cloned
        if not os.isdir(repoDir) then
            print("Cloning " .. repoName .. " " .. repoVersion .. "...")
            if not os.execute("git clone " .. repoUrl .. " " .. repoDir) then
                error("Failed to clone " .. repoName .. " repository.")
            end
            if not os.execute("cd " .. repoDir .. " && git checkout " .. repoVersion .. redirectNul) then
                error("Failed to checkout " .. repoVersion .. " for " .. repoName .. ".")
            end
        end
    end

    cloneRepo(
        "VMA", VMA_DIR, "https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator.git",
        VMA_VERSION)
    cloneRepo(
        "Vulkan-Headers", VULKAN_HEADERS_DIR, "https://github.com/KhronosGroup/Vulkan-Headers.git",
        VULKAN_HEADERS_VERSION)
end

local function generateBuildFile()
    local implFile = path.join(BUILD_DIR, "build.bat")
    local f = assert(io.open(implFile, "w"))
    f:write(string.format([[
@echo off
setlocal enabledelayedexpansion

:: Setup tooling
call vcvars64.bat || exit /b 1

:: Compile the VMA library
call cl /c ^
	/I %s ^
	/I %s ^
	/MT /O1 /DNDEBUG /Fo.\ .\vk_mem_alloc.cpp || exit /b 1
call lib .\vk_mem_alloc.obj /OUT:.\..\vma_windows_x86_64.lib || exit /b 1

echo Done.

endlocal
]], path.join(VMA_DIR, "include"),
    path.join(VULKAN_HEADERS_DIR, "include")))
    f:close()
end

local function generateImplFile(vulkanVersion)
    local implFile = path.join(BUILD_DIR, "vk_mem_alloc.cpp")
    local f = assert(io.open(implFile, "w"))
    f:write(string.format([[
#define VMA_VULKAN_VERSION %d
#define VMA_STATIC_VULKAN_FUNCTIONS 0
#define VMA_DYNAMIC_VULKAN_FUNCTIONS 0
#define VMA_IMPLEMENTATION
#include "vk_mem_alloc.h"
]], vulkanVersion))
    f:close()
end

-- Workspace and project configuration
workspace "vma"
    configurations { "Debug", "Release" }
    location(path.join("build", "make", os.host()))
    targetdir "bin/%{cfg.buildcfg}"

    -- Execute setup
    local osName, arch = getOsAndArchitecture()
    print("Detected OS: " .. osName .. ", Architecture: " .. arch)
    setupDirectories()
    downloadDependencies()

    local vmaVersionMap = {
        ["4"] = "1004000",
        ["3"] = "1003000",
        ["2"] = "1002000",
        ["1"] = "1001000",
        ["0"] = "1000000",
    }
    local vmaVersion = vmaVersionMap[_OPTIONS["vk-version"]] or vmaVersionMap["1"]
    generateImplFile(tonumber(vmaVersion))
    generateBuildFile()

    -- Define all supported platforms
    platforms { "x86_64", "ARM64" }  -- Add "x86" or others if needed
    -- Set default platform based on detected arch
    defaultplatform(arch)  -- Assumes arch is "x86_64" or "ARM64"

project "vma"
    kind "StaticLib"
    language "C++"
    targetdir "./"
    targetname("vma_%{os.host()}_%{cfg.platform}")

    includedirs {
        path.join(VMA_DIR, "include"),
        path.join(VULKAN_HEADERS_DIR, "include")
    }
    files { path.join(BUILD_DIR, "vk_mem_alloc.cpp") }

    filter "system:windows"
        buildoptions { "/MT" }
    filter "system:linux or system:macosx"
        buildoptions { "-fPIC" }

    filter "configurations:Debug"
        defines { "DEBUG" }
        symbols "On"
    filter "configurations:Release"
        defines { "NDEBUG" }
        optimize "On"
        symbols "Off"
