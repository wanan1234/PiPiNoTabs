// =============================================================
//  PiPiNoTabs — 搜索按钮诊断版
//  记录点击搜索按钮时的视图层级信息
//  双指双击弹出菜单，可查看日志
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <stdarg.h>

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

// ---------- 开关 ----------
static BOOL PPIsEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"PiPiNoTabsEnabled"];
}

// ---------- 打印视图层级 ----------
static void PPDumpViewHierarchyForView(UIView *view, NSMutableString *output) {
    if (!view) return;
    NSInteger depth = 0;
    UIView *current = view;
    NSMutableArray *ancestors = [NSMutableArray array];
    while (current) {
        [ancestors insertObject:current atIndex:0];
        current = current.superview;
    }
    
    for (UIView *v in ancestors) {
        NSMutableString *indent = [NSMutableString string];
        for (NSInteger i = 0; i < depth; i++) [indent appendString:@"  "];
        
        NSString *className = NSStringFromClass([v class]);
        NSString *frame = NSStringFromCGRect(v.frame);
        NSString *hidden = v.hidden ? @"YES" : @"NO";
        NSString *alpha = [NSString stringWithFormat:@"%.2f", v.alpha];
        NSString *userInteraction = v.userInteractionEnabled ? @"YES" : @"NO";
        NSString *tag = [NSString stringWithFormat:@"%ld", (long)v.tag];
        NSString *a11y = v.accessibilityLabel ?: @"(无)";
        NSString *a11yId = v.accessibilityIdentifier ?: @"(无)";
        
        [output appendFormat:@"%@[%@] frame=%@ hidden=%@ alpha=%@ userInteraction=%@ tag=%@ a11y=%@ a11yId=%@\n",
         indent, className, frame, hidden, alpha, userInteraction, tag, a11y, a11yId];
        
        // 如果是 UIButton，打印标题和图片
        if ([v isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)v;
            NSString *title = [btn titleForState:UIControlStateNormal] ?: @"(无)";
            UIImage *image = [btn imageForState:UIControlStateNormal];
            [output appendFormat:@"%@  BUTTON: title=\"%@\" hasImage=%@\n",
             indent, title, image ? @"YES" : @"NO"];
        }
        // 如果是 UIImageView，打印图片信息
        if ([v isKindOfClass:[UIImageView class]]) {
            UIImageView *iv = (UIImageView *)v;
            [output appendFormat:@"%@  IMAGEVIEW: image=%@\n",
             indent, iv.image ? @"存在" : @"(无)"];
        }
        depth++;
    }
}

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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"皮皮虾诊断"
                                                                   message:[NSString stringWithFormat:@"开关状态：%@\n日志路径: Documents/PiPiNoTabs.log\n\n点击搜索按钮后查看日志", enabled ? @"已开启" : @"已关闭"]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:enabled ? @"关闭" : @"开启" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] setBool:!enabled forKey:@"PiPiNoTabsEnabled"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        showToast(@"请重启皮皮虾", window);
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
    }
    return self;
}
%new
- (void)pp_handleDoubleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        if (@available(iOS 10.0, *)) {
            [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
        }
        showSettingsMenu(self);
    }
}
%end

// =============================================================
// Hook UIApplication：检测点击事件，记录搜索按钮点击
// =============================================================
%hook UIApplication

- (void)sendEvent:(UIEvent *)event {
    %orig;
    
    if (event.type != UIEventTypeTouches) return;
    NSSet *touches = [event allTouches];
    if (touches.count == 0) return;
    
    UITouch *touch = [touches anyObject];
    if (touch.phase != UITouchPhaseEnded) return;
    
    // 获取点击位置
    CGPoint location = [touch locationInView:touch.window];
    UIView *hitView = [touch.window hitTest:location withEvent:event];
    if (!hitView) return;
    
    // 只记录点击按钮的事件
    if (![hitView isKindOfClass:[UIButton class]]) {
        // 如果点击的是 UIImageView，向上查找 UIButton
        UIResponder *responder = hitView;
        while (responder && ![responder isKindOfClass:[UIButton class]]) {
            responder = [responder nextResponder];
        }
        if ([responder isKindOfClass:[UIButton class]]) {
            hitView = (UIView *)responder;
        } else {
            return;
        }
    }
    
    UIButton *btn = (UIButton *)hitView;
    
    // 检查是否是搜索按钮：在屏幕右侧区域，且包含图片
    CGRect frameInWindow = [btn convertRect:btn.bounds toView:nil];
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    BOOL isRight = frameInWindow.origin.x > screenWidth * 0.7;
    BOOL hasImage = [btn imageForState:UIControlStateNormal] != nil;
    BOOL hasImageView = NO;
    for (UIView *sub in btn.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            hasImageView = YES;
            break;
        }
    }
    
    // 记录所有点击的按钮信息（但只对可能是搜索按钮的做详细记录）
    NSMutableString *log = [NSMutableString string];
    [log appendFormat:@"\n========== 按钮点击检测 ==========\n"];
    [log appendFormat:@"时间: %@\n", [NSDate date]];
    [log appendFormat:@"位置: (%.1f, %.1f) 屏幕宽度: %.1f\n", frameInWindow.origin.x, frameInWindow.origin.y, screenWidth];
    [log appendFormat:@"是否右侧: %@\n", isRight ? @"YES" : @"NO"];
    [log appendFormat:@"按钮标题: %@\n", [btn titleForState:UIControlStateNormal] ?: @"(无)"];
    [log appendFormat:@"按钮有图片: %@\n", hasImage ? @"YES" : @"NO"];
    [log appendFormat:@"按钮包含 UIImageView: %@\n", hasImageView ? @"YES" : @"NO"];
    [log appendFormat:@"按钮 frame: %@\n", NSStringFromCGRect(btn.frame)];
    [log appendFormat:@"按钮类名: %@\n", NSStringFromClass([btn class])];
    [log appendFormat:@"按钮 accessibilityLabel: %@\n", btn.accessibilityLabel ?: @"(无)"];
    [log appendFormat:@"按钮 accessibilityIdentifier: %@\n", btn.accessibilityIdentifier ?: @"(无)"];
    
    // 打印完整的视图层级
    [log appendFormat:@"\n--- 视图层级 (从按钮到根) ---\n"];
    PPDumpViewHierarchyForView(btn, log);
    
    WriteLog(@"%@", log);
    
    // 如果是搜索按钮，额外显示 Toast 提示
    if (isRight && (hasImage || hasImageView)) {
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (keyWindow) {
            dispatch_async(dispatch_get_main_queue(), ^{
                showToast(@"搜索按钮已记录，查看日志", keyWindow);
            });
        }
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
    WriteLog(@"PiPiNoTabs 搜索按钮诊断版加载");
    WriteLog(@"Bundle ID: %@", [[NSBundle mainBundle] bundleIdentifier]);
    WriteLog(@"开关状态: %@", PPIsEnabled() ? @"开启" : @"关闭");
    WriteLog(@"========================================");
}
