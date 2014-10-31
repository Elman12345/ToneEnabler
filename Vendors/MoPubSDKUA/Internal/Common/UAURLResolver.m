//
//  UAURLResolver.m
//  MoPub
//
//  Copyright (c) 2013 MoPub. All rights reserved.
//

#import "UAURLResolver.h"
#import "NSURL+UAAdditions.h"
#import "UAInstanceProvider.h"
#import "UALogging.h"
#import "UACoreInstanceProvider.h"

static NSString * const kMoPubSafariScheme = @"mopubnativebrowser";
static NSString * const kMoPubSafariNavigateHost = @"navigate";
static NSString * const kMoPubHTTPHeaderContentType = @"Content-Type";

@interface UAURLResolver ()

@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, assign) NSStringEncoding responseEncoding;

- (BOOL)handleURL:(NSURL *)URL;
- (NSString *)storeItemIdentifierForURL:(NSURL *)URL;
- (BOOL)URLShouldOpenInApplication:(NSURL *)URL;
- (BOOL)URLIsHTTPOrHTTPS:(NSURL *)URL;
- (BOOL)URLPointsToAMap:(NSURL *)URL;
- (NSStringEncoding)stringEncodingFromContentType:(NSString *)contentType;

@end

@implementation UAURLResolver

@synthesize URL = _URL;
@synthesize delegate = _delegate;
@synthesize connection = _connection;
@synthesize responseData = _responseData;

+ (UAURLResolver *)resolver
{
    return [[UAURLResolver alloc] init];
}


- (void)startResolvingWithURL:(NSURL *)URL delegate:(id<UAURLResolverDelegate>)delegate
{
    [self.connection cancel];

    self.URL = URL;
    self.delegate = delegate;
    self.responseData = [NSMutableData data];
    self.responseEncoding = NSUTF8StringEncoding;

    if (![self handleURL:self.URL]) {
        NSURLRequest *request = [[UACoreInstanceProvider sharedProvider] buildConfiguredURLRequestWithURL:self.URL];
        self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
    }
}

- (void)cancel
{
    [self.connection cancel];
    self.connection = nil;
}

#pragma mark - Handling Application/StoreKit URLs

/*
 * Parses the provided URL for actions to perform (opening StoreKit, opening Safari, etc.).
 * If the URL represents an action, this method will inform its delegate of the correct action to
 * perform.
 *
 * Returns YES if the URL contained an action, and NO otherwise.
 */
- (BOOL)handleURL:(NSURL *)URL
{
    if ([self storeItemIdentifierForURL:URL]) {
        [self.delegate showStoreKitProductWithParameter:[self storeItemIdentifierForURL:URL] fallbackURL:URL];
    } else if ([self safariURLForURL:URL]) {
        NSURL *safariURL = [NSURL URLWithString:[self safariURLForURL:URL]];
        [self.delegate openURLInApplication:safariURL];
    } else if ([self URLShouldOpenInApplication:URL]) {
        if ([[UIApplication sharedApplication] canOpenURL:URL]) {
            [self.delegate openURLInApplication:URL];
        } else {
            [self.delegate failedToResolveURLWithError:[NSError errorWithDomain:@"com.mopub" code:-1 userInfo:nil]];
        }
    } else {
        return NO;
    }

    return YES;
}

#pragma mark Identifying Application URLs

- (BOOL)URLShouldOpenInApplication:(NSURL *)URL
{
    return ![self URLIsHTTPOrHTTPS:URL] || [self URLPointsToAMap:URL];
}

- (BOOL)URLIsHTTPOrHTTPS:(NSURL *)URL
{
    return [URL.scheme isEqualToString:@"http"] || [URL.scheme isEqualToString:@"https"];
}

- (BOOL)URLPointsToAMap:(NSURL *)URL
{
    return [URL.host hasSuffix:@"maps.google.com"] || [URL.host hasSuffix:@"maps.apple.com"];
}

#pragma mark Extracting StoreItem Identifiers

- (NSString *)storeItemIdentifierForURL:(NSURL *)URL
{
    NSString *itemIdentifier = nil;
    if ([URL.host hasSuffix:@"itunes.apple.com"]) {
        NSString *lastPathComponent = [[URL path] lastPathComponent];
        if ([lastPathComponent hasPrefix:@"id"]) {
            itemIdentifier = [lastPathComponent substringFromIndex:2];
        } else {
            itemIdentifier = [URL.mp_queryAsDictionary objectForKey:@"id"];
        }
    } else if ([URL.host hasSuffix:@"phobos.apple.com"]) {
        itemIdentifier = [URL.mp_queryAsDictionary objectForKey:@"id"];
    }

    NSCharacterSet *nonIntegers = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if (itemIdentifier && itemIdentifier.length > 0 && [itemIdentifier rangeOfCharacterFromSet:nonIntegers].location == NSNotFound) {
        return itemIdentifier;
    }

    return nil;
}

#pragma mark - Identifying URLs to open in Safari

- (NSString *)safariURLForURL:(NSURL *)URL
{
    NSString *safariURL = nil;

    if ([[URL scheme] isEqualToString:kMoPubSafariScheme] &&
        [[URL host] isEqualToString:kMoPubSafariNavigateHost]) {
        safariURL = [URL.mp_queryAsDictionary objectForKey:@"url"];
    }

    return safariURL;
}

#pragma mark - Identifying NSStringEncoding from NSURLResponse Content-Type header

- (NSStringEncoding)stringEncodingFromContentType:(NSString *)contentType
{
    NSStringEncoding encoding = NSUTF8StringEncoding;

    if (![contentType length]) {
        UALogWarn(@"Attempting to set string encoding from nil %@", kMoPubHTTPHeaderContentType);
        return encoding;
    }

    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?<=charset=)[^;]*" options:kNilOptions error:nil];

    NSTextCheckingResult *charsetResult = [regex firstMatchInString:contentType options:kNilOptions range:NSMakeRange(0, [contentType length])];
    if (charsetResult && charsetResult.range.location != NSNotFound) {
        NSString *charset = [contentType substringWithRange:[charsetResult range]];

        // ensure that charset is not deallocated early
        CFStringRef cfCharset = CFBridgingRetain(charset);
        CFStringEncoding cfEncoding = CFStringConvertIANACharSetNameToEncoding(cfCharset);
        CFBridgingRelease(cfCharset);

        if (cfEncoding == kCFStringEncodingInvalidId) {
            return encoding;
        }
        encoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
    }

    return encoding;
}

#pragma mark - <NSURLConnectionDataDelegate>

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.responseData appendData:data];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    if ([self handleURL:request.URL]) {
        [connection cancel];
        return nil;
    } else {
        self.URL = request.URL;
        return request;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSDictionary *headers = [(NSHTTPURLResponse *)response allHeaderFields];
    NSString *contentType = [headers objectForKey:kMoPubHTTPHeaderContentType];
    self.responseEncoding = [self stringEncodingFromContentType:contentType];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self.delegate showWebViewWithHTMLString:[[NSString alloc] initWithData:self.responseData encoding:self.responseEncoding] baseURL:self.URL];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self.delegate failedToResolveURLWithError:error];
}

@end