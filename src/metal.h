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
typedef struct MetalComputePass MetalComputePass;

typedef struct MetalShaderSource {
  const char *source;
  size_t source_len;
} MetalShaderSource;
typedef enum MetalTextureFormat {
  METAL_TEXTURE_FORMAT_BGRA8_UNORM,
  METAL_TEXTURE_FORMAT_RGBA8_UNORM,
  METAL_TEXTURE_FORMAT_RGBA16_FLOAT,
  METAL_TEXTURE_FORMAT_RGBA32_FLOAT,
  METAL_TEXTURE_FORMAT_R32_FLOAT,
  METAL_TEXTURE_FORMAT_DEPTH32_FLOAT,
} MetalTextureFormat;
typedef enum MetalTextureUsage {
  METAL_TEXTURE_USAGE_SHADER_READ = 1 << 0,
  METAL_TEXTURE_USAGE_SHADER_WRITE = 1 << 1,
  METAL_TEXTURE_USAGE_RENDER_TARGET = 1 << 2,
  METAL_TEXTURE_USAGE_DEPTH_STENCIL = 1 << 3,
} MetalTextureUsage;
typedef struct MetalTextureDesc {
  uint32_t width;
  uint32_t height;
  uint32_t mip_count;
  uint32_t sample_count;
  MetalTextureFormat format;
  uint32_t usage;
} MetalTextureDesc;

MetalRenderer *metal_create(void *raw_layer, uint32_t width, uint32_t height);
void metal_resize(MetalRenderer *renderer, uint32_t width, uint32_t height);
void metal_destroy(MetalRenderer *renderer);

MetalShaderLibrary *
metal_create_shader_library(MetalRenderer *renderer,
                            const MetalShaderSource *sources,
                            size_t source_count);
void metal_destroy_shader_library(MetalShaderLibrary *library);

MetalRenderPipeline *metal_create_render_pipeline(MetalRenderer *renderer,
                                                  MetalShaderLibrary *library,
                                                  const char *vertex_name,
                                                  const char *fragment_name);
void metal_destroy_render_pipeline(MetalRenderPipeline *pipeline);

MetalComputePipeline *metal_create_compute_pipeline(MetalRenderer *renderer,
                                                    MetalShaderLibrary *library,
                                                    const char *kernel_name);
void metal_destroy_compute_pipeline(MetalComputePipeline *pipeline);

MetalBuffer *metal_create_buffer(MetalRenderer *renderer, const void *data,
                                 size_t size);
void metal_buffer_write(MetalBuffer *buffer, const void *data, size_t size);
void metal_destroy_buffer(MetalBuffer *buffer);

MetalTexture *metal_create_texture(MetalRenderer *renderer,
                                   const MetalTextureDesc *desc);
void metal_destroy_texture(MetalTexture *texture);

MetalFrame *metal_begin_frame(MetalRenderer *renderer);
MetalRenderPass *metal_begin_render_pass(MetalFrame *frame, double r, double g,
                                         double b, double a);
void metal_render_pass_set_pipeline(MetalRenderPass *pass,
                                    MetalRenderPipeline *pipeline);
void metal_render_pass_set_vertex_buffer(MetalRenderPass *pass, uint32_t slot,
                                         MetalBuffer *buffer);
void metal_render_pass_set_fragment_buffer(MetalRenderPass *pass, uint32_t slot,
                                           MetalBuffer *buffer);
void metal_render_pass_set_fragment_texture(MetalRenderPass *pass,
                                            uint32_t slot,
                                            MetalTexture *texture);
void metal_render_pass_draw(MetalRenderPass *pass, uint32_t vertex_count);
void metal_end_render_pass(MetalRenderPass *pass);

MetalComputePass *metal_begin_compute_pass(MetalFrame *frame);
void metal_compute_pass_set_pipeline(MetalComputePass *pass,
                                     MetalComputePipeline *pipeline);
void metal_compute_pass_set_buffer(MetalComputePass *pass, uint32_t slot,
                                   MetalBuffer *buffer);
void metal_compute_pass_set_texture(MetalComputePass *pass, uint32_t slot,
                                    MetalTexture *texture);
void metal_compute_pass_dispatch(MetalComputePass *pass, uint32_t width,
                                 uint32_t height, uint32_t depth);
void metal_end_compute_pass(MetalComputePass *pass);

void metal_present(MetalFrame *frame);

#ifdef __cplusplus
}
#endif
