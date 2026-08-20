#ifndef ZEN_WORLD_METAL
#define ZEN_WORLD_METAL

#include <metal_stdlib>
using namespace metal;

#include "interval.metal"
#include "ray.metal"
#include "hit_record.metal"
#include "sphere.metal"

struct World {
    constant Sphere* spheres;
    uint sphere_count;

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

    float3 trace(Ray ray) {
        HitRecord rec;

        if (hit(ray, Interval(0.001, INFINITY), rec)) {
            return 0.5 * (rec.normal + float3(1.0));
        }

        float3 unit_direction = normalize(ray.direction);
        float a = 0.5 * (unit_direction.y + 1.0);

        return (1.0 - a) * float3(1.0, 1.0, 1.0) + a * float3(0.5, 0.7, 1.0);
    }
};

#endif
