# Odin VMA

Bindings for [Vulkan Memory Allocator][] **v3.2.0** in [Odin Programming Language][].

## Basic Usage

Copy the `vma` folder to your project or `shared` directory.

```odin
vma_vulkan_functions := vma.create_vulkan_functions()

allocator_create_info: vma.Allocator_Create_Info = {
    flags = {.Buffer_Device_Address},
    instance = instance,
    vulkan_api_version = 1003000, // 1.3
    physical_device = physical_device,
    device = device,
    vulkan_functions = &vma_vulkan_functions,
}

allocator: vma.Allocator = ---
if res := vma.create_allocator(allocator_create_info, &allocator); res != .SUCCESS {
    log.errorf("Failed to Create Vulkan Memory Allocator: [%v]", res)
    return
}

defer vma.destroy_allocator(allocator)
```

## Building VMA

Precompiled binaries are not available, but you can easily compile the library using the
provided scripts.

Requirement:

- `git` - Must be in the PATH
- `Vulkan SDK` - You can get from [LunarXchange](https://vulkan.lunarg.com/)

Follow the steps below to build VMA:

1. **Using CMake**:
   Define the `VMA_VULKAN_VERSION` option to specify the desired Vulkan version in the API
   format (e.g., `1003000` for Vulkan 1.3).

2. **Build Using Scripts**:
   Use the provided build scripts to compile the project.
   - **Windows**: Run `build.bat` with the minor version as the first argument (e.g.,
     `build.bat 3` for Vulkan 1.3).
   - **Linux/macOS**:
     - Make the script executable by running:

       ```bash
       chmod +x build.sh
       ```

     - Run `build.sh` with the minor version as the first argument (e.g., `build.sh 3` for
       Vulkan 1.3).

## Naming Conventions

Types and values follow the [Odin Naming Convention][]. In general, `Ada_Case` for types and
`snake_case` for values

|                    | Case                                |
| ------------------ | ----------------------------------- |
| Import Name        | snake_case (but prefer single word) |
| Types              | Ada_Case                            |
| Enum Values        | Ada_Case                            |
| Procedures         | snake_case                          |
| Local Variables    | snake_case                          |
| Constant Variables | SCREAMING_SNAKE_CASE                |

## License

MIT License - See [LICENSE](./LICENSE) file for details.

[Vulkan Memory Allocator]: https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator
[Odin Programming Language]: https://odin-lang.org/
[Odin Naming Convention]: https://github.com/odin-lang/Odin/wiki/Naming-Convention
