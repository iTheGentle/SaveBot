//
//  NSGIF.m
//
//  Created by Metasmile (github.com/metasmile)
//

#import "NSGIF.h"
#import <Accelerate/Accelerate.h>

// Declare constants
#define prefix     @"NSGIF"
#define tolerance    @(0.01)

CG_INLINE CGFloat
NSGIFScaleRatio(NSGIFScale scalePhase, CGSize sourceSize)
{
    switch (scalePhase){
        case NSGIFScaleVeryLow:
            return .2f;
        case NSGIFScaleLow:
            return .3f;
        case NSGIFScaleMedium:
            return .5f;
        case NSGIFScaleHigh:
            return .7f;
        case NSGIFScaleOriginal:
            return 1;
        case NSGIFScaleOptimize:
        default:{
            NSGIFScale targetScalePhase = NSGIFScaleMedium;
            if (sourceSize.width >= 1200 || sourceSize.height >= 1200)
                targetScalePhase = NSGIFScaleVeryLow;
            else if (sourceSize.width >= 800 || sourceSize.height >= 800)
                targetScalePhase = NSGIFScaleLow;
            else if (sourceSize.width >= 400 || sourceSize.height >= 400)
                targetScalePhase = NSGIFScaleMedium;
            else if (sourceSize.width < 400|| sourceSize.height < 400)
                targetScalePhase = NSGIFScaleHigh;
            return NSGIFScaleRatio(targetScalePhase, sourceSize);
        }
    }
}

static CGRect
NormalizedCropRectAspectFill(CGSize targetSize, CGSize sizeValueOfAspectRatio){
    if(CGSizeEqualToSize(sizeValueOfAspectRatio, CGSizeZero)){
        return (CGRect){CGPointZero, targetSize};
    }
    BOOL portrait = targetSize.height >= targetSize.width;
    CGFloat ratio = MIN(targetSize.width,targetSize.height)/MAX(targetSize.width,targetSize.height);
    CGFloat aspectRatio = sizeValueOfAspectRatio.width/sizeValueOfAspectRatio.height;
    ratio *= portrait ? 1/aspectRatio : aspectRatio;
    ratio = MIN(MAX(0,ratio), 1); //wrap
    return portrait ? CGRectMake(0,(1-ratio)/2.f, 1,ratio) : CGRectMake((1-ratio)/2.f, 0, ratio, 1);
}

CG_INLINE CGRect
CropRectAspectFill(CGSize targetSize, CGSize sizeValueOfAspectRatio){
    CGRect normalizedCropRect = NormalizedCropRectAspectFill(targetSize,sizeValueOfAspectRatio);
    if(CGSizeEqualToSize(normalizedCropRect.size, CGSizeZero)){
        return (CGRect){CGPointZero, targetSize};
    }
    return CGRectMake(
            (CGFloat)floor(normalizedCropRect.origin.x * targetSize.width),
            (CGFloat)floor(normalizedCropRect.origin.y * targetSize.height),
            (CGFloat)floor(normalizedCropRect.size.width * targetSize.width),
            (CGFloat)floor(normalizedCropRect.size.height * targetSize.height)
    );
}

@interface NSSerializedResourceRequest()
@property(atomic, assign) BOOL proceeding;
@end

@implementation NSSerializedResourceRequest : NSObject

- (instancetype)initWithSourceVideo:(NSURL *)fileURL {
    self = [self init];
    if (self) {
        self.framesPerSecond = 4;
        self.sourceVideoFile = fileURL;
    }
    return self;
}

- (NSTimeInterval)durationMeasured {
    double duration = self.frameCount/self.framesPerSecond;
    return duration>0 ? MIN(self.maxDuration, duration) : self.maxDuration;
}

+ (instancetype)requestWithSourceVideo:(NSURL *)fileURL {
    return [[self alloc] initWithSourceVideo:fileURL];
}

- (void)assert{
    NSParameterAssert(self.sourceVideoFile);
    NSAssert(self.framesPerSecond>0, @"framesPerSecond must be higer than 0.");
    NSAssert(self.aspectRatioToCrop.width>=0 && self.aspectRatioToCrop.height>=0, @"all values in aspectRatioToCrop must be same or higer than 0.");
}
@end

#pragma mark - NSGIFRequest
@implementation NSGIFRequest

+ (instancetype)requestWithSourceVideo:(NSURL *)fileURL destination:(NSURL *)videoFileURL {
    NSGIFRequest * request = [[self alloc] initWithSourceVideo:fileURL];
    request.destinationVideoFile = videoFileURL;
    return request;
}

+ (instancetype)requestWithSourceVideoForLivePhoto:(NSURL *__nullable)fileURL {
    NSGIFRequest * request = [[NSGIFRequest alloc] initWithSourceVideo:fileURL];
    request.framesPerSecond = 8;
    return request;
}

- (void)cancelIfNeeded {
    //TODO: interrupt current proceeding jobs of request.
}

- (NSURL *)destinationVideoFile {
    if(_destinationVideoFile){
        return _destinationVideoFile;
    }
    NSAssert(self.sourceVideoFile, @"URL of a source video required if didn't provide destination url.");
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[prefix stringByAppendingPathExtension:@"gif"]]];
}

@end

#pragma mark - NSExtractFramesRequest
@implementation NSFrameExtractingRequest

- (instancetype)init {
    self = [super init];
    if (self) {
        self.scalePreset = NSGIFScaleOriginal;

        _extension = @"jpg";
        _destinationDirectory = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    }
    return self;
}
@end


#pragma mark - NSSerializedResourceResponse
@implementation NSSerializedResourceResponse : NSObject

- (instancetype)initWithImageURLs:(NSArray<NSURL *>*)urls {
    self = [self init];
    if (self) {
        _imageUrls = urls;
    }
    return self;
}

+ (instancetype)responseWithImageURLs:(NSArray<NSURL *>*)urls {
    return [[self alloc] initWithImageURLs:urls];
}
@end


#pragma mark - NSFrameExtractingResponse
@interface NSFrameExtractingResponse()
@property(nonatomic, assign) NSTimeInterval durationOfFrames;
@end

@implementation NSFrameExtractingResponse
@end

#pragma mark - NSGIF
@implementation NSGIF

#pragma mark - NSGIF - create
+ (void)create:(NSGIFRequest *__nullable)request completion:(void (^ __nullable)(NSURL *__nullable))completionBlock {
    [request assert];

    AVURLAsset *asset = [AVURLAsset assetWithURL:request.sourceVideoFile];
    NSArray * assetTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    NSAssert(assetTracks.count,@"Not found any AVMediaTypeVideo in AVURLAsset which fetched from given sourceVideo file url");
    //early return if asset is nil or not found video.
    if(!assetTracks.count){
        !completionBlock?:completionBlock(nil);
        return;
    }

    // set result output scale ratio
    CGFloat outputScale = request.hardScale ?: NSGIFScaleRatio(request.scalePreset, ((AVAssetTrack *)assetTracks[0]).naturalSize);

    // measure minimum timescale
    CMTimeScale const timeScale = MIN(asset.duration.timescale, ((AVAssetTrack *)assetTracks[0]).naturalTimeScale);

    // Get the length of the video in seconds
    double videoDurationInSec = asset.duration.value/timeScale;

    // Clip videoLength via given max duration if needed
    if(request.maxDuration > 0){
        videoDurationInSec = MIN(request.maxDuration, videoDurationInSec);
    }

    // Configured framesPerSecond will be ignored if it was lower than nominalFrameRate of AVAssetTrack
    float const frameRate = MAX(request.framesPerSecond, ((AVAssetTrack *)assetTracks[0]).nominalFrameRate);

    // frameLength, not Integer
    double const frameLength = videoDurationInSec * frameRate;

    // frame absolute delay time "{N.nnn}s"
    double const frameDelayTimeInSecWithMilliseconds = videoDurationInSec/frameLength;

    // Automatically set framecount by given framesPerSecond "{N}"
    NSUInteger frameCount = request.frameCount ?: (NSUInteger) floor(frameLength);

    // How far along the video track we want to move, in seconds.
    double const frameGapTimeByCountInSec = videoDurationInSec/MAX(frameCount-1,0);

    // Add frames to the buffer
    NSMutableArray *timePoints = [NSMutableArray array];
    for (int currentFrameIndex = 0; currentFrameIndex<frameCount; ++currentFrameIndex) {
        double seconds = frameGapTimeByCountInSec * currentFrameIndex;
        CMTime time = CMTimeMakeWithSeconds(seconds, timeScale);
        [timePoints addObject:[NSValue valueWithCMTime:time]];
    }

    //Append reversed frames if needed
    if(request.appendReversedFrames && timePoints.count>2){
        [timePoints addObjectsFromArray:[[timePoints reverseObjectEnumerator].allObjects subarrayWithRange:NSMakeRange(1, timePoints.count-1)]];
    }

    // Create properties dictionaries
    NSDictionary * const fileProperties = @{
            (NSString *)kCGImagePropertyGIFDictionary: @{
                    (NSString *)kCGImagePropertyGIFLoopCount: @(request.loopCount)
            }
    };
    NSDictionary * const frameProperties = @{
            (NSString *)kCGImagePropertyGIFDictionary: @{
                    //Seconds, If a time of 50 milliseconds or less is specified, then the actual delay time stored in this parameter is 100 miliseconds. See kCGImagePropertyGIFUnclampedDelayTime.
                    (NSString *)kCGImagePropertyGIFDelayTime: @(frameDelayTimeInSecWithMilliseconds)
            },
            (NSString *)kCGImagePropertyColorModel: (NSString *)kCGImagePropertyColorModelRGB
    };

    // Prepare group for firing completion block
    dispatch_group_t gifQueue = dispatch_group_create();
    dispatch_group_enter(gifQueue);

    __block NSURL *gifURL;

    request.proceeding = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        gifURL = [self createGIFforTimePoints:timePoints
                                      fromURL:request.sourceVideoFile
                                        toURL:request.destinationVideoFile
                               fileProperties:fileProperties
                              frameProperties:frameProperties
                                   frameCount:frameCount
                                  outputScale:outputScale
                            aspectRatioToCrop:request.aspectRatioToCrop
                                     progress:request.progressHandler];

        dispatch_group_leave(gifQueue);
    });

    dispatch_group_notify(gifQueue, dispatch_get_main_queue(), ^{
        // Return GIF URL
        request.proceeding = NO;
        completionBlock(gifURL);
        gifURL = nil;
        request.progressHandler = nil;
    });
}

#pragma mark - Base methods

+ (NSURL *)createGIFforTimePoints:(NSArray *)timePoints
                          fromURL:(NSURL *)url
                            toURL:(NSURL *)destFileURL
                   fileProperties:(NSDictionary *)fileProperties
                  frameProperties:(NSDictionary *)frameProperties
                       frameCount:(NSUInteger)frameCount
                      outputScale:(CGFloat)outputScale
                aspectRatioToCrop:(CGSize)aspectRatioToCrop
                         progress:(NSGIFProgressHandler)handler{

    NSParameterAssert(timePoints);
    NSParameterAssert(url);
    NSParameterAssert(destFileURL);
    NSParameterAssert(fileProperties);
    NSParameterAssert(frameProperties);

    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)destFileURL, kUTTypeGIF , frameCount, NULL);

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;

    CMTime firstFrameTime = [[timePoints firstObject] CMTimeValue];
    CMTime tol = CMTimeMakeWithSeconds([tolerance floatValue], firstFrameTime.timescale);
    generator.requestedTimeToleranceBefore = tol;
    generator.requestedTimeToleranceAfter = tol;

    NSError *error = nil;
    CGImageRef previousImageRefCopy = nil;
    NSUInteger lengthOfTimePoints = timePoints.count;
    BOOL stop = NO;
    for (NSValue *time in timePoints) {
        @autoreleasepool {
            UIImage * currentFrameImage = [UIImage imageWithCGImage:[generator copyCGImageAtTime:[time CMTimeValue] actualTime:nil error:&error]];

            //rescale
            if(outputScale != 1){
                currentFrameImage = [self.class imageByScalingToFill:currentFrameImage size:CGSizeMake(currentFrameImage.size.width * outputScale, currentFrameImage.size.height * outputScale) rescaleTo:currentFrameImage.scale];
            }
            //crop
            if(!CGSizeEqualToSize(aspectRatioToCrop,CGSizeZero)){
                currentFrameImage = [self.class imageByCroppingRect:currentFrameImage rect:CropRectAspectFill(currentFrameImage.size, aspectRatioToCrop)];
            }

            NSAssert(!error, @"Error copying image to create gif");
            if (error) {
                NSLog(@"Error copying image: %@", error);
            }

            CGImageRef currentFrameImageRef = CGImageCreateCopy(currentFrameImage.CGImage);

            if (currentFrameImageRef) {
                CGImageRelease(previousImageRefCopy);
                previousImageRefCopy = CGImageCreateCopy(currentFrameImageRef);
            } else if (previousImageRefCopy) {
                currentFrameImageRef = CGImageCreateCopy(previousImageRefCopy);
            } else {
                NSLog(@"Error copying image and no previous frames to duplicate");
                return nil;
            }
            CGImageDestinationAddImage(destination, currentFrameImageRef, (__bridge CFDictionaryRef)frameProperties);
            CGImageRelease(currentFrameImageRef);
            NSUInteger position = [timePoints indexOfObject:time]+1;
            !handler?:handler((CGFloat)position/lengthOfTimePoints,position, lengthOfTimePoints, [time CMTimeValue], &stop, frameProperties);
            if(stop){
                break;
            }
        }
    }
    CGImageRelease(previousImageRefCopy);

    CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)fileProperties);
    // Finalize the GIF
    if (!CGImageDestinationFinalize(destination)) {
        NSLog(@"Failed to finalize GIF destination: %@", error);
        if (destination != nil) {
            CFRelease(destination);
        }
        return nil;
    }
    CFRelease(destination);

    return destFileURL;
}


#pragma mark Frame Extracter

+ (void)extract:(NSFrameExtractingRequest *__nullable)request completion:(void (^ __nullable)(NSFrameExtractingResponse *__nullable))completionBlock {
    [request assert];

    // Create properties dictionaries
    AVURLAsset *asset = [AVURLAsset assetWithURL:request.sourceVideoFile];
    NSArray * assetTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    NSAssert(assetTracks.count,@"Not found any AVMediaTypeVideo in AVURLAsset which fetched from given sourceVideo file url");
    //early return if asset is nil or not found video.
    if(!assetTracks.count){
        !completionBlock?:completionBlock(nil);
        return;
    }

    // set result output scale ratio
    CGFloat outputScale = NSGIFScaleRatio(request.scalePreset, ((AVAssetTrack *)assetTracks[0]).naturalSize);

    CMTimeScale const timeScale = MIN(asset.duration.timescale, ((AVAssetTrack *)assetTracks[0]).naturalTimeScale);

    // Get the length of the video in seconds
    double videoDurationInSec = (double)asset.duration.value/timeScale;

    // Clip videoLength via given max duration if needed
    if(request.maxDuration > 0){
        videoDurationInSec = MIN(request.maxDuration, videoDurationInSec);
    }

    // Configured framesPerSecond will be ignored if it was higher than nominalFrameRate of AVAssetTrack
    float const frameRate = MIN(request.framesPerSecond, ((AVAssetTrack *)assetTracks[0]).nominalFrameRate);

    // Automatically set framecount by given framesPerSecond
    NSUInteger frameCount = request.frameCount ?: (NSUInteger) (videoDurationInSec * frameRate);

    // How far along the video track we want to move, in seconds.
    double const frameGapTimeInSec = videoDurationInSec/(frameCount>1 ? (frameCount-1) : frameCount);

    // Add frames to the buffer
    NSMutableArray *timePoints = [NSMutableArray array];
    for (int currentFrameIndex = 0; currentFrameIndex<frameCount; ++currentFrameIndex) {
        double seconds = frameGapTimeInSec * currentFrameIndex;
        CMTime time = CMTimeMakeWithSeconds(seconds, timeScale);
        [timePoints addObject:[NSValue valueWithCMTime:time]];
    }

    // Prepare group for firing completion block
    dispatch_group_t gifQueue = dispatch_group_create();
    dispatch_group_enter(gifQueue);

    __block NSArray<NSURL *> *extractImageUrls;

    request.proceeding = YES;

    //typeof(self) __weak weakSelf = self;
__typeof(self) __weak weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            extractImageUrls = [weakSelf extractFramesforTimePoints:timePoints
                                                          extension:request.extension
                                                            fromURL:request.sourceVideoFile
                                                              toURL:request.destinationDirectory
                                                        outputScale:outputScale
                                                  aspectRatioToCrop:request.aspectRatioToCrop
                                                           progress:request.progressHandler];

            dispatch_group_leave(gifQueue);
        }


    });

    dispatch_group_notify(gifQueue, dispatch_get_main_queue(), ^{
        // Return GIF URL
        request.proceeding = NO;
        NSFrameExtractingResponse * response = [NSFrameExtractingResponse responseWithImageURLs:extractImageUrls];
        response.durationOfFrames = videoDurationInSec;
        completionBlock(response);

        extractImageUrls = nil;
        request.progressHandler = nil;
    });
}

+ (NSArray<NSURL *> *)extractFramesforTimePoints:(NSArray * const)timePoints
                                       extension:(NSString * const)extension
                                         fromURL:(NSURL * const)url
                                           toURL:(NSURL * const)destDir
                                     outputScale:(CGFloat const)outputScale
                               aspectRatioToCrop:(CGSize)aspectRatioToCrop
                                        progress:(NSGIFProgressHandler const)handler{

    NSParameterAssert(timePoints);
    NSParameterAssert(url);
    BOOL isDirectory;
    NSParameterAssert([[NSFileManager defaultManager] fileExistsAtPath:url.path isDirectory:&isDirectory]);
    NSAssert(!isDirectory, @"Given fromURL is must only be a file");
    BOOL destDirExisted = [[NSFileManager defaultManager] fileExistsAtPath:destDir.path isDirectory:&isDirectory];
    NSAssert(!destDir || destDirExisted, @"Given toURL does not exist.");
    NSAssert(!destDir || isDirectory, @"Given toURL is must only be a directory");
    NSParameterAssert(destDir);

    NSMutableArray<NSURL *> * resultFrameImagesUrls = [NSMutableArray<NSURL *> array];

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;

    CMTime firstFrameTime = [[timePoints firstObject] CMTimeValue];
    CMTime tol = CMTimeMakeWithSeconds([tolerance floatValue], firstFrameTime.timescale);
    generator.requestedTimeToleranceBefore = tol;
    generator.requestedTimeToleranceAfter = tol;

    NSError *error = nil;
    NSUInteger lengthOfTimePoints = timePoints.count;
    BOOL stop = NO;

    for (NSValue *time in timePoints) {
        @autoreleasepool {
            NSUInteger frameIndex = [timePoints indexOfObject:time];

            NSString * filePathComponent = [[[[url lastPathComponent]
                    stringByDeletingPathExtension]
                    stringByAppendingFormat:@"_extracted_frame_%d", (int) frameIndex]
                    stringByAppendingPathExtension:extension];

            NSURL * destFileURL = [destDir URLByAppendingPathComponent:filePathComponent isDirectory:NO];

            UIImage * currentFrameImage = [UIImage imageWithCGImage:[generator copyCGImageAtTime:[time CMTimeValue] actualTime:nil error:&error] scale:1 orientation:UIImageOrientationUp];

            //rescale
            if(outputScale != 1){
                currentFrameImage = [self.class imageByScalingToFill:currentFrameImage size:CGSizeMake(currentFrameImage.size.width * outputScale, currentFrameImage.size.height * outputScale) rescaleTo:currentFrameImage.scale];
            }

            //crop
            if(!CGSizeEqualToSize(aspectRatioToCrop,CGSizeZero)){
                currentFrameImage = [self.class imageByCroppingRect:currentFrameImage rect:CropRectAspectFill(currentFrameImage.size, aspectRatioToCrop)];
            }

            NSUInteger position = [timePoints indexOfObject:time]+1;
            !handler?:handler((CGFloat)position/lengthOfTimePoints,position, lengthOfTimePoints, [time CMTimeValue], &stop, nil);

            if(stop){
                break;
            }

            if([self.class writeImage:currentFrameImage toURL:destFileURL]){
                [resultFrameImagesUrls addObject:destFileURL];
            }
        }
    }

    return resultFrameImagesUrls;
}

#pragma mark Utils - I/O
+ (BOOL)writeImage:(UIImage *)image toURL:(NSURL *)filePathURL{
    NSData * imageData;
    if([@"image/png" isEqualToString:[self mimeTypeFromPathExtension:[filePathURL path]]]){
        imageData = UIImagePNGRepresentation(image);
    }else{
        imageData = UIImageJPEGRepresentation(image, 1);
    }
    return [imageData writeToURL:filePathURL atomically:YES];
}

+ (NSString *)mimeTypeFromPathExtension:(NSString *)pathExtension {
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)pathExtension, NULL);
    CFStringRef mimeType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    if (!mimeType) {
        return @"application/octet-stream";
    }
    NSString * _mimeType = (__bridge_transfer NSString*)mimeType;
    return _mimeType;
}

#pragma mark Utils - Images
+ (UIImage *)imageByCroppingRect:(UIImage *)image rect:(CGRect)rect {
    CGImageRef croppedImageRef = CGImageCreateWithImageInRect([image CGImage], rect);
    UIImage *croppedImage = [UIImage imageWithCGImage:croppedImageRef scale:image.scale orientation:image.imageOrientation];
    if (croppedImageRef) {
        CGImageRelease(croppedImageRef);
    }
    return croppedImage;
}

+ (UIImage*)imageByScalingToFill:(UIImage *)image size:(CGSize)fillSize rescaleTo:(CGFloat)scaleToRescale{
    CGImageRef sourceRef = image.CGImage;
    vImage_Buffer srcBuffer;
    vImage_CGImageFormat format = {
            .bitsPerComponent = 8,
            .bitsPerPixel = 32,
            .colorSpace = NULL,
            .bitmapInfo = (CGBitmapInfo) kCGImageAlphaFirst,
            .version = 0,
            .decode = NULL,
            .renderingIntent = kCGRenderingIntentDefault,
    };
    vImage_Error ret = vImageBuffer_InitWithCGImage(&srcBuffer, &format, NULL, sourceRef, kvImageNoFlags);
    if (ret != kvImageNoError) {
        free(srcBuffer.data);
        return nil;
    }

    const NSUInteger scale = (NSUInteger) scaleToRescale;
    const NSUInteger dstWidth = (NSUInteger) fillSize.width * scale;
    const NSUInteger dstHeight = (NSUInteger) fillSize.height * scale;
    const NSUInteger bytesPerPixel = 4;
    const NSUInteger dstBytesPerRow = bytesPerPixel * dstWidth;
    uint8_t *dstData = (uint8_t *) calloc(dstHeight * dstWidth * bytesPerPixel, sizeof(uint8_t));
    vImage_Buffer dstBuffer = {
            .data = dstData,
            .height = dstHeight,
            .width = dstWidth,
            .rowBytes = dstBytesPerRow
    };

    ret = vImageScale_ARGB8888(&srcBuffer, &dstBuffer, NULL, kvImageHighQualityResampling);
    free(srcBuffer.data);
    if (ret != kvImageNoError) {
        free(dstData);
        return nil;
    }

    ret = kvImageNoError;
    CGImageRef destRef = vImageCreateCGImageFromBuffer(&dstBuffer, &format, NULL, NULL, kvImageNoFlags, &ret);
    free(dstData);

    UIImage *destImage = [[UIImage alloc] initWithCGImage:destRef scale:0.0 orientation:image.imageOrientation];
    CGImageRelease(destRef);
    CGImageRelease(sourceRef);

    return destImage;
}

@end
