
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

float3 ray_position_at(Ray ray, float t) {
    return ray.origin + t * ray.direction;
}

float3 ray_color(Ray ray) {
    float3 unit_direction = ray.direction;
    float3 a = 0.5 * (unit_direction.y + 1.0);
    return (1.0 - a) * float3(1.0, 1.0, 1.0) + a * float3(0.5, 0.7, 1.0);
}

struct RayTraceInput {
    uint image_width;
    uint image_height;

    float3 camera_center;
    float3 pixel_delta_u;
    float3 pixel_delta_v;
    float3 viewport_upper_left;
};

kernel void ray_trace_kernel(
    texture2d<float, access::write> image [[texture(0)]],
    constant RayTraceInput& input [[buffer(0)]],
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
    float3 color = ray_color(ray);

    image.write(metal::float4(color.x, color.y, color.z, 1.0), gid);
}
