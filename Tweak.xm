// =============================================================
//  PiPiNoTabs — 极速隐藏版（基于第一次成功代码优化）
//  功能：透明化底部 TabBar 和顶部「关注、推荐、视频、图片、虾聊、文字」
//  不处理搜索图标，不处理弹窗拦截
//  执行时机：viewWillAppear 同步 + viewDidAppear 异步，无延迟
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

// ---------- Hook ----------
%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply()) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            // 在视图即将显示时同步执行，此时视图尚未渲染，用户完全看不到变化
            PPProcessAllWindows();
        });
    }
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply()) {
        // 再次执行，确保动态添加的视图也被覆盖（异步执行，但此时视图已显示，可能一闪而过）
        // 但因为已经同步执行过一次，这里只是兜底
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}
%end

%ctor {
    if (PPShouldApply()) {
        // 尽早执行一次（可能视图未加载，但没关系）
        dispatch_async(dispatch_get_main_queue(), ^{
            PPProcessAllWindows();
        });
    }
}
