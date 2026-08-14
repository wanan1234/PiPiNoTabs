// =============================================================
//  PiPiNoTabs — 完整修复版（双指双击 + 无闪烁 + 重启询问）
//  功能：隐藏顶部标签、导航栏背景、右上角搜索按钮
//  手势：双指双击（UITapGestureRecognizer）
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ---------- 开关管理 ----------
static BOOL PPIsEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"PiPiNoTabsEnabled"];
}

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"] && PPIsEnabled();
}

// ---------- 透明化核心逻辑 ----------
static void PPTransparentizeViews(UIView *view, BOOL recursive) {
    if (!view) return;
    if (!PPIsEnabled()) return;
    
    @try {
        NSString *className = NSStringFromClass([view class]);
        
        // 1. 隐藏底部 TabBar（TTTabbar）
        if ([className isEqualToString:@"TTTabbar"]) {
            [UIView performWithoutAnimation:^{
                view.hidden = YES;
                view.alpha = 0.0;
                view.userInteractionEnabled = NO;
                for (UIView *sub in view.subviews) {
                    sub.hidden = YES;
                    sub.alpha = 0.0;
                    sub.userInteractionEnabled = NO;
                }
            }];
            return;
        }
        
        // 2. 隐藏顶部标签文字（UILabel）
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            NSArray *targetTitles = @[@"关注", @"推荐", @"视频", @"图片", @"图文", @"职业圈", @"虾聊", @"文字"];
            for (NSString *title in targetTitles) {
                if ([label.text isEqualToString:title]) {
                    [UIView performWithoutAnimation:^{
                        label.hidden = YES;
                        label.alpha = 0.0;
                    }];
                    break;
                }
            }
        }
        
        // 3. 隐藏导航栏背景（_UIBarBackground 及其子视图）
        if ([className isEqualToString:@"_UIBarBackground"] ||
            [className isEqualToString:@"_UIBarBackgroundShadowView"] ||
            [className isEqualToString:@"_UIBarBackgroundShadowContentImageView"]) {
            [UIView performWithoutAnimation:^{
                view.hidden = YES;
                view.alpha = 0.0;
            }];
        }
        
        // 4. 隐藏右上角搜索按钮（位于导航栏右侧的 UIButton 且包含 UIImageView）
        if ([view isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)view;
            UIView *navBar = btn.superview;
            while (navBar && ![navBar isKindOfClass:[UINavigationBar class]]) {
                navBar = navBar.superview;
            }
            if (navBar) {
                CGFloat navWidth = navBar.bounds.size.width;
                if (btn.frame.origin.x > navWidth / 2) {
                    BOOL hasImageView = NO;
                    for (UIView *sub in btn.subviews) {
                        if ([sub isKindOfClass:[UIImageView class]]) {
                            hasImageView = YES;
                            break;
                        }
                    }
                    if (hasImageView) {
                        [UIView performWithoutAnimation:^{
                            btn.hidden = YES;
                            btn.alpha = 0.0;
                            btn.userInteractionEnabled = NO;
                        }];
                    }
                }
            }
        }
        
        // 5. 隐藏导航栏右侧的其他容器（如包含搜索按钮的 UIView）
        if ([view isKindOfClass:[UIView class]]) {
            UIView *parent = view.superview;
            if (parent && [parent isKindOfClass:[UINavigationBar class]]) {
                BOOL hasRightButton = NO;
                for (UIView *sub in view.subviews) {
                    if ([sub isKindOfClass:[UIButton class]]) {
                        CGRect subFrame = sub.frame;
                        if (subFrame.origin.x > parent.bounds.size.width / 2) {
                            hasRightButton = YES;
                            break;
                        }
                    }
                }
                if (hasRightButton) {
                    [UIView performWithoutAnimation:^{
                        view.hidden = YES;
                        view.alpha = 0.0;
                    }];
                }
            }
        }
        
        // 递归子视图
        if (recursive) {
            for (UIView *sub in view.subviews) {
                PPTransparentizeViews(sub, YES);
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[PiPiNoTabs] 遍历视图异常: %@", e);
    }
}

static void PPProcessAllWindows() {
    if (!PPIsEnabled()) return;
    Class textEffectsWindowClass = NSClassFromString(@"UITextEffectsWindow");
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (textEffectsWindowClass && [window isKindOfClass:textEffectsWindowClass]) continue;
        PPTransparentizeViews(window, YES);
    }
}

static void PPApplySettings() {
    if (!PPShouldApply()) return;
    [UIView performWithoutAnimation:^{
        PPProcessAllWindows();
    }];
}

// =============================================================
// 手势控制（双指双击）
// =============================================================
static void showToast(NSString *msg, UIWindow *window) {
    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    UIAlertController *toast = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
    [top presentViewController:toast animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [toast dismissViewControllerAnimated:YES completion:nil];
    });
}

static void showSettingsMenu(UIWindow *window) {
    UIViewController *topVC = window.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;
    
    BOOL enabled = PPIsEnabled();
    NSString *status = enabled ? @"已开启" : @"已关闭";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"皮皮虾界面控制"
                                                                   message:[NSString stringWithFormat:@"当前状态：%@\n切换后需重启 App 生效", status]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSString *actionTitle = enabled ? @"关闭隐藏功能" : @"开启隐藏功能";
    [alert addAction:[UIAlertAction actionWithTitle:actionTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        // 确认切换
        UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"提示"
                                                                         message:@"切换模式后需要重启 App 才能生效，确定要继续吗？"
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            BOOL newState = !enabled;
            [[NSUserDefaults standardUserDefaults] setBool:newState forKey:@"PiPiNoTabsEnabled"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // 询问是否立即重启
            UIAlertController *restartAlert = [UIAlertController alertControllerWithTitle:@"重启应用"
                                                                                   message:[NSString stringWithFormat:@"已%@隐藏功能\n是否立即重启皮皮虾以应用新设置？", newState ? @"开启" : @"关闭"]
                                                                            preferredStyle:UIAlertControllerStyleAlert];
            [restartAlert addAction:[UIAlertAction actionWithTitle:@"立即重启" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                exit(0);
            }]];
            [restartAlert addAction:[UIAlertAction actionWithTitle:@"稍后手动重启" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                showToast(@"请手动重启皮皮虾以应用新设置", window);
            }]];
            
            UIViewController *top = window.rootViewController;
            while (top.presentedViewController) top = top.presentedViewController;
            [top presentViewController:restartAlert animated:YES completion:nil];
        }]];
        [confirm addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        UIViewController *top = window.rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
        [top presentViewController:confirm animated:YES completion:nil];
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
        gesture.delaysTouchesBegan = NO;
        gesture.delaysTouchesEnded = NO;
        [self addGestureRecognizer:gesture];
        NSLog(@"[PiPiNoTabs] 双指双击手势已添加");
    }
    return self;
}

%new
- (void)pp_handleDoubleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateRecognized) return;
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [generator prepare];
        [generator impactOccurred];
    }
    showSettingsMenu(self);
}

%end

// =============================================================
// Hook UIViewController：在适当时机应用设置
// =============================================================
%hook UIViewController

- (void)viewDidLoad {
    %orig;
    if (PPShouldApply()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIView performWithoutAnimation:^{
                PPProcessAllWindows();
            }];
        });
    }
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply()) {
        static BOOL firstAppear = YES;
        if (firstAppear) {
            firstAppear = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIView performWithoutAnimation:^{
                    PPProcessAllWindows();
                }];
            });
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView performWithoutAnimation:^{
                    PPProcessAllWindows();
                }];
            });
        }
    }
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (PPShouldApply()) {
        static NSTimeInterval lastApplyTime = 0;
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (now - lastApplyTime > 0.2) {
            lastApplyTime = now;
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIView performWithoutAnimation:^{
                    PPProcessAllWindows();
                }];
            });
        }
    }
}

%end

// =============================================================
// 构造函数
// =============================================================
%ctor {
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"PiPiNoTabsEnabled"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"PiPiNoTabsEnabled"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    NSLog(@"[PiPiNoTabs] 插件加载完成，开关状态：%@", PPIsEnabled() ? @"开启" : @"关闭");
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (PPShouldApply()) {
            [UIView performWithoutAnimation:^{
                PPProcessAllWindows();
            }];
        }
    });
}
