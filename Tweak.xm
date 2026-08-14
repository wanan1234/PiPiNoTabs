// =============================================================
//  PiPiNoTabs — 最终整合版（保留原有隐藏逻辑 + 搜索按钮 + 菜单）
//  双指双击菜单，只执行一次，隐藏但可点击
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

static BOOL gHasApplied = NO;

// ---------- 原有核心逻辑（透明化） ----------
static void PPTransparentizeViews(UIView *view) {
    if (!view) return;
    if (!PPIsEnabled()) return;

    @try {
        // 1. 底部 TabBar（TTTabbar）完全隐藏
        if ([NSStringFromClass([view class]) isEqualToString:@"TTTabbar"]) {
            view.alpha = 0.0;
            view.hidden = YES;
            view.userInteractionEnabled = NO;
            for (UIView *sub in view.subviews) {
                sub.alpha = 0.0;
                sub.hidden = YES;
                sub.userInteractionEnabled = NO;
            }
            return;
        }

        // 2. 顶部标签文字（UILabel）透明化但保留交互
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            NSArray *targetTitles = @[@"关注", @"推荐", @"视频", @"图片", @"图文", @"职业圈", @"虾聊", @"文字"];
            for (NSString *title in targetTitles) {
                if ([label.text isEqualToString:title]) {
                    label.alpha = 0.01; // 极小值以保留交互
                    label.hidden = NO;
                    label.userInteractionEnabled = YES;
                    // 透明化父视图（如果是 UIButton 或 UIControl）
                    UIView *parent = label.superview;
                    if (parent && ([parent isKindOfClass:[UIButton class]] || [parent isKindOfClass:[UIControl class]])) {
                        parent.alpha = 0.01;
                        parent.hidden = NO;
                        parent.userInteractionEnabled = YES;
                    }
                    break;
                }
            }
        }

        // 3. 导航栏背景完全隐藏
        if ([NSStringFromClass([view class]) isEqualToString:@"_UIBarBackground"] ||
            [NSStringFromClass([view class]) isEqualToString:@"_UIBarBackgroundShadowView"] ||
            [NSStringFromClass([view class]) isEqualToString:@"_UIBarBackgroundShadowContentImageView"]) {
            view.hidden = YES;
            view.alpha = 0.0;
        }

        // 4. 搜索按钮隐藏但保留交互
        if ([view isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)view;
            // 检查是否包含 UIImageView（搜索按钮特征）
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
                btn.alpha = 0.01;
                btn.hidden = NO;
                btn.userInteractionEnabled = YES;
                // 不隐藏父容器
            }
        }

        // 递归子视图
        for (UIView *sub in view.subviews) {
            PPTransparentizeViews(sub);
        }
    } @catch (NSException *e) {}
}

static void PPProcessAllWindows() {
    if (!PPIsEnabled()) return;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if ([window isKindOfClass:NSClassFromString(@"UITextEffectsWindow")]) continue;
        if ([window isKindOfClass:NSClassFromString(@"BDSBrightnessWindow")]) continue;
        if ([window isKindOfClass:NSClassFromString(@"HUDWindow")]) continue;
        PPTransparentizeViews(window);
    }
}

static void PPApplySettings() {
    if (!PPShouldApply()) return;
    if (gHasApplied) return;
    gHasApplied = YES;
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
// Hook UIViewController：在 viewDidAppear 执行一次
// =============================================================
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply() && !gHasApplied) {
        // 在 viewDidAppear 中执行，确保视图完全显示，延迟 0.1 秒避开动画
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            PPApplySettings();
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
    // 作为备用，延迟较长时间执行
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (PPShouldApply() && !gHasApplied) {
            PPApplySettings();
        }
    });
}
