#import <stdatomic.h>
#import "TextureAdapter.h"
#import "ImageFunc.h"

@implementation TextureAdapter {
  BOOL _active;
  dispatch_queue_t _dispatch_queue;
  NSObject<FlutterTextureRegistry>* _registry;
  CVPixelBufferRef _Atomic _pixelBuffer;
  CVPixelBufferRef _pixelBufferSource;
}

- (instancetype)initWithRegistry:(NSObject<FlutterTextureRegistry>*)registry {
  self = [super init];
  if (self) {
    _registry = registry;
    NSString* queue_name = [NSString stringWithFormat:@"com.reedom.flutter/text_scanner/texture_renderer/queue/%lu", (unsigned long)self.hash];
    _dispatch_queue = dispatch_queue_create([queue_name cStringUsingEncoding:NSUTF8StringEncoding], DISPATCH_QUEUE_CONCURRENT);
  }
  return self;
}

- (void)activateTexture {
  if (!_active) {
    _active = YES;
    _textureId = [_registry registerTexture:self];
  }
}

- (void)deactivateTexture {
  if (_active) {
    _active = NO;
    [_registry unregisterTexture:_textureId];

    dispatch_barrier_sync(_dispatch_queue, ^{
      if (self->_pixelBufferSource) {
        CFRelease(self->_pixelBufferSource);
        self->_pixelBufferSource = nil;
      }
    });
    CVPixelBufferRef old = nil;
    atomic_exchange(&_pixelBuffer, old);
    if (old != nil) {
      CFRelease(old);
    }
  }
}

- (void)setPixelBufferNoCopy:(CVPixelBufferRef)pixelBuffer {
  CVPixelBufferRef old = atomic_exchange(&_pixelBuffer, pixelBuffer);
  [_registry textureFrameAvailable:_textureId];
  if (old != nil) {
    CFRelease(old);
  }
}

- (void)storePixelBufferNoCopy:(CVPixelBufferRef)pixelBuffer {
  dispatch_barrier_sync(_dispatch_queue, ^{
    if (self->_pixelBufferSource) {
      CFRelease(self->_pixelBufferSource);
    }
    CFRetain(pixelBuffer);
    self->_pixelBufferSource = pixelBuffer;
  });

  CVPixelBufferRef old = atomic_exchange(&self->_pixelBuffer, _pixelBufferSource);
  [_registry textureFrameAvailable:_textureId];
  if (old != nil) {
    CFRelease(old);
  }
}

- (void)storePixelBuffer:(CVPixelBufferRef)pixelBuffer {
  CVPixelBufferRef newPixelBuffer = TS_copyPixelBuffer(pixelBuffer);
  dispatch_barrier_sync(_dispatch_queue, ^{
    if (self->_pixelBufferSource) {
      CFRelease(self->_pixelBufferSource);
    }
    CFRetain(newPixelBuffer);
    self->_pixelBufferSource = newPixelBuffer;
  });

  CVPixelBufferRef old = atomic_exchange(&_pixelBuffer, _pixelBufferSource);
  [_registry textureFrameAvailable:_textureId];
  if (old != nil) {
    CFRelease(old);
  }
}

- (void)renderStoredPixelBuffer {
  if (!_active) return;

  dispatch_sync(_dispatch_queue, ^{
    if (self->_pixelBufferSource) {
      CFRetain(self->_pixelBufferSource);
      atomic_store(&self->_pixelBuffer, self->_pixelBufferSource);
      [self->_registry textureFrameAvailable:self->_textureId];
    }
  });
}

- (CVPixelBufferRef)getStoredPixelBuffer {
  __block CVPixelBufferRef pixelBuffer;
  dispatch_sync(_dispatch_queue, ^{
    pixelBuffer = self->_pixelBufferSource;
  });
  return pixelBuffer;
}

- (CGSize)getStoredImageSize {
  __block CGSize size;
  dispatch_sync(_dispatch_queue, ^{
    if (self->_pixelBufferSource) {
      size_t width = CVPixelBufferGetWidth(self->_pixelBufferSource);
      size_t height = CVPixelBufferGetHeight(self->_pixelBufferSource);
      size = CGSizeMake(width, height);
    } else {
      size = CGSizeZero;
    }
  });
  return size;
}

#pragma mark FlutterTexture

- (CVPixelBufferRef)copyPixelBuffer {
  CVPixelBufferRef pixelBuffer = _pixelBuffer;
  atomic_exchange(&_pixelBuffer, nil);
  return pixelBuffer;
}

@end
