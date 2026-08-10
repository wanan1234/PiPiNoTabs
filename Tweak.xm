#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"];
}

// ---------- 透明化核心函数 ----------
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
            UINavigationBar *navBar = (UINavigationBar *)view;
            [UIView performWithoutAnimation:^{
                navBar.backgroundColor = [UIColor clearColor];
                navBar.barTintColor = [UIColor clearColor];
                navBar.translucent = YES;
                for (UIView *sub in navBar.subviews) {
                    if ([sub isKindOfClass:NSClassFromString(@"_UIBarBackground")] ||
                        [sub isKindOfClass:NSClassFromString(@"UIVisualEffectView")]) {
                        sub.alpha = 0.0;
                        sub.backgroundColor = [UIColor clearColor];
                    }
                    // 处理 _UINavigationBarContentView 中的搜索按钮
                    if ([sub isKindOfClass:NSClassFromString(@"_UINavigationBarContentView")]) {
                        for (UIView *inner in sub.subviews) {
                            if ([inner isKindOfClass:[UIButton class]]) {
                                UIButton *btn = (UIButton *)inner;
                                if ([btn.accessibilityLabel isEqualToString:@"搜索"] || [btn.accessibilityLabel containsString:@"搜索"]) {
                                    btn.alpha = 0.0;
                                    btn.userInteractionEnabled = YES;
                                }
                            }
                            if ([NSStringFromClass([inner class]) containsString:@"BarButton"]) {
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
            // 继续递归子视图
        }

        // 3. 顶部标签容器（包含关注、推荐等）及其背景透明化
        // 找到包含这些标签的父视图，并透明化其背景
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
        if (hasTarget && ![view isKindOfClass:[UINavigationBar class]] && ![NSStringFromClass([view class]) isEqualToString:@"TTTabbar"]) {
            [UIView performWithoutAnimation:^{
                view.backgroundColor = [UIColor clearColor];
                view.opaque = NO;
                // 透明化所有子视图中的 UILabel（标签文字透明）
                for (UIView *sub in view.subviews) {
                    if ([sub isKindOfClass:[UILabel class]]) {
                        sub.alpha = 0.0;
                    }
                }
                // 透明化可能存在的搜索图标
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
            return; // 处理完容器后不再深入（避免重复处理）
        }

        // 4. 单独处理搜索图标（如果未包含在容器中）
        if ([view isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)view;
            if ([btn.accessibilityLabel isEqualToString:@"搜索"] || [btn.accessibilityLabel containsString:@"搜索"]) {
                [UIView performWithoutAnimation:^{
                    btn.alpha = 0.0;
                    btn.userInteractionEnabled = YES;
                }];
            }
        }

        for (UIView *sub in view.subviews) {
            PPTransparentizeViews(sub);
        }
    } @catch (NSException *e) {}
}

// ---------- 处理所有窗口 ----------
static void PPProcessAllWindows() {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        PPTransparentizeViews(window);
    }
}

// ---------- 儿童模式弹窗屏蔽 ----------
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

%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (PPShouldApply() && PPShouldBlockAlert(viewControllerToPresent)) {
        return;
    }
    %orig;
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply()) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            // 在 viewDidAppear 中延迟极短时间（0.01秒）执行，确保视图完全加载，用户无感知
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                PPProcessAllWindows();
            });
        });
    }
}
%end

%ctor {
    if (PPShouldApply()) {
        // 尽可能早执行一次（可能视图未加载，但没关系）
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}
