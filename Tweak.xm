// =============================================================
//  PiPiNoTabs — 最终修复版（基于诊断日志）
//  只执行一次 + 搜索按钮正确隐藏
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL PPIsEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"PiPiNoTabsEnabled"];
}

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"] && PPIsEnabled();
}

// 全局标志：确保只执行一次
static BOOL gHasApplied = NO;

// ---------- 核心隐藏函数 ----------
static void PPHideAll(UIView *view) {
    if (!view) return;
    if (!PPIsEnabled()) return;

    @try {
        NSString *className = NSStringFromClass([view class]);

        // 1. 隐藏底部 TabBar（TTTabbar）
        if ([className isEqualToString:@"TTTabbar"]) {
            view.hidden = YES;
            view.alpha = 0.0;
            view.userInteractionEnabled = NO;
            for (UIView *sub in view.subviews) {
                sub.hidden = YES;
                sub.alpha = 0.0;
            }
            return;
        }

        // 2. 隐藏导航栏背景
        if ([className isEqualToString:@"_UIBarBackground"] ||
            [className isEqualToString:@"_UIBarBackgroundShadowView"] ||
            [className isEqualToString:@"_UIBarBackgroundShadowContentImageView"]) {
            view.hidden = YES;
            view.alpha = 0.0;
        }

        // 3. 隐藏顶部标签
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            NSArray *targets = @[@"关注", @"推荐", @"视频", @"图片", @"图文", @"职业圈", @"虾聊", @"文字"];
            if ([targets containsObject:label.text]) {
                label.hidden = YES;
                label.alpha = 0.0;
            }
        }

        // 4. 隐藏搜索按钮（遍历所有 UIButton，检查是否在屏幕右侧区域且包含图片）
        if ([view isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)view;
            // 检查是否包含 UIImageView
            BOOL hasImageView = NO;
            for (UIView *sub in btn.subviews) {
                if ([sub isKindOfClass:[UIImageView class]]) {
                    hasImageView = YES;
                    break;
                }
            }
            // 检查是否在屏幕右侧区域（x > 屏幕宽度的 70%）
            CGRect frameInWindow = [btn convertRect:btn.bounds toView:nil];
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            if (hasImageView && frameInWindow.origin.x > screenWidth * 0.7) {
                btn.hidden = YES;
                btn.alpha = 0.0;
                btn.userInteractionEnabled = NO;
                // 也隐藏父容器（如果父容器是 UIView 且只有一个按钮）
                UIView *container = btn.superview;
                if (container && ![container isKindOfClass:[UINavigationBar class]]) {
                    // 检查容器是否只包含这一个按钮
                    NSInteger buttonCount = 0;
                    for (UIView *sub in container.subviews) {
                        if ([sub isKindOfClass:[UIButton class]]) buttonCount++;
                    }
                    if (buttonCount <= 1) {
                        container.hidden = YES;
                        container.alpha = 0.0;
                    }
                }
            }
        }

        // 递归子视图
        for (UIView *sub in view.subviews) {
            PPHideAll(sub);
        }
    } @catch (NSException *e) {
        NSLog(@"[PiPiNoTabs] 异常: %@", e);
    }
}

static void PPApply() {
    if (!PPIsEnabled()) return;
    if (gHasApplied) return;  // 只执行一次
    gHasApplied = YES;

    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if ([window isKindOfClass:NSClassFromString(@"UITextEffectsWindow")]) continue;
        if ([window isKindOfClass:NSClassFromString(@"BDSBrightnessWindow")]) continue;
        if ([window isKindOfClass:NSClassFromString(@"HUDWindow")]) continue;
        PPHideAll(window);
    }
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"皮皮虾界面控制"
                                                                   message:[NSString stringWithFormat:@"当前状态：%@", enabled ? @"已开启" : @"已关闭"]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:enabled ? @"关闭隐藏" : @"开启隐藏" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"提示"
                                                                         message:@"切换后需重启 App 生效，确定？"
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[NSUserDefaults standardUserDefaults] setBool:!enabled forKey:@"PiPiNoTabsEnabled"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            // 重置执行标志，让下次启动时能执行新的状态
            gHasApplied = NO;
            UIAlertController *restart = [UIAlertController alertControllerWithTitle:@"重启应用"
                                                                             message:@"是否立即重启？"
                                                                      preferredStyle:UIAlertControllerStyleAlert];
            [restart addAction:[UIAlertAction actionWithTitle:@"立即重启" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                exit(0);
            }]];
            [restart addAction:[UIAlertAction actionWithTitle:@"稍后" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                showToast(@"请手动重启皮皮虾", window);
            }]];
            UIViewController *top = window.rootViewController;
            while (top.presentedViewController) top = top.presentedViewController;
            [top presentViewController:restart animated:YES completion:nil];
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
// Hook UIWindow：双指双击
// =============================================================
%hook UIWindow
- (instancetype)initWithFrame:(CGRect)frame {
    self = %orig;
    if (self) {
        UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_handleDoubleTap:)];
        gesture.numberOfTouchesRequired = 2;
        gesture.numberOfTapsRequired = 2;
        [self addGestureRecognizer:gesture];
    }
    return self;
}
%new
- (void)pp_handleDoubleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        if (@available(iOS 10.0, *)) {
            [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
        }
        showSettingsMenu(self);
    }
}
%end

// =============================================================
// Hook UIViewController：只执行一次
// =============================================================
%hook UIViewController
- (void)viewDidLoad {
    %orig;
    if (PPShouldApply() && !gHasApplied) {
        // 只执行一次，延迟 0.1 秒确保视图完全加载
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView performWithoutAnimation:^{
                PPApply();
            }];
        });
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
}
