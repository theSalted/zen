#ifndef ZEN_CAMERA_METAL
#define ZEN_CAMERA_METAL

#include <metal_stdlib>
using namespace metal;

#include "ray.metal"
#include "scene.metal"
#include "prng.metal"

struct Camera {
    float3 camera_center;
    float3 pixel_delta_u;
    float3 pixel_delta_v;
    float defocus_angle;
    float focus_dist;
    float3 defocus_disk_u;
    float3 defocus_disk_v;
    float3 viewport_upper_left;
    uint samples_per_pixel;
    uint ray_depth;

    float3 render(Scene scene, uint2 gid) {
        float3 color = float3(0.0);
        for (uint i = 0; i < samples_per_pixel; i++) {
            Ray ray = get_ray(gid, uint(i));
            color += scene.trace(ray, gid, uint(i), ray_depth);
        }
        color /= float(samples_per_pixel);
        color = linear_to_gamma(color);
        color = clamp(color, float3(0.0), float3(1.0));
        return color;
    }

    private:
        Ray get_ray(uint2 gid, uint sample_index) {
            PRNG prng = PRNG(gid.x, gid.y, sample_index);
            float3 offset = sample_square(prng);

            float3 pixel_center =
                viewport_upper_left
                + (float(gid.x) + 0.5 + offset.x) * pixel_delta_u
                + (float(gid.y) + 0.5 + offset.y) * pixel_delta_v;

            float3 ray_origin = (defocus_angle <= 0) ? camera_center : defocus_disk_sample(prng);
            float3 ray_direction = pixel_center - ray_origin;
            float ray_time = prng.rand();


            return {ray_origin, ray_direction, ray_time};
        }

        float3 defocus_disk_sample(thread PRNG& prng) const {
            float3 p = random_in_unit_disk(prng);
            return camera_center + (p[0] * defocus_disk_u) + (p[1] * defocus_disk_v);
        }

        float3 random_in_unit_disk(thread PRNG& prng) const {
            uint max_depth = 10;

            for (uint i = 0; i < max_depth; ++i) {
                float3 p = float3(prng.rand(-1.0, 1.0), prng.rand(-1.0, 1.0), 0.0);
                if (dot(p, p) < 1.0) {
                    return p;
                }
            }

            float r = sqrt(prng.rand());
            float theta = 2.0 * M_PI_F * prng.rand();

            return float3(r * cos(theta), r * sin(theta), 0.0);
        }

        float3 sample_square(thread PRNG& prng) {
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
