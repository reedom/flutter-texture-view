#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

@class UIImage;

extern CVPixelBufferRef TS_cropImage(CVPixelBufferRef pixelBuffer, CGRect cropFactor);
extern CVPixelBufferRef TS_copyPixelBuffer(CVPixelBufferRef pixelBuffer);
extern CGImageRef TS_createCGImageFromPixelBuffer(CVPixelBufferRef pixelBuffer);
extern UIImage* TS_normalizeImage(UIImage* image, CGFloat maxWidth, CGFloat maxHeight);
extern CVPixelBufferRef TS_pixelBufferFromImage(CGImageRef image);
