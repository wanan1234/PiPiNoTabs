// =============================================================
//  PiPiNoTabs — 隐藏「发现」「加号」「消息」，保留「首页」「我的」均匀分布
//  自适应 TabBar 宽度，按钮均匀填充
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL PPShouldApply() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleID isEqualToString:@"com.bd.iphone.superPropipi"];
}

// 递归查找并处理 TabBar
static void PPProcessTabBar(UIView *view) {
    if (!view) return;
    if ([NSStringFromClass([view class]) isEqualToString:@"TTTabbar"]) {
        // 收集所有子视图（按钮）
        NSMutableArray *buttons = [NSMutableArray array];
        for (UIView *sub in view.subviews) {
            // 只要是子视图都视为按钮（因为皮皮虾可能用自定义类）
            [buttons addObject:sub];
        }
        if (buttons.count == 0) return;
        
        // 分离要保留的按钮
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
                // 隐藏其他按钮：宽度设为0，移出屏幕
                btn.hidden = YES;
                btn.alpha = 0.0;
                btn.userInteractionEnabled = NO;
                btn.frame = CGRectZero;
            }
        }
        
        // 重新布局保留的按钮（均匀分布）
        if (keepButtons.count == 2) {
            CGFloat totalWidth = view.frame.size.width;
            CGFloat buttonWidth = totalWidth / keepButtons.count;
            CGFloat height = view.frame.size.height;
            for (NSInteger i = 0; i < keepButtons.count; i++) {
                UIView *btn = keepButtons[i];
                [UIView performWithoutAnimation:^{
                    btn.frame = CGRectMake(i * buttonWidth, 0, buttonWidth, height);
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
            [view setNeedsLayout];
            [view layoutIfNeeded];
            NSLog(@"[PiPiNoTabs] TabBar 已均匀分布，宽度: %.0f", totalWidth);
        } else {
            NSLog(@"[PiPiNoTabs] 保留按钮数量异常: %lu", (unsigned long)keepButtons.count);
        }
        return;
    }
    for (UIView *sub in view.subviews) {
        PPProcessTabBar(sub);
    }
}

// 屏蔽儿童模式弹窗
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

// 加载确认（可注释掉）
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
        PPShowAlert(@"插件已加载，正在处理TabBar...");
        // 延迟执行，确保视图加载完毕
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
            if (window) {
                PPProcessTabBar(window);
                // 再次执行，以防布局变化
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    PPProcessTabBar(window);
                });
            }
        });
    }
}
