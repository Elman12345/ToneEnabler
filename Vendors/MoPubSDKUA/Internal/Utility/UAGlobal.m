//
//  UAGlobal.m
//  MoPub
//
//  Copyright 2011 MoPub, Inc. All rights reserved.
//

#import "UAGlobal.h"
#import "UAConstants.h"
#import "UALogging.h"
#import "NSURL+UAAdditions.h"
#import <CommonCrypto/CommonDigest.h>

#import <sys/types.h>
#import <sys/sysctl.h>

BOOL UAViewHasHiddenAncestor(UIView *view);
UIWindow *UAViewGetParentWindow(UIView *view);
BOOL UAViewIntersectsParentWindow(UIView *view);
NSString *UASHA1Digest(NSString *string);

UIInterfaceOrientation UAInterfaceOrientation()
{
    return [UIApplication sharedApplication].statusBarOrientation;
}

UIWindow *UAKeyWindow()
{
    return [UIApplication sharedApplication].keyWindow;
}

CGFloat UAStatusBarHeight() {
    if ([UIApplication sharedApplication].statusBarHidden) return 0.0;

    UIInterfaceOrientation orientation = UAInterfaceOrientation();

    return UIInterfaceOrientationIsLandscape(orientation) ?
        CGRectGetWidth([UIApplication sharedApplication].statusBarFrame) :
        CGRectGetHeight([UIApplication sharedApplication].statusBarFrame);
}

CGRect UAApplicationFrame()
{
    CGRect frame = UAScreenBounds();

    frame.origin.y += UAStatusBarHeight();
    frame.size.height -= UAStatusBarHeight();

    return frame;
}

CGRect UAScreenBounds()
{
    CGRect bounds = [UIScreen mainScreen].bounds;

    if (UIInterfaceOrientationIsLandscape(UAInterfaceOrientation()))
    {
        CGFloat width = bounds.size.width;
        bounds.size.width = bounds.size.height;
        bounds.size.height = width;
    }

    return bounds;
}

CGFloat UADeviceScaleFactor()
{
    if ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] &&
        [[UIScreen mainScreen] respondsToSelector:@selector(scale)])
    {
        return [[UIScreen mainScreen] scale];
    }
    else return 1.0;
}

NSDictionary *UADictionaryFromQueryString(NSString *query) {
    NSMutableDictionary *queryDict = [NSMutableDictionary dictionary];
    NSArray *queryElements = [query componentsSeparatedByString:@"&"];
    for (NSString *element in queryElements) {
        NSArray *keyVal = [element componentsSeparatedByString:@"="];
        NSString *key = [keyVal objectAtIndex:0];
        NSString *value = [keyVal lastObject];
        [queryDict setObject:[value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                      forKey:key];
    }
    return queryDict;
}

NSString *UASHA1Digest(NSString *string)
{
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    NSData *data = [string dataUsingEncoding:NSASCIIStringEncoding];
    CC_SHA1([data bytes], (CC_LONG)[data length], digest);

    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
    {
        [output appendFormat:@"%02x", digest[i]];
    }

    return output;
}

BOOL UAViewIsVisible(UIView *view)
{
    // In order for a view to be visible, it:
    // 1) must not be hidden,
    // 2) must not have an ancestor that is hidden,
    // 3) must be within the frame of its parent window.
    //
    // Note: this function does not check whether any part of the view is obscured by another view.

    return (!view.hidden &&
            !UAViewHasHiddenAncestor(view) &&
            UAViewIntersectsParentWindow(view));
}

BOOL UAViewHasHiddenAncestor(UIView *view)
{
    UIView *ancestor = view.superview;
    while (ancestor) {
        if (ancestor.hidden) return YES;
        ancestor = ancestor.superview;
    }
    return NO;
}

UIWindow *UAViewGetParentWindow(UIView *view)
{
    UIView *ancestor = view.superview;
    while (ancestor) {
        if ([ancestor isKindOfClass:[UIWindow class]]) {
            return (UIWindow *)ancestor;
        }
        ancestor = ancestor.superview;
    }
    return nil;
}

BOOL UAViewIntersectsParentWindow(UIView *view)
{
    UIWindow *parentWindow = UAViewGetParentWindow(view);

    if (parentWindow == nil) {
        return NO;
    }

    // We need to call convertRect:toView: on this view's superview rather than on this view itself.
    CGRect viewFrameInWindowCoordinates = [view.superview convertRect:view.frame toView:parentWindow];

    return CGRectIntersectsRect(viewFrameInWindowCoordinates, parentWindow.frame);
}

BOOL UAViewIntersectsParentWindowWithPercent(UIView *view, CGFloat percentVisible)
{
    UIWindow *parentWindow = UAViewGetParentWindow(view);

    if (parentWindow == nil) {
        return NO;
    }

    // We need to call convertRect:toView: on this view's superview rather than on this view itself.
    CGRect viewFrameInWindowCoordinates = [view.superview convertRect:view.frame toView:parentWindow];
    CGRect intersection = CGRectIntersection(viewFrameInWindowCoordinates, parentWindow.frame);

    CGFloat intersectionArea = CGRectGetWidth(intersection) * CGRectGetHeight(intersection);
    CGFloat originalArea = CGRectGetWidth(view.bounds) * CGRectGetHeight(view.bounds);

    return intersectionArea >= (originalArea * percentVisible);
}

////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation NSString (UAAdditions)

- (NSString *)URLEncodedString
{
    NSString *result = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                           (CFStringRef)self,
                                                                           NULL,
                                                                           (CFStringRef)@"!*'();:@&=+$,/?%#[]<>",
                                                                           kCFStringEncodingUTF8));
    return result;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation UIDevice (UAAdditions)

- (NSString *)hardwareDeviceName
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    return platform;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@interface UATelephoneConfirmationController ()

@property (nonatomic, strong) UIAlertView *alertView;
@property (nonatomic, strong) NSURL *telephoneURL;
@property (nonatomic, copy) UATelephoneConfirmationControllerClickHandler clickHandler;

@end

@implementation UATelephoneConfirmationController

- (id)initWithURL:(NSURL *)url clickHandler:(UATelephoneConfirmationControllerClickHandler)clickHandler
{
    if (![url mp_hasTelephoneScheme] && ![url mp_hasTelephonePromptScheme]) {
        // Shouldn't be here as the url must have a tel or telPrompt scheme.
        UALogError(@"Processing URL as a telephone URL when %@ doesn't follow the tel:// or telprompt:// schemes", url.absoluteString);
        return nil;
    }

    if (self = [super init]) {
        // If using tel://xxxxxxx, the host will be the number.  If using tel:xxxxxxx, we will try the resourceIdentifier.
        NSString *phoneNumber = [url host];

        if (!phoneNumber) {
            phoneNumber = [url resourceSpecifier];
            if ([phoneNumber length] == 0) {
                UALogError(@"Invalid telelphone URL: %@.", url.absoluteString);
                return nil;
            }
        }

        _alertView = [[UIAlertView alloc] initWithTitle: @"Are you sure you want to call?"
                                                message:phoneNumber
                                               delegate:self
                                      cancelButtonTitle:@"Cancel"
                                      otherButtonTitles:@"Call", nil];
        self.clickHandler = clickHandler;

        // We want to manually handle telPrompt scheme alerts.  So we'll convert telPrompt schemes to tel schemes.
        if ([url mp_hasTelephonePromptScheme]) {
            self.telephoneURL = [NSURL URLWithString:[NSString stringWithFormat:@"tel://%@", phoneNumber]];
        } else {
            self.telephoneURL = url;
        }
    }

    return self;
}

- (void)dealloc
{
    self.alertView.delegate = nil;
    [self.alertView dismissWithClickedButtonIndex:0 animated:YES];
}

- (void)show
{
    [self.alertView show];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    BOOL confirmed = (buttonIndex == 1);

    if (self.clickHandler) {
        self.clickHandler(self.telephoneURL, confirmed);
    }

}

@end
