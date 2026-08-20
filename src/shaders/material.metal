#ifndef ZEN_MATERIAL_METAL
#define ZEN_MATERIAL_METAL

#include <metal_stdlib>
using namespace metal;

#include "hit_record.metal"
#include "prng.metal"

enum MaterialType: uint {
    Lambertian = 0,
    Metal = 1,
    Dialectric = 2,
};

struct Material {
    uint type;
    float3 albedo;
    float fuzz;
    float refraction_index;

    static bool scatter(
        Material mat,
        Ray ray_in,
        HitRecord rec,
        thread PRNG& prng,
        thread Ray& scattered,
        thread float3& attenuation
    ) {
        switch (mat.type) {
            case Lambertian:
                return lambertian(mat, rec, prng, scattered, attenuation);

            case Metal:
                return metal(mat, ray_in, rec, prng, scattered, attenuation);

            case Dialectric:
                return dialectric(mat, ray_in, rec, prng, scattered, attenuation);

            default:
                return false;
        }
    }

    static bool lambertian(
        Material mat,
        HitRecord rec,
        thread PRNG& prng,
        thread Ray& scattered,
        thread float3& attenuation
    ) {
        float3 direction = rec.normal + prng.rand_unit_vector();
        if (near_zero(direction)) {
            direction = rec.normal;
        }

        scattered = Ray{rec.point, direction};
        attenuation = mat.albedo;

        return true;
    }

    static bool metal(
        Material mat,
        Ray ray_in,
        HitRecord rec,
        thread PRNG& prng,
        thread Ray& scattered,
        thread float3& attenuation
    ) {
        float3 reflected = reflect(normalize(ray_in.direction), rec.normal);
        reflected = normalize(reflected) + mat.fuzz * prng.rand_unit_vector();

        scattered = Ray{rec.point, reflected};
        attenuation = mat.albedo;

        return dot(scattered.direction, rec.normal) > 0.0;
    }

    static bool dialectric(
        Material mat,
        Ray ray_in,
        HitRecord rec,
        thread PRNG& prng,
        thread Ray& scattered,
        thread float3& attenuation
    ) {
        attenuation = float3(1.0);

        float ri = rec.front_face
            ? 1.0 / mat.refraction_index
            : mat.refraction_index;

        float3 unit_direction = normalize(ray_in.direction);

        float cos_theta = fmin(dot(-unit_direction, rec.normal), 1.0);
        float sin_theta = sqrt(1.0 - cos_theta * cos_theta);

        bool cannot_refract = ri * sin_theta > 1.0;
        float3 direction;

        if (cannot_refract || reflectance(cos_theta, ri) > prng.rand())
            direction = reflect(unit_direction, rec.normal);
        else
            direction = refract(unit_direction, rec.normal, ri);

        scattered = Ray{rec.point, direction};

        return true;
    }

    static bool near_zero(float3 v) {
        float s = 1e-8;
        return abs(v.x) < s && abs(v.y) < s && abs(v.z) < s;
    }

    static float reflectance(float cosine, float refraction_index) {
        float r0 = (1 - refraction_index) / (1 + refraction_index);
        r0 = r0*r0;
        return r0 + (1 - r0) * pow((1 - cosine), 5);
    }
};

#endif
