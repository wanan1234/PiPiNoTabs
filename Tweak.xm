// =============================================================
//  PiPiNoTabs — 稳定增强版（多次应用透明化）
//  在 viewDidAppear、viewDidLayoutSubviews 中执行
//  Hook TTTabbar 的 layoutSubviews 持续透明化
//  搜索图标多重识别
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"];
}

// ---------- 全局标记，防止无限递归 ----------
static BOOL isApplying = NO;

// ---------- 递归透明化 ----------
static void PPTransparentizeViews(UIView *view) {
    if (!view) return;
    if (isApplying) return;
    isApplying = YES;
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
            isApplying = NO;
            return;
        }

        // 2. 顶部标签文字透明（不透明背景）
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            NSArray *targetTitles = @[@"关注", @"推荐", @"视频", @"图片", @"虾聊", @"文字"];
            for (NSString *title in targetTitles) {
                if ([label.text isEqualToString:title]) {
                    [UIView performWithoutAnimation:^{
                        label.alpha = 0.0;
                    }];
                    break;
                }
            }
        }

        // 3. 搜索图标透明但可点击（多重识别）
        if ([view isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)view;
            // 通过 accessibilityLabel
            if ([btn.accessibilityLabel isEqualToString:@"搜索"] || [btn.accessibilityLabel containsString:@"搜索"]) {
                [UIView performWithoutAnimation:^{
                    btn.alpha = 0.0;
                    btn.userInteractionEnabled = YES;
                }];
            }
            // 通过 image 的 accessibilityIdentifier
            if (btn.imageView) {
                NSString *imageAccessibility = btn.imageView.accessibilityIdentifier;
                if ([imageAccessibility containsString:@"search"] || [imageAccessibility containsString:@"Search"]) {
                    [UIView performWithoutAnimation:^{
                        btn.alpha = 0.0;
                        btn.userInteractionEnabled = YES;
                    }];
                }
            }
            // 通过类名包含 Search
            if ([NSStringFromClass([btn class]) containsString:@"Search"]) {
                [UIView performWithoutAnimation:^{
                    btn.alpha = 0.0;
                    btn.userInteractionEnabled = YES;
                }];
            }
        }

        // 4. 递归子视图
        for (UIView *sub in view.subviews) {
            PPTransparentizeViews(sub);
        }
    } @catch (NSException *e) {
        // 忽略
    }
    isApplying = NO;
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

// ---------- Hook TTTabbar 的 layoutSubviews ----------
%hook TTTabbar
- (void)layoutSubviews {
    %orig;
    if (PPShouldApply()) {
        // 在布局后重新应用透明化
        dispatch_async(dispatch_get_main_queue(), ^{
            PPTransparentizeViews(self);
        });
    }
}
%end

// ---------- Hook UIViewController ----------
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
            // 立即执行
            PPProcessAllWindows();
            // 延迟 0.1 秒再执行一次，应对动态加载
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                PPProcessAllWindows();
            });
            // 再延迟 0.3 秒执行一次，确保所有视图被覆盖
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                PPProcessAllWindows();
            });
        });
    }
}
- (void)viewDidLayoutSubviews {
    %orig;
    if (PPShouldApply()) {
        // 布局变化时重新应用
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            // 使用 CADisplayLink 或定时器持续观察，但这里简单使用 dispatch_after
            // 但为了避免冲突，我们使用一个静态标记
        });
        // 每次布局后都执行，但限制频率
        static NSTimeInterval lastTime = 0;
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (now - lastTime > 0.2) { // 0.2秒内只执行一次
            lastTime = now;
            PPProcessAllWindows();
        }
    }
}
%end

%ctor {
    if (PPShouldApply()) {
        // 尽早执行一次
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}
