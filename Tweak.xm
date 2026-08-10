// =============================================================
//  PiPiNoTabs — 隐藏皮皮虾底部「发现」「加号」「消息」
//  保留「首页」「我的」，均匀布局，并屏蔽儿童模式弹窗
//  Bundle ID: com.bd.iphone.superPropiipi
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropiipi"];
}

// 隐藏并重新布局 TabBar 按钮
static void PPHideAndRearrange(UIView *tabBar) {
    if (!tabBar) return;
    // 检查是否是 TTTabbar 或其子类
    if (![NSStringFromClass([tabBar class]) containsString:@"TTTabbar"]) return;
    
    // 收集所有按钮视图
    NSMutableArray *buttons = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        NSString *className = NSStringFromClass([sub class]);
        if ([className containsString:@"TabBarButton"] || [className containsString:@"TabBarItem"]) {
            [buttons addObject:sub];
        }
    }
    if (buttons.count == 0) return;
    
    // 分离要保留的按钮
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
            // 隐藏其他按钮（发现、加号、消息）
            btn.hidden = YES;
            btn.alpha = 0.0;
            btn.userInteractionEnabled = NO;
        }
    }
    
    // 重新布局保留的按钮（均匀分布）
    if (keepButtons.count == 2) {
        CGFloat width = tabBar.frame.size.width / keepButtons.count;
        CGFloat height = tabBar.frame.size.height;
        for (NSInteger i = 0; i < keepButtons.count; i++) {
            UIView *btn = keepButtons[i];
            [UIView performWithoutAnimation:^{
                btn.frame = CGRectMake(i * width, 0, width, height);
                btn.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                // 确保内部子视图居中
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

static void PPProcessTabBar() {
    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    if (!window) return;
    // 遍历所有子视图查找 TTTabbar
    for (UIView *sub in window.subviews) {
        if ([NSStringFromClass([sub class]) containsString:@"TTTabbar"]) {
            PPHideAndRearrange(sub);
            return;
        }
    }
}

// ---------- 屏蔽儿童/青少年模式弹窗 ----------
static BOOL PPShouldBlockAlert(UIViewController *vc) {
    NSString *className = NSStringFromClass([vc class]);
    if ([className containsString:@"BDSStyledAlertController"]) {
        // 检查标题是否包含“儿童/青少年模式”
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
        // 拦截弹窗，不显示
        return;
    }
    %orig;
}
%end

%ctor {
    if (PPShouldApply()) {
        NSLog(@"[PiPiNoTabs] 插件加载成功");
        // 延迟执行 TabBar 处理，确保视图已加载
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            PPProcessTabBar();
        });
    }
}
