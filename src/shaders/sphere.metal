#ifndef ZEN_SPHERE_METAL
#define ZEN_SPHERE_METAL

#include <metal_stdlib>
using namespace metal;

#include "interval.metal"
#include "ray.metal"
#include "hit_record.metal"

struct Sphere {
    float3 center;
    float radius;
    uint material_index;

    bool hit(
        Ray ray,
        Interval ray_t,
        thread HitRecord& rec
    ) const {
        float3 oc = center - ray.origin;

        float a = length_squared(ray.direction);
        float h = dot(ray.direction, oc);
        float c = length_squared(oc) - radius * radius;

        float discriminant = h * h - a * c;
        if (discriminant < 0.0) {
            return false;
        }

        float sqrtd = sqrt(discriminant);

        float root = (h - sqrtd) / a;
        if (!ray_t.surrounds(root)) {
            root = (h + sqrtd) / a;
            if (!ray_t.surrounds(root)) {
                return false;
            }
        }

        rec.t = root;
        rec.point = ray.at(rec.t);
        rec.material_index = material_index;

        float3 outward_normal = (rec.point - center) / radius;
        rec.set_face_normal(ray, outward_normal);

        return true;
    }
};

#endif
