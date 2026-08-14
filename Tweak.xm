// =============================================================
//  PiPiNoTabs — 诊断版（详细日志，分析闪烁和搜索按钮问题）
//  双指双击菜单，日志写入沙盒 Documents
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ---------- 日志工具 ----------
static void WriteLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    NSString *logPath = [documentsDirectory stringByAppendingPathComponent:@"PiPiNoTabs.log"];

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:documentsDirectory]) {
        [fm createDirectoryAtPath:documentsDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    NSString *timestamp = [df stringFromDate:[NSDate date]];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", timestamp, msg];

    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (!fh) {
        [line writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
    NSLog(@"[PiPiNoTabs-Diagnostic] %@", msg);
}

// ---------- 开关管理 ----------
static BOOL PPIsEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"PiPiNoTabsEnabled"];
}

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"] && PPIsEnabled();
}

// ---------- 视图层级诊断 ----------
static void PPDumpViewHierarchy(UIView *view, NSInteger depth, NSMutableString *output) {
    if (!view) return;
    NSMutableString *indent = [NSMutableString string];
    for (NSInteger i = 0; i < depth; i++) [indent appendString:@"  "];

    NSString *className = NSStringFromClass([view class]);
    NSString *frame = NSStringFromCGRect(view.frame);
    NSString *hidden = view.hidden ? @"YES" : @"NO";
    NSString *alpha = [NSString stringWithFormat:@"%.2f", view.alpha];
    NSString *tag = [NSString stringWithFormat:@"%ld", (long)view.tag];
    NSString *accessibility = view.accessibilityLabel ?: @"(无)";

    [output appendFormat:@"%@[%@] frame=%@ hidden=%@ alpha=%@ tag=%@ a11y=%@\n",
     indent, className, frame, hidden, alpha, tag, accessibility];

    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        [output appendFormat:@"%@  TEXT: \"%@\"\n", indent, label.text ?: @"(空)"];
    }
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        [output appendFormat:@"%@  BUTTON title: \"%@\"\n", indent, [btn titleForState:UIControlStateNormal] ?: @"(无)"];
    }

    for (UIView *sub in view.subviews) {
        PPDumpViewHierarchy(sub, depth + 1, output);
    }
}

// ---------- 导航栏诊断 ----------
static void PPDumpNavigationBar(UIView *rootView, NSMutableString *output) {
    if (!rootView) return;

    // 遍历查找所有 UINavigationBar
    NSMutableArray *queue = [NSMutableArray arrayWithObject:rootView];
    while (queue.count > 0) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if ([view isKindOfClass:[UINavigationBar class]]) {
            UINavigationBar *navBar = (UINavigationBar *)view;
            [output appendFormat:@"\n=== UINavigationBar found ===\n"];
            [output appendFormat:@"frame: %@\n", NSStringFromCGRect(navBar.frame)];
            [output appendFormat:@"subviews count: %lu\n", (unsigned long)navBar.subviews.count];

            CGFloat navWidth = navBar.bounds.size.width;
            [output appendFormat:@"navWidth: %.1f\n", navWidth];

            for (UIView *sub in navBar.subviews) {
                CGRect subFrame = sub.frame;
                BOOL isRight = subFrame.origin.x > navWidth / 2;
                [output appendFormat:@"  %@ frame=%@ isRight=%d\n",
                 NSStringFromClass([sub class]),
                 NSStringFromCGRect(subFrame),
                 isRight];

                // 递归打印子视图
                for (UIView *subsub in sub.subviews) {
                    [output appendFormat:@"    %@ frame=%@\n",
                     NSStringFromClass([subsub class]),
                     NSStringFromCGRect(subsub.frame)];
                }
            }
        }

        for (UIView *sub in view.subviews) {
            [queue addObject:sub];
        }
    }
}

// ---------- 核心隐藏函数（带日志） ----------
static void PPHideAll(UIView *view, NSInteger depth, NSMutableString *log) {
    if (!view) return;
    if (!PPIsEnabled()) return;

    @try {
        NSString *className = NSStringFromClass([view class]);

        // 1. 隐藏底部 TabBar（TTTabbar）
        if ([className isEqualToString:@"TTTabbar"]) {
            [log appendFormat:@"  找到 TTTabbar，执行隐藏\n"];
            view.hidden = YES;
            view.alpha = 0.0;
            view.userInteractionEnabled = NO;
            for (UIView *sub in view.subviews) {
                sub.hidden = YES;
                sub.alpha = 0.0;
            }
            return;
        }

        // 2. 隐藏导航栏背景
        if ([className isEqualToString:@"_UIBarBackground"] ||
            [className isEqualToString:@"_UIBarBackgroundShadowView"] ||
            [className isEqualToString:@"_UIBarBackgroundShadowContentImageView"]) {
            [log appendFormat:@"  隐藏导航栏背景: %@\n", className];
            view.hidden = YES;
            view.alpha = 0.0;
        }

        // 3. 隐藏顶部标签
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            NSArray *targets = @[@"关注", @"推荐", @"视频", @"图片", @"图文", @"职业圈", @"虾聊", @"文字"];
            if ([targets containsObject:label.text]) {
                [log appendFormat:@"  隐藏标签: \"%@\"\n", label.text];
                label.hidden = YES;
                label.alpha = 0.0;
            }
        }

        // 4. 隐藏右上角搜索按钮（详细诊断）
        if ([view isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)view;
            // 查找导航栏
            UIView *navBar = btn.superview;
            while (navBar && ![navBar isKindOfClass:[UINavigationBar class]]) {
                navBar = navBar.superview;
            }
            if (navBar) {
                CGRect frameInNav = [btn convertRect:btn.bounds toView:navBar];
                CGFloat navWidth = navBar.bounds.size.width;
                BOOL isRight = frameInNav.origin.x > navWidth / 2;

                if (isRight) {
                    [log appendFormat:@"  找到右侧按钮: %@ frame=%@\n", className, NSStringFromCGRect(frameInNav)];
                    [log appendFormat:@"    navWidth=%.1f, x=%.1f, 父视图=%@\n",
                     navWidth, frameInNav.origin.x, NSStringFromClass([btn.superview class])];

                    // 尝试隐藏按钮及其容器
                    UIView *container = btn.superview;
                    if (container && container.superview == navBar) {
                        [log appendFormat:@"  隐藏容器: %@\n", NSStringFromClass([container class])];
                        container.hidden = YES;
                        container.alpha = 0.0;
                    } else {
                        [log appendFormat:@"  隐藏按钮本身\n"];
                        btn.hidden = YES;
                        btn.alpha = 0.0;
                        btn.userInteractionEnabled = NO;
                    }
                }
            }
        }

        // 递归子视图
        for (UIView *sub in view.subviews) {
            PPHideAll(sub, depth + 1, log);
        }
    } @catch (NSException *e) {
        [log appendFormat:@"  异常: %@\n", e];
    }
}

static void PPApplyWithDiagnostic() {
    if (!PPIsEnabled()) return;

    NSMutableString *log = [NSMutableString string];
    [log appendFormat:@"\n=== PPApplyWithDiagnostic 开始 (执行次数: %d) ===\n", ++executionCount];
    [log appendFormat:@"时间: %@\n", [NSDate date]];

    // 先记录当前窗口信息
    NSArray *windows = [UIApplication sharedApplication].windows;
    [log appendFormat:@"窗口数量: %lu\n", (unsigned long)windows.count];

    for (UIWindow *window in windows) {
        if ([window isKindOfClass:NSClassFromString(@"UITextEffectsWindow")]) {
            [log appendFormat:@"  跳过: UITextEffectsWindow\n"];
            continue;
        }
        [log appendFormat:@"  处理窗口: %@ frame=%@\n",
         NSStringFromClass([window class]),
         NSStringFromCGRect(window.frame)];

        // 诊断导航栏
        PPDumpNavigationBar(window, log);

        // 执行隐藏
        PPHideAll(window, 0, log);
    }

    WriteLog(@"%@", log);
}

static NSInteger executionCount = 0;

// =============================================================
// 手势控制（双指双击）
// =============================================================
static void showToast(NSString *msg, UIWindow *window) {
    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    UIAlertController *toast = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
    [top presentViewController:toast animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [toast dismissViewControllerAnimated:YES completion:nil];
    });
}

static void showSettingsMenu(UIWindow *window) {
    UIViewController *topVC = window.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;

    BOOL enabled = PPIsEnabled();
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"皮皮虾界面控制"
                                                                   message:[NSString stringWithFormat:@"当前状态：%@\n日志路径: Documents/PiPiNoTabs.log", enabled ? @"已开启" : @"已关闭"]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:enabled ? @"关闭隐藏" : @"开启隐藏" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"提示"
                                                                         message:@"切换后需重启 App 生效，确定？"
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[NSUserDefaults standardUserDefaults] setBool:!enabled forKey:@"PiPiNoTabsEnabled"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            UIAlertController *restart = [UIAlertController alertControllerWithTitle:@"重启应用"
                                                                             message:@"是否立即重启？"
                                                                      preferredStyle:UIAlertControllerStyleAlert];
            [restart addAction:[UIAlertAction actionWithTitle:@"立即重启" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                exit(0);
            }]];
            [restart addAction:[UIAlertAction actionWithTitle:@"稍后" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                showToast(@"请手动重启皮皮虾", window);
            }]];
            UIViewController *top = window.rootViewController;
            while (top.presentedViewController) top = top.presentedViewController;
            [top presentViewController:restart animated:YES completion:nil];
        }]];
        [confirm addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        UIViewController *top = window.rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
        [top presentViewController:confirm animated:YES completion:nil];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"查看日志" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths firstObject];
        NSString *logPath = [documentsDirectory stringByAppendingPathComponent:@"PiPiNoTabs.log"];
        NSString *logContent = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil];
        if (!logContent) logContent = @"日志文件不存在或为空";
        UIAlertController *logAlert = [UIAlertController alertControllerWithTitle:@"日志内容" message:logContent preferredStyle:UIAlertControllerStyleAlert];
        [logAlert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleDefault handler:nil]];
        UIViewController *top = window.rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
        [top presentViewController:logAlert animated:YES completion:nil];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = window;
        alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(window.bounds), CGRectGetMidY(window.bounds), 0, 0);
    }
    [topVC presentViewController:alert animated:YES completion:nil];
}

// =============================================================
// Hook UIWindow：双指双击
// =============================================================
%hook UIWindow
- (instancetype)initWithFrame:(CGRect)frame {
    self = %orig;
    if (self) {
        UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_handleDoubleTap:)];
        gesture.numberOfTouchesRequired = 2;
        gesture.numberOfTapsRequired = 2;
        [self addGestureRecognizer:gesture];
        WriteLog(@"双指双击手势已添加到窗口");
    }
    return self;
}
%new
- (void)pp_handleDoubleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        if (@available(iOS 10.0, *)) {
            [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
        }
        WriteLog(@"用户触发双指双击，弹出菜单");
        showSettingsMenu(self);
    }
}
%end

// =============================================================
// Hook UIViewController
// =============================================================
%hook UIViewController
- (void)viewDidLoad {
    %orig;
    if (PPShouldApply()) {
        WriteLog(@"viewDidLoad 触发 PPApplyWithDiagnostic");
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIView performWithoutAnimation:^{
                PPApplyWithDiagnostic();
            }];
        });
    }
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (PPShouldApply()) {
        WriteLog(@"viewWillAppear 触发 PPApplyWithDiagnostic (可能重复)");
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView performWithoutAnimation:^{
                    PPApplyWithDiagnostic();
                }];
            });
        });
    }
}
%end

// =============================================================
// 构造函数
// =============================================================
%ctor {
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"PiPiNoTabsEnabled"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"PiPiNoTabsEnabled"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    WriteLog(@"========================================");
    WriteLog(@"PiPiNoTabs 诊断版加载");
    WriteLog(@"Bundle ID: %@", [[NSBundle mainBundle] bundleIdentifier]);
    WriteLog(@"开关状态: %@", PPIsEnabled() ? @"开启" : @"关闭");
    WriteLog(@"========================================");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (PPShouldApply()) {
            [UIView performWithoutAnimation:^{
                PPApplyWithDiagnostic();
            }];
        }
    });
}
