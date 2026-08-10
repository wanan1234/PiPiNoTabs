// =============================================================
//  PiPiNoTabs — 透明化版
//  底部 TabBar 完全透明且不可交互
//  顶部「关注、推荐、视频、图片、虾聊、文字、搜索」透明但可点击
//  无手势、无弹窗、无布局调整
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"];
}

// ---------- 递归遍历视图，透明化目标 ----------
static void PPTransparentizeViews(UIView *view) {
    if (!view) return;
    
    // 1. 透明化底部 TabBar（TTTabbar）
    if ([NSStringFromClass([view class]) isEqualToString:@"TTTabbar"]) {
        [UIView performWithoutAnimation:^{
            view.alpha = 0.0;
            view.userInteractionEnabled = NO;  // 不可交互，避免误触
            // 子视图也透明化
            for (UIView *sub in view.subviews) {
                sub.alpha = 0.0;
                sub.userInteractionEnabled = NO;
            }
        }];
        return;
    }
    
    // 2. 透明化顶部选项（通过文字匹配）
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        NSArray *targetTitles = @[@"关注", @"推荐", @"视频", @"图片", @"虾聊", @"文字"];
        for (NSString *title in targetTitles) {
            if ([label.text isEqualToString:title]) {
                [UIView performWithoutAnimation:^{
                    label.alpha = 0.0;
                    // 保持可交互（如果父视图是按钮，其交互不受影响）
                    // 如果 label 本身有手势，需要保留，但一般 label 是按钮的子视图
                }];
                break;
            }
        }
    }
    
    // 3. 透明化搜索图标（通常是 UIButton 或 UIBarButtonItem）
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        // 如果按钮是搜索图标（可根据 image 或 accessibilityLabel 判断）
        // 简化：如果按钮的 image 是搜索图标，或 accessibilityLabel 为 "搜索"
        NSString *accessibilityLabel = btn.accessibilityLabel;
        if ([accessibilityLabel isEqualToString:@"搜索"] || [accessibilityLabel containsString:@"搜索"]) {
            [UIView performWithoutAnimation:^{
                btn.alpha = 0.0;
                btn.userInteractionEnabled = YES; // 保持可点击
            }];
        }
    }
    
    // 递归遍历子视图
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
            // 延迟极短时间，确保视图加载完成
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                PPProcessAllWindows();
            });
        });
    }
}
%end

%ctor {
    if (PPShouldApply()) {
        // 立即执行，可能部分视图未加载，但没关系
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}
