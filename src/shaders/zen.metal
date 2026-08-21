#include <metal_stdlib>
using namespace metal;

#include "common.metal"
#include "prng.metal"
#include "interval.metal"
#include "ray.metal"
#include "hit_record.metal"
#include "sphere.metal"
#include "world.metal"
#include "camera.metal"
#include "material.metal"

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
    //constexpr sampler s(address::clamp_to_edge, filter::nearest);
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float3 color = image.sample(s, in.uv).rgb;
    //color = floor(color * 24.0) / 24.0;
    return float4(color, 1.0);
}

struct RayTraceInput {
    uint image_width;
    uint image_height;

    float3 camera_center;
    float3 pixel_delta_u;
    float3 pixel_delta_v;
    float3 viewport_upper_left;

    uint sphere_count;
    uint material_count;
};

kernel void ray_trace_kernel(
    texture2d<float, access::write> image [[texture(0)]],
    constant RayTraceInput& input [[buffer(0)]],
    constant Sphere* spheres [[buffer(1)]],
    constant Material* materials [[buffer(2)]],
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

    World world = {spheres, input.sphere_count, materials, input.material_count};

    float3 color = camera.render(world, gid);
    image.write(float4(color, 1.0), gid);
}
