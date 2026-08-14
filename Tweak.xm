// =============================================================
//  PiPiNoTabs — 精确版（基于诊断日志精确定位搜索按钮）
//  双指双击菜单，只隐藏搜索按钮容器，不影响其他功能
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

// ---------- 精确识别搜索按钮容器 ----------
static BOOL isSearchButtonContainer(UIView *view) {
    if (!view) return NO;
    
    // 1. 检查 frame 是否匹配（允许微小偏差）
    CGRect frame = view.frame;
    if (fabs(frame.origin.x - 362) > 2 ||
        fabs(frame.origin.y - 57) > 2 ||
        fabs(frame.size.width - 52) > 2 ||
        fabs(frame.size.height - 30) > 2) {
        return NO;
    }
    
    // 2. 检查是否包含 UIButton
    UIButton *btn = nil;
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UIButton class]]) {
            btn = (UIButton *)sub;
            break;
        }
    }
    if (!btn) return NO;
    
    // 3. 检查按钮是否包含 UIImageView
    BOOL hasImageView = NO;
    for (UIView *sub in btn.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            hasImageView = YES;
            break;
        }
    }
    if (!hasImageView) return NO;
    
    // 4. 检查按钮 frame 是否匹配
    CGRect btnFrame = btn.frame;
    if (fabs(btnFrame.origin.x - 16) > 2 ||
        fabs(btnFrame.origin.y - 5) > 2 ||
        fabs(btnFrame.size.width - 20) > 2 ||
        fabs(btnFrame.size.height - 20) > 2) {
        return NO;
    }
    
    return YES;
}

// ---------- 核心隐藏函数 ----------
static void PPHideAll(UIView *view) {
    if (!view) return;
    if (!PPIsEnabled()) return;

    @try {
        NSString *className = NSStringFromClass([view class]);

        // 1. 底部 TabBar（TTTabbar）完全隐藏
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
            return;
        }

        // 3. 顶部标签：透明化，保留交互
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            NSArray *targets = @[@"关注", @"推荐", @"视频", @"图片", @"图文", @"职业圈", @"虾聊", @"文字"];
            if ([targets containsObject:label.text]) {
                label.alpha = 0.0;
                label.hidden = NO;
                label.userInteractionEnabled = YES;
                UIView *parent = label.superview;
                if (parent && ([parent isKindOfClass:[UIButton class]] || [parent isKindOfClass:[UIControl class]])) {
                    parent.alpha = 0.0;
                    parent.hidden = NO;
                    parent.userInteractionEnabled = YES;
                }
            }
        }

        // 4. 搜索按钮：精确定位容器，透明化但保留交互
        if (isSearchButtonContainer(view)) {
            // 透明化容器，但不隐藏
            view.alpha = 0.0;
            view.hidden = NO;
            view.userInteractionEnabled = YES;
            // 确保子视图（按钮）也透明但可交互
            for (UIView *sub in view.subviews) {
                sub.alpha = 0.0;
                sub.hidden = NO;
                sub.userInteractionEnabled = YES;
            }
            return; // 不需要继续递归
        }

        // 5. 导航栏内容视图透明化
        if ([className isEqualToString:@"_UINavigationBarContentView"]) {
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
// Hook UIViewController
// =============================================================
%hook UIViewController
- (void)viewDidLoad {
    %orig;
    if (PPShouldApply()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            PPApply();
        });
    }
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            PPApply();
        });
    }
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (PPShouldApply()) {
        dispatch_async(dispatch_get_main_queue(), ^{
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (PPShouldApply()) {
            PPApply();
        }
    });
}
