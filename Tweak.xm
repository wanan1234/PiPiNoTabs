// =============================================================
//  PiPiNoTabs — 隐藏皮皮虾底部「发现」「加号」「消息」
//  保留「首页」「我的」，均匀布局，屏蔽儿童模式弹窗
//  Bundle ID: com.bd.iphone.superPropipi
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"];
}

// ---------- TabBar 处理 ----------
static void PPHideAndRearrange(UIView *tabBar) {
    if (!tabBar) return;
    // 只处理 TTTabbar
    if (![NSStringFromClass([tabBar class]) isEqualToString:@"TTTabbar"]) return;
    
    NSMutableArray *buttons = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        // 收集所有子视图（包括自定义的按钮）
        [buttons addObject:sub];
    }
    if (buttons.count == 0) return;
    
    NSMutableArray *keepButtons = [NSMutableArray array];
    for (UIView *btn in buttons) {
        // 获取标题
        NSString *title = nil;
        for (UIView *inner in btn.subviews) {
            if ([inner isKindOfClass:[UILabel class]]) {
                title = ((UILabel *)inner).text;
                break;
            }
        }
        if (!title) {
            @try { title = [btn valueForKey:@"title"]; } @catch (NSException *e) {}
        }
        if (title && ([title isEqualToString:@"首页"] || [title isEqualToString:@"我的"])) {
            [keepButtons addObject:btn];
        } else {
            // 隐藏其他（发现、加号、消息）
            btn.hidden = YES;
            btn.alpha = 0.0;
            btn.userInteractionEnabled = NO;
        }
    }
    
    // 重新布局保留的按钮
    if (keepButtons.count == 2) {
        CGFloat width = tabBar.frame.size.width / keepButtons.count;
        CGFloat height = tabBar.frame.size.height;
        for (NSInteger i = 0; i < keepButtons.count; i++) {
            UIView *btn = keepButtons[i];
            [UIView performWithoutAnimation:^{
                btn.frame = CGRectMake(i * width, 0, width, height);
                btn.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                for (UIView *sub in btn.subviews) {
                    sub.frame = btn.bounds;
                    if ([sub isKindOfClass:[UILabel class]]) {
                        ((UILabel *)sub).textAlignment = NSTextAlignmentCenter;
                    }
                }
            }];
        }
        [tabBar setNeedsLayout];
        [tabBar layoutIfNeeded];
        NSLog(@"[PiPiNoTabs] TabBar 已重新布局，保留 %lu 个按钮", (unsigned long)keepButtons.count);
    } else {
        NSLog(@"[PiPiNoTabs] 保留按钮数量异常: %lu", (unsigned long)keepButtons.count);
    }
}

// 递归查找 TTTabbar
static void PPFindAndProcessTabBar(UIView *view) {
    if (!view) return;
    if ([NSStringFromClass([view class]) isEqualToString:@"TTTabbar"]) {
        PPHideAndRearrange(view);
        return;
    }
    for (UIView *sub in view.subviews) {
        PPFindAndProcessTabBar(sub);
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
%end

// ---------- 加载确认 ----------
static void PPShowAlert(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"PiPiNoTabs"
                                                        message:msg
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    });
}

%ctor {
    if (PPShouldApply()) {
        PPShowAlert(@"插件已加载");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
            if (window) {
                PPFindAndProcessTabBar(window);
            }
        });
    }
}
