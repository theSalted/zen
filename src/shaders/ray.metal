#ifndef ZEN_RAY_METAL
#define ZEN_RAY_METAL

#include <metal_stdlib>
using namespace metal;

struct Ray {
    float3 origin;
    float3 direction;
    float time;

    Ray() {}

    Ray(float3 origin, float3 direction): origin(origin), direction(direction), time(0.0) {}

    Ray(float3 origin, float3 direction, float time): origin(origin), direction(direction), time(time) {}

    float3 at(float t) const {
        return origin + t * direction;
    }
};

#endif
