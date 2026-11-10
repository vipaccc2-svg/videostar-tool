#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *const kBundle = @"com.frontierdesign.videostar";

__attribute__((constructor)) static void init() {
    if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:kBundle]) return;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *w = [UIApplication sharedApplication].keyWindow;
        if (!w) return;
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(w.bounds.size.width - 70, 200, 60, 60);
        btn.backgroundColor = [UIColor cyanColor];
        btn.layer.cornerRadius = 30;
        [btn setTitle:@"★" forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:35];
        [w addSubview:btn];
    });
}
