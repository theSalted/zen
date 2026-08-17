#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MetalRenderer MetalRenderer;
typedef struct MetalRenderPipeline MetalRenderPipeline;

MetalRenderer *metal_create(void *raw_layer, uint32_t width, uint32_t height);
void metal_render(MetalRenderer *renderer, MetalRenderPipeline *pipeline);
void metal_resize(MetalRenderer *renderer, uint32_t width, uint32_t height);
void metal_destroy(MetalRenderer *renderer);

MetalRenderPipeline *metal_create_render_pipeline(MetalRenderer *renderer, const char *shader_source, size_t shader_source_len, const char *vertex_name, const char *fragment_name);
void metal_destroy_render_pipeline(MetalRenderPipeline *pipeline);

#ifdef __cplusplus
}
#endif
