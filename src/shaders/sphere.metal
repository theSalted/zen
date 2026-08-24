#ifndef ZEN_SPHERE_METAL
#define ZEN_SPHERE_METAL

#include <metal_stdlib>
using namespace metal;

#include "interval.metal"
#include "ray.metal"
#include "hit_record.metal"

struct Sphere {
    Ray center;
    float radius;
    uint material_index;

    Sphere(float3 static_center, float radius, uint material_index) :
        center(static_center, float3(0.0, 0.0, 0.0), 0.0),
        radius(fmax(0.0, radius)),
        material_index(material_index) {}
    Sphere(float3 center1, float3 center2, float radius, uint material_index) :
        center(center1, center2 - center1, 0.0),
        radius(fmax(0.0, radius)),
        material_index(material_index) {}

    bool hit(
        Ray ray,
        Interval ray_t,
        thread HitRecord& rec
    ) const {
        float3 current_center = center.at(ray.time);
        float3 oc = current_center - ray.origin;

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

        float3 outward_normal = (rec.point - current_center) / radius;
        rec.set_face_normal(ray, outward_normal);

        return true;
    }
};

#endif
