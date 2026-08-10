// =============================================================
//  PiPiNoTabs — 最终稳定版（即时隐藏 + 双指双击菜单）
//  隐藏「发现」「加号」「消息」，保留「首页」「我的」均匀分布
//  双指双击弹出菜单，可开启/关闭隐藏
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString * const kPPEnabledKey = @"PiPiNoTabs_Enabled";
static NSMutableDictionary *PPOriginalFrames = nil;
static NSMutableDictionary *PPOriginalHidden = nil;

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"];
}

static BOOL PPIsEnabled() {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if ([def objectForKey:kPPEnabledKey] == nil) return YES;
    return [def boolForKey:kPPEnabledKey];
}

static void PPSetEnabled(BOOL enabled) {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kPPEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// 保存原始状态
static void PPSaveOriginalState(UIView *tabBar) {
    if (!tabBar) return;
    if (!PPOriginalFrames) {
        PPOriginalFrames = [NSMutableDictionary dictionary];
        PPOriginalHidden = [NSMutableDictionary dictionary];
    }
    NSString *key = [NSString stringWithFormat:@"%p", tabBar];
    NSMutableArray *frames = [NSMutableArray array];
    NSMutableArray *hiddens = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        [frames addObject:[NSValue valueWithCGRect:sub.frame]];
        [hiddens addObject:@(sub.hidden)];
    }
    PPOriginalFrames[key] = frames;
    PPOriginalHidden[key] = hiddens;
}

// 恢复原始状态
static void PPRestoreOriginalState(UIView *tabBar) {
    if (!tabBar) return;
    if (!PPOriginalFrames) return;
    NSString *key = [NSString stringWithFormat:@"%p", tabBar];
    NSArray *frames = PPOriginalFrames[key];
    NSArray *hiddens = PPOriginalHidden[key];
    if (!frames || !hiddens) return;
    NSArray *subviews = tabBar.subviews;
    for (NSInteger i = 0; i < subviews.count && i < frames.count; i++) {
        UIView *sub = subviews[i];
        sub.frame = [frames[i] CGRectValue];
        sub.hidden = [hiddens[i] boolValue];
        sub.alpha = sub.hidden ? 1.0 : 1.0;
        sub.userInteractionEnabled = YES;
    }
    [tabBar setNeedsLayout];
    [tabBar layoutIfNeeded];
}

// 隐藏并重新布局
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
    
    // 收集按钮
    NSMutableArray *buttons = [NSMutableArray arrayWithArray:tabBar.subviews];
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
    
    // 重新布局
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

// 递归查找并处理 TTTabbar
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

// 处理所有窗口
static void PPProcessAllWindows() {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        PPFindAndProcessTabBar(window);
    }
}

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
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply()) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                PPProcessAllWindows();
            });
        });
    }
}
%end

// ---------- 双指双击菜单 ----------
static void PPShowMenu() {
    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    if (!window) return;
    UIViewController *root = window.rootViewController;
    if (!root) return;
    BOOL enabled = PPIsEnabled();
    NSString *title = enabled ? @"当前：已隐藏" : @"当前：显示";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"PiPiNoTabs"
                                                                   message:title
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *toggle = [UIAlertAction actionWithTitle:enabled ? @"关闭隐藏" : @"开启隐藏"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * _Nonnull action) {
                                                       PPSetEnabled(!enabled);
                                                       PPProcessAllWindows();
                                                   }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:toggle];
    [alert addAction:cancel];
    [root presentViewController:alert animated:YES completion:nil];
}

// 手势处理类
@interface PPGestureTarget : NSObject
@end
@implementation PPGestureTarget
- (void)handleDoubleTap:(UITapGestureRecognizer *)gesture {
    PPShowMenu();
}
@end

static void PPAddGesture() {
    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    if (!window) return;
    for (UIGestureRecognizer *g in window.gestureRecognizers) {
        if ([g isKindOfClass:[UITapGestureRecognizer class]]) {
            UITapGestureRecognizer *tap = (UITapGestureRecognizer *)g;
            if (tap.numberOfTapsRequired == 2 && tap.numberOfTouchesRequired == 2) {
                return;
            }
        }
    }
    static PPGestureTarget *target = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        target = [[PPGestureTarget alloc] init];
    });
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:target action:@selector(handleDoubleTap:)];
    tap.numberOfTapsRequired = 2;
    tap.numberOfTouchesRequired = 2;
    [window addGestureRecognizer:tap];
}

%ctor {
    if (PPShouldApply()) {
        PPAddGesture();
        // 立即尝试处理（可能视图未加载，但没关系）
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}
