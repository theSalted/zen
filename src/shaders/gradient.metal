
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};


//unused
kernel void gradient_kernel(
    texture2d<float, access::write> image [[texture(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint width = image.get_width();
    uint height = image.get_height();

    if (gid.x >= width || gid.y >= height) {
        return;
    }

    float r = float(gid.x) / float(width - 1);
    float g = float(gid.y) / float(height - 1);

    image.write(metal::float4(r, g, 0.0, 1.0), gid);
}

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

// ray
struct Ray {
    float3 origin;
    float3 direction;
};

struct HitRecord {
    float3 point;
    float3 normal;
    float t;
};

struct Sphere {
    float3 center;
    float radius;
};

float3 ray_position_at(Ray ray, float t) {
    return ray.origin + t * ray.direction;
}

bool sphere_hit(
    Sphere sphere,
    Ray ray,
    float ray_tmin,
    float ray_tmax,
    thread HitRecord& rec
) {
    float3 oc = sphere.center - ray.origin;

    float a = length_squared(ray.direction);
    float h = dot(ray.direction, oc);
    float c = length_squared(oc) - sphere.radius * sphere.radius;

    float discriminant = h * h - a * c;
    if (discriminant < 0.0) {
        return false;
    }

    float sqrtd = sqrt(discriminant);

    float root = (h - sqrtd) / a;
    if (root <= ray_tmin || ray_tmax <= root) {
        root = (h + sqrtd) / a;
        if (root <= ray_tmin || ray_tmax <= root) {
            return false;
        }
    }

    rec.t = root;
    rec.point = ray_position_at(ray, rec.t);
    rec.normal = (rec.point - sphere.center) / sphere.radius;

    return true;
}

bool hit_world(
    Ray ray,
    float ray_tmin,
    float ray_tmax,
    constant Sphere* spheres,
    uint sphere_count,
    thread HitRecord& rec
) {
    HitRecord temp_rec;
    bool hit_anything = false;
    float closet_so_far = ray_tmax;

    for (uint i = 0; i < sphere_count; i += 1) {
        if (sphere_hit(spheres[i], ray, ray_tmin, closet_so_far, temp_rec)) {
            hit_anything = true;
            closet_so_far = temp_rec.t;
            rec = temp_rec;
        }
    }

    return hit_anything;
}

float3 trace_ray(Ray ray, constant Sphere* spheres, uint sphere_count) {
    HitRecord rec;

    if (hit_world(ray, 0.001, INFINITY, spheres, sphere_count, rec)) {
        return 0.5 * (rec.normal + float3(1.0));
    }

    float3 unit_direction = normalize(ray.direction);
    float a = 0.5 * (unit_direction.y + 1.0);

    return (1.0 - a) * float3(1.0, 1.0, 1.0) + a * float3(0.5, 0.7, 1.0);
}

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

    float3 pixel_center = input.viewport_upper_left + (gid.x + 0.5) * input.pixel_delta_u + (gid.y + 0.5) * input.pixel_delta_v;
    float3 camera_center = pixel_center - input.camera_center;
    Ray ray = {input.camera_center, camera_center};
    float3 color = trace_ray(ray, spheres, input.sphere_count);

    image.write(float4(color, 1.0), gid);
}
