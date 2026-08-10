// =============================================================
//  PiPiNoTabs — 安全透明化版（避免递归过深）
//  底部 TabBar 完全透明不可交互
//  顶部导航栏（UINavigationBar）及自定义容器透明化
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"];
}

// ---------- 安全处理视图 ----------
static void PPProcessViewSafely(UIView *view) {
    if (!view) return;
    @try {
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
        
        // 2. 透明化 UINavigationBar（如果存在）
        if ([view isKindOfClass:[UINavigationBar class]]) {
            [UIView performWithoutAnimation:^{
                view.backgroundColor = [UIColor clearColor];
                view.opaque = NO;
                view.translucent = YES;
                // 子视图（标题、按钮）透明但保留交互
                for (UIView *sub in view.subviews) {
                    if ([sub isKindOfClass:[UIButton class]]) {
                        // 搜索按钮等
                        sub.alpha = 0.0;
                        sub.userInteractionEnabled = YES;
                    } else {
                        sub.alpha = 0.0;
                        sub.userInteractionEnabled = YES; // 保留交互
                    }
                }
            }];
            return;
        }
        
        // 3. 针对自定义顶部容器（可能包含“关注、推荐”等）
        // 如果视图的类名包含 "Top" 或 "Header" 或 "Navigation"，且包含子标签，尝试透明化背景
        NSString *className = NSStringFromClass([view class]);
        if ([className containsString:@"Top"] || [className containsString:@"Header"] || [className containsString:@"Nav"]) {
            // 只处理可能包含标签的容器，不处理其他
            BOOL containsLabel = NO;
            for (UIView *sub in view.subviews) {
                if ([sub isKindOfClass:[UILabel class]]) {
                    containsLabel = YES;
                    break;
                }
            }
            if (containsLabel) {
                [UIView performWithoutAnimation:^{
                    view.backgroundColor = [UIColor clearColor];
                    view.opaque = NO;
                    // 子标签透明化，保留交互
                    for (UIView *sub in view.subviews) {
                        if ([sub isKindOfClass:[UILabel class]]) {
                            sub.alpha = 0.0;
                            // 如果标签有手势，仍会触发
                        }
                    }
                }];
                // 不继续遍历子视图，避免重复处理
                return;
            }
        }
        
        // 4. 递归处理子视图（但限制深度以防过深）
        static NSInteger depth = 0;
        if (depth < 10) { // 限制递归深度
            depth++;
            for (UIView *sub in view.subviews) {
                PPProcessViewSafely(sub);
            }
            depth--;
        }
    } @catch (NSException *e) {
        // 忽略异常
    }
}

// ---------- 主处理函数 ----------
static void PPProcessAllWindows() {
    @try {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            PPProcessViewSafely(window);
        }
    } @catch (NSException *e) {
        // 忽略
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
