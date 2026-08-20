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
            float3 attenuation = float3(1.0);

            for (int i = 0; i < depth; i++) {
                HitRecord rec;
                if (!hit(ray, Interval(0.001, INFINITY), rec)) {
                    return attenuation * sky(ray.direction);
                }

                Material mat = materials[rec.material_index];
                Ray scattered;
                float3 bounce_attenuation;

                if (!Material::scatter(mat, ray, rec, prng, scattered, bounce_attenuation)) {
                    return float3(0.0);
                }

                ray = scattered;
                attenuation *= bounce_attenuation;
            }

            return float3(0.0);
        }

        float3 sky(float3 direction) {
            float3 unit_direction = normalize(direction);
            float a = 0.5 * (unit_direction.y + 1.0);

            return (1.0 - a) * float3(1.0, 1.0, 1.0) + a * float3(0.5, 0.7, 1.0);
        }

};

#endif
