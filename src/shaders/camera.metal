#ifndef ZEN_CAMERA_METAL
#define ZEN_CAMERA_METAL

#include <metal_stdlib>
using namespace metal;

#include "ray.metal"
#include "world.metal"
#include "prng.metal"

struct Camera {
    float3 camera_center;
    float3 pixel_delta_u;
    float3 pixel_delta_v;
    float3 viewport_upper_left;
    int samples_per_pixel = 30;

    float3 render(World world, uint2 gid) {
        float3 color = float3(0.0);
        for (int i = 0; i < samples_per_pixel; i++) {
            Ray ray = get_ray(gid, uint(i));
            color += world.trace(ray, gid, uint(i));
        }
        color /= float(samples_per_pixel);
        color = linear_to_gamma(color);
        color = clamp(color, float3(0.0), float3(1.0));
        return color;
    }

    private:
        Ray get_ray(uint2 gid, uint sample_index) {
            float3 offset = sample_square(gid, sample_index);

            float3 pixel_center =
                viewport_upper_left
                + (float(gid.x) + 0.5 + offset.x) * pixel_delta_u
                + (float(gid.y) + 0.5 + offset.y) * pixel_delta_v;

            float3 ray_origin = camera_center;
            float3 ray_direction = pixel_center - camera_center;

            return {ray_origin, ray_direction};
        }

        float3 sample_square(uint2 seed, uint sample_index) {
            PRNG prng = PRNG(seed.x, seed.y, sample_index);
            return float3(prng.rand() - 0.5, prng.rand() - 0.5, 0.0);
        }

        float ltog(float linear) {
            if (linear > 0) {
                return sqrt(linear);
            }
            return 0;
        }

        float3 linear_to_gamma(float3 linear_color) {
            linear_color.x = ltog(linear_color.x);
            linear_color.y = ltog(linear_color.y);
            linear_color.z = ltog(linear_color.z);
            return linear_color;
        }
};

#endif
