//
//  MPKitButton.m
//
//  Copyright 2019 Button, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "MPKitButton.h"

@import ButtonMerchant;

static NSString * const BTNMPKitVersion = @"2.0.0";

static NSString * const BTNReferrerTokenDefaultsKey   = @"com.usebutton.referrer";
static NSString * const BTNLinkFetchStatusDefaultsKey = @"com.usebutton.link.fetched";

NSString * const MPKitButtonAttributionResultKey = @"mParticle-Button Attribution Result";
NSString * const BTNPostInstallURLKey = @"BTNPostInstallURLKey";

NSString * const MPKitButtonErrorDomain = @"com.mparticle.kits.button";
NSString * const MPKitButtonErrorMessageKey = @"mParticle-Button Error";
NSString * const MPKitButtonIntegrationAttribution = @"com.usebutton.source_token";


#pragma mark - MPIButton

@implementation MPIButton

- (instancetype)init {
    self = [super init];
    return self;
}


- (NSString *)attributionToken {
    return ButtonMerchant.attributionToken;
}

@end


#pragma mark - MPKitButton

@interface MPKitButton ()

@property (nonatomic, strong, nonnull) MPIButton *button;
@property (nonatomic, copy)   NSString *applicationId;
@property (nonatomic, strong) NSURLSession *session;

@end


@implementation MPKitButton

@synthesize kitApi = _kitApi;

+ (NSNumber *)kitCode {
    return @1022;
}


+ (void)load {
    MPKitRegister *kitRegister = [[MPKitRegister alloc] initWithName:@"Button"
                                                           className:NSStringFromClass(self)];
    [MParticle registerExtension:kitRegister];
}


#pragma mark - MPKitInstanceProtocol methods

- (MPKitExecStatus *)didFinishLaunchingWithConfiguration:(NSDictionary *)configuration {
    MPKitExecStatus *execStatus = nil;
    _button = [[MPIButton alloc] init];
    _applicationId = [configuration[@"application_id"] copy];
    if (!_applicationId) {
        execStatus = [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode] returnCode:MPKitReturnCodeRequirementsNotMet];
        return execStatus;
    }

    [ButtonMerchant configureWithApplicationId:_applicationId];

    _configuration = configuration;
    _started       = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self checkForAttribution];
    });

    execStatus = [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode] returnCode:MPKitReturnCodeSuccess];

    return execStatus;
}


- (id)providerKitInstance {
    return [self started] ? self.button : nil;
}


- (nonnull MPKitExecStatus *)openURL:(nonnull NSURL *)url options:(nullable NSDictionary<NSString *, id> *)options {
    [ButtonMerchant trackIncomingURL:url];
    return [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode]
                                         returnCode:MPKitReturnCodeSuccess];
}


- (nonnull MPKitExecStatus *)openURL:(nonnull NSURL *)url sourceApplication:(nullable NSString *)sourceApplication annotation:(nullable id)annotation {
    [ButtonMerchant trackIncomingURL:url];
    return [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode]
                                         returnCode:MPKitReturnCodeSuccess];
}


- (nonnull MPKitExecStatus *)continueUserActivity:(nonnull NSUserActivity *)userActivity restorationHandler:(void(^ _Nonnull)(NSArray * _Nullable restorableObjects))restorationHandler {
    [ButtonMerchant trackIncomingUserActivity:userActivity];
    return [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode]
                                         returnCode:MPKitReturnCodeSuccess];
}


#pragma mark - Private Methods

- (NSError *)errorWithMessage:(NSString *)message {
    NSError *error = [NSError errorWithDomain:MPKitButtonErrorDomain code:0 userInfo:@{MPKitButtonErrorMessageKey: message}];
    return error;
}


- (void)checkForAttribution {
    [ButtonMerchant handlePostInstallURL:^(NSURL * _Nullable postInstallURL, NSError * _Nullable error) {
        if (error || !postInstallURL) {
            NSError *attributionError = [self errorWithMessage:@"No attribution information available."];
            [self->_kitApi onAttributionCompleteWithResult:nil error:attributionError];
            return;
        }
        NSDictionary *linkInfo = @{ BTNPostInstallURLKey: postInstallURL};
        MPAttributionResult *attributionResult = [[MPAttributionResult alloc] init];
        attributionResult.linkInfo = linkInfo;
        [self->_kitApi onAttributionCompleteWithResult:attributionResult error:nil];
    }];
}

@end
