// =============================================================
//  PiPiNoTabs — 增强版（带双指双击开关）
//  功能：透明化底部 TabBar、顶部标签文字、以及搜索图标
//  新增：双指双击菜单控制启用/禁用
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ---------- 开关状态 ----------
static BOOL PPIsEnabled() {
    // 默认启用（若未设置则默认为 YES）
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"PiPiNoTabsEnabled"] == nil) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"PiPiNoTabsEnabled"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"PiPiNoTabsEnabled"];
}

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (![bundleID isEqualToString:@"com.bd.iphone.superPropipi"]) {
        return NO;
    }
    return PPIsEnabled();
}

// ---------- 应用或恢复视图 ----------
static void PPApplyToView(UIView *view, BOOL hide) {
    if (!view) return;
    @try {
        // 1. TabBar
        if ([NSStringFromClass([view class]) isEqualToString:@"TTTabbar"]) {
            [UIView performWithoutAnimation:^{
                view.alpha = hide ? 0.0 : 1.0;
                view.userInteractionEnabled = !hide;
                for (UIView *sub in view.subviews) {
                    sub.alpha = hide ? 0.0 : 1.0;
                    sub.userInteractionEnabled = !hide;
                }
            }];
            return;
        }
        
        // 2. 顶部标签文字（UILabel）
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            NSArray *targetTitles = @[@"关注", @"推荐", @"视频", @"图片", @"图文", @"职业圈", @"虾聊", @"文字"];
            for (NSString *title in targetTitles) {
                if ([label.text isEqualToString:title]) {
                    [UIView performWithoutAnimation:^{
                        label.alpha = hide ? 0.0 : 1.0;
                    }];
                    break;
                }
            }
        }
        
        // 3. 搜索图标容器
        if ([view isKindOfClass:[UIView class]]) {
            if ([view.superview isKindOfClass:[UINavigationBar class]]) {
                BOOL hasButton = NO;
                BOOL hasImageView = NO;
                for (UIView *sub in view.subviews) {
                    if ([sub isKindOfClass:[UIButton class]]) {
                        hasButton = YES;
                        for (UIView *subsub in sub.subviews) {
                            if ([subsub isKindOfClass:[UIImageView class]]) {
                                hasImageView = YES;
                                break;
                            }
                        }
                    }
                }
                if (hasButton && hasImageView) {
                    [UIView performWithoutAnimation:^{
                        view.alpha = hide ? 0.0 : 1.0;
                        // 保持容器可交互（如果需要点击）
                        // view.userInteractionEnabled = !hide;
                    }];
                }
            }
        }
        
        // 递归子视图
        for (UIView *sub in view.subviews) {
            PPApplyToView(sub, hide);
        }
    } @catch (NSException *e) {}
}

static void PPProcessAllWindows(BOOL hide) {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        PPApplyToView(window, hide);
    }
}

// ---------- 定时器（重复执行，确保生效） ----------
static void PPStartTimer() {
    // 立即执行一次
    PPProcessAllWindows(PPIsEnabled());
    // 每隔 0.1 秒执行一次，共 15 次（持续 1.5 秒）
    for (int i = 1; i <= 15; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            PPProcessAllWindows(PPIsEnabled());
        });
    }
}

// ---------- 手势控制 ----------
static void showToast(NSString *msg, UIWindow *window) {
    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) {
        top = top.presentedViewController;
    }
    UIAlertController *toast = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
    [top presentViewController:toast animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [toast dismissViewControllerAnimated:YES completion:nil];
    });
}

static void showSettingsMenu(UIWindow *window) {
    UIViewController *topVC = window.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    
    BOOL enabled = PPIsEnabled();
    NSString *status = enabled ? @"已启用" : @"已禁用";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"PiPiNoTabs 控制"
                                                                   message:[NSString stringWithFormat:@"当前状态：%@", status]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@ 隐藏功能", enabled ? @"禁用" : @"启用"]
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
                                                BOOL newState = !enabled;
                                                [[NSUserDefaults standardUserDefaults] setBool:newState forKey:@"PiPiNoTabsEnabled"];
                                                [[NSUserDefaults standardUserDefaults] synchronize];
                                                // 立即应用新状态
                                                PPProcessAllWindows(newState);
                                                // 如果启用，重新启动定时器（但定时器是一次性的，可以重新触发）
                                                if (newState) {
                                                    PPStartTimer();
                                                }
                                                showToast([NSString stringWithFormat:@"功能已%@", newState ? @"启用" : @"禁用"], window);
                                            }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = window;
        alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(window.bounds), CGRectGetMidY(window.bounds), 0, 0);
    }
    
    [topVC presentViewController:alert animated:YES completion:nil];
}

// =============================================================
// Hook UIWindow：双指双击手势
// =============================================================
%hook UIWindow

- (instancetype)initWithFrame:(CGRect)frame {
    self = %orig;
    if (self) {
        UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_handleDoubleTap:)];
        gesture.numberOfTouchesRequired = 2;
        gesture.numberOfTapsRequired = 2;
        gesture.cancelsTouchesInView = NO;
        [self addGestureRecognizer:gesture];
        NSLog(@"[PiPiNoTabs] 2-finger double-tap gesture added");
    }
    return self;
}

%new
- (void)pp_handleDoubleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        // 触觉反馈
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            [generator prepare];
            [generator impactOccurred];
        }
        showSettingsMenu(self);
    }
}

%end

// =============================================================
// Hook UIViewController：在视图出现时触发定时器
// =============================================================
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply()) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                PPStartTimer();
            });
        });
    }
}
%end

// =============================================================
// 注入入口
// =============================================================
%ctor {
    if (PPShouldApply()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows(PPIsEnabled());
        });
    }
}
