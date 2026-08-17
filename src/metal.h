#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MetalRenderer MetalRenderer;
typedef struct MetalShaderLibrary MetalShaderLibrary;
typedef struct MetalRenderPipeline MetalRenderPipeline;
typedef struct MetalComputePipeline MetalComputePipeline;
typedef struct MetalBuffer MetalBuffer;
typedef struct MetalTexture MetalTexture;
typedef struct MetalFrame MetalFrame;
typedef struct MetalRenderPass MetalRenderPass;

typedef struct MetalShaderSource {
  const char *source;
  size_t source_len;
} MetalShaderSource;

MetalRenderer *metal_create(void *raw_layer, uint32_t width, uint32_t height);
void metal_resize(MetalRenderer *renderer, uint32_t width, uint32_t height);
void metal_destroy(MetalRenderer *renderer);

MetalShaderLibrary *metal_create_shader_library(MetalRenderer *renderer, const
MetalShaderSource *sources, size_t source_count);
void metal_destroy_shader_library(MetalShaderLibrary *library);

MetalRenderPipeline *metal_create_render_pipeline(MetalRenderer *renderer,
MetalShaderLibrary *library, const char *vertex_name, const char *fragment_name);
void metal_destroy_render_pipeline(MetalRenderPipeline *pipeline);

MetalComputePipeline *metal_create_compute_pipeline(MetalRenderer *renderer,
MetalShaderLibrary *library, const char *kernel_name);
void metal_destroy_compute_pipeline(MetalComputePipeline *pipeline);

MetalBuffer *metal_create_buffer(MetalRenderer *renderer, const void *data, size_t
size);
void metal_buffer_write(MetalBuffer *buffer, const void *data, size_t size);
void metal_destroy_buffer(MetalBuffer *buffer);

MetalTexture *metal_create_texture_2d(MetalRenderer *renderer, uint32_t width,
uint32_t height);
void metal_destroy_texture(MetalTexture *texture);

MetalFrame *metal_begin_frame(MetalRenderer *renderer);
MetalRenderPass *metal_begin_render_pass(MetalFrame *frame, double r, double g,
double b, double a);
void metal_render_pass_set_pipeline(MetalRenderPass *pass, MetalRenderPipeline
*pipeline);
void metal_render_pass_set_vertex_buffer(MetalRenderPass *pass, uint32_t slot,
MetalBuffer *buffer);
void metal_render_pass_set_fragment_texture(MetalRenderPass *pass, uint32_t slot,
MetalTexture *texture);
void metal_render_pass_draw(MetalRenderPass *pass, uint32_t vertex_count);
void metal_end_render_pass(MetalRenderPass *pass);
void metal_present(MetalFrame *frame);

#ifdef __cplusplus
}
#endif
