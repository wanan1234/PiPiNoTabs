// =============================================================
//  PiPiNoTabs — 全屏透明化版（无痕快速）
//  底部 TabBar 完全透明不可交互
//  顶部导航栏容器背景透明，文字透明但可点击
//  搜索图标透明但可点击
//  儿童模式弹窗屏蔽
//  无延迟感（极短延迟 0.01 秒）
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

        // 2. 顶部导航栏容器（包含关注、推荐等标签）
        if ([view isKindOfClass:[UIView class]]) {
            // 检查是否包含目标标签
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
            if (hasTarget && ![NSStringFromClass([view class]) isEqualToString:@"TTTabbar"]) {
                [UIView performWithoutAnimation:^{
                    view.backgroundColor = [UIColor clearColor];
                    view.opaque = NO;
                    // 透明化所有子视图中的 UILabel
                    for (UIView *sub in view.subviews) {
                        if ([sub isKindOfClass:[UILabel class]]) {
                            sub.alpha = 0.0;
                        }
                    }
                    // 透明化搜索图标（UIButton 且 accessibilityLabel 为搜索）
                    for (UIView *sub in view.subviews) {
                        if ([sub isKindOfClass:[UIButton class]]) {
                            UIButton *btn = (UIButton *)sub;
                            if ([btn.accessibilityLabel isEqualToString:@"搜索"] || [btn.accessibilityLabel containsString:@"搜索"]) {
                                btn.alpha = 0.0;
                                btn.userInteractionEnabled = YES;
                            }
                        }
                    }
                    // 递归更深层（确保搜索图标在更深的层级也被覆盖）
                    for (UIView *sub in view.subviews) {
                        for (UIView *inner in sub.subviews) {
                            if ([inner isKindOfClass:[UIButton class]]) {
                                UIButton *btn = (UIButton *)inner;
                                if ([btn.accessibilityLabel isEqualToString:@"搜索"] || [btn.accessibilityLabel containsString:@"搜索"]) {
                                    btn.alpha = 0.0;
                                    btn.userInteractionEnabled = YES;
                                }
                            }
                        }
                    }
                }];
                return; // 处理完容器后不再深入
            }
        }

        // 3. 单独处理搜索图标（如果之前没处理到）
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
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply()) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            // 极短延迟（0.01秒），确保视图完全加载，用户无感知
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                PPProcessAllWindows();
            });
        });
    }
}
%end

// ---------- 加载入口 ----------
%ctor {
    if (PPShouldApply()) {
        // 立即尝试一次（可能部分视图未加载）
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}
