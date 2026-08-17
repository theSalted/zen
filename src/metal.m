#import "metal.h"
#include <stdlib.h>
#include <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

struct MetalRenderer {
    __strong CAMetalLayer *layer;
    __strong id<MTLDevice> device;
    __strong id<MTLCommandQueue> queue;
};

struct MetalRenderPipeline {
    __strong id<MTLRenderPipelineState> state;
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

void metal_render(MetalRenderer *renderer, MetalRenderPipeline *pipeline) {
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

        [encoder setRenderPipelineState:pipeline->state];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
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

MetalRenderPipeline *metal_create_render_pipeline(MetalRenderer *renderer, const char *shader_source, size_t shader_source_len, const char *vertex_name, const char *fragment_name) {
    NSString *source = [[NSString alloc]
        initWithBytes:shader_source
        length:shader_source_len
        encoding:NSUTF8StringEncoding
    ];

    if(!source) return 0;

    NSError *error = nil;

    // TODO: library abstraction some day
    id<MTLLibrary> library = [renderer->device newLibraryWithSource:source options:nil error:&error];
    if (!library) {
        NSLog(@"Metal shader compile failed: %@", error);
        return 0;
    }

    NSString *vertex_function_name = [NSString stringWithUTF8String:vertex_name];
    NSString *fragment_function_name = [NSString stringWithUTF8String:fragment_name];

    id<MTLFunction> vertex = [library newFunctionWithName:vertex_function_name];
    id<MTLFunction> fragment = [library newFunctionWithName:fragment_function_name];

    if (!vertex || !fragment) return 0;

    MTLRenderPipelineDescriptor *desc = [MTLRenderPipelineDescriptor new];
    desc.vertexFunction = vertex;
    desc.fragmentFunction = fragment;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

    id<MTLRenderPipelineState> state = [renderer->device newRenderPipelineStateWithDescriptor:desc error:&error];

    if (!state) {
        NSLog(@"Metal pipeline creation failed: %@", error);
        return 0;
    }

    MetalRenderPipeline *pipeline = calloc(1, sizeof(*pipeline));
    if (!pipeline) return 0;

    pipeline->state = state;
    return pipeline;
}

void metal_destroy_render_pipeline(MetalRenderPipeline *pipeline) {
    if (!pipeline) return;

    pipeline->state = nil;
    free(pipeline);
}
