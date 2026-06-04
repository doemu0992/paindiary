#import "ExceptionCatcher.h"

NSException * _Nullable catchObjCException(NS_NOESCAPE void (^ _Nonnull block)(void)) {
    @try {
        block();
        return nil;
    } @catch (NSException *exception) {
        return exception;
    }
}
