#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MetalRenderer MetalRenderer;

MetalRenderer *metal_create(void *raw_layer, uint32_t width, uint32_t height);
void metal_render(MetalRenderer *renderer);
void metal_resize(MetalRenderer *renderer, uint32_t width, uint32_t height);
void metal_destroy(MetalRenderer *renderer);

#ifdef __cplusplus
}
#endif
