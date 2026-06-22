#import <Foundation/Foundation.h>

/// Executes block and catches any ObjC NSException.
/// Returns nil on success, or the caught exception on failure.
NSException * _Nullable catchObjCException(NS_NOESCAPE void (^ _Nonnull block)(void));
