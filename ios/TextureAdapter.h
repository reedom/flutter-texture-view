#import <Flutter/Flutter.h>

@interface TextureAdapter : NSObject<FlutterTexture>

@property(readonly, nonatomic) BOOL active;
@property(readonly, nonatomic) int64_t textureId;

- (instancetype)initWithRegistry:(NSObject<FlutterTextureRegistry>*)registry;

- (void)activateTexture;
- (void)deactivateTexture;

- (void)setPixelBufferNoCopy:(CVPixelBufferRef)pixelBuffer;
- (void)storePixelBufferNoCopy:(CVPixelBufferRef)pixelBuffer;
- (void)storePixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)renderStoredPixelBuffer;
- (CVPixelBufferRef)getStoredPixelBuffer;
- (CGSize)getStoredImageSize;

@end
