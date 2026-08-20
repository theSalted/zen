#ifndef ZEN_PRNG_METAL
#define ZEN_PRNG_METAL

#include <metal_stdlib>
using namespace metal;

struct PRNG {
    float seed;

    unsigned TausStep(const unsigned z, const int s1, const int s2, const int s3, const unsigned M)
    {
        unsigned b=(((z << s1) ^ z) >> s2);
        return (((z & M) << s3) ^ b);
    }

    PRNG(const unsigned seed1, const unsigned seed2, const unsigned seed3) {
        unsigned seed = seed1 * 1099087573UL;
        unsigned seedb = seed2 * 1099087573UL;
        unsigned seedc = seed3 * 1099087573UL;

        unsigned z1 = TausStep(seed,13,19,12,429496729UL);
        unsigned z2 = TausStep(seed,2,25,4,4294967288UL);
        unsigned z3 = TausStep(seed,3,11,17,429496280UL);
        unsigned z4 = (1664525*seed + 1013904223UL);

        unsigned r1 = (z1^z2^z3^z4^seedb);

        z1 = TausStep(r1,13,19,12,429496729UL);
        z2 = TausStep(r1,2,25,4,4294967288UL);
        z3 = TausStep(r1,3,11,17,429496280UL);
        z4 = (1664525*r1 + 1013904223UL);

        r1 = (z1^z2^z3^z4^seedc);

        z1 = TausStep(r1,13,19,12,429496729UL);
        z2 = TausStep(r1,2,25,4,4294967288UL);
        z3 = TausStep(r1,3,11,17,429496280UL);
        z4 = (1664525*r1 + 1013904223UL);

        this->seed = (z1^z2^z3^z4) * 2.3283064365387e-10;
    }

    float rand() {
        unsigned hashed_seed = this->seed * 1099087573UL;

        unsigned z1 = TausStep(hashed_seed,13,19,12,429496729UL);
        unsigned z2 = TausStep(hashed_seed,2,25,4,4294967288UL);
        unsigned z3 = TausStep(hashed_seed,3,11,17,429496280UL);
        unsigned z4 = (1664525*hashed_seed + 1013904223UL);

        float old_seed = this->seed;

        this->seed = (z1^z2^z3^z4) * 2.3283064365387e-10;

        return old_seed;
    }

    float rand(float min, float max) {
        return min + (max - min) * rand();
    }

    float3 rand3() {
        return float3(rand(), rand(), rand());
    }

    float3 rand3(float min, float max) {
        return float3(rand(min, max), rand(min, max), rand(min, max));
    }

    float3 rand_unit_vector() {
        for (int i = 0; i < 100; i++) {
            float3 p = rand3(-1, 1);
            float lensq = length_squared(p);

            if (1e-8 < lensq && lensq <= 1)
                return p / sqrt(lensq);
        }

        return float3(1.0, 0.0, 0.0);
    }

    float3 rand_on_hemisphere(float3 normal) {
        float3 on_unit_sphere = rand_unit_vector();
        if (dot(on_unit_sphere, normal) > 0.0)
            return on_unit_sphere;
        else
            return -on_unit_sphere;
    }
};

#endif
