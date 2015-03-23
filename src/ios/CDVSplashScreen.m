/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CDVSplashScreen.h"
#import <Cordova/CDVViewController.h>
#import <Cordova/CDVScreenOrientationDelegate.h>

#define kSplashScreenDurationDefault 0.25f


@implementation CDVSplashScreen

- (void)pluginInitialize
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageDidLoad) name:CDVPageDidLoadNotification object:self.webView];

    [self setVisible:YES];
}

- (void)show:(CDVInvokedUrlCommand*)command
{
    [self setVisible:YES];
}

- (void)hide:(CDVInvokedUrlCommand*)command
{
    [self setVisible:NO];
}

- (void)pageDidLoad
{
    id autoHideSplashScreenValue = [self.commandDelegate.settings objectForKey:[@"AutoHideSplashScreen" lowercaseString]];

    // if value is missing, default to yes
    if ((autoHideSplashScreenValue == nil) || [autoHideSplashScreenValue boolValue]) {
        [self setVisible:NO];
    }
}

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
    NSLog(@"keyPath: %@, obj: %@, change: %@", keyPath, [object description], [change description]);
//    [self updateImage];
    [self updateImageToFrame:((UIView*)object).frame];
}

- (void)createViews
{
    /*
     * The Activity View is the top spinning throbber in the status/battery bar. We init it with the default Grey Style.
     *
     *     whiteLarge = UIActivityIndicatorViewStyleWhiteLarge
     *     white      = UIActivityIndicatorViewStyleWhite
     *     gray       = UIActivityIndicatorViewStyleGray
     *
     */
    NSString* topActivityIndicator = [self.commandDelegate.settings objectForKey:[@"TopActivityIndicator" lowercaseString]];
    UIActivityIndicatorViewStyle topActivityIndicatorStyle = UIActivityIndicatorViewStyleGray;

    if ([topActivityIndicator isEqualToString:@"whiteLarge"]) {
        topActivityIndicatorStyle = UIActivityIndicatorViewStyleWhiteLarge;
    } else if ([topActivityIndicator isEqualToString:@"white"]) {
        topActivityIndicatorStyle = UIActivityIndicatorViewStyleWhite;
    } else if ([topActivityIndicator isEqualToString:@"gray"]) {
        topActivityIndicatorStyle = UIActivityIndicatorViewStyleGray;
    }

    UIView* parentView = self.viewController.view;
    parentView.userInteractionEnabled = NO;  // disable user interaction while splashscreen is shown
    _activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:topActivityIndicatorStyle];
    _activityView.center = CGPointMake(parentView.bounds.size.width / 2, parentView.bounds.size.height / 2);
    _activityView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin
        | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    [_activityView startAnimating];

    // Set the frame & image later.
    [self initImagesWithParent:parentView];

    id showSplashScreenSpinnerValue = [self.commandDelegate.settings objectForKey:[@"ShowSplashScreenSpinner" lowercaseString]];
    // backwards compatibility - if key is missing, default to true
    if ((showSplashScreenSpinnerValue == nil) || [showSplashScreenSpinnerValue boolValue]) {
        [parentView addSubview:_activityView];
    }

    // Frame is required when launching in portrait mode.
    // Bounds for landscape since it captures the rotation.
    [parentView addObserver:self forKeyPath:@"frame" options:0 context:nil];
    [parentView addObserver:self forKeyPath:@"bounds" options:0 context:nil];
}

- (void)destroyViews
{
    [self destroyImages];
    [_activityView removeFromSuperview];
    _activityView = nil;
    _curImageName = nil;

    self.viewController.view.userInteractionEnabled = YES;  // re-enable user interaction upon completion
    [self.viewController.view removeObserver:self forKeyPath:@"frame"];
    [self.viewController.view removeObserver:self forKeyPath:@"bounds"];
}

- (CDV_iOSDevice) getCurrentDevice
{
    CDV_iOSDevice device;
    
    UIScreen* mainScreen = [UIScreen mainScreen];
    CGFloat mainScreenHeight = mainScreen.bounds.size.height;
    CGFloat mainScreenWidth = mainScreen.bounds.size.width;
    
    int limit = MAX(mainScreenHeight,mainScreenWidth);
    
    device.iPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    device.iPhone = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone);
    device.retina = ([mainScreen scale] == 2.0);
    device.iPhone5 = (device.iPhone && limit == 568.0);
    // note these below is not a true device detect, for example if you are on an
    // iPhone 6/6+ but the app is scaled it will prob set iPhone5 as true, but
    // this is appropriate for detecting the runtime screen environment
    device.iPhone6 = (device.iPhone && limit == 667.0);
    device.iPhone6Plus = (device.iPhone && limit == 736.0);
    
    return device;
}

-(NSString*) getInterfaceOrientationString:(UIInterfaceOrientation)orientation {
    switch (orientation) {
        case UIInterfaceOrientationPortrait:
            return @"Portrait";
        case UIInterfaceOrientationPortraitUpsideDown:
            return @"Upsidedown";
        case UIInterfaceOrientationLandscapeLeft:
            return @"LandscapeLeft";
        case UIInterfaceOrientationLandscapeRight:
            return @"LandscapeRight";
        default:
            break;
    }
    return @"Unknown";
}

- (void)setVisible:(BOOL)visible
{
    if (visible == _visible) {
        return;
    }
    _visible = visible;

    id fadeSplashScreenValue = [self.commandDelegate.settings objectForKey:[@"FadeSplashScreen" lowercaseString]];
    id fadeSplashScreenDuration = [self.commandDelegate.settings objectForKey:[@"FadeSplashScreenDuration" lowercaseString]];

    float fadeDuration = fadeSplashScreenDuration == nil ? kSplashScreenDurationDefault : [fadeSplashScreenDuration floatValue];

    if ((fadeSplashScreenValue == nil) || ![fadeSplashScreenValue boolValue]) {
        fadeDuration = 0;
    }

    // Never animate the showing of the splash screen.
    if (visible) {
        if (_imageView_p == nil && _imageView_l == nil) {
            [self createViews];
        }
    } else if (fadeDuration == 0) {
        [self destroyViews];
    } else {
        [UIView transitionWithView:self.viewController.view
                          duration:fadeDuration
                           options:UIViewAnimationOptionTransitionNone
                        animations:^(void) {
                            [_imageView_p setAlpha:0];
                            [_imageView_l setAlpha:0];
                            [_activityView setAlpha:0];
                        }
                        completion:^(BOOL finished) {
                            if (finished) {
                                [self destroyViews];
                            }
                        }
        ];
    }
}


-(void)initImagesWithParent:(UIView*)parentView {
    NSUInteger supportedOrientations = [self.viewController supportedInterfaceOrientations];
    _supportsLandscape = (supportedOrientations & UIInterfaceOrientationMaskLandscape);
    _supportsPortrait = (supportedOrientations & UIInterfaceOrientationMaskPortrait || supportedOrientations & UIInterfaceOrientationMaskPortraitUpsideDown);
    

    _imageView_p = [[UIImageView alloc] init];
    [_imageView_p setHidden:YES];
    _imageView_l = [[UIImageView alloc] init];
    [_imageView_l setHidden:YES];
    
    if (_supportsPortrait) {
        NSString* imageName = [self getImageName:UIInterfaceOrientationPortrait device:[self getCurrentDevice]];
        UIImage* img = [UIImage imageNamed:imageName];
        if (img) {
            _imageView_p.image = img;
            [self updateImageBounds:_imageView_p];
            [parentView addSubview:_imageView_p];
        }
        else {
            NSLog(@"WARNING! Image '%@' not found!", imageName);
        }
    }
    
    
    if (_supportsLandscape) {
        NSString* imageName = [self getImageName:UIInterfaceOrientationLandscapeLeft device:[self getCurrentDevice]];
        UIImage* img = [UIImage imageNamed:imageName];
        if (img) {
            _imageView_l.image = img;
            [self updateImageBounds:_imageView_l];
            [parentView addSubview:_imageView_l];
        }
        else {
            NSLog(@"WARNING! Image '%@' not found!", imageName);
        }
    }
    
    [self updateImageToFrame:self.viewController.view.bounds];
}

-(void)destroyImages {
    if (_supportsPortrait) [_imageView_p removeFromSuperview];
    if (_supportsLandscape) [_imageView_l removeFromSuperview];
    _imageView_p = nil;
    _imageView_l = nil;
}

-(void)updateImageBounds:(UIImageView*)imgView {
    UIImage* img = imgView.image;
    CGRect imgBounds = (img) ? CGRectMake(0, 0, img.size.width, img.size.height) : CGRectZero;
    
    CGSize screenSize = [self.viewController.view convertRect:[UIScreen mainScreen].bounds fromView:nil].size;
    
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
    if (imgBounds.size.width > imgBounds.size.height) {
        orientation = UIInterfaceOrientationLandscapeLeft;
    }
    
    CGAffineTransform imgTransform = CGAffineTransformIdentity;
    
    /* If and only if an iPhone application is landscape-only as per
     * UISupportedInterfaceOrientations, the view controller's orientation is
     * landscape. In this case the image must be rotated in order to appear
     * correctly.
     */
    BOOL isIPad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
    if (UIInterfaceOrientationIsLandscape(orientation) && !isIPad) {
        imgTransform = CGAffineTransformMakeRotation(M_PI / 2);
        imgBounds.size = CGSizeMake(imgBounds.size.height, imgBounds.size.width);
    }
    
    // There's a special case when the image is the size of the screen.
    if (CGSizeEqualToSize(screenSize, imgBounds.size)) {
        CGRect statusFrame = [self.viewController.view convertRect:[UIApplication sharedApplication].statusBarFrame fromView:nil];
        if (!(IsAtLeastiOSVersion(@"7.0"))) {
            imgBounds.origin.y -= statusFrame.size.height;
        }
    } else if (imgBounds.size.width > 0) {
        CGRect viewBounds = self.viewController.view.bounds;
        if ((viewBounds.size.width > viewBounds.size.height && orientation == UIInterfaceOrientationPortrait) ||
            (viewBounds.size.width < viewBounds.size.height && orientation == UIInterfaceOrientationLandscapeLeft)) {
            CGSize newbounds = CGSizeMake(viewBounds.size.height, viewBounds.size.width);
            viewBounds.size = newbounds;
        }
        CGFloat imgAspect = imgBounds.size.width / imgBounds.size.height;
        CGFloat viewAspect = viewBounds.size.width / viewBounds.size.height;
        // This matches the behaviour of the native splash screen.
        CGFloat ratio;
        if (viewAspect > imgAspect) {
            ratio = viewBounds.size.width / imgBounds.size.width;
        } else {
            ratio = viewBounds.size.height / imgBounds.size.height;
        }
        imgBounds.size.height *= ratio;
        imgBounds.size.width *= ratio;
    }
    
    imgView.transform = imgTransform;
    imgView.frame = imgBounds;
}

-(BOOL)isLandscape:(UIInterfaceOrientation)orientation {
    return orientation == UIInterfaceOrientationLandscapeRight || orientation == UIInterfaceOrientationLandscapeLeft;
}

-(BOOL)isPortrait:(UIInterfaceOrientation)orientation {
    return orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown;
}

-(void)rotateImage:(UIImageView*)imgView {
    CGAffineTransform imgTransform = CGAffineTransformMakeRotation(M_PI / 2);
    CGSize flipFrame =  CGSizeMake(imgView.frame.size.height, imgView.frame.size.width);
    imgView.frame = CGRectMake(0, 0, flipFrame.width, flipFrame.height);
    imgView.transform = imgTransform;
    
}

-(void)showLandscape:(CGRect)frame {
    [_imageView_p setHidden:YES];
    [_imageView_l setHidden:NO];
    _imageView_l.frame = frame;
}

-(void)showPortrait:(CGRect)frame {
    [_imageView_p setHidden:NO];
    [_imageView_l setHidden:YES];
    _imageView_p.frame = frame;
}

-(void)updateImageToFrame:(CGRect)frame {
    UIInterfaceOrientation currentOrientation = frame.size.width > frame.size.height ? UIInterfaceOrientationLandscapeLeft : UIInterfaceOrientationPortrait;
    
    if ([self isLandscape:currentOrientation]) {
        // simple case
        if (_supportsLandscape) {
            [self showLandscape:frame];
        }
        else {
            [self showPortrait:frame];
            // rotate image and flip frame
            [self rotateImage:_imageView_p];
        }
    }
    else {
        // simple case
        if (_supportsPortrait) {
            [self showPortrait:frame];
        }
        else {
            [self showLandscape:frame];
            // rotate image and flip frame
            [self rotateImage:_imageView_l];
        }
    }
    
}

- (NSString*)getImageName:(UIInterfaceOrientation)orientation device:(CDV_iOSDevice)device
{
    // Use UILaunchImageFile if specified in plist.  Otherwise, use Default.
    NSString* imageName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UILaunchImageFile"];
    
    if (imageName) {
        imageName = [imageName stringByDeletingPathExtension];
    } else {
        imageName = @"Default";
    }
    
    if (device.iPhone5) { // does not support landscape
        imageName = [imageName stringByAppendingString:@"-568h"];
    } else if (device.iPhone6) { // does not support landscape
        imageName = [imageName stringByAppendingString:@"-667h"];
    } else if (device.iPhone6Plus) { // supports landscape
        switch (orientation) {
            case UIInterfaceOrientationLandscapeLeft:
            case UIInterfaceOrientationLandscapeRight:
                imageName = [imageName stringByAppendingString:@"-Landscape"];
                break;
            default:
                break;
        }
        imageName = [imageName stringByAppendingString:@"-736h"];
        
    } else if (device.iPad) { // supports landscape
        switch (orientation) {
            case UIInterfaceOrientationLandscapeLeft:
            case UIInterfaceOrientationLandscapeRight:
                imageName = [imageName stringByAppendingString:@"-Landscape"];
                break;
                
            case UIInterfaceOrientationPortrait:
            case UIInterfaceOrientationPortraitUpsideDown:
            default:
                imageName = [imageName stringByAppendingString:@"-Portrait"];
                break;
        }
    }
    
    return imageName;
}




@end
