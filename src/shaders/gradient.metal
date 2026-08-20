
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

// utility
float degree_to_radians(float degrees) {
    return degrees * M_PI_F / 180.0;
}


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
        float ray_tmin,
        float ray_tmax,
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
        if (root <= ray_tmin || ray_tmax <= root) {
            root = (h + sqrtd) / a;
            if (root <= ray_tmin || ray_tmax <= root) {
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
        float ray_tmin,
        float ray_tmax,
        thread HitRecord& rec
    ) {
        HitRecord temp_rec;
        bool hit_anything = false;
        float closest_so_far = ray_tmax;

        for (uint i = 0; i < sphere_count; i += 1) {
            Sphere sphere = spheres[i];

            if (sphere.hit(ray, ray_tmin, closest_so_far, temp_rec)) {
                hit_anything = true;
                closest_so_far = temp_rec.t;
                rec = temp_rec;
            }
        }

        return hit_anything;
    }

    float3 trace(Ray ray) {
        HitRecord rec;

        if (hit(ray, 0.001, INFINITY, rec)) {
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
