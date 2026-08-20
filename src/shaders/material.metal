#ifndef ZEN_MATERIAL_METAL
#define ZEN_MATERIAL_METAL

#include <metal_stdlib>
using namespace metal;

enum MaterialType: uint {
    Lambertian = 0,
};

struct Material {
    uint type;
    float3 albedo;
    float fuzz;
    float refraction_index;
};

#endif
