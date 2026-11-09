/**
 * BLESpamApp-Bridging-Header.h
 *
 * Exposes Objective-C private headers to Swift.
 * Set SWIFT_OBJC_BRIDGING_HEADER = BLESpamApp/Bridge/BLESpamApp-Bridging-Header.h
 * in Xcode build settings.
 */

#import "PrivateBLE.h"

// Needed for dlopen / dlsym runtime loading of BluetoothManager.framework
#include <dlfcn.h>
