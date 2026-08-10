// =============================================================
//  PiPiNoTabs — 全屏透明化稳定版
//  底部 TabBar 完全透明，顶部导航栏背景透明，文字透明但可点击
//  无弹窗、无手势、无布局调整
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"];
}

// ---------- 透明化处理 ----------
static void PPTransparentize(UIView *view) {
    if (!view) return;
    @try {
        // 1. 底部 TabBar
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
        
        // 2. 顶部容器（包含"关注"、"推荐"等标签的容器）
        // 直接根据类名或位置判断，避免误伤
        if ([view isKindOfClass:[UIView class]] && view.subviews.count > 0) {
            BOOL containsTarget = NO;
            for (UIView *sub in view.subviews) {
                if ([sub isKindOfClass:[UILabel class]]) {
                    UILabel *label = (UILabel *)sub;
                    NSArray *titles = @[@"关注", @"推荐", @"视频", @"图片", @"虾聊", @"文字"];
                    for (NSString *title in titles) {
                        if ([label.text isEqualToString:title]) {
                            containsTarget = YES;
                            break;
                        }
                    }
                }
                if (containsTarget) break;
            }
            if (containsTarget) {
                [UIView performWithoutAnimation:^{
                    view.backgroundColor = [UIColor clearColor];
                    view.opaque = NO;
                    // 子视图文字透明
                    for (UIView *sub in view.subviews) {
                        if ([sub isKindOfClass:[UILabel class]]) {
                            sub.alpha = 0.0;
                        }
                        // 搜索按钮透明但可点击
                        if ([sub isKindOfClass:[UIButton class]]) {
                            UIButton *btn = (UIButton *)sub;
                            if ([btn.accessibilityLabel isEqualToString:@"搜索"] || [btn.accessibilityLabel containsString:@"搜索"]) {
                                btn.alpha = 0.0;
                                btn.userInteractionEnabled = YES;
                            }
                        }
                    }
                }];
                // 已处理，返回
                return;
            }
        }
        
        // 3. 递归子视图
        for (UIView *sub in view.subviews) {
            PPTransparentize(sub);
        }
    } @catch (NSException *e) {
        // 忽略异常
    }
}

static void PPProcessAllWindows() {
    @try {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            PPTransparentize(window);
        }
    } @catch (NSException *e) {}
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
            // 立即执行（无延迟），确保无痕
            dispatch_async(dispatch_get_main_queue(), ^{
                PPProcessAllWindows();
            });
        });
    }
}
- (void)viewWillLayoutSubviews {
    %orig;
    if (PPShouldApply()) {
        // 每次布局时重新应用透明化，防止恢复
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}
%end

%ctor {
    if (PPShouldApply()) {
        // 最早时机执行
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}
