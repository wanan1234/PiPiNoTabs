// =============================================================
//  PiPiNoTabs — 稳定快速版（隐藏顶部文字 + 底部Tab）
//  顶部标签文字透明，白色背景保留
//  底部 TabBar 完全透明不可交互
//  搜索图标透明但可点击
//  儿童模式弹窗屏蔽
//  执行时机：viewWillAppear 同步执行，无延迟
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

        // 2. 顶部标签文字透明（不透明背景）
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            NSArray *targetTitles = @[@"关注", @"推荐", @"视频", @"图片", @"虾聊", @"文字"];
            for (NSString *title in targetTitles) {
                if ([label.text isEqualToString:title]) {
                    [UIView performWithoutAnimation:^{
                        label.alpha = 0.0;
                        // 保持可交互（如果父视图是按钮，其交互不受影响）
                    }];
                    break;
                }
            }
        }

        // 3. 搜索图标透明但可点击
        if ([view isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)view;
            if ([btn.accessibilityLabel isEqualToString:@"搜索"] || [btn.accessibilityLabel containsString:@"搜索"]) {
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
            // 同步执行，视图尚未显示，用户完全看不到变化
            PPProcessAllWindows();
        });
    }
}
%end

%ctor {
    if (PPShouldApply()) {
        // 尽早尝试，但可能视图未加载，但没关系
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}
