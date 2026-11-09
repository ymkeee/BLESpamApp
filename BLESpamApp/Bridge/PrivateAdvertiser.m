/**
 * PrivateAdvertiser.m
 *
 * Calls the private CBPeripheralManager advertising selector.
 *
 * The private method signature (from dyld_shared_cache dump):
 *
 *   - (void)_startAdvertisingWithAdvertisementData:(NSDictionary *)data
 *                                         andMask:(uint8_t)mask
 *                                        andFlags:(uint8_t)flags
 *                              andCompletionHandler:(void (^)(NSError *))handler;
 *
 * Because the method takes uint8_t scalar arguments we use NSInvocation
 * to set each argument by type rather than relying on performSelector:
 * (which only accepts id arguments).
 */

#import "PrivateAdvertiser.h"
#import <objc/message.h>

@implementation PrivateAdvertiser

+ (void)broadcast:(NSDictionary *)adData
               on:(CBPeripheralManager *)peripheral {

    SEL privateSel = NSSelectorFromString(
        @"_startAdvertisingWithAdvertisementData:andMask:andFlags:andCompletionHandler:"
    );

    if (![peripheral respondsToSelector:privateSel]) {
        // Fallback: public API
        [peripheral startAdvertising:adData];
        return;
    }

    NSMethodSignature *sig = [peripheral methodSignatureForSelector:privateSel];
    if (!sig) {
        [peripheral startAdvertising:adData];
        return;
    }

    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target   = peripheral;
    inv.selector = privateSel;

    // arg index 0 = self, 1 = _cmd, 2+ = actual args

    // arg 2: advertisementData (NSDictionary *)
    [inv setArgument:&adData atIndex:2];

    // arg 3: mask (uint8_t) — 0x00 = default connectable
    uint8_t mask  = 0x00;
    [inv setArgument:&mask atIndex:3];

    // arg 4: flags (uint8_t) — 0x06 = LE General Discoverable | BR/EDR Not Supported
    uint8_t flags = 0x06;
    [inv setArgument:&flags atIndex:4];

    // arg 5: completionHandler (void(^)(NSError*)) — nil is fine
    id handler = nil;
    [inv setArgument:&handler atIndex:5];

    [inv invoke];
}

@end
