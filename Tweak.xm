// =============================================================
//  PiPiNoTabs — 稳定高速版（无闪烁、无延迟）
//  策略：在 viewDidLoad 中同步执行，只处理明确视图
//  顶部标签文字透明，底部Tab完全透明，搜索图标透明
//  青少年弹窗屏蔽（双重拦截）
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"];
}

// 查找并透明化搜索图标（在 UINavigationBar 中）
static void PPFindAndHideSearchIcon(UIView *view) {
    if (!view) return;
    // 如果是 UIButton 且 accessibilityLabel 包含“搜索”
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        NSString *label = btn.accessibilityLabel;
        if (label && ([label isEqualToString:@"搜索"] || [label containsString:@"搜索"])) {
            btn.alpha = 0.0;
            btn.userInteractionEnabled = YES;
            return;
        }
    }
    // 如果是 UIBarButtonItem 的视图，查找内部按钮
    if ([NSStringFromClass([view class]) containsString:@"BarButton"]) {
        for (UIView *sub in view.subviews) {
            if ([sub isKindOfClass:[UIButton class]]) {
                UIButton *btn = (UIButton *)sub;
                NSString *label = btn.accessibilityLabel;
                if (label && ([label isEqualToString:@"搜索"] || [label containsString:@"搜索"])) {
                    btn.alpha = 0.0;
                    btn.userInteractionEnabled = YES;
                    return;
                }
            }
        }
    }
    // 递归子视图
    for (UIView *sub in view.subviews) {
        PPFindAndHideSearchIcon(sub);
    }
}

// 透明化顶部标签文字和底部 TabBar
static void PPProcessViews(UIView *view) {
    if (!view) return;
    // 1. 底部 TabBar（TTTabbar）
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
    // 2. 顶部标签文字（UILabel）
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        NSArray *titles = @[@"关注", @"推荐", @"视频", @"图片", @"虾聊", @"文字"];
        for (NSString *title in titles) {
            if ([label.text isEqualToString:title]) {
                label.alpha = 0.0;
                break;
            }
        }
    }
    // 3. 搜索图标（在 UINavigationBar 中）
    if ([view isKindOfClass:[UINavigationBar class]]) {
        PPFindAndHideSearchIcon(view);
        // 继续遍历子视图（尽管上面已经递归，但为了保险）
    }
    // 递归子视图
    for (UIView *sub in view.subviews) {
        PPProcessViews(sub);
    }
}

// 处理所有窗口
static void PPProcessAllWindows() {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        PPProcessViews(window);
    }
}

// ---------- 屏蔽青少年弹窗（双重拦截） ----------
// 1. 拦截 presentViewController
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

// 2. 拦截 addSubview（备用）
%hook UIWindow
- (void)addSubview:(UIView *)view {
    if (PPShouldApply()) {
        // 检查是否是弹窗视图
        if ([NSStringFromClass([view class]) containsString:@"BDSStyledAlertController"]) {
            // 进一步检查标题
            @try {
                UIViewController *vc = nil;
                id responder = [view nextResponder];
                if ([responder isKindOfClass:[UIViewController class]]) {
                    vc = (UIViewController *)responder;
                }
                if (vc) {
                    NSString *title = [vc valueForKey:@"title"];
                    if (title && [title containsString:@"儿童/青少年模式"]) {
                        return; // 拦截
                    }
                }
            } @catch (NSException *e) {}
        }
    }
    %orig;
}
%end

// 主 Hook
%hook UIViewController
- (void)viewDidLoad {
    %orig;
    if (PPShouldApply()) {
        // 在 viewDidLoad 中同步执行，这是最早的时机
        PPProcessAllWindows();
    }
}
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (PPShouldApply() && PPShouldBlockAlert(viewControllerToPresent)) {
        return;
    }
    %orig;
}
%end

%ctor {
    if (PPShouldApply()) {
        // 尽早执行，但视图可能尚未加载，不过没关系
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}
