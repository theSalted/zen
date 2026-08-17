# zen

## Requirements

- Zig 0.16.0+
- CMake 3.16+ (to build SDL)

## Building

```sh
git clone --recurse-submodules <repo-url>
cd zen

# If you already cloned without submodules:
git submodule update --init

# Build SDL (one-time; rerun after updating the submodule)
zig build vendor

# Build and run the app
zig build run

# Run tests
zig build test
```
