// =============================================================
//  PiPiNoTabs — 调试版（显示加载状态和 Tab 按钮标题）
//  Bundle ID: com.bd.iphone.superPropiipi
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropiipi"];
}

static void PPShowAlert(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
        if (!window) return;
        UIViewController *root = window.rootViewController;
        if (!root) return;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"PiPiNoTabs 调试"
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [root presentViewController:alert animated:YES completion:nil];
    });
}

// 查找 TTTabbar 并收集按钮信息
static void PPFindAndReport(UIView *view) {
    if (!view) return;
    if ([NSStringFromClass([view class]) containsString:@"TTTabbar"]) {
        NSMutableString *info = [NSMutableString stringWithString:@"找到 TTTabbar\n子视图: "];
        NSInteger count = 0;
        for (UIView *sub in view.subviews) {
            NSString *className = NSStringFromClass([sub class]);
            [info appendFormat:@"\n%@", className];
            count++;
            if (count > 5) break;
        }
        PPShowAlert(info);
        return;
    }
    for (UIView *sub in view.subviews) {
        PPFindAndReport(sub);
    }
}

static void PPScanAndReport() {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        PPFindAndReport(window);
    }
}

%ctor {
    if (!PPShouldApply()) return;
    PPShowAlert(@"PiPiNoTabs 已加载！");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        PPScanAndReport();
    });
}
