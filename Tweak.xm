// =============================================================
//  PiPiNoTabs — 增加搜索图标透明化（基于你的定时器版）
//  功能：透明化底部 TabBar、顶部标签文字、以及搜索图标
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
        // 1. 透明化底部 TabBar（包含中间的加号）
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
        
        // 2. 透明化顶部标签文字（UILabel）
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            NSArray *targetTitles = @[@"关注", @"推荐", @"视频", @"图片", @"图文", @"职业圈", @"虾聊", @"文字"];
            for (NSString *title in targetTitles) {
                if ([label.text isEqualToString:title]) {
                    [UIView performWithoutAnimation:^{
                        label.alpha = 0.0;
                    }];
                    break;
                }
            }
        }
        
        // 3. 透明化搜索图标（UIButton）
        if ([view isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)view;
            // 通过 accessibilityLabel 或 accessibilityIdentifier 识别搜索按钮
            NSString *label = btn.accessibilityLabel;
            NSString *identifier = btn.accessibilityIdentifier;
            if ((label && [label containsString:@"搜索"]) ||
                (identifier && [identifier containsString:@"search"])) {
                [UIView performWithoutAnimation:^{
                    btn.alpha = 0.0;
                    // 保持可点击（如需要）
                    // btn.userInteractionEnabled = YES;
                }];
            }
            // 如果按钮的 image 是搜索图标（可通过 image 的 accessibilityIdentifier 判断，但此处简化）
            // 或通过父视图类名判断（如果按钮在 UINavigationBar 中）
            // 更通用：如果按钮在 UINavigationBar 中且只有一个 UIImageView，可能为搜索按钮
            // 但这里我们用 accessibility 识别
        }
        
        // 递归子视图
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
