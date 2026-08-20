#ifndef ZEN_WORLD_METAL
#define ZEN_WORLD_METAL

#include <metal_stdlib>
using namespace metal;

#include "interval.metal"
#include "ray.metal"
#include "hit_record.metal"
#include "sphere.metal"
#include "prng.metal"
#include "material.metal"

struct World {
    constant Sphere* spheres;
    uint sphere_count;
    constant Material* materials;
    uint material_count;

    bool hit(
        Ray ray,
        Interval ray_t,
        thread HitRecord& rec
    ) {
        HitRecord temp_rec;
        bool hit_anything = false;
        float closest_so_far = ray_t.max;

        for (uint i = 0; i < sphere_count; i += 1) {
            Sphere sphere = spheres[i];

            if (sphere.hit(ray, Interval(ray_t.min, closest_so_far), temp_rec)) {
                hit_anything = true;
                closest_so_far = temp_rec.t;
                rec = temp_rec;
            }
        }

        return hit_anything;
    }

    float3 trace(Ray ray, uint2 gid, uint sample_index) {
        PRNG prng = PRNG(gid.x, gid.y, sample_index);
        return trace(ray, prng, 10);
    }

    private:
        float3 trace(Ray ray, thread PRNG& prng, int depth) {
            if (depth <= 0) {
                return float3(0.0);
            }

            HitRecord rec;

            if (hit(ray, Interval(0.001, INFINITY), rec)) {
                Material mat = materials[rec.material_index];
                if (mat.type == Lambertian) {
                    float3 direction = rec.normal + prng.rand_unit_vector();
                    if (near_zero(direction)) {
                        direction = rec.normal;
                    }
                    Ray scattered = Ray{rec.point, direction};
                    float3 attenuation = mat.albedo;
                    return attenuation * trace(scattered, prng, depth - 1);
                }

                return float3(1.0, 0.0, 1.0);
            }

            // sky
            float3 unit_direction = normalize(ray.direction);
            float a = 0.5 * (unit_direction.y + 1.0);

            return (1.0 - a) * float3(1.0, 1.0, 1.0) + a * float3(0.5, 0.7, 1.0);
        }

        bool near_zero(float3 v) {
            float s = 1e-8;
            return abs(v.x) < s && abs(v.y) < s && abs(v.z) < s;
        }
};

#endif
