pub const Renderer = opaque {
    pub fn init(raw_layer: *anyopaque, width: u32, height: u32) ?*Renderer {
        return metal_create(raw_layer, width, height);
    }

    pub fn resize(renderer: *Renderer, width: u32, height: u32) void {
        metal_resize(renderer, width, height);
    }

    pub fn deinit(renderer: *Renderer) void {
        metal_destroy(renderer);
    }
};
pub const ShaderLibrary = opaque {
    pub fn init(
        renderer: *Renderer,
        sources: []const ShaderSource,
    ) ?*ShaderLibrary {
        return metal_create_shader_library(renderer, sources.ptr, sources.len);
    }

    pub fn deinit(library: *ShaderLibrary) void {
        metal_destroy_shader_library(library);
    }
};
pub const RenderPipeline = opaque {
    pub fn init(
        renderer: *Renderer,
        library: *ShaderLibrary,
        vertex_name: [*:0]const u8,
        fragment_name: [*:0]const u8,
    ) ?*RenderPipeline {
        return metal_create_render_pipeline(
            renderer,
            library,
            vertex_name,
            fragment_name,
        );
    }

    pub fn deinit(pipeline: *RenderPipeline) void {
        metal_destroy_render_pipeline(pipeline);
    }
};
pub const ComputePipeline = opaque {
    pub fn init(
        renderer: *Renderer,
        library: *ShaderLibrary,
        kernel_name: [*:0]const u8,
    ) ?*ComputePipeline {
        return metal_create_compute_pipeline(renderer, library, kernel_name);
    }

    pub fn deinit(pipeline: *ComputePipeline) void {
        metal_destroy_compute_pipeline(pipeline);
    }
};
pub const Buffer = opaque {
    pub fn init(
        renderer: *Renderer,
        data: ?*const anyopaque,
        size: usize,
    ) ?*Buffer {
        return metal_create_buffer(renderer, data, size);
    }

    pub fn write(buffer: *Buffer, data: *const anyopaque, size: usize) void {
        metal_buffer_write(buffer, data, size);
    }

    pub fn deinit(buffer: *Buffer) void {
        metal_destroy_buffer(buffer);
    }
};
pub const Texture = opaque {
    pub fn init(renderer: *Renderer, desc: *const TextureDesc) ?*Texture {
        return metal_create_texture(renderer, desc);
    }

    pub fn deinit(texture: *Texture) void {
        metal_destroy_texture(texture);
    }
};
pub const Frame = opaque {
    pub fn init(renderer: *Renderer) ?*Frame {
        return metal_begin_frame(renderer);
    }

    pub fn present(frame: *Frame) void {
        metal_present(frame);
    }
};
pub const RenderPass = opaque {
    pub fn init(frame: *Frame, r: f64, g: f64, b: f64, a: f64) ?*RenderPass {
        return metal_begin_render_pass(frame, r, g, b, a);
    }

    pub fn setPipeline(pass: *RenderPass, pipeline: *RenderPipeline) void {
        metal_render_pass_set_pipeline(pass, pipeline);
    }

    pub fn setVertexBuffer(pass: *RenderPass, slot: u32, buffer: *Buffer) void {
        metal_render_pass_set_vertex_buffer(pass, slot, buffer);
    }

    pub fn setFragmentBuffer(
        pass: *RenderPass,
        slot: u32,
        buffer: *Buffer,
    ) void {
        metal_render_pass_set_fragment_buffer(pass, slot, buffer);
    }

    pub fn setFragmentTexture(
        pass: *RenderPass,
        slot: u32,
        texture: *Texture,
    ) void {
        metal_render_pass_set_fragment_texture(pass, slot, texture);
    }

    pub fn draw(pass: *RenderPass, vertex_count: u32) void {
        metal_render_pass_draw(pass, vertex_count);
    }

    pub fn end(pass: *RenderPass) void {
        metal_end_render_pass(pass);
    }
};
pub const ComputePass = opaque {
    pub fn init(frame: *Frame) ?*ComputePass {
        return metal_begin_compute_pass(frame);
    }

    pub fn setPipeline(pass: *ComputePass, pipeline: *ComputePipeline) void {
        metal_compute_pass_set_pipeline(pass, pipeline);
    }

    pub fn setBuffer(pass: *ComputePass, slot: u32, buffer: *Buffer) void {
        metal_compute_pass_set_buffer(pass, slot, buffer);
    }

    pub fn setTexture(pass: *ComputePass, slot: u32, texture: *Texture) void {
        metal_compute_pass_set_texture(pass, slot, texture);
    }

    pub fn dispatch(pass: *ComputePass, width: u32, height: u32, depth: u32) void {
        metal_compute_pass_dispatch(pass, width, height, depth);
    }

    pub fn end(pass: *ComputePass) void {
        metal_end_compute_pass(pass);
    }
};

pub const ShaderSource = extern struct {
    source: [*]const u8,
    source_len: usize,
};
pub const TextureFormat = enum(c_int) {
    bgra8_unorm,
    rgba8_unorm,
    rgba16_float,
    rgba32_float,
    r32_float,
    depth32_float,
};
pub const TextureUsage = packed struct(u32) {
    shader_read: bool = false,
    shader_write: bool = false,
    render_target: bool = false,
    depth_stencil: bool = false,
    _: u28 = 0,
};
pub const TextureDesc = extern struct {
    width: u32,
    height: u32,
    mip_count: u32 = 1,
    sample_count: u32 = 1,
    format: TextureFormat,
    usage: u32,
};

extern fn metal_create(raw_layer: *anyopaque, width: u32, height: u32) ?*Renderer;
extern fn metal_resize(renderer: *Renderer, width: u32, height: u32) void;
extern fn metal_destroy(renderer: *Renderer) void;

extern fn metal_create_shader_library(
    renderer: *Renderer,
    sources: [*]const ShaderSource,
    source_count: usize,
) ?*ShaderLibrary;
extern fn metal_destroy_shader_library(library: *ShaderLibrary) void;

extern fn metal_create_render_pipeline(
    renderer: *Renderer,
    library: *ShaderLibrary,
    vertex_name: [*:0]const u8,
    fragment_name: [*:0]const u8,
) ?*RenderPipeline;
extern fn metal_destroy_render_pipeline(pipeline: *RenderPipeline) void;

extern fn metal_create_compute_pipeline(
    renderer: *Renderer,
    library: *ShaderLibrary,
    kernel_name: [*:0]const u8,
) ?*ComputePipeline;
extern fn metal_destroy_compute_pipeline(pipeline: *ComputePipeline) void;

extern fn metal_create_buffer(
    renderer: *Renderer,
    data: ?*const anyopaque,
    size: usize,
) ?*Buffer;
extern fn metal_buffer_write(buffer: *Buffer, data: *const anyopaque, size: usize) void;
extern fn metal_destroy_buffer(buffer: *Buffer) void;

extern fn metal_create_texture(renderer: *Renderer, desc: *const TextureDesc) ?*Texture;
extern fn metal_destroy_texture(texture: *Texture) void;

extern fn metal_begin_frame(renderer: *Renderer) ?*Frame;
extern fn metal_begin_render_pass(
    frame: *Frame,
    r: f64,
    g: f64,
    b: f64,
    a: f64,
) ?*RenderPass;
extern fn metal_render_pass_set_pipeline(pass: *RenderPass, pipeline: *RenderPipeline) void;
extern fn metal_render_pass_set_vertex_buffer(pass: *RenderPass, slot: u32, buffer: *Buffer) void;
extern fn metal_render_pass_set_fragment_buffer(pass: *RenderPass, slot: u32, buffer: *Buffer) void;
extern fn metal_render_pass_set_fragment_texture(pass: *RenderPass, slot: u32, texture: *Texture) void;
extern fn metal_render_pass_draw(pass: *RenderPass, vertex_count: u32) void;
extern fn metal_end_render_pass(pass: *RenderPass) void;

extern fn metal_begin_compute_pass(frame: *Frame) ?*ComputePass;
extern fn metal_compute_pass_set_pipeline(pass: *ComputePass, pipeline: *ComputePipeline) void;
extern fn metal_compute_pass_set_buffer(pass: *ComputePass, slot: u32, buffer: *Buffer) void;
extern fn metal_compute_pass_set_texture(pass: *ComputePass, slot: u32, texture: *Texture) void;
extern fn metal_compute_pass_dispatch(pass: *ComputePass, width: u32, height: u32, depth: u32) void;
extern fn metal_end_compute_pass(pass: *ComputePass) void;

extern fn metal_present(frame: *Frame) void;
