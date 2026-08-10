// =============================================================
//  PiPiNoTabs — 增强版（拦截 addSubview 屏蔽弹窗，通用 TabBar 处理）
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
    // 只要类名包含 Tabbar 或 TabBar 就处理
    if (![NSStringFromClass([tabBar class]) containsString:@"Tabbar"] &&
        ![NSStringFromClass([tabBar class]) containsString:@"TabBar"]) return;
    
    NSMutableArray *buttons = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        NSString *className = NSStringFromClass([sub class]);
        if ([className containsString:@"TabBarButton"] || [className containsString:@"TabBarItem"]) {
            [buttons addObject:sub];
        }
    }
    if (buttons.count == 0) return;
    
    NSMutableArray *keepButtons = [NSMutableArray array];
    for (UIView *btn in buttons) {
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
            btn.hidden = YES;
            btn.alpha = 0.0;
            btn.userInteractionEnabled = NO;
        }
    }
    
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
    }
}

// ---------- 弹窗屏蔽：拦截 UIWindow 的 addSubview ----------
%hook UIWindow
- (void)addSubview:(UIView *)view {
    if (PPShouldApply()) {
        // 检测是否是弹窗视图（类名包含 BDSStyledAlertController 或类似）
        NSString *className = NSStringFromClass([view class]);
        if ([className containsString:@"BDSStyledAlertController"] ||
            [className containsString:@"Alert"]) {
            // 进一步检查标题
            @try {
                UIViewController *vc = nil;
                // 尝试获取控制器
                if ([view isKindOfClass:[UIView class]]) {
                    // 如果视图是控制器视图，通过 nextResponder 获取
                    id responder = [view nextResponder];
                    if ([responder isKindOfClass:[UIViewController class]]) {
                        vc = (UIViewController *)responder;
                    }
                }
                if (vc) {
                    NSString *title = [vc valueForKey:@"title"];
                    if (title && [title containsString:@"儿童/青少年模式"]) {
                        // 屏蔽此弹窗
                        return;
                    }
                }
            } @catch (NSException *e) {}
        }
    }
    %orig;
}
%end

%ctor {
    if (PPShouldApply()) {
        NSLog(@"[PiPiNoTabs] 插件加载成功");
        // 延迟执行 TabBar 处理
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
            if (!window) return;
            for (UIView *sub in window.subviews) {
                if ([NSStringFromClass([sub class]) containsString:@"Tabbar"] ||
                    [NSStringFromClass([sub class]) containsString:@"TabBar"]) {
                    PPHideAndRearrange(sub);
                    break;
                }
            }
        });
    }
}
