// =============================================================
//  PiPiNoTabs — 全屏透明化版（无痕）
//  底部 TabBar 完全透明不可交互
//  顶部导航栏容器背景透明，文字透明但可点击
//  搜索图标透明但可点击
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
    NSArray *targetTitles = @[@"关注", @"推荐", @"视频", @"图片", @"虾聊", @"文字"];
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
    if ([view isKindOfClass:[UIView class]] && PPViewContainsTargetLabels(view)) {
        if (![NSStringFromClass([view class]) isEqualToString:@"TTTabbar"]) {
            [UIView performWithoutAnimation:^{
                // 背景透明
                view.backgroundColor = [UIColor clearColor];
                view.opaque = NO;
                // 子视图中的标签文字透明，但保留交互
                for (UIView *sub in view.subviews) {
                    if ([sub isKindOfClass:[UILabel class]]) {
                        sub.alpha = 0.0;
                    }
                    // 所有按钮透明但保留交互（包括搜索图标）
                    if ([sub isKindOfClass:[UIButton class]]) {
                        sub.alpha = 0.0;
                        sub.userInteractionEnabled = YES;
                    }
                }
            }];
            return;
        }
    }
    
    // 3. 递归遍历子视图
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
- (void)viewDidLoad {
    %orig;
    if (PPShouldApply()) {
        // 在视图加载完成后立即执行，无延迟
        PPProcessAllWindows();
    }
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply()) {
        // 再次执行，确保视图显示前透明
        PPProcessAllWindows();
    }
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply()) {
        // 最后再执行一次，防止某些动态添加的视图
        PPProcessAllWindows();
    }
}
%end

%ctor {
    if (PPShouldApply()) {
        // 立即尝试处理（可能视图未加载，但没关系）
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}
