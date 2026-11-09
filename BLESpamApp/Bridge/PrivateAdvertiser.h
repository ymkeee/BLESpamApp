/**
 * PrivateAdvertiser.h
 *
 * ObjC trampoline that calls the private CBPeripheralManager selector
 * with properly typed arguments — something Swift cannot do directly
 * because it cannot mix uint8_t C scalars in performSelector:.
 */

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

@interface PrivateAdvertiser : NSObject

/**
 * Broadcasts @c adData on @c peripheral using the private selector:
 *   _startAdvertisingWithAdvertisementData:andMask:andFlags:andCompletionHandler:
 *
 * Falls back to the public -startAdvertising: if the private method is unavailable.
 *
 * @param adData       Advertisement dictionary (CBAdvertisementDataManufacturerDataKey, etc.)
 * @param peripheral   The CBPeripheralManager instance to use.
 */
+ (void)broadcast:(NSDictionary *)adData
               on:(CBPeripheralManager *)peripheral;

@end

NS_ASSUME_NONNULL_END
