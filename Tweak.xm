// =============================================================
//  PiPiNoTabs — 定时器版（覆盖延迟加载）
//  功能：透明化底部 TabBar 和顶部标签文字
//  策略：在 viewDidAppear 中启动定时器，每隔 0.1 秒执行一次，持续 1.5 秒
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"];
}

static void PPTransparentizeViews(UIView *view) {
    if (!view) return;
    @try {
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
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            NSArray *targetTitles = @[@"关注", @"推荐", @"视频", @"图片",@"图文", @"职业圈", @"虾聊", @"文字"];
            for (NSString *title in targetTitles) {
                if ([label.text isEqualToString:title]) {
                    [UIView performWithoutAnimation:^{
                        label.alpha = 0.0;
                    }];
                    break;
                }
            }
        }
        for (UIView *sub in view.subviews) {
            PPTransparentizeViews(sub);
        }
    } @catch (NSException *e) {}
}

static void PPProcessAllWindows() {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        PPTransparentizeViews(window);
    }
}

static void PPStartTimer() {
    __block NSInteger count = 0;
    // 立即执行一次
    PPProcessAllWindows();
    // 每隔 0.1 秒执行一次，共 15 次（持续 1.5 秒）
    for (int i = 1; i <= 15; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply()) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            // 在视图显示后启动定时器
            dispatch_async(dispatch_get_main_queue(), ^{
                PPStartTimer();
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
