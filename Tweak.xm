// =============================================================
//  PiPiNoTabs — 最终无闪烁版（隐藏但可点击）
//  双指双击菜单，只执行一次
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

// ---------- 核心隐藏函数（透明化，保留交互） ----------
static void PPHideAll(UIView *view) {
    if (!view) return;
    if (!PPIsEnabled()) return;

    @try {
        NSString *className = NSStringFromClass([view class]);

        // 1. 底部 TabBar（TTTabbar）完全隐藏，不保留交互
        if ([className isEqualToString:@"TTTabbar"]) {
            view.hidden = YES;
            view.alpha = 0.0;
            view.userInteractionEnabled = NO;
            for (UIView *sub in view.subviews) {
                sub.hidden = YES;
                sub.alpha = 0.0;
                sub.userInteractionEnabled = NO;
            }
            return;
        }

        // 2. 导航栏背景完全隐藏
        if ([className isEqualToString:@"_UIBarBackground"] ||
            [className isEqualToString:@"_UIBarBackgroundShadowView"] ||
            [className isEqualToString:@"_UIBarBackgroundShadowContentImageView"]) {
            view.hidden = YES;
            view.alpha = 0.0;
            // 不修改 userInteractionEnabled，因为背景本身不响应事件
        }

        // 3. 顶部标签（隐藏但保留点击）
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            NSArray *targets = @[@"关注", @"推荐", @"视频", @"图片", @"图文", @"职业圈", @"虾聊", @"文字"];
            if ([targets containsObject:label.text]) {
                label.alpha = 0.0;
                label.hidden = NO;           // 保持 hidden=NO 以保留交互
                label.userInteractionEnabled = YES;
                // 如果父视图是 UIButton 或 UIControl，也要透明化但保留交互
                UIView *parent = label.superview;
                if (parent && ([parent isKindOfClass:[UIButton class]] || [parent isKindOfClass:[UIControl class]])) {
                    parent.alpha = 0.0;
                    parent.hidden = NO;
                    parent.userInteractionEnabled = YES;
                }
            }
        }

        // 4. 顶部按钮（如搜索按钮）隐藏但保留点击
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
            // 检查位置是否在屏幕右侧（x > 屏幕宽度的 70%）
            CGRect frameInWindow = [btn convertRect:btn.bounds toView:nil];
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            if (hasImageView && frameInWindow.origin.x > screenWidth * 0.7) {
                btn.alpha = 0.0;
                btn.hidden = NO;
                btn.userInteractionEnabled = YES;
                // 不要隐藏父容器，只透明按钮本身
            }
        }

        // 5. 对于其他可能包含顶部选项的容器（如 UINavigationBar 的 contentView），透明化但不隐藏
        if ([view isKindOfClass:[UINavigationBar class]]) {
            // 只处理导航栏本身，不要完全隐藏
            view.alpha = 1.0; // 保持导航栏可见（背景已隐藏）
        }
        if ([className isEqualToString:@"_UINavigationBarContentView"]) {
            // 内容视图透明化，但保留交互
            view.alpha = 0.0;
            view.hidden = NO;
            view.userInteractionEnabled = YES;
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

    [UIView performWithoutAnimation:^{
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if ([window isKindOfClass:NSClassFromString(@"UITextEffectsWindow")]) continue;
            if ([window isKindOfClass:NSClassFromString(@"BDSBrightnessWindow")]) continue;
            if ([window isKindOfClass:NSClassFromString(@"HUDWindow")]) continue;
            PPHideAll(window);
        }
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
            gHasApplied = NO;  // 重置标志，让下次启动时能执行新状态
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
// Hook UIViewController：在 viewWillAppear 中执行一次
// =============================================================
%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply() && !gHasApplied) {
        // 延迟极短时间，确保在视图动画开始前执行
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            PPApply();
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
    // 如果 App 启动时已经加载了视图，也尝试应用一次（但用标志确保只执行一次）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (PPShouldApply() && !gHasApplied) {
            PPApply();
        }
    });
}
