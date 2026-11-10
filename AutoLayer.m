#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *const kBundle = @"com.frontierdesign.videostar";

static void pushImage(UIImage *img) {
    if (!img) return;
    int numClasses;
    Class *classes = objc_copyClassList(&numClasses);
    for (int i = 0; i < numClasses; i++) {
        NSString *clsName = NSStringFromClass(classes[i]);
        if ([clsName hasPrefix:@"VS"] && [clsName containsString:@"Layer"]) {
            id mgr = nil;
            if ([classes[i] respondsToSelector:NSSelectorFromString(@"sharedInstance")]) {
                mgr = ((id(*)(id, SEL))objc_msgSend)(classes[i], NSSelectorFromString(@"sharedInstance"));
            } else if ([classes[i] respondsToSelector:NSSelectorFromString(@"sharedManager")]) {
                mgr = ((id(*)(id, SEL))objc_msgSend)(classes[i], NSSelectorFromString(@"sharedManager"));
            }
            if (!mgr) continue;
            
            unsigned int mCount = 0;
            Method *methods = class_copyMethodList([mgr class], &mCount);
            for (unsigned int j = 0; j < mCount; j++) {
                NSString *selName = NSStringFromSelector(method_getName(methods[j]));
                if ([selName hasPrefix:@"add"] && method_getNumberOfArguments(methods[j]) == 3) {
                    ((void(*)(id, SEL, id))objc_msgSend)(mgr, method_getName(methods[j]), img);
                    break;
                }
            }
            free(methods);
            break;
        }
    }
    free(classes);
}

__attribute__((constructor)) static void init() {
    if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:kBundle]) return;

    // Tạo nút bong bóng UI
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
