#import <Foundation/Foundation.h>
#if defined(__has_include) && __has_include(<mParticle_Apple_SDK/mParticle.h>)
    #import <mParticle_Apple_SDK/mParticle.h>
    #import <mParticle_Apple_SDK/mParticle_Apple_SDK-Swift.h>
#elif defined(__has_include) && __has_include(<mParticle_Apple_SDK_NoLocation/mParticle.h>)
    #import <mParticle_Apple_SDK_NoLocation/mParticle.h>
    #import <mParticle_Apple_SDK_NoLocation/mParticle_Apple_SDK-Swift.h>
#else
    #import "mParticle.h"
    #import "mParticle_Apple_SDK-Swift.h"
#endif

extern NSString * _Nonnull const MPKitButtonErrorDomain;
extern NSString * _Nonnull const MPKitButtonErrorMessageKey;

/// A key into the linkInfo passed to the onAttributionComplete handler.
/// (Note: This key will be set to the same value as `BTNDeferredDeepLinkURLKey`.
///        We added it later to match the naming convention used by other kits.)
extern NSString * _Nonnull const MPKitButtonAttributionResultKey;

/// A key into the linkInfo passed to the onAttributionComplete handler.
extern NSString * _Nonnull const BTNPostInstallURLKey;

#pragma mark - MPIButton
@interface MPIButton : NSObject

/// Returns the Button referrer token if present (i.e. btn_ref).
@property (nonatomic, copy, readonly, nullable) NSString *attributionToken;

@end


#pragma mark - MPKitButton
@interface MPKitButton : NSObject <MPKitProtocol>

@property (nonatomic, strong, nonnull) NSDictionary *configuration;
@property (nonatomic, unsafe_unretained, readonly) BOOL started;

@end
