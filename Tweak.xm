// =============================================================
//  PiPiNoTabs — 终极稳定版（Hook setText 实时透明化）
//  顶部标签文字透明，底部 TabBar 透明
//  不处理搜索图标，不处理弹窗拦截
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"];
}

// 目标文字列表
static NSArray *PPTargetTitles(void) {
    static NSArray *titles = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        titles = @[@"关注", @"推荐", @"视频", @"图片", @"虾聊", @"文字"];
    });
    return titles;
}

// 透明化底部 TabBar
static void PPProcessTabBar(UIView *view) {
    if ([NSStringFromClass([view class]) isEqualToString:@"TTTabbar"]) {
        [UIView performWithoutAnimation:^{
            view.alpha = 0.0;
            view.userInteractionEnabled = NO;
            for (UIView *sub in view.subviews) {
                sub.alpha = 0.0;
                sub.userInteractionEnabled = NO;
            }
        }];
    }
}

// 遍历一次视图树（初始处理）
static void PPProcessAllWindows() {
    @try {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            // 处理 TabBar
            PPProcessTabBar(window);
            // 处理所有标签（但后续由 Hook 接管，这里只是初始清理）
            // 但由于后续 Hook 会处理，这里可以不做标签处理，加快速度
        }
    } @catch (NSException *e) {
        // 忽略
    }
}

// ---------- Hook UILabel 的 setText ----------
%hook UILabel
- (void)setText:(NSString *)text {
    %orig(text);
    if (PPShouldApply()) {
        // 检查是否为目标文字
        for (NSString *target in PPTargetTitles()) {
            if ([text isEqualToString:target]) {
                // 透明化
                self.alpha = 0.0;
                break;
            }
        }
    }
}
%end

// ---------- Hook TTTabbar 的 layoutSubviews（处理动态添加） ----------
%hook TTTabbar
- (void)layoutSubviews {
    %orig;
    if (PPShouldApply()) {
        // 每次布局时重新透明化（防止被重置）
        PPProcessTabBar(self);
    }
}
%end

%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply()) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            // 初始处理（处理已存在的视图）
            PPProcessAllWindows();
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
