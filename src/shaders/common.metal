#ifndef ZEN_COMMON_METAL
#define ZEN_COMMON_METAL

#include <metal_stdlib>
using namespace metal;

float degree_to_radians(float degrees) {
    return degrees * M_PI_F / 180.0;
}

#endif
