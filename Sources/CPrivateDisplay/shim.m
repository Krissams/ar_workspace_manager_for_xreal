// Header-only target for the private CGVirtualDisplay classes (provided at runtime by
// CoreGraphics). The only compiled code here is the cursor-scale bridge, which resolves the
// private CGSSetCursorScale / CGSGetCursorScale symbols at runtime via dlsym.
#import "CPrivateDisplay.h"
#import <dlfcn.h>

typedef int CGSConnectionID;
typedef CGSConnectionID (*VRDMainConnFn)(void);
typedef CGError (*VRDSetScaleFn)(CGSConnectionID, float);
typedef CGError (*VRDGetScaleFn)(CGSConnectionID, float *);

void VRDSetCursorScale(float scale) {
    VRDMainConnFn mainConn = (VRDMainConnFn)dlsym(RTLD_DEFAULT, "CGSMainConnectionID");
    VRDSetScaleFn setScale = (VRDSetScaleFn)dlsym(RTLD_DEFAULT, "CGSSetCursorScale");
    if (mainConn && setScale) {
        setScale(mainConn(), scale);
    }
}

float VRDGetCursorScale(void) {
    VRDMainConnFn mainConn = (VRDMainConnFn)dlsym(RTLD_DEFAULT, "CGSMainConnectionID");
    VRDGetScaleFn getScale = (VRDGetScaleFn)dlsym(RTLD_DEFAULT, "CGSGetCursorScale");
    float scale = 1.0f;
    if (mainConn && getScale) {
        getScale(mainConn(), &scale);
    }
    return scale;
}

BOOL VRDRunCatchingNSException(void (^block)(void), NSString **reason) {
    @try {
        block();
        return YES;
    } @catch (NSException *e) {
        if (reason) *reason = e.reason ?: e.name;
        return NO;
    }
}

// Resolve private entry points at runtime: fail explicitly on unsupported macOS versions.
CGError VRDGetAllDisplays(uint32_t capacity, CGDirectDisplayID *displays, uint32_t *count) {
    typedef CGError (*Fn)(uint32_t, CGDirectDisplayID *, uint32_t *);
    Fn getDisplays = (Fn)dlsym(RTLD_DEFAULT, "CGSGetDisplayList");
    return getDisplays ? getDisplays(capacity, displays, count)
                       : CGGetOnlineDisplayList(capacity, displays, count);
}
