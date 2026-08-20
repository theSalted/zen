#ifndef ZEN_HIT_RECORD_METAL
#define ZEN_HIT_RECORD_METAL

#include <metal_stdlib>
using namespace metal;

#include "ray.metal"

struct HitRecord {
    float3 point;
    float3 normal;
    float t;
    bool front_face;

    void set_face_normal(Ray ray, float3 outward_normal) {
        front_face = dot(ray.direction, outward_normal) < 0;
        normal = front_face ? outward_normal : -outward_normal;
    }
};

#endif
