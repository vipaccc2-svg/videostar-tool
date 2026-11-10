// language: Objective-C, file: AutoLayer.m, target: iOS 15+ arm64/arm64e
// *Dylib hoàn chỉnh: Có UI Menu, hiển thị tên tác giả, hook tự động nhập ảnh.*

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *const kBundle = @"com.frontierdesign.videostar";

// Biến trạng thái
static BOOL g_autoImport = NO;
static BOOL g_showLog = NO;
static BOOL g_autoSplitBeat = NO;

// ==========================================================
// LOGIC HOOK VÀO VIDEO STAR
// ==========================================================
static void pushImageToLayer(UIImage *img) {
    if (!img) return;
    int numClasses;
    Class *classes = objc_copyClassList(&numClasses);
    Class targetClass = nil;
    
    for (int i = 0; i < numClasses; i++) {
        NSString *clsName = NSStringFromClass(classes[i]);
        if ([clsName hasPrefix:@"VS"] && ([clsName containsString:@"Layer"] || [clsName containsString:@"Project"])) {
            if ([classes[i] respondsToSelector:NSSelectorFromString(@"sharedInstance")] || 
                [classes[i] respondsToSelector:NSSelectorFromString(@"sharedManager")] ||
                [classes[i] respondsToSelector:NSSelectorFromString(@"shared")]) {
                targetClass = classes[i];
                break;
            }
        }
    }
    free(classes);

    if (!targetClass) return;

    id mgr = nil;
    if ([targetClass respondsToSelector:NSSelectorFromString(@"sharedInstance")])
        mgr = ((id(*)(id, SEL))objc_msgSend)(targetClass, NSSelectorFromString(@"sharedInstance"));
    else if ([targetClass respondsToSelector:NSSelectorFromString(@"sharedManager")])
        mgr = ((id(*)(id, SEL))objc_msgSend)(targetClass, NSSelectorFromString(@"sharedManager"));
    else if ([targetClass respondsToSelector:NSSelectorFromString(@"shared")])
        mgr = ((id(*)(id, SEL))objc_msgSend)(targetClass, NSSelectorFromString(@"shared"));

    if (!mgr) return;

    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList([mgr class], &methodCount);
    SEL addSel = nil;
    
    for (unsigned int i = 0; i < methodCount; i++) {
        NSString *selName = NSStringFromSelector(method_getName(methods[i]));
        if ([selName hasPrefix:@"add"] || [selName hasPrefix:@"insert"]) {
            if (method_getNumberOfArguments(methods[i]) == 3) {
                addSel = method_getName(methods[i]);
                break;
            }
        }
    }
    free(methods);

    if (addSel) {
        ((void(*)(id, SEL, id))objc_msgSend)(mgr, addSel, img);
        if (g_showLog) NSLog(@"[AutoLayer] Đã đẩy ảnh vào layer qua %@", NSStringFromSelector(addSel));
    }
}

static void swizzleMethod(Class cls, SEL originalSelector, SEL swizzledSelector) {
    Method originalMethod = class_getInstanceMethod(cls, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(cls, swizzledSelector);
    if (!originalMethod || !swizzledMethod) return;
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

@interface NSObject (AutoLayerHooks)
- (void)al_hook_photoPickerDidFinish:(NSArray<UIImage*>*)imgs;
- (void)al_hook_imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary*)info;
@end

@implementation NSObject (AutoLayerHooks)

- (void)al_hook_photoPickerDidFinish:(NSArray<UIImage*>*)imgs {
    if (g_autoImport && [imgs isKindOfClass:[NSArray class]]) {
        for (UIImage *img in imgs) pushImageToLayer(img);
        return; 
    }
    [self al_hook_photoPickerDidFinish:imgs];
}

- (void)al_hook_imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary*)info {
    if (g_autoImport) {
        UIImage *img = info[UIImagePickerControllerOriginalImage];
        if (img) pushImageToLayer(img);
        [picker dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    [self al_hook_imagePickerController:picker didFinishPickingMediaWithInfo:info];
}

@end

// ==========================================================
// UI OVERLAY (CÓ TÊN TÁC GIẢ)
// ==========================================================
@interface VSToolOverlay : UIView
@property (nonatomic, strong) UIButton *toggleBtn;
@property (nonatomic, strong) UIView *menuView;
@end

@implementation VSToolOverlay

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) { [self setupUI]; }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];
    
    // Nút bong bóng (Floating Button)
    self.toggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.toggleBtn.frame = CGRectMake(self.bounds.size.width - 70, 200, 60, 60);
    self.toggleBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.9 alpha:0.9];
    self.toggleBtn.layer.cornerRadius = 30;
    self.toggleBtn.layer.borderColor = [UIColor whiteColor].CGColor;
    self.toggleBtn.layer.borderWidth = 2;
    self.toggleBtn.layer.shadowColor = [UIColor cyanColor].CGColor;
    self.toggleBtn.layer.shadowRadius = 10;
    self.toggleBtn.layer.shadowOpacity = 0.8;
    
    UILabel *star = [[UILabel alloc] initWithFrame:self.toggleBtn.bounds];
    star.text = @"★";
    star.font = [UIFont systemFontOfSize:35];
    star.textColor = [UIColor whiteColor];
    star.textAlignment = NSTextAlignmentCenter;
    [self.toggleBtn addSubview:star];
    
    [self.toggleBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.toggleBtn];
    
    // Menu chính
    self.menuView = [[UIView alloc] initWithFrame:CGRectMake(20, 150, self.bounds.size.width - 40, 350)];
    self.menuView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.08 alpha:0.95];
    self.menuView.layer.cornerRadius = 15;
    self.menuView.layer.borderColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.9 alpha:1.0].CGColor;
    self.menuView.layer.borderWidth = 1.5;
    self.menuView.hidden = YES;
    
    // Tiêu đề: TÊN CỦA BẠN
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, 250, 30)];
    title.text = @"★ Tool by vipaccc2-svg"; // <--- ĐỔI TÊN TẠI ĐÂY NẾU MUỐN
    title.textColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.9 alpha:1.0];
    title.font = [UIFont boldSystemFontOfSize:20];
    [self.menuView addSubview:title];
    
    // Nút tắt
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(self.menuView.bounds.size.width - 40, 15, 30, 30);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.menuView addSubview:closeBtn];
    
    // Các dòng tính năng
    [self addRowAtIndex:0 title:@"Auto nhập ảnh vào các lớp hình ảnh" action:@selector(toggleAutoImport)];
    [self addRowAtIndex:1 title:@"Hiển thị code gần nhất từng nhập" action:@selector(toggleShowLog)];
    [self addRowAtIndex:2 title:@"Auto chia beat" action:@selector(toggleAutoBeat)];
    
    // Chữ ký dưới cùng
    UILabel *footer = [[UILabel alloc] initWithFrame:CGRectMake(0, 330, self.menuView.bounds.size.width, 20)];
    footer.text = @"VIDEOSTAR • VIPACCC2-SVG";
    footer.textColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.9 alpha:0.8];
    footer.font = [UIFont systemFontOfSize:10];
    footer.textAlignment = NSTextAlignmentCenter;
    [self.menuView addSubview:footer];
    
    [self addSubview:self.menuView];
}

- (void)addRowAtIndex:(int)index title:(NSString*)title action:(SEL)action {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 60 + index * 90, self.menuView.bounds.size.width, 80)];
    row.backgroundColor = [UIColor clearColor];
    
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, self.menuView.bounds.size.width - 100, 80)];
    lbl.text = title;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:15];
    lbl.numberOfLines = 2;
    [row addSubview:lbl];
    
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(self.menuView.bounds.size.width - 70, 25, 50, 30)];
    sw.onTintColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.9 alpha:1.0];
    sw.tag = index;
    [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];
    
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(20, 79, self.menuView.bounds.size.width - 40, 1)];
    sep.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    [row addSubview:sep];
    
    [self.menuView addSubview:row];
}

- (void)toggleMenu { self.menuView.hidden = !self.menuView.hidden; }
- (void)toggleAutoImport:(UISwitch*)sender { g_autoImport = sender.isOn; }
- (void)toggleShowLog:(UISwitch*)sender { g_showLog = sender.isOn; }
- (void)toggleAutoBeat:(UISwitch*)sender { g_autoSplitBeat = sender.isOn; }

@end

// ==========================================================
// KHỞI TẠO DYNAMIC
// ==========================================================
__attribute__((constructor))
static void AutoLayerInit(void) {
    NSString *bundle = [[NSBundle mainBundle] bundleIdentifier];
    if (![bundle isEqualToString:kBundle]) return;

    int numClasses;
    Class *classes = objc_copyClassList(&numClasses);
    for (int i = 0; i < numClasses; i++) {
        Class cls = classes[i];
        NSString *clsName = NSStringFromClass(cls);
        if (![clsName hasPrefix:@"VS"]) continue;

        if ([clsName containsString:@"Picker"] || [clsName containsString:@"Photo"]) {
            SEL selDidFinish = NSSelectorFromString(@"photoPickerDidFinish:");
            SEL selMediaInfo = NSSelectorFromString(@"imagePickerController:didFinishPickingMediaWithInfo:");
            
            if (class_getInstanceMethod(cls, selDidFinish)) {
                swizzleMethod(cls, selDidFinish, @selector(al_hook_photoPickerDidFinish:));
            }
            if (class_getInstanceMethod(cls, selMediaInfo)) {
                swizzleMethod(cls, selMediaInfo, @selector(al_hook_imagePickerController:didFinishPickingMediaWithInfo:));
            }
        }
    }
    free(classes);

    swizzleMethod([UIImagePickerController class],
                  @selector(imagePickerController:didFinishPickingMediaWithInfo:),
                  @selector(al_hook_imagePickerController:didFinishPickingMediaWithInfo:));

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;
        VSToolOverlay *overlay = [[VSToolOverlay alloc] initWithFrame:window.bounds];
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [window addSubview:overlay];
    });
}
