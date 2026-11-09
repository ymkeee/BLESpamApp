/**
 * PrivateBLE.h
 *
 * Declarations for private CoreBluetooth / BluetoothManager classes
 * used to broadcast arbitrary manufacturer data on iOS.
 *
 * These headers are reverse-engineered from dyld_shared_cache.
 * Referenced via dlopen + NSClassFromString so the binary links
 * against public CoreBluetooth only.
 */

#ifndef PrivateBLE_h
#define PrivateBLE_h

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

// ─────────────────────────────────────────────────────────────────────────────
// MARK: CBPeripheralManager private extension
//
// The key private selector is:
//   -[CBPeripheralManager _startAdvertisingWithAdvertisementData:
//                         andMask:andFlags:andCompletionHandler:]
//
// This bypasses the public "serviceUUIDs required" restriction and allows
// raw manufacturer data frames without registered GATT services.
// ─────────────────────────────────────────────────────────────────────────────

@interface CBPeripheralManager (Private)

/**
 * Private advertising method that allows raw manufacturer data
 * without requiring registered services.
 *
 * @param advertisementData  Same dict as public API but manufacturer data is accepted.
 * @param mask               Advertising type mask (0 = default connectable).
 * @param flags              AD Flags byte (0x06 = BR/EDR Not Supported | LE General Discoverable).
 * @param completionHandler  Called when advertising starts (may be nil).
 */
- (void)_startAdvertisingWithAdvertisementData:(NSDictionary *)advertisementData
                                       andMask:(uint8_t)mask
                                      andFlags:(uint8_t)flags
                            andCompletionHandler:(void (^)(NSError * _Nullable))completionHandler;

/**
 * Stop advertising immediately.
 */
- (void)_stopAdvertising;

/**
 * Returns YES if peripheral is currently advertising.
 */
- (BOOL)_isAdvertising;

@end

// ─────────────────────────────────────────────────────────────────────────────
// MARK: BluetoothManager (private framework — loaded via dlopen)
//
// /System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager
//
// This class gives lower-level access including MAC address spoofing
// via the BTLocalDevice XPC interface.
// ─────────────────────────────────────────────────────────────────────────────

NS_ASSUME_NONNULL_BEGIN

@interface BluetoothManager : NSObject

+ (instancetype)sharedInstance;

/** Power the BT radio on/off */
- (void)setPowered:(BOOL)powered;
- (BOOL)powered;

/** Returns the current local MAC address string (e.g. "AA:BB:CC:DD:EE:FF") */
- (NSString *)address;

/** Randomise the local Bluetooth MAC address (requires com.apple.bluetooth.system entitlement) */
- (void)setAddress:(NSString *)address;

@end

NS_ASSUME_NONNULL_END

#endif /* PrivateBLE_h */
