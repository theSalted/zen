#ifndef ZEN_RAY_METAL
#define ZEN_RAY_METAL

#include <metal_stdlib>
using namespace metal;

struct Ray {
    float3 origin;
    float3 direction;

    float3 at(float t) {
        return origin + t * direction;
    }
};

#endif
