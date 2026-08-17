#import "metal.h"
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

struct MetalRenderer {
    __strong CAMetalLayer *layer;
    __strong id<MTLDevice> device;
    __strong id<MTLCommandQueue> queue;
};

MetalRenderer *metal_create(void *raw_layer, uint32_t width, uint32_t height) {
    CAMetalLayer *layer = (__bridge CAMetalLayer *)raw_layer;
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) return 0;

    id<MTLCommandQueue> queue = [device newCommandQueue];
    if (!queue) return 0;

    layer.device = device;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.framebufferOnly = NO;
    layer.drawableSize = CGSizeMake(width, height);

    MetalRenderer *renderer = calloc(1, sizeof(*renderer));
    if (!renderer) return 0;

    renderer->layer = layer;
    renderer->device = device;
    renderer->queue = queue;
    return renderer;
}

void metal_resize(MetalRenderer *renderer, uint32_t width, uint32_t height) {
    renderer->layer.drawableSize = CGSizeMake(width, height);
}

void metal_render(MetalRenderer *renderer) {
    @autoreleasepool {
        id<CAMetalDrawable> drawable = [renderer->layer nextDrawable];
        if (!drawable) return;

        MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
        pass.colorAttachments[0].texture = drawable.texture;
        pass.colorAttachments[0].loadAction = MTLLoadActionClear;
        pass.colorAttachments[0].storeAction = MTLStoreActionStore;
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0.02, 0.02, 0.025, 1.0);

        id<MTLCommandBuffer> command = [renderer->queue commandBuffer];
        id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];

        [encoder endEncoding];

        [command presentDrawable:drawable];
        [command commit];
    }
}


void metal_destroy(MetalRenderer *renderer) {
    if (!renderer) return;

    renderer->layer = nil;
    renderer->device = nil;
    renderer->queue = nil;

    free(renderer);
}
