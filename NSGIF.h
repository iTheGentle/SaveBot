//
//  NSGIF.h
//
//  Created by Sebastian Dobrincu
//  Modified by Brian Lee (github.com/metasmile)
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, NSGIFScale) {
    NSGIFScaleOptimize,
    NSGIFScaleVeryLow,
    NSGIFScaleLow,
    NSGIFScaleMedium,
    NSGIFScaleHigh,
    NSGIFScaleOriginal
};

typedef void (^ NSGIFProgressHandler)(double progress, NSUInteger offset, NSUInteger length, CMTime time, BOOL *__nullable stop, NSDictionary *__nullable frameProperties);

#pragma mark NSSerializedAssetRequest
@interface NSSerializedResourceRequest : NSObject
/* required.
 * a file's url of source video */
@property(nullable, nonatomic) NSURL * sourceVideoFile;

/*optional (addition by Sean Howard)
 * ignoring any other parameters, will scale according to scale value
 */
@property(nonatomic, assign) CGFloat hardScale;

/* optional but important.
 * Defaults to NSGIFScaleOptimize (not set).
 * This option will affect gif file size, memory usage and processing speed. */
@property(nonatomic, assign) NSGIFScale scalePreset;

/* optional.
 * Defaults is to not set. unit is seconds, which means unlimited */
@property(nonatomic, assign) NSTimeInterval maxDuration;

/* readonly
 * Automatically measure from maxDuration, framesPerSecond and frameCount */
@property(nonatomic, readonly) NSTimeInterval durationMeasured;

/* optional but important.
 * Defaults to 4.
 * number of frames in seconds.
 * This option will affect gif file size, memory usage and processing speed. */
@property(nonatomic, assign) NSUInteger framesPerSecond;

/* optional but defaults is recommended.
 * Defaults is to not set.
 * How far along the video track we want to move, in seconds. It will automatically assign from duration of video and framesPerSecond. */
@property(nonatomic, assign) NSUInteger frameCount;

/* optional.
 * Defaults is to not set.
 * This option will crop(via AspectFill Mode) fast while create each images. Their size will be automatically calculated.
 * ex)
 *  square  : aspectRatioToCrop = CGSizeMake(1,1)
 *  16:9    : aspectRatioToCrop = CGSizeMake(16,9) */
@property(nonatomic, assign) CGSize aspectRatioToCrop;

/* optional.
 * Defaults is nil */
@property (nonatomic, copy, nullable) NSGIFProgressHandler progressHandler;

/* readonly
 * status for gif creating job 'YES' equals to 'now proceeding'
 */
@property(atomic, readonly) BOOL proceeding;

- (instancetype __nonnull)initWithSourceVideo:(NSURL * __nullable)fileURL;
+ (instancetype __nonnull)requestWithSourceVideo:(NSURL * __nullable)fileURL;
@end

#pragma mark NSGIFRequest
@interface NSGIFRequest : NSSerializedResourceRequest

/* optional.
 * defaults to nil.
 * automatically assign the file name of source video (ex: IMG_0000.MOV -> IMG_0000.gif)  */
@property(nullable, nonatomic) NSURL * destinationVideoFile;

/* optional.
 * Defaults to 0,
 * the number of times the GIF will repeat. which means repeat infinitely. */
@property(nonatomic, assign) NSUInteger loopCount;

/* optional.
 * Defaults to NO,
 * Useful option to make auto-reversing animation */
@property(nonatomic, assign) BOOL appendReversedFrames;

+ (NSGIFRequest * __nonnull)requestWithSourceVideo:(NSURL * __nullable)fileURL destination:(NSURL * __nullable)videoFileURL;
+ (NSGIFRequest * __nonnull)requestWithSourceVideoForLivePhoto:(NSURL *__nullable)fileURL;
@end

#pragma mark NSExtractFramesRequest
@interface NSFrameExtractingRequest : NSSerializedResourceRequest
/* optional.
 * Defaults to jpg.
 * This property will be affect to UTType(Automatically detected) of extracting image file.
 */
@property(nonatomic, readwrite, nullable) NSString * extension;

/* optional.
 * defaults to temp directory.
 */
@property(nullable, nonatomic) NSURL * destinationDirectory;
@end

#pragma mark NSSerializedResourceResponse
@interface NSSerializedResourceResponse : NSObject

@property(nullable, nonatomic, readonly) NSArray<NSURL *> * imageUrls;

@end

@interface NSFrameExtractingResponse : NSSerializedResourceResponse

@property(nonatomic, readonly) NSTimeInterval durationOfFrames;

@end

@interface NSGIF : NSObject

+ (void)create:(NSGIFRequest *__nullable)request completion:(void (^ __nullable)(NSURL * __nullable))completionBlock;

+ (void)extract:(NSFrameExtractingRequest *__nullable)request completion:(void (^ __nullable)(NSFrameExtractingResponse * __nullable))completionBlock;
@end
