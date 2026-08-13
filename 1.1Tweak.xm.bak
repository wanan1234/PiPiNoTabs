// =============================================================
//  PiPiNoTabs — 添加双指双击控制菜单
//  功能：透明化底部 TabBar、顶部标签文字、以及搜索图标
//  手势：双指双击弹出控制菜单，可开关隐藏功能（需重启生效）
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ---------- 开关判断 ----------
static BOOL PPIsEnabled() {
    // 默认开启，用户可通过手势切换
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"PiPiNoTabsEnabled"];
}

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"] && PPIsEnabled();
}

// ---------- 透明化核心逻辑 ----------
static void PPTransparentizeViews(UIView *view) {
    if (!view) return;
    if (!PPIsEnabled()) return; // 开关关闭则不执行任何操作
    
    @try {
        // 1. 透明化底部 TabBar（包含中间加号）
        if ([NSStringFromClass([view class]) isEqualToString:@"TTTabbar"]) {
            [UIView performWithoutAnimation:^{
                view.alpha = 0.0;
                view.userInteractionEnabled = NO;
                for (UIView *sub in view.subviews) {
                    sub.alpha = 0.0;
                    sub.userInteractionEnabled = NO;
                }
            }];
            return;
        }
        
        // 2. 透明化顶部标签文字（UILabel）
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            NSArray *targetTitles = @[@"关注", @"推荐", @"视频", @"图片", @"图文", @"职业圈", @"虾聊", @"文字"];
            for (NSString *title in targetTitles) {
                if ([label.text isEqualToString:title]) {
                    [UIView performWithoutAnimation:^{
                        label.alpha = 0.0;
                    }];
                    break;
                }
            }
        }
        
        // 3. 透明化搜索图标所在容器
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
                        view.alpha = 0.0;
                    }];
                }
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
        PPTransparentizeViews(window);
    }
}

static void PPStartTimer() {
    if (!PPIsEnabled()) return;
    // 立即执行一次
    PPProcessAllWindows();
    // 每隔 0.1 秒执行一次，共 15 次（持续 1.5 秒）
    for (int i = 1; i <= 15; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}

// =============================================================
// 手势控制：双指双击菜单
// =============================================================

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
    NSString *status = enabled ? @"已开启" : @"已关闭";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"皮皮虾界面隐藏控制"
                                                                   message:[NSString stringWithFormat:@"当前状态：%@\n切换后需重启 App 生效", status]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSString *actionTitle = enabled ? @"关闭隐藏功能" : @"开启隐藏功能";
    [alert addAction:[UIAlertAction actionWithTitle:actionTitle
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
                                                // 弹出确认框，提示需要重启
                                                UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                                                                       message:@"切换后需要重启 App 才能完全生效，确定要继续吗？"
                                                                                                                preferredStyle:UIAlertControllerStyleAlert];
                                                [confirmAlert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                                    BOOL newState = !enabled;
                                                    [[NSUserDefaults standardUserDefaults] setBool:newState forKey:@"PiPiNoTabsEnabled"];
                                                    [[NSUserDefaults standardUserDefaults] synchronize];
                                                    showToast(newState ? @"隐藏功能已开启，请重启 App" : @"隐藏功能已关闭，请重启 App", window);
                                                }]];
                                                [confirmAlert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
                                                
                                                UIViewController *top = window.rootViewController;
                                                while (top.presentedViewController) {
                                                    top = top.presentedViewController;
                                                }
                                                [top presentViewController:confirmAlert animated:YES completion:nil];
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
        NSLog(@"[PiPiNoTabs] 2-finger double-tap gesture added");
    }
    return self;
}

%new
- (void)pp_handleDoubleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateRecognized) return;
    // 触觉反馈
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [generator prepare];
        [generator impactOccurred];
    }
    showSettingsMenu(self);
}

%end

// =============================================================
// 原有 Hook：UIViewController 触发定时任务
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
// 构造函数：初始化默认状态并执行一次透明化
// =============================================================
%ctor {
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"PiPiNoTabsEnabled"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"PiPiNoTabsEnabled"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    if (PPShouldApply()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}
