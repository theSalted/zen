#import "metal.h"
#include <stdlib.h>
#include <string.h>
#include <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

struct MetalRenderer {
  __strong CAMetalLayer *layer;
  __strong id<MTLDevice> device;
  __strong id<MTLCommandQueue> queue;
};
struct MetalShaderLibrary { __strong id<MTLLibrary> library; };
struct MetalRenderPipeline { __strong id<MTLRenderPipelineState> state; };
struct MetalComputePipeline { __strong id<MTLComputePipelineState> state; };
struct MetalBuffer {
  __strong id<MTLBuffer> buffer;
  size_t size;
};
struct MetalTexture { __strong id<MTLTexture> texture; };
struct MetalFrame {
  __strong id<CAMetalDrawable> drawable;
  __strong id<MTLCommandBuffer> command;
};
struct MetalRenderPass {
  MetalFrame *frame;
  __strong id<MTLRenderCommandEncoder> encoder;
};
struct MetalComputePass {
  MetalFrame *frame;
  __strong id<MTLComputeCommandEncoder> encoder;
  __strong id<MTLComputePipelineState> pipeline;
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

void metal_destroy(MetalRenderer *renderer) {
    if (!renderer) return;
    renderer->layer = nil;
    renderer->device = nil;
    renderer->queue = nil;
    free(renderer);
}

MetalShaderLibrary *metal_create_shader_library(MetalRenderer *renderer, const MetalShaderSource *sources, size_t source_count) {
    NSMutableString *combined = [NSMutableString string];

    for (size_t i = 0; i < source_count; i += 1) {
        NSString *part = [[NSString alloc] initWithBytes:sources[i].source
        length:sources[i].source_len encoding:NSUTF8StringEncoding];
        if (!part) return 0;
        [combined appendString:part];
        [combined appendString:@"\n"];
    }

    NSError *error = nil;
    id<MTLLibrary> library = [renderer->device newLibraryWithSource:combined
    options:nil error:&error];
    if (!library) {
        NSLog(@"Metal shader compile failed: %@", error);
        return 0;
    }

    MetalShaderLibrary *result = calloc(1, sizeof(*result));
    if (!result) return 0;

    result->library = library;
    return result;
}

void metal_destroy_shader_library(MetalShaderLibrary *library) {
    if (!library) return;
    library->library = nil;
    free(library);
}

MetalRenderPipeline *metal_create_render_pipeline(MetalRenderer *renderer, MetalShaderLibrary *library, const char *vertex_name, const char *fragment_name) {
    NSString *vertex_function_name = [NSString stringWithUTF8String:vertex_name];
    NSString *fragment_function_name = [NSString
    stringWithUTF8String:fragment_name];

    id<MTLFunction> vertex = [library->library
    newFunctionWithName:vertex_function_name];
    id<MTLFunction> fragment = [library->library
    newFunctionWithName:fragment_function_name];
    if (!vertex || !fragment) return 0;

    MTLRenderPipelineDescriptor *desc = [MTLRenderPipelineDescriptor new];
    desc.vertexFunction = vertex;
    desc.fragmentFunction = fragment;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

    NSError *error = nil;
    id<MTLRenderPipelineState> state = [renderer->device
    newRenderPipelineStateWithDescriptor:desc error:&error];
    if (!state) {
        NSLog(@"Metal render pipeline failed: %@", error);
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

MetalComputePipeline *metal_create_compute_pipeline(MetalRenderer *renderer, MetalShaderLibrary *library, const char *kernel_name) {
    NSString *function_name = [NSString stringWithUTF8String:kernel_name];
    id<MTLFunction> kernel = [library->library newFunctionWithName:function_name];
    if (!kernel) return 0;

    NSError *error = nil;
    id<MTLComputePipelineState> state = [renderer->device
    newComputePipelineStateWithFunction:kernel error:&error];
    if (!state) {
        NSLog(@"Metal compute pipeline failed: %@", error);
        return 0;
    }

    MetalComputePipeline *pipeline = calloc(1, sizeof(*pipeline));
    if (!pipeline) return 0;

    pipeline->state = state;
    return pipeline;
}

void metal_destroy_compute_pipeline(MetalComputePipeline *pipeline) {
    if (!pipeline) return;
    pipeline->state = nil;
    free(pipeline);
}

MetalBuffer *metal_create_buffer(MetalRenderer *renderer, const void *data, size_t
size) {
    id<MTLBuffer> buffer = nil;

    if (data) {
        buffer = [renderer->device newBufferWithBytes:data length:size
        options:MTLResourceStorageModeShared];
    } else {
        buffer = [renderer->device newBufferWithLength:size
        options:MTLResourceStorageModeShared];
    }

    if (!buffer) return 0;

    MetalBuffer *result = calloc(1, sizeof(*result));
    if (!result) return 0;

    result->buffer = buffer;
    result->size = size;
    return result;
}

void metal_buffer_write(MetalBuffer *buffer, const void *data, size_t size) {
    if (!buffer || !data || size > buffer->size) return;
    memcpy(buffer->buffer.contents, data, size);
}

void metal_destroy_buffer(MetalBuffer *buffer) {
    if (!buffer) return;
    buffer->buffer = nil;
    free(buffer);
}

MetalTexture *metal_create_texture_2d(MetalRenderer *renderer, uint32_t width, uint32_t height) {
    MTLTextureDescriptor *desc = [MTLTextureDescriptor
    texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:width
    height:height mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite |
    MTLTextureUsageRenderTarget;
    desc.storageMode = MTLStorageModePrivate;

    id<MTLTexture> texture = [renderer->device newTextureWithDescriptor:desc];
    if (!texture) return 0;

    MetalTexture *result = calloc(1, sizeof(*result));
    if (!result) return 0;

    result->texture = texture;
    return result;
}

void metal_destroy_texture(MetalTexture *texture) {
    if (!texture) return;
    texture->texture = nil;
    free(texture);
}

MetalFrame *metal_begin_frame(MetalRenderer *renderer) {
    id<CAMetalDrawable> drawable = [renderer->layer nextDrawable];
    if (!drawable) return 0;

    id<MTLCommandBuffer> command = [renderer->queue commandBuffer];
    if (!command) return 0;

    MetalFrame *frame = calloc(1, sizeof(*frame));
    if (!frame) return 0;

    frame->drawable = drawable;
    frame->command = command;
    return frame;
}

MetalRenderPass *metal_begin_render_pass(MetalFrame *frame, double r, double g, double b, double a) {
    MTLRenderPassDescriptor *desc = [MTLRenderPassDescriptor renderPassDescriptor];
    desc.colorAttachments[0].texture = frame->drawable.texture;
    desc.colorAttachments[0].loadAction = MTLLoadActionClear;
    desc.colorAttachments[0].storeAction = MTLStoreActionStore;
    desc.colorAttachments[0].clearColor = MTLClearColorMake(r, g, b, a);

    id<MTLRenderCommandEncoder> encoder = [frame->command
    renderCommandEncoderWithDescriptor:desc];
    if (!encoder) return 0;

    MetalRenderPass *pass = calloc(1, sizeof(*pass));
    if (!pass) return 0;

    pass->frame = frame;
    pass->encoder = encoder;
    return pass;
}

void metal_render_pass_set_pipeline(MetalRenderPass *pass, MetalRenderPipeline *pipeline) {
    [pass->encoder setRenderPipelineState:pipeline->state];
}

void metal_render_pass_set_vertex_buffer(MetalRenderPass *pass, uint32_t slot, MetalBuffer *buffer) {
    [pass->encoder setVertexBuffer:buffer->buffer offset:0 atIndex:slot];
}

void metal_render_pass_set_fragment_buffer(MetalRenderPass *pass, uint32_t slot, MetalBuffer *buffer) {
    [pass->encoder setFragmentBuffer:buffer->buffer offset:0 atIndex:slot];
}

void metal_render_pass_set_fragment_texture(MetalRenderPass *pass, uint32_t slot, MetalTexture *texture) {
    [pass->encoder setFragmentTexture:texture->texture atIndex:slot];
}

void metal_render_pass_draw(MetalRenderPass *pass, uint32_t vertex_count) {
    [pass->encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0
    vertexCount:vertex_count];
}

void metal_end_render_pass(MetalRenderPass *pass) {
    if (!pass) return;
    [pass->encoder endEncoding];
    pass->encoder = nil;
    free(pass);
}

MetalComputePass *metal_begin_compute_pass(MetalFrame *frame) {
    id<MTLComputeCommandEncoder> encoder = [frame->command computeCommandEncoder];
    if (!encoder) return 0;

    MetalComputePass *pass = calloc(1, sizeof(*pass));
    if (!pass) return 0;

    pass->frame = frame;
    pass->encoder = encoder;
    return pass;
}

void metal_compute_pass_set_pipeline(MetalComputePass *pass, MetalComputePipeline *pipeline) {
    pass->pipeline = pipeline->state;
    [pass->encoder setComputePipelineState:pipeline->state];
}

void metal_compute_pass_set_buffer(MetalComputePass *pass, uint32_t slot, MetalBuffer *buffer) {
    [pass->encoder setBuffer:buffer->buffer offset:0 atIndex:slot];
}

void metal_compute_pass_set_texture(MetalComputePass *pass, uint32_t slot, MetalTexture *texture) {
    [pass->encoder setTexture:texture->texture atIndex:slot];
}

void metal_compute_pass_dispatch(MetalComputePass *pass, uint32_t width, uint32_t height, uint32_t depth) {
    if (!pass->pipeline || width == 0 || height == 0 || depth == 0) return;

    NSUInteger x = pass->pipeline.threadExecutionWidth;
    NSUInteger y = pass->pipeline.maxTotalThreadsPerThreadgroup / x;
    if (y == 0) y = 1;

    MTLSize threads = MTLSizeMake(width, height, depth);
    MTLSize group = MTLSizeMake(x, y, 1);
    [pass->encoder dispatchThreads:threads threadsPerThreadgroup:group];
}

void metal_end_compute_pass(MetalComputePass *pass) {
    if (!pass) return;
    [pass->encoder endEncoding];
    pass->encoder = nil;
    pass->pipeline = nil;
    free(pass);
}

void metal_present(MetalFrame *frame) {
    if (!frame) return;
    [frame->command presentDrawable:frame->drawable];
    [frame->command commit];
    frame->drawable = nil;
    frame->command = nil;
    free(frame);
}
