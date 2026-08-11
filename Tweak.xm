// =============================================================
//  PiPiNoTabs — 通过坐标识别搜索图标（基于你的定时器版）
//  功能：透明化底部 TabBar、顶部标签文字、以及右上角搜索图标容器
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
        // 1. 透明化底部 TabBar
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
        
        // 3. 透明化右上角搜索图标（通过坐标识别）
        if ([view isKindOfClass:[UIView class]]) {
            CGRect frame = view.frame;
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            // 右上角区域：x > screenWidth - 100, y < 100
            if (frame.origin.x > screenWidth - 100 && frame.origin.y < 100) {
                // 检查是否包含 UIImageView（搜索图标通常是 UIImageView）
                BOOL hasImageView = NO;
                for (UIView *sub in view.subviews) {
                    if ([sub isKindOfClass:[UIImageView class]]) {
                        hasImageView = YES;
                        break;
                    }
                }
                if (hasImageView) {
                    [UIView performWithoutAnimation:^{
                        view.alpha = 0.0;
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
