// =============================================================
//  PiPiNoTabs — 隐藏皮皮虾底部 TabBar，双击手势开关
//  隐藏整个 TTTabbar，调整内容视图全屏，双指双击弹出设置
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"];
}

static BOOL PPIsEnabled = YES; // 默认开启隐藏

// 保存原始 tabBar frame 以便恢复
static CGRect PPOriginalTabBarFrame;

// ---------- 隐藏/恢复 TabBar ----------
static void PPHideTabBar(UIView *tabBar, BOOL hide) {
    if (!tabBar) return;
    if (hide) {
        // 隐藏并移出屏幕
        tabBar.hidden = YES;
        tabBar.alpha = 0.0;
        // 保存原始 frame
        PPOriginalTabBarFrame = tabBar.frame;
        // 移出屏幕
        CGRect newFrame = tabBar.frame;
        newFrame.origin.y = [UIScreen mainScreen].bounds.size.height;
        tabBar.frame = newFrame;
        // 调整父视图的内容视图（通常是 UIViewController 的 view）铺满全屏
        UIView *parent = tabBar.superview;
        if (parent) {
            for (UIView *sub in parent.subviews) {
                if (sub != tabBar) {
                    sub.frame = parent.bounds;
                    sub.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                }
            }
        }
    } else {
        // 恢复
        tabBar.hidden = NO;
        tabBar.alpha = 1.0;
        tabBar.frame = PPOriginalTabBarFrame;
        // 恢复子视图 frame（可能需要重新布局）
        [tabBar.superview setNeedsLayout];
        [tabBar.superview layoutIfNeeded];
    }
}

// 查找 TTTabbar
static UIView* PPFindTabBar(UIView *root) {
    if (!root) return nil;
    if ([NSStringFromClass([root class]) isEqualToString:@"TTTabbar"]) {
        return root;
    }
    for (UIView *sub in root.subviews) {
        UIView *found = PPFindTabBar(sub);
        if (found) return found;
    }
    return nil;
}

// ---------- 手势控制 ----------
static void PPShowMenu(UIViewController *vc) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"PiPiNoTabs"
                                                                   message:[NSString stringWithFormat:@"当前状态: %@", PPIsEnabled ? @"隐藏" : @"显示"]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *toggleAction = [UIAlertAction actionWithTitle:PPIsEnabled ? @"显示 TabBar" : @"隐藏 TabBar"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
                                                             PPIsEnabled = !PPIsEnabled;
                                                             UIView *tabBar = PPFindTabBar(vc.view);
                                                             if (tabBar) {
                                                                 PPHideTabBar(tabBar, PPIsEnabled);
                                                             }
                                                             // 保存状态
                                                             [[NSUserDefaults standardUserDefaults] setBool:PPIsEnabled forKey:@"PiPiNoTabs_Enabled"];
                                                             [[NSUserDefaults standardUserDefaults] synchronize];
                                                         }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:toggleAction];
    [alert addAction:cancelAction];
    [vc presentViewController:alert animated:YES completion:nil];
}

// 手势回调
static void PPHandleDoubleTap(UITapGestureRecognizer *gesture) {
    UIViewController *vc = nil;
    UIResponder *responder = gesture.view;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            vc = (UIViewController *)responder;
            break;
        }
        responder = [responder nextResponder];
    }
    if (vc) {
        PPShowMenu(vc);
    }
}

// 添加手势到主视图
static void PPAddGesture(UIView *view) {
    if (!view) return;
    // 检查是否已有手势
    for (UIGestureRecognizer *g in view.gestureRecognizers) {
        if ([g isKindOfClass:[UITapGestureRecognizer class]]) {
            UITapGestureRecognizer *tap = (UITapGestureRecognizer *)g;
            if (tap.numberOfTapsRequired == 2 && tap.numberOfTouchesRequired == 2) {
                return;
            }
        }
    }
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:nil action:@selector(pp_handleDoubleTap:)];
    tap.numberOfTapsRequired = 2;
    tap.numberOfTouchesRequired = 2;
    [view addGestureRecognizer:tap];
    // 由于 target 为 nil，使用分类方法实现
    // 下面通过添加分类实现
}

// 分类实现手势
@interface UIView (PiPiNoTabs)
- (void)pp_handleDoubleTap:(UITapGestureRecognizer *)gesture;
@end
@implementation UIView (PiPiNoTabs)
- (void)pp_handleDoubleTap:(UITapGestureRecognizer *)gesture {
    PPHandleDoubleTap(gesture);
}
@end

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
%end

// ---------- 主逻辑 ----------
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!PPShouldApply()) return;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 读取保存的状态
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults objectForKey:@"PiPiNoTabs_Enabled"] != nil) {
            PPIsEnabled = [defaults boolForKey:@"PiPiNoTabs_Enabled"];
        }
        // 延迟执行确保视图加载
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIView *tabBar = PPFindTabBar(self.view);
            if (tabBar) {
                PPHideTabBar(tabBar, PPIsEnabled);
            }
            // 添加手势
            PPAddGesture(self.view);
            // 弹窗提示
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"PiPiNoTabs"
                                                                           message:[NSString stringWithFormat:@"插件已加载，当前: %@\n双指双击可切换", PPIsEnabled ? @"隐藏" : @"显示"]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    });
}
%end

%ctor {
    if (PPShouldApply()) {
        NSLog(@"[PiPiNoTabs] 插件加载成功");
    }
}
