// =============================================================
//  PiPiNoTabs — 即时隐藏 + 双指双击菜单
//  隐藏「发现」「加号」「消息」，保留「首页」「我的」均匀分布
//  双指双击弹出菜单，可开启/关闭隐藏功能
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString * const kPPEnabledKey = @"PiPiNoTabs_Enabled";

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"];
}

static BOOL PPIsEnabled() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:kPPEnabledKey] == nil) {
        return YES; // 默认启用
    }
    return [defaults boolForKey:kPPEnabledKey];
}

static void PPSetEnabled(BOOL enabled) {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kPPEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// 保存原始布局
static NSMutableDictionary *PPOriginalFrames = nil;
static NSMutableDictionary *PPOriginalHidden = nil;

static void PPSaveOriginalState(UIView *tabBar) {
    if (!tabBar) return;
    if (!PPOriginalFrames) {
        PPOriginalFrames = [NSMutableDictionary dictionary];
        PPOriginalHidden = [NSMutableDictionary dictionary];
    }
    NSArray *subviews = tabBar.subviews;
    for (NSInteger i = 0; i < subviews.count; i++) {
        UIView *btn = subviews[i];
        NSString *key = [NSString stringWithFormat:@"%ld", (long)i];
        PPOriginalFrames[key] = [NSValue valueWithCGRect:btn.frame];
        PPOriginalHidden[key] = @(btn.hidden);
    }
}

static void PPRestoreOriginalState(UIView *tabBar) {
    if (!tabBar || !PPOriginalFrames) return;
    NSArray *subviews = tabBar.subviews;
    for (NSInteger i = 0; i < subviews.count && i < subviews.count; i++) {
        NSString *key = [NSString stringWithFormat:@"%ld", (long)i];
        NSValue *frameVal = PPOriginalFrames[key];
        NSNumber *hiddenVal = PPOriginalHidden[key];
        if (frameVal && hiddenVal) {
            UIView *btn = subviews[i];
            btn.frame = [frameVal CGRectValue];
            btn.hidden = [hiddenVal boolValue];
            btn.alpha = 1.0;
            btn.userInteractionEnabled = YES;
        }
    }
    [tabBar setNeedsLayout];
    [tabBar layoutIfNeeded];
}

// 重新布局函数
static void PPHideAndRearrange(UIView *tabBar) {
    if (!tabBar) return;
    if (![NSStringFromClass([tabBar class]) isEqualToString:@"TTTabbar"]) return;
    
    // 如果未启用，恢复原始状态
    if (!PPIsEnabled()) {
        PPRestoreOriginalState(tabBar);
        return;
    }
    
    // 首次处理时保存原始状态
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        PPSaveOriginalState(tabBar);
    });
    
    NSMutableArray *buttons = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        [buttons addObject:sub];
    }
    if (buttons.count == 0) return;
    
    NSMutableArray *keepButtons = [NSMutableArray array];
    for (UIView *btn in buttons) {
        NSString *title = nil;
        for (UIView *inner in btn.subviews) {
            if ([inner isKindOfClass:[UILabel class]]) {
                title = ((UILabel *)inner).text;
                break;
            }
        }
        if (!title) {
            @try { title = [btn valueForKey:@"title"]; } @catch (NSException *e) {}
        }
        if (title && ([title isEqualToString:@"首页"] || [title isEqualToString:@"我的"])) {
            [keepButtons addObject:btn];
        } else {
            btn.hidden = YES;
            btn.alpha = 0.0;
            btn.userInteractionEnabled = NO;
        }
    }
    
    if (keepButtons.count == 2) {
        CGFloat width = tabBar.frame.size.width / keepButtons.count;
        CGFloat height = tabBar.frame.size.height;
        for (NSInteger i = 0; i < keepButtons.count; i++) {
            UIView *btn = keepButtons[i];
            [UIView performWithoutAnimation:^{
                btn.frame = CGRectMake(i * width, 0, width, height);
                btn.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                for (UIView *sub in btn.subviews) {
                    sub.frame = btn.bounds;
                    if ([sub isKindOfClass:[UILabel class]]) {
                        ((UILabel *)sub).textAlignment = NSTextAlignmentCenter;
                    }
                }
            }];
        }
        [tabBar setNeedsLayout];
        [tabBar layoutIfNeeded];
    }
}

// 递归查找 TTTabbar
static void PPFindAndProcessTabBar(UIView *view) {
    if (!view) return;
    if ([NSStringFromClass([view class]) isEqualToString:@"TTTabbar"]) {
        PPHideAndRearrange(view);
        return;
    }
    for (UIView *sub in view.subviews) {
        PPFindAndProcessTabBar(sub);
    }
}

// ---------- Hook TTTabbar 的 layoutSubviews ----------
%hook TTTabbar
- (void)layoutSubviews {
    %orig;
    if (PPShouldApply()) {
        PPHideAndRearrange(self);
    }
}
%end

// ---------- 屏蔽儿童模式弹窗 ----------
static BOOL PPShouldBlockAlert(UIViewController *vc) {
    NSString *className = NSStringFromClass([vc class]);
    if ([className containsString:@"BDSStyledAlertController"]) {
        @try {
            NSString *title = [vc valueForKey:@"title"];
            if (title && [title containsString:@"儿童/青少年模式"]) {
                return YES;
            }
        } @catch (NSException *e) {}
    }
    return NO;
}

%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (PPShouldApply() && PPShouldBlockAlert(viewControllerToPresent)) {
        return;
    }
    %orig;
}
%end

// ---------- 双指双击菜单 ----------
static void PPShowMenu(UIView *view) {
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (!root) return;
    BOOL enabled = PPIsEnabled();
    NSString *title = enabled ? @"当前：已隐藏" : @"当前：显示";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"PiPiNoTabs"
                                                                   message:title
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *toggleAction = [UIAlertAction actionWithTitle:enabled ? @"关闭隐藏" : @"开启隐藏"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
                                                             PPSetEnabled(!enabled);
                                                             // 强制刷新布局
                                                             UIWindow *window = [UIApplication sharedApplication].keyWindow;
                                                             if (window) {
                                                                 PPFindAndProcessTabBar(window);
                                                                 [window setNeedsLayout];
                                                                 [window layoutIfNeeded];
                                                             }
                                                         }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:toggleAction];
    [alert addAction:cancel];
    dispatch_async(dispatch_get_main_queue(), ^{
        [root presentViewController:alert animated:YES completion:nil];
    });
}

static void PPAddGesture() {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) return;
    // 检查是否已添加手势
    for (UIGestureRecognizer *gesture in window.gestureRecognizers) {
        if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
            UITapGestureRecognizer *tap = (UITapGestureRecognizer *)gesture;
            if (tap.numberOfTapsRequired == 2 && tap.numberOfTouchesRequired == 2) {
                return;
            }
        }
    }
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:nil action:@selector(pp_handleDoubleDoubleTap:)];
    tap.numberOfTapsRequired = 2;
    tap.numberOfTouchesRequired = 2;
    [window addGestureRecognizer:tap];
    // 由于 target 为 nil，使用分类方法
    [window pp_addGestureHandler];
}

@interface UIWindow (PiPiNoTabs)
- (void)pp_handleDoubleDoubleTap:(UITapGestureRecognizer *)gesture;
- (void)pp_addGestureHandler;
@end

@implementation UIWindow (PiPiNoTabs)
- (void)pp_handleDoubleDoubleTap:(UITapGestureRecognizer *)gesture {
    PPShowMenu(self);
}
- (void)pp_addGestureHandler {
    // 空实现，仅用于确保方法存在
}
@end

// ---------- 加载入口 ----------
%ctor {
    if (PPShouldApply()) {
        // 立即执行隐藏（无延迟）
        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            if (window) {
                PPFindAndProcessTabBar(window);
                PPAddGesture();
            }
        });
    }
}
