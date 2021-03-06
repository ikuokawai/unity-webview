/*
 * Copyright (C) 2011 Keijiro Takahashi
 * Copyright (C) 2012 GREE, Inc.
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

#import <UIKit/UIKit.h>

extern UIViewController *UnityGetGLViewController();
extern "C" void UnitySendMessage(const char *, const char *, const char *);

#pragma mark - UIWebView Hacks for iOS

@interface UIWebView (ABGUIScrollViewHack)
@property (nonatomic, retain, readonly) UIScrollView *ABG_scrollView;
@end

@implementation UIWebView (ABGUIScrollViewHack)
- (UIScrollView *)ABG_scrollView
{
    if ([self respondsToSelector:@selector(scrollView)]) {
        return [self scrollView];
    }
    
    for (id subview in self.subviews) {
        if ([[subview class] isSubclassOfClass: [UIScrollView class]]) {
            return subview;
        }
    }
    
    return nil;
}
@end

#pragma mark - LoadingIndicatorView

@interface LoadingIndicatorView : UIView

@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, retain) UIColor *color;
@property (nonatomic, retain) UILabel *label;

@end

@implementation LoadingIndicatorView

- (id)initWithFrame:(CGRect)frame scale:(CGFloat)scale
{
	self = [super initWithFrame:frame];
	if(self)
	{
		self.backgroundColor = [UIColor clearColor];
		self.opaque = NO;
		self.autoresizesSubviews = YES;
		self.color = [UIColor colorWithWhite:0.0f alpha:0.4f];
		self.cornerRadius = 8.0f * scale;
		
		UIActivityIndicatorView *indicator = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge] autorelease];
		indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
		indicator.transform = CGAffineTransformMakeScale(scale, scale);
		[indicator startAnimating];
		[self addSubview:indicator];

		self.label = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
		self.label.text = @"Loading...";
		self.label.textAlignment = UITextAlignmentCenter;
		self.label.font = [UIFont boldSystemFontOfSize:12.0f * scale];
		self.label.textColor = [UIColor whiteColor];
		self.label.backgroundColor = [UIColor clearColor];
		[self addSubview:self.label];

		CGFloat margin = 2.0f * scale;
		CGSize indicatorSize = CGSizeApplyAffineTransform(indicator.bounds.size, indicator.transform);
		CGSize labelSize = [self.label.text sizeWithFont:self.label.font];
		CGFloat h = indicatorSize.height + margin + labelSize.height;
		indicator.center = CGPointMake(self.bounds.size.width * 0.5f, self.bounds.size.height * 0.5f - h * 0.5f + indicatorSize.height * 0.5f);
		self.label.frame = CGRectMake(0.0f, indicator.center.y + indicatorSize.height * 0.5f + margin, self.bounds.size.width, labelSize.height);
	}
	return self;
}

- (void)dealloc
{
	self.color = nil;
	self.label = nil;
	[super dealloc];
}

- (void)drawRect:(CGRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetFillColorWithColor(context, self.color.CGColor);
	CGContextMoveToPoint(context, CGRectGetMinX(self.bounds), CGRectGetMaxY(self.bounds) - self.cornerRadius);
	CGContextAddArcToPoint(context, CGRectGetMinX(self.bounds), CGRectGetMinY(self.bounds), CGRectGetMidX(self.bounds), CGRectGetMinY(self.bounds), self.cornerRadius);
	CGContextAddArcToPoint(context, CGRectGetMaxX(self.bounds), CGRectGetMinY(self.bounds), CGRectGetMaxX(self.bounds), CGRectGetMidY(self.bounds), self.cornerRadius);
	CGContextAddArcToPoint(context, CGRectGetMaxX(self.bounds), CGRectGetMaxY(self.bounds), CGRectGetMidX(self.bounds), CGRectGetMaxY(self.bounds), self.cornerRadius);
	CGContextAddArcToPoint(context, CGRectGetMinX(self.bounds), CGRectGetMaxY(self.bounds), CGRectGetMinX(self.bounds), CGRectGetMidY(self.bounds), self.cornerRadius);
	CGContextClosePath(context);
	CGContextFillPath(context);
}

@end

#pragma mark - Objective-C Implementation

@interface WebViewPlugin : NSObject<UIWebViewDelegate>
@property (nonatomic, retain) UIWebView *webView;
@property (nonatomic, copy) NSString *gameObjectName;
@property (nonatomic, copy) NSString *customScheme;
@property (nonatomic, retain) UILabel *label;
@property (nonatomic, retain) LoadingIndicatorView *loadingIndicatorView;
@end

@implementation WebViewPlugin

- (id)initWithGameObjectName:(const char *)gameObjectName_ customScheme:(const char *)scheme
{
    self = [super init];
    if (self) {
        UIView *view = UnityGetGLViewController().view;
        self.webView = [[[UIWebView alloc] initWithFrame:view.frame] autorelease];
        self.webView.delegate = self;
        self.webView.hidden = YES;
        self.webView.dataDetectorTypes = UIDataDetectorTypeNone;
        self.webView.ABG_scrollView.alwaysBounceVertical = NO;
        [self setScrollable:NO];
        [view addSubview:self.webView];
        
        self.gameObjectName = [NSString stringWithUTF8String:gameObjectName_];
        if(scheme != NULL)
        {
            self.customScheme = [NSString stringWithUTF8String:scheme];
        }
        else
        {
            self.customScheme = nil;
        }
    }
    
    return self;
}

- (void)dealloc
{
    self.webView.delegate = nil;
    [self.webView stopLoading];
    [self.webView removeFromSuperview];
    self.webView = nil;
    self.gameObjectName = nil;
	self.loadingIndicatorView = nil;
    [super dealloc];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    NSString *url = [[request URL] absoluteString];
    NSString *scheme = [[request URL] scheme];
    if (self.customScheme != nil && [scheme isEqualToString:self.customScheme]) {
        UnitySendMessage([self.gameObjectName UTF8String],
                         "CallFromJS", [url UTF8String]);
        return NO;
    } else if ([scheme isEqualToString:@"unity"]) {
        UnitySendMessage([self.gameObjectName UTF8String],
                         "CallFromJS", [[url substringFromIndex:6] UTF8String]);
        return NO;
    } else if ([scheme isEqualToString:@"ohttp"]) {
        UnitySendMessage([self.gameObjectName UTF8String],
                         "CallFromJS", [url UTF8String]);
        return NO;
    } else if ([scheme isEqualToString:@"ohttps"]) {
        UnitySendMessage([self.gameObjectName UTF8String],
                         "CallFromJS", [url UTF8String]);
        return NO;
    }
    else {
        return YES;
    }
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    self.webView.ABG_scrollView.hidden = YES;
	
	if(!self.loadingIndicatorView)
	{
		CGFloat scale = ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)? 2.0f: 1.0f);
		CGFloat width = 88.0f * scale;
		CGFloat height = 88.0f * scale;
		self.loadingIndicatorView = [[[LoadingIndicatorView alloc] initWithFrame:CGRectMake(self.webView.bounds.size.width * 0.5f - width * 0.5f, self.webView.bounds.size.height * 0.5f - height * 0.5f, width, height) scale:scale] autorelease];
		[self.webView addSubview:self.loadingIndicatorView];
	}
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    self.webView.ABG_scrollView.hidden = NO;
	[self.loadingIndicatorView removeFromSuperview];
	self.loadingIndicatorView = nil;
    
    UnitySendMessage([self.gameObjectName UTF8String],
                     "CallOnFinish",
                     "");
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    self.webView.ABG_scrollView.hidden = NO;
	[self.loadingIndicatorView removeFromSuperview];
	self.loadingIndicatorView = nil;
    
    NSString *message = [NSString stringWithFormat:@"%d|%@|%@", error.code, error.domain, error.localizedDescription];
    UnitySendMessage([self.gameObjectName UTF8String],
                     "CallOnFail",
                     [message UTF8String]);
}

- (void)loadURL:(const char *)url
{
    if(self.webView.request.mainDocumentURL != nil)
    {
    	[self.webView stringByEvaluatingJavaScriptFromString:@"document.body.innerHTML=\"\";"];
    }

    NSString *urlStr = [NSString stringWithUTF8String:url];
    NSURL *nsurl = [NSURL URLWithString:urlStr];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:nsurl];
    [self.webView loadRequest:request];
}

-(void)reloadURL{
    [self.webView reload];
}

- (void)clearContent
{
	[self.webView loadHTMLString:@"<html><body style=\"background:transparent;\"></body></html>" baseURL:nil];
}

- (void)evaluateJS:(const char *)js
{
    NSString *jsStr = [NSString stringWithUTF8String:js];
    [self.webView stringByEvaluatingJavaScriptFromString:jsStr];
}

- (void)setVisibility:(BOOL)visibility
{
    self.webView.hidden = !visibility;
}

-(void)setScrollable:(BOOL)isScrollable
{
    self.webView.ABG_scrollView.scrollEnabled = isScrollable;
}

-(void)setBounceModeOfVertical:(BOOL)vertical Horizontal:(BOOL)horizontal{
    self.webView.ABG_scrollView.alwaysBounceVertical = vertical;
    self.webView.ABG_scrollView.alwaysBounceHorizontal = horizontal;
}

-(void)setDelaysContentTouchesEnable:(BOOL) deferrable{
    self.webView.ABG_scrollView.delaysContentTouches = deferrable;
}

-(void) setLabelStatusWithColor:(UIColor*)color BackGroundColor:(UIColor*)bgColor Alignment:(UITextAlignment) alignment Font:(UIFont*)font{
    self.label.textColor = color;
    self.label.backgroundColor = bgColor;
    self.label.textAlignment = alignment;
    self.label.font = font;
}

-(void) setLabelShadowWithColor:(UIColor*)color Offset:(CGSize) offset{
    self.label.shadowColor = color;
    self.label.shadowOffset = offset;
}

-(void)setBackground:(BOOL)opaque Color:(UIColor*)color
{
    self.webView.opaque = opaque;
    self.webView.backgroundColor = color;
}

- (void)setFrame:(NSInteger)x positionY:(NSInteger)y width:(NSInteger)width height:(NSInteger)height
{
    UIView* view = UnityGetGLViewController().view;
    CGRect frame = self.webView.frame;
    CGRect screen = view.bounds;
    frame.origin.x = x + ((screen.size.width - width)/2);
    frame.origin.y = -y + ((screen.size.height - height)/2);
    frame.size.width = width;
    frame.size.height = height;
    self.webView.frame = frame;
}

- (void)setMargins:(NSInteger)left top:(NSInteger)top right:(NSInteger)right bottom:(NSInteger)bottom
{
    UIView *view = UnityGetGLViewController().view;
    
    CGRect frame = view.frame;
    CGFloat scale = view.contentScaleFactor;
    frame.size.width -= (left + right) / scale;
    frame.size.height -= (top + bottom) / scale;
    frame.origin.x += left / scale;
    frame.origin.y += top / scale;
    self.webView.frame = frame;
    
}

@end

#pragma mark - Unity Plugin

extern "C" {
    void *_WebViewPlugin_Init(const char *gameObjectName, const char *scheme);
    void _WebViewPlugin_Destroy(void *instance);
    void _WebViewPlugin_LoadURL(void *instance, const char *url);
    void _WebViewPlugin_ReloadURL(void* instance);
	void _WebViewPlugin_ClearContent(void* instance);
    void _WebViewPlugin_EvaluateJS(void *instance, const char *url);
    void _WebViewPlugin_SetVisibility(void *instance, BOOL visibility);
    void _WebViewPlugin_SetBackgroundColor(void* instance,CGFloat r,CGFloat g,CGFloat b,CGFloat a,BOOL opaque);
    void _WebViewPlugin_SetScrollable(void* instance,BOOL scrollable);
    void _WebViewPlugin_SetBounceMode(void* instance,BOOL vertical,BOOL horizontal);
    void _WebViewPlugin_SetDelaysTouchEnable(void* instance,BOOL deferrable );
    void _WebViewPlugin_SetFrame(void* instace,NSInteger x,NSInteger y,NSInteger width,NSInteger height);
    void _WebViewPlugin_SetMargins(void *instance, NSInteger left, NSInteger top, NSInteger right, NSInteger bottom);
}

void *_WebViewPlugin_Init(const char *gameObjectName, const char *scheme)
{
    id instance = [[WebViewPlugin alloc] initWithGameObjectName:gameObjectName customScheme:scheme];
    return (void *)instance;
}

void _WebViewPlugin_Destroy(void *instance)
{
    WebViewPlugin *webViewPlugin = (WebViewPlugin *)instance;
    [webViewPlugin release];
}

void _WebViewPlugin_LoadURL(void *instance, const char *url)
{
    WebViewPlugin *webViewPlugin = (WebViewPlugin *)instance;
    [webViewPlugin loadURL:url];
}
void _WebViewPlugin_ReloadURL(void* instance){
    WebViewPlugin* webViewPlugin = (WebViewPlugin*) instance;
    [webViewPlugin reloadURL];
}

void _WebViewPlugin_ClearContent(void* instance){
    WebViewPlugin* webViewPlugin = (WebViewPlugin*) instance;
    [webViewPlugin clearContent];
}

void _WebViewPlugin_EvaluateJS(void *instance, const char *js)
{
    WebViewPlugin *webViewPlugin = (WebViewPlugin *)instance;
    [webViewPlugin evaluateJS:js];
}

void _WebViewPlugin_SetVisibility(void *instance, BOOL visibility)
{
    WebViewPlugin *webViewPlugin = (WebViewPlugin *)instance;
    [webViewPlugin setVisibility:visibility];
}

void _WebViewPlugin_SetBackgroundColor(void* instance,CGFloat r,CGFloat g,CGFloat b,CGFloat a,BOOL opaque)
{
    UIColor* color = [UIColor colorWithRed:r green:g blue:b alpha:a];
    WebViewPlugin* webViewPlugin = (WebViewPlugin*)instance;
    [webViewPlugin setBackground:opaque Color:color];
}

void _WebViewPlugin_SetScrollable(void* instance,BOOL scrollable){
    
    WebViewPlugin* webViewPlugin = (WebViewPlugin*) instance;
    [webViewPlugin setScrollable:scrollable];
}

void _WebViewPlugin_SetBounceMode(void* instance,BOOL vertical,BOOL horizontal){
    WebViewPlugin* webViewPlugin = (WebViewPlugin*) instance;
    [webViewPlugin setBounceModeOfVertical:vertical Horizontal:horizontal];
}

void _WebViewPlugin_SetDelaysTouchEnable(void* instance,BOOL deferrable){
    WebViewPlugin* webViewPlugin = (WebViewPlugin*) instance;
    [webViewPlugin setDelaysContentTouchesEnable:deferrable];
}

void _WebViewPlugin_SetFrame(void* instance,NSInteger x,NSInteger y,NSInteger width,NSInteger height)
{
    float screenScale = [ UIScreen instancesRespondToSelector:@selector( scale ) ]?
    [ UIScreen mainScreen ].scale:1.0f;
    
    WebViewPlugin* webViewPlugin = (WebViewPlugin*)instance;
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        if(screenScale == 2.0)
            screenScale = 1.0f;
    }
    [webViewPlugin setFrame:x/screenScale positionY:y/screenScale width:width/screenScale height: height/screenScale];
}

void _WebViewPlugin_SetMargins(void *instance, NSInteger left, NSInteger top, NSInteger right, NSInteger bottom)
{
    WebViewPlugin *webViewPlugin = (WebViewPlugin *)instance;
    [webViewPlugin setMargins:left top:top right:right bottom:bottom];
}
