// =============================================================
//  PiPiNoTabs — 全屏透明化版
//  底部 TabBar 完全透明不可交互
//  顶部导航栏容器背景透明，文字透明但可点击
//  儿童模式弹窗屏蔽
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"];
}

// 检查一个视图是否包含目标标签（用于识别顶部容器）
static BOOL PPViewContainsTargetLabels(UIView *view) {
    if (!view) return NO;
    // 目标文字
    NSArray *targetTitles = @[@"关注", @"推荐", @"视频", @"图片", @"虾聊", @"文字"];
    // 递归检查子视图中的 UILabel
    __block BOOL found = NO;
    void (^checkSubviews)(UIView *) = ^(UIView *v) {
        if ([v isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)v;
            for (NSString *title in targetTitles) {
                if ([label.text isEqualToString:title]) {
                    found = YES;
                    return;
                }
            }
        }
        for (UIView *sub in v.subviews) {
            checkSubviews(sub);
            if (found) break;
        }
    };
    checkSubviews(view);
    return found;
}

// ---------- 递归遍历视图，透明化目标 ----------
static void PPTransparentizeViews(UIView *view) {
    if (!view) return;
    
    // 1. 透明化底部 TabBar（TTTabbar）
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
    
    // 2. 透明化顶部容器（包含“关注”、“推荐”等标签的容器）
    // 检查当前视图是否是容器且包含目标标签
    if ([view isKindOfClass:[UIView class]] && PPViewContainsTargetLabels(view)) {
        // 确保不是 TabBar（已处理）
        if (![NSStringFromClass([view class]) isEqualToString:@"TTTabbar"]) {
            [UIView performWithoutAnimation:^{
                // 背景透明
                view.backgroundColor = [UIColor clearColor];
                view.opaque = NO;
                // 子视图中的标签文字透明，但保留交互
                for (UIView *sub in view.subviews) {
                    if ([sub isKindOfClass:[UILabel class]]) {
                        sub.alpha = 0.0;
                        // 保持可点击（如果有手势，仍会触发）
                    }
                }
                // 搜索图标透明但可点击（通过accessibilityLabel识别）
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
            // 已处理此容器，不继续遍历其子视图（避免重复处理）
            return;
        }
    }
    
    // 3. 单独处理搜索图标（可能在导航栏其他位置）
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        if ([btn.accessibilityLabel isEqualToString:@"搜索"] || [btn.accessibilityLabel containsString:@"搜索"]) {
            [UIView performWithoutAnimation:^{
                btn.alpha = 0.0;
                btn.userInteractionEnabled = YES;
            }];
        }
    }
    
    // 4. 递归遍历子视图
    for (UIView *sub in view.subviews) {
        PPTransparentizeViews(sub);
    }
}

// ---------- 主处理函数 ----------
static void PPProcessAllWindows() {
    @try {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            PPTransparentizeViews(window);
        }
    } @catch (NSException *e) {
        // 静默失败
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
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                PPProcessAllWindows();
            });
        });
    }
}
%end

%ctor {
    if (PPShouldApply()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}
