// =============================================================
//  PiPiNoTabs — 优化版（快速隐藏 + 搜索按钮容器隐藏）
//  双指双击菜单
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

// 递归隐藏，但只针对特定类
static void PPHideViewsInView(UIView *view) {
    if (!view) return;
    if (!PPIsEnabled()) return;
    
    NSString *className = NSStringFromClass([view class]);
    
    // 1. 隐藏底部 TabBar
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
    
    // 2. 隐藏顶部标签文字
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
    
    // 3. 隐藏导航栏背景
    if ([className isEqualToString:@"_UIBarBackground"] ||
        [className isEqualToString:@"_UIBarBackgroundShadowView"] ||
        [className isEqualToString:@"_UIBarBackgroundShadowContentImageView"]) {
        [UIView performWithoutAnimation:^{
            view.hidden = YES;
            view.alpha = 0.0;
        }];
    }
    
    // 4. 隐藏搜索按钮容器（UIView，位于导航栏右侧，包含 UIButton 和 UIImageView）
    if ([view isKindOfClass:[UIView class]]) {
        UIView *parent = view.superview;
        if (parent && [parent isKindOfClass:[UINavigationBar class]]) {
            // 判断是否在右侧
            CGFloat navWidth = parent.bounds.size.width;
            if (view.frame.origin.x > navWidth / 2) {
                BOOL hasButton = NO;
                BOOL hasImageView = NO;
                for (UIView *sub in view.subviews) {
                    if ([sub isKindOfClass:[UIButton class]]) hasButton = YES;
                    if ([sub isKindOfClass:[UIImageView class]]) hasImageView = YES;
                }
                if (hasButton && hasImageView) {
                    [UIView performWithoutAnimation:^{
                        view.hidden = YES;
                        view.alpha = 0.0;
                    }];
                }
            }
        }
    }
    
    // 递归子视图
    for (UIView *sub in view.subviews) {
        PPHideViewsInView(sub);
    }
}

static void PPProcessAllWindows() {
    if (!PPIsEnabled()) return;
    Class textEffectsWindowClass = NSClassFromString(@"UITextEffectsWindow");
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (textEffectsWindowClass && [window isKindOfClass:textEffectsWindowClass]) continue;
        PPHideViewsInView(window);
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
    NSString *status = enabled ? @"已开启" : @"已关闭";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"皮皮虾界面控制"
                                                                   message:[NSString stringWithFormat:@"当前状态：%@\n切换后需重启 App 生效", status]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSString *actionTitle = enabled ? @"关闭隐藏功能" : @"开启隐藏功能";
    [alert addAction:[UIAlertAction actionWithTitle:actionTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"提示"
                                                                         message:@"切换模式后需要重启 App 才能生效，确定要继续吗？"
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            BOOL newState = !enabled;
            [[NSUserDefaults standardUserDefaults] setBool:newState forKey:@"PiPiNoTabsEnabled"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
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
// Hook UIWindow：双指双击
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
// Hook UIViewController：尽早执行隐藏，只执行两次
// =============================================================
static BOOL PPInitialized = NO;

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    if (!PPShouldApply()) return;
    // 只执行一次，在viewDidLoad时立即执行
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [UIView performWithoutAnimation:^{
            PPProcessAllWindows();
        }];
    });
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (!PPShouldApply()) return;
    // 第二次执行，应对动态加载，但只执行一次（用静态标志）
    static BOOL secondRun = NO;
    if (!secondRun) {
        secondRun = YES;
        // 延迟极短时间，确保视图已加载
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView performWithoutAnimation:^{
                PPProcessAllWindows();
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
    NSLog(@"[PiPiNoTabs] 插件加载完成，开关状态：%@", PPIsEnabled() ? @"开启" : @"关闭");
    
    // 初次启动时也执行一次，防止遗漏
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (PPShouldApply()) {
            [UIView performWithoutAnimation:^{
                PPProcessAllWindows();
            }];
        }
    });
}
