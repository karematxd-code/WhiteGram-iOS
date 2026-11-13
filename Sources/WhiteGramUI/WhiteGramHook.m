#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface UIViewController (WhiteGramHook)
- (void)wg_viewWillAppear:(BOOL)animated;
@end

@implementation UIViewController (WhiteGramHook)

- (void)wg_viewWillAppear:(BOOL)animated {
    [self wg_viewWillAppear:animated];
    
    NSString *className = NSStringFromClass([self class]);
    NSString *title = self.navigationItem.title ?: @"";
    
    // Check if the current controller is a Telegram/AyuGram Settings controller
    BOOL isSettingsScreen = [className containsString:@"Settings"] || 
                            [className containsString:@"AccountSettings"] || 
                            [title isEqualToString:@"Settings"] || 
                            [title isEqualToString:@"Настройки"];
    
    if (isSettingsScreen) {
        if (!self.navigationItem.leftBarButtonItem || 
            ![self.navigationItem.leftBarButtonItem.title containsString:@"WhiteGram"]) {
            
            UIBarButtonItem *wgItem = [[UIBarButtonItem alloc] initWithTitle:@"⚡ WhiteGram"
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(wg_openSettingsAction)];
            wgItem.tintColor = [UIColor systemBlueColor];
            self.navigationItem.leftBarButtonItem = wgItem;
        }
    }
}

- (void)wg_openSettingsAction {
    Class overlayManager = NSClassFromString(@"WhiteGramOverlayManager");
    if (overlayManager && [overlayManager respondsToSelector:NSSelectorFromString(@"presentWhiteGramSettings")]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [overlayManager performSelector:NSSelectorFromString(@"presentWhiteGramSettings")];
        #pragma clang diagnostic pop
    }
}

@end

static void WhiteGramPerformSwizzling(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [UIViewController class];
        SEL origSel = @selector(viewWillAppear:);
        SEL swizSel = @selector(wg_viewWillAppear:);
        
        Method origMethod = class_getInstanceMethod(cls, origSel);
        Method swizMethod = class_getInstanceMethod(cls, swizSel);
        
        if (origMethod && swizMethod) {
            method_exchangeImplementations(origMethod, swizMethod);
            NSLog(@"[WhiteGram] UIViewController viewWillAppear swizzled successfully.");
        }
    });
}

__attribute__((constructor))
static void WhiteGramInitialize(void) {
    NSLog(@"[WhiteGram] Dylib loaded into pid %d. Initializing WhiteGram runtime hooks...", getpid());
    
    WhiteGramPerformSwizzling();
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        NSLog(@"[WhiteGram] UIApplicationDidFinishLaunchingNotification received. Mounting overlay...");
        Class overlayManager = NSClassFromString(@"WhiteGramOverlayManager");
        if (overlayManager && [overlayManager respondsToSelector:NSSelectorFromString(@"startOverlay")]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [overlayManager performSelector:NSSelectorFromString(@"startOverlay")];
            #pragma clang diagnostic pop
        }
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        Class overlayManager = NSClassFromString(@"WhiteGramOverlayManager");
        if (overlayManager && [overlayManager respondsToSelector:NSSelectorFromString(@"startOverlay")]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [overlayManager performSelector:NSSelectorFromString(@"startOverlay")];
            #pragma clang diagnostic pop
        }
    }];
}
