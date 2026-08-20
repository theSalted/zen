#ifndef ZEN_CAMERA_METAL
#define ZEN_CAMERA_METAL

#include <metal_stdlib>
using namespace metal;

#include "ray.metal"

struct Camera {
    float3 camera_center;
    float3 pixel_delta_u;
    float3 pixel_delta_v;
    float3 viewport_upper_left;

    Ray get_ray(uint2 gid) const {
        float3 pixel_center =
            viewport_upper_left
            + (float(gid.x) + 0.5) * pixel_delta_u
            + (float(gid.y) + 0.5) * pixel_delta_v;

        return {camera_center, pixel_center - camera_center};
    }
};

#endif
