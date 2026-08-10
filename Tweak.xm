// =============================================================
//  PiPiNoTabs — 全屏透明化终极版
//  在 viewWillAppear 中立即执行，无延迟
//  透明化 UINavigationBar 背景、搜索图标、顶部标签、底部 TabBar
//  儿童模式弹窗屏蔽
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"];
}

// ---------- 递归透明化 ----------
static void PPTransparentizeViews(UIView *view) {
    if (!view) return;
    @try {
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

        // 2. UINavigationBar 透明化
        if ([view isKindOfClass:[UINavigationBar class]]) {
            [UIView performWithoutAnimation:^{
                view.backgroundColor = [UIColor clearColor];
                view.translucent = YES;
                // 遍历子视图，将所有背景视图透明
                for (UIView *sub in view.subviews) {
                    if ([sub isKindOfClass:NSClassFromString(@"_UIBarBackground")] ||
                        [sub isKindOfClass:NSClassFromString(@"UIVisualEffectView")]) {
                        sub.alpha = 0.0;
                        sub.backgroundColor = [UIColor clearColor];
                    }
                    // 透明化 _UINavigationBarContentView 中的按钮（如搜索）
                    if ([sub isKindOfClass:NSClassFromString(@"_UINavigationBarContentView")]) {
                        for (UIView *inner in sub.subviews) {
                            if ([inner isKindOfClass:[UIButton class]]) {
                                UIButton *btn = (UIButton *)inner;
                                // 通过 accessibilityLabel 或 image 识别搜索按钮
                                if ([btn.accessibilityLabel isEqualToString:@"搜索"] || [btn.accessibilityLabel containsString:@"搜索"]) {
                                    btn.alpha = 0.0;
                                    btn.userInteractionEnabled = YES;
                                }
                            }
                            // 也可能是 UIBarButtonItem 的视图，通过类名识别
                            if ([NSStringFromClass([inner class]) containsString:@"BarButton"]) {
                                // 尝试找到内部的按钮
                                for (UIView *subInner in inner.subviews) {
                                    if ([subInner isKindOfClass:[UIButton class]]) {
                                        UIButton *btn = (UIButton *)subInner;
                                        if ([btn.accessibilityLabel isEqualToString:@"搜索"] || [btn.accessibilityLabel containsString:@"搜索"]) {
                                            btn.alpha = 0.0;
                                            btn.userInteractionEnabled = YES;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }];
            // 处理完 UINavigationBar 后继续遍历其子视图（但可能已经处理了）
        }

        // 3. 顶部标签容器（包含关注、推荐等）
        if ([view isKindOfClass:[UIView class]]) {
            __block BOOL hasTarget = NO;
            for (UIView *sub in view.subviews) {
                if ([sub isKindOfClass:[UILabel class]]) {
                    UILabel *label = (UILabel *)sub;
                    NSArray *titles = @[@"关注", @"推荐", @"视频", @"图片", @"虾聊", @"文字"];
                    for (NSString *title in titles) {
                        if ([label.text isEqualToString:title]) {
                            hasTarget = YES;
                            break;
                        }
                    }
                }
                if (hasTarget) break;
            }
            // 如果包含目标标签且不是 TabBar 或 NavigationBar
            if (hasTarget && ![view isKindOfClass:[UINavigationBar class]] && ![NSStringFromClass([view class]) isEqualToString:@"TTTabbar"]) {
                [UIView performWithoutAnimation:^{
                    view.backgroundColor = [UIColor clearColor];
                    view.opaque = NO;
                    for (UIView *sub in view.subviews) {
                        if ([sub isKindOfClass:[UILabel class]]) {
                            sub.alpha = 0.0;
                        }
                    }
                    // 也透明化可能存在的搜索图标
                    for (UIView *sub in view.subviews) {
                        if ([sub isKindOfClass:[UIButton class]]) {
                            UIButton *btn = (UIButton *)sub;
                            if ([btn.accessibilityLabel isEqualToString:@"搜索"] || [btn.accessibilityLabel containsString:@"搜索"]) {
                                btn.alpha = 0.0;
                                btn.userInteractionEnabled = YES;
                            }
                        }
                    }
                }];
                return;
            }
        }

        // 4. 单独处理搜索图标（可能在导航栏其他地方）
        if ([view isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)view;
            if ([btn.accessibilityLabel isEqualToString:@"搜索"] || [btn.accessibilityLabel containsString:@"搜索"]) {
                [UIView performWithoutAnimation:^{
                    btn.alpha = 0.0;
                    btn.userInteractionEnabled = YES;
                }];
            }
        }

        // 递归子视图
        for (UIView *sub in view.subviews) {
            PPTransparentizeViews(sub);
        }
    } @catch (NSException *e) {
        // 忽略异常
    }
}

// ---------- 处理所有窗口 ----------
static void PPProcessAllWindows() {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        PPTransparentizeViews(window);
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

// ---------- Hook ----------
%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (PPShouldApply() && PPShouldBlockAlert(viewControllerToPresent)) {
        return;
    }
    %orig;
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply()) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            // 在视图即将显示时立即执行，无延迟
            PPProcessAllWindows();
        });
    }
}
%end

%ctor {
    if (PPShouldApply()) {
        // 尽早执行一次，但可能视图未加载
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}
