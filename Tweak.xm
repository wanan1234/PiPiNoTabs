// =============================================================
//  PiPiNoTabs — 完整版（定时器 + 搜索图标隐藏）
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
        // 1. 透明化底部 TabBar（包含中间加号）
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
        
        // 3. 透明化搜索图标所在容器（UIView 包含 UIButton + UIImageView，且父视图是 UINavigationBar）
        if ([view isKindOfClass:[UIView class]]) {
            // 检查父视图是否是 UINavigationBar
            if ([view.superview isKindOfClass:[UINavigationBar class]]) {
                BOOL hasButton = NO;
                BOOL hasImageView = NO;
                for (UIView *sub in view.subviews) {
                    if ([sub isKindOfClass:[UIButton class]]) {
                        hasButton = YES;
                        // 检查按钮是否包含 UIImageView
                        for (UIView *subsub in sub.subviews) {
                            if ([subsub isKindOfClass:[UIImageView class]]) {
                                hasImageView = YES;
                                break;
                            }
                        }
                    }
                }
                if (hasButton && hasImageView) {
                    // 很可能是搜索图标容器
                    [UIView performWithoutAnimation:^{
                        view.alpha = 0.0;
                        // 保持容器可交互（如果需要点击）
                        // view.userInteractionEnabled = YES;
                    }];
                }
            }
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
