#import <UIKit/UIKit.h>
#import "ImageFunc.h"

static void imageDataReleaseCallback(void *releaseRefCon, const void *baseAddress) {
  free((void *)baseAddress);
}

CVPixelBufferRef TS_cropImage(CVPixelBufferRef pixelBuffer, CGRect cropFactor) {
  CVPixelBufferLockBaseAddress(pixelBuffer, 0);
  void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
  size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
  size_t width = CVPixelBufferGetWidth(pixelBuffer);
  size_t height = CVPixelBufferGetHeight(pixelBuffer);

  int cropX0 = (int)(width * cropFactor.origin.x);
  int cropY0 = (int)(height * cropFactor.origin.y);
  int cropWidth = (int)(width * cropFactor.size.width);
  int cropHeight = (int)(height * cropFactor.size.height);
  int outWidth = cropWidth;
  int outHeight = cropHeight;
  vImage_Buffer inBuff;
  inBuff.height = cropHeight;
  inBuff.width = cropWidth;
  inBuff.rowBytes = bytesPerRow;

  int startpos = (int)(cropY0 * bytesPerRow + 4 * cropX0);
  inBuff.data = baseAddress+startpos;

  unsigned char *outImg = (unsigned char*)malloc(4 * outWidth * outHeight);
  vImage_Buffer outBuff = {outImg, outHeight, outWidth, 4 * outWidth};

  vImage_Error err = vImageScale_ARGB8888(&inBuff, &outBuff, NULL, 0);
  if (err != kvImageNoError) NSLog(@" error %ld", err);

  CVPixelBufferRef outPixedBuffer = NULL;
  CVPixelBufferCreateWithBytes(kCFAllocatorDefault, outWidth, outHeight, kCVPixelFormatType_32BGRA, outImg, outWidth * 4, imageDataReleaseCallback, NULL, NULL, &outPixedBuffer);
  CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
  // free((void*)outImg); no need to free the buffer

  return outPixedBuffer;
}

CVPixelBufferRef TS_copyPixelBuffer(CVPixelBufferRef pixelBuffer) {
  return TS_cropImage(pixelBuffer, CGRectMake(0.0, 0.0, 1.0, 1.0));
}

CVPixelBufferRef TS_copyPixelBuffer2(CVPixelBufferRef pixelBuffer) {
  CVPixelBufferLockBaseAddress(pixelBuffer, 0);
  void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
  size_t width = CVPixelBufferGetWidth(pixelBuffer);
  size_t height = CVPixelBufferGetHeight(pixelBuffer);

  void* data = malloc(4 * width * height);
  memcpy(data, baseAddress, 4 * width * height);

  CVPixelBufferRef outPixedBuffer = NULL;
  CVPixelBufferCreateWithBytes(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, data, width * 4, imageDataReleaseCallback, NULL, NULL, &outPixedBuffer);
  CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

  return outPixedBuffer;
}

CGImageRef TS_createCGImageFromPixelBuffer(CVPixelBufferRef pixelBuffer) {
  CVPixelBufferLockBaseAddress(pixelBuffer, 0);

  uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
  size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
  size_t width = CVPixelBufferGetWidth(pixelBuffer);
  size_t height = CVPixelBufferGetHeight(pixelBuffer);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

  CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
  CGImageRef newImage = CGBitmapContextCreateImage(newContext);
  CGContextRelease(newContext);

  CGColorSpaceRelease(colorSpace);
  CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
  /* CVBufferRelease(imageBuffer); */  // do not call this!

  return newImage;
}

// Normalize UIImage picked by UIImagePicker.
// There are the following expectation for the final image:
// - the image orientation must be UIImageOrientationUp
// - the image size must be within maxWidth and maxHeight having same proportion of the original
// - the image color space should be simplified enough as vImage functions can handle.
UIImage* TS_normalizeImage(UIImage* image, CGFloat maxWidth, CGFloat maxHeight) {
  BOOL hasMaxWidth = 0 < maxWidth;
  BOOL hasMaxHeight = 0 < maxHeight;
  CGFloat originalWidth = image.size.width;
  CGFloat originalHeight = image.size.height;
  CGFloat width = hasMaxWidth ? MIN(maxWidth, originalWidth) : originalWidth;
  CGFloat height = hasMaxHeight ? MIN(maxHeight, originalHeight) : originalHeight;

  if ((width < originalWidth) || (height < originalHeight)) {
    double downscaledWidth = floor((height / originalHeight) * originalWidth);
    double downscaledHeight = floor((width / originalWidth) * originalHeight);

    if (width < height) {
      if (!hasMaxWidth) {
        width = downscaledWidth;
      } else {
        height = downscaledHeight;
      }
    } else if (height < width) {
      if (!hasMaxHeight) {
        height = downscaledHeight;
      } else {
        width = downscaledWidth;
      }
    } else {
      if (originalWidth < originalHeight) {
        width = downscaledWidth;
      } else if (originalHeight < originalWidth) {
        height = downscaledHeight;
      }
    }
  }

  UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), NO, 1.0);
  [image drawInRect:CGRectMake(0, 0, width, height)];

  UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  return scaledImage;
}

CVPixelBufferRef TS_pixelBufferFromImage(CGImageRef image) {
  vImage_Buffer sourceBuffer = {};
  vImage_CGImageFormat format = {};
//  format.bitsPerComponent = 8;
//  format.bitsPerPixel = 32;
//  format.bitmapInfo = CGImageGetBitmapInfo(image);
//  format.renderingIntent = kCGRenderingIntentDefault;
  vImage_Error vError;
  vError = vImageBuffer_InitWithCGImage(&sourceBuffer, &format, nil, image, kvImageNoFlags);
  if (vError != kvImageNoError) {
    NSLog(@"TS_pixelBufferFromImage.vImageBuffer_InitWithCGImage returns error: %zd", vError);
    return nil;
  }

//  CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(image);
//  if (alphaInfo == kCGImageAlphaPremultipliedLast ||
//      alphaInfo == kCGImageAlphaPremultipliedFirst) {
//    vError = vImageUnpremultiplyData_BGRA8888(&sourceBuffer, &sourceBuffer, kvImageNoFlags);
//    if (vError != kvImageNoError) {
//      NSLog(@"TS_pixelBufferFromImage.vImageUnpremultiplyData_ARGB8888 returns error: %zd", vError);
//      return nil;
//    }
//  }
//
  void* data = malloc(4 * sourceBuffer.width * sourceBuffer.height);
  vImage_Buffer destBuffer = {data, sourceBuffer.height, sourceBuffer.width, 4 * sourceBuffer.width};
  vError = vImageScale_ARGB8888(&sourceBuffer, &destBuffer, nil, kvImageNoFlags);
  free(sourceBuffer.data);
  if (vError != kvImageNoError) {
    NSLog(@"TS_pixelBufferFromImage.vImageScale_ARGB8888 returns error: %zd", vError);
    return nil;
  }

//  if (alphaInfo == kCGImageAlphaPremultipliedLast ||
//      alphaInfo == kCGImageAlphaPremultipliedFirst) {
//    vError = vImagePremultiplyData_BGRA8888(&destBuffer, &destBuffer, kvImageNoFlags);
//    if (vError != kvImageNoError) {
//      NSLog(@"TS_pixelBufferFromImage.vImagePremultiplyData_ARGB8888 returns error: %zd", vError);
//      return nil;
//    }
//  }
//
  CVPixelBufferRef pixelBuffer = NULL;
  CVPixelBufferCreateWithBytes(kCFAllocatorDefault, destBuffer.width, destBuffer.height,
                               kCVPixelFormatType_32BGRA, destBuffer.data, destBuffer.width * 4,
                               imageDataReleaseCallback, NULL, NULL, &pixelBuffer);
  // free((void*)destBuffer.data); no need to free the buffer
  return pixelBuffer;
}

#if 0

CVPixelBufferRef TS_pixelBufferFromImage10(CGImageRef image) {
  CGSize frameSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image)); // Not sure why this is even necessary, using CGImageGetWidth/Height in status/context seems to work fine too

  CVPixelBufferRef pixelBuffer = NULL;
  CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, frameSize.width, frameSize.height, kCVPixelFormatType_32BGRA, nil, &pixelBuffer);
  if (status != kCVReturnSuccess) {
    return NULL;
  }

  CVPixelBufferLockBaseAddress(pixelBuffer, 0);
  void *data = CVPixelBufferGetBaseAddress(pixelBuffer);
  CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(data, frameSize.width, frameSize.height, 8, CVPixelBufferGetBytesPerRow(pixelBuffer), rgbColorSpace, (CGBitmapInfo) kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
  CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);

  CGColorSpaceRelease(rgbColorSpace);
  CGContextRelease(context);
  CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

  return pixelBuffer;
}

CVPixelBufferRef TS_pixelBufferFaster(CGImageRef image) {
  CVPixelBufferRef pxbuffer = NULL;
  NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                           [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                           nil];

  size_t width =  CGImageGetWidth(image);
  size_t height = CGImageGetHeight(image);
  size_t bytesPerRow = CGImageGetBytesPerRow(image);

  CFDataRef  dataFromImageDataProvider = CGDataProviderCopyData(CGImageGetDataProvider(image));
  GLubyte  *imageData = (GLubyte *)CFDataGetBytePtr(dataFromImageDataProvider);
  CVPixelBufferCreateWithBytes(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
                               imageData, bytesPerRow, NULL, NULL,
                               (__bridge CFDictionaryRef)options, &pxbuffer);
  CFRelease(dataFromImageDataProvider);
//  CFRetain(pxbuffer);
  return pxbuffer;
}

CVPixelBufferRef TS_pixelBufferFromCGImageWithPool(CVPixelBufferPoolRef pixelBufferPool, CGImageRef image) {
  CVPixelBufferRef pxbuffer = NULL;
  NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                           [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                           nil];

  size_t width =  CGImageGetWidth(image);
  size_t height = CGImageGetHeight(image);
  size_t bytesPerRow = CGImageGetBytesPerRow(image);
  size_t bitsPerComponent = CGImageGetBitsPerComponent(image);
  CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(image);
  void *pxdata = NULL;

  if (pixelBufferPool == NULL) {
    NSLog(@"pixelBufferPool is null!");
  }

  CVReturn status = CVPixelBufferPoolCreatePixelBuffer (NULL, pixelBufferPool, &pxbuffer);
  if (pxbuffer == NULL) {
    status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
                                 (__bridge CFDictionaryRef) options, &pxbuffer);
  }

  if (status != kCVReturnSuccess || pxbuffer == NULL) {
    NSLog(@"cannot create new pixel buffer");
    return NULL;
  }

  CVPixelBufferLockBaseAddress(pxbuffer, 0);
  pxdata = CVPixelBufferGetBaseAddress(pxbuffer);

#if 1
  CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(pxdata, width, height,
                                               bitsPerComponent, bytesPerRow, rgbColorSpace, bitmapInfo);
  CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
  CGContextDrawImage(context, CGRectMake(0, 0, width,height), image);
  CGColorSpaceRelease(rgbColorSpace);
  CGContextRelease(context);
#else
  CFDataRef  dataFromImageDataProvider = CGDataProviderCopyData(CGImageGetDataProvider(image));
  CFIndex length = CFDataGetLength(dataFromImageDataProvider);
  GLubyte  *imageData = (GLubyte *)CFDataGetBytePtr(dataFromImageDataProvider);
  memcpy(pxdata,imageData,length);
  CFRelease(dataFromImageDataProvider);
#endif

  return pxbuffer;
}

#endif
