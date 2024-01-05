# Odin VMA

Bindings for [Vulkan Memory Allocator](https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator) in Odin Programming Language.

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

if res := vma.create_allocator(&allocator_create_info, &allocator); res != .SUCCESS {
    log.errorf("Failed to Create Vulkan Memory Allocator: [%v]", res)
    return
}

defer vma.destroy_allocator(allocator)
```

## Binaries

The bindings comes with precompiled binary for Windows and Linux x64, you can find the libs in the `vma/lib` folder.

There is a `CMakeLists.txt` that you can use to build yourself.

## Naming Conventions

Types and values follow the [Odin Naming Convention](https://github.com/odin-lang/Odin/wiki/Naming-Convention). In general, `Ada_Case` for types and `snake_case` for values

|                    | Case                                |
| ------------------ | ----------------------------------- |
| Import Name        | snake_case (but prefer single word) |
| Types              | Ada_Case                            |
| Enum Values        | Ada_Case                            |
| Procedures         | snake_case                          |
| Local Variables    | snake_case                          |
| Constant Variables | SCREAMING_SNAKE_CASE                |

## License

MIT license.
