// =============================================================
//  PiPiNoTabs — 健壮高速版（适配新版皮皮虾）
//  功能：透明化底部 TabBar 和顶部「关注、推荐、视频、图文、职业圈、虾聊」
//  执行策略：%ctor 异步 + viewWillAppear 异步 + viewDidAppear 异步
//  每次执行间隔极短（0.01秒），确保覆盖所有加载时机
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

        // 2. 透明化顶部选项（通过文字匹配）
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            // 更新为新版顶部标签
            NSArray *targetTitles = @[@"关注", @"推荐", @"视频", @"图文", @"职业圈", @"虾聊"];
            for (NSString *title in targetTitles) {
                if ([label.text isEqualToString:title]) {
                    [UIView performWithoutAnimation:^{
                        label.alpha = 0.0;
                    }];
                    break;
                }
            }
        }

        // 递归子视图
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

// ---------- 多次执行 ----------
static void PPScheduleExecution() {
    // 立即执行一次
    PPProcessAllWindows();
    // 延迟 0.01 秒执行一次
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        PPProcessAllWindows();
    });
    // 延迟 0.05 秒再执行一次，确保动态加载的视图也被覆盖
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        PPProcessAllWindows();
    });
}

// ---------- Hook ----------
%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply()) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            // 在视图即将显示时异步执行（极短延迟，用户无感知）
            dispatch_async(dispatch_get_main_queue(), ^{
                PPScheduleExecution();
            });
        });
    }
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply()) {
        // 再次执行，确保覆盖
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}
%end

%ctor {
    if (PPShouldApply()) {
        // 尽早执行一次，但视图可能未加载，没关系，后续会再次执行
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}
