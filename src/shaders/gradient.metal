
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut vertex_main(uint vertex_id [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2(3.0, -1.0),
        float2(-1.0, 3.0),
    };

    float2 uvs[3] = {
        float2(0.0, 1.0),
        float2(2.0, 1.0),
        float2(0.0, -1.0),
    };
    VertexOut out;
    out.position = float4(positions[vertex_id], 0.0, 1.0);
    out.uv = uvs[vertex_id];

    return out;
}

fragment float4 fragment_main(
    VertexOut in [[stage_in]],
    texture2d<float> image [[texture(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::nearest);
    return image.sample(s, in.uv);
}

// utility
float degree_to_radians(float degrees) {
    return degrees * M_PI_F / 180.0;
}


// courtesy of https://github.com/YVin3D/Loki
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

        // Round 1: Randomise seed
        unsigned z1 = TausStep(seed,13,19,12,429496729UL);
        unsigned z2 = TausStep(seed,2,25,4,4294967288UL);
        unsigned z3 = TausStep(seed,3,11,17,429496280UL);
        unsigned z4 = (1664525*seed + 1013904223UL);

        // Round 2: Randomise seed again using second seed
        unsigned r1 = (z1^z2^z3^z4^seedb);

        z1 = TausStep(r1,13,19,12,429496729UL);
        z2 = TausStep(r1,2,25,4,4294967288UL);
        z3 = TausStep(r1,3,11,17,429496280UL);
        z4 = (1664525*r1 + 1013904223UL);

        // Round 3: Randomise seed again using third seed
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

        thread float old_seed = this->seed;

        this->seed = (z1^z2^z3^z4) * 2.3283064365387e-10;

        return old_seed;
    }

    float rand(float min, float max) {
        return min + (max - min) * rand();
    }
};

struct Interval {
    float min;
    float max;

    Interval()
        : min(INFINITY), max(-INFINITY) {}

    Interval(float min_, float max_)
        : min(min_), max(max_) {}

    float size() const {
        return max - min;
    }

    bool contains(float x) const {
        return x >= min && x <= max;
    }

    bool surrounds(float x) const {
        return x > min && x < max;
    }

    static Interval empty() {
        return Interval(INFINITY, -INFINITY);
    }

    static Interval universe() {
        return Interval(-INFINITY, INFINITY);
    }
};

// ray
struct Ray {
    float3 origin;
    float3 direction;

    float3 at(float t) {
        return origin + t * direction;
    }
};

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

struct Sphere {
    float3 center;
    float radius;

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

        float3 outward_normal = (rec.point - center) / radius;
        rec.set_face_normal(ray, outward_normal);

        return true;
    }
};

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

struct Camera {
    float3 camera_center;
    float3 pixel_delta_u;
    float3 pixel_delta_v;
    float3 viewport_upper_left;

    Ray get_ray(uint2 gid) const {
        float3 pixel_center =
            viewport_upper_left
            + (float(gid.x) + 0.5) * pixel_delta_u
            + (float(gid.y) + 0.5) * pixel_delta_v;

        return {camera_center, pixel_center - camera_center};
    }
};

struct RayTraceInput {
    uint image_width;
    uint image_height;

    float3 camera_center;
    float3 pixel_delta_u;
    float3 pixel_delta_v;
    float3 viewport_upper_left;

    uint sphere_count;
};

kernel void ray_trace_kernel(
    texture2d<float, access::write> image [[texture(0)]],
    constant RayTraceInput& input [[buffer(0)]],
    constant Sphere* spheres [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint width = image.get_width();
    uint height = image.get_height();

    if (gid.x >= width || gid.y >= height) {
        return;
    }

    Camera camera = {
        input.camera_center,
        input.pixel_delta_u,
        input.pixel_delta_v,
        input.viewport_upper_left,
    };
    Ray ray = camera.get_ray(gid);

    World world = {spheres, input.sphere_count};
    float3 color = world.trace(ray);

    image.write(float4(color, 1.0), gid);
}
