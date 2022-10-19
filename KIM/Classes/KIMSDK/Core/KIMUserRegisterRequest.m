//
//  KIMUserRegisterRequest.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/26.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMUserRegisterRequest.h"
#import "KakaImmessage.pbobjc.h"
#import "KIMRequest+Internal.h"
@interface KIMUserRegisterRequest()
@property(nonatomic,strong)KIMUserRegisterRequestCompletion completionCallback;
@end
@implementation KIMUserRegisterRequest
-(instancetype)initWithServerAddr:(NSString *const)serverAddr serverPort:(const unsigned short)serverPort userAccount:(NSString*)userAccount userPassword:(NSString*)userPassword userNickName:(NSString*)userNickName userGender:(KIMUserGender)userGender andCompletion:(KIMUserRegisterRequestCompletion)completion
{
    if (!([serverAddr length] && [userAccount length] && [userPassword length])) {
        return nil;
    }
    self = [super initWithServerAddr:serverAddr serverPort:serverPort];
    
    if (self) {
        self.userAccount = userAccount;
        self.userPassword = userPassword;
        self.userNickName = userNickName;
        self.gender = userGender;
        self.completionCallback = completion;
    }
    
    return self;
}
-(void)failedWithError:(KIMRequestFailedType)failedType
{
    //在主队列中中调用回调函数
    if (self.completionCallback) {
        __weak KIMUserRegisterRequest * weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.completionCallback(weakSelf, [NSError errorWithDomain:@"KIMUserRegisterRequest" code:failedType userInfo:nil]);
        });
    }
}
-(GPBMessage*)requestMessage
{
    KIMProtoRegisterMessage * message = [[KIMProtoRegisterMessage alloc] init];
    message.userAccount = self.userAccount;
    message.userPassword = self.userPassword;
    message.userNickName = self.userNickName;
    KIMProtoRegisterMessage_UserSex sex = KIMProtoRegisterMessage_UserSex_Unkown;
    switch (self.gender) {
        case KIMUserGender_Male:
            sex = KIMProtoRegisterMessage_UserSex_Male;
            break;
        case KIMUserGender_Female:
            sex = KIMProtoRegisterMessage_UserSex_Female;
            break;
        case KIMUserGender_Unknown:
        default:
            sex = KIMProtoRegisterMessage_UserSex_Unkown;
            break;
    }
    [message setSex:sex];
    return message;
}
-(void)handleResponse:(GPBMessage*)message
{
    if (!self.completionCallback) {
        return;
    }
    if (![message.descriptor.fullName isEqualToString:KIMProtoResponseRegisterMessage.descriptor.fullName]) {
        self.completionCallback(self,[NSError errorWithDomain:NSStringFromClass(self.class) code:-2 userInfo:nil]);
        return;
    }
    KIMProtoResponseRegisterMessage * responseMessage = (KIMProtoResponseRegisterMessage*)message;
    
    if (KIMProtoResponseRegisterMessage_RegisterState_Success !=responseMessage.registerState) {
        if (self.completionCallback) {
            __weak KIMUserRegisterRequest * weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.completionCallback(weakSelf, [NSError errorWithDomain:@"KIMUserRegisterRequest" code:1 userInfo:@{@"failureError":[NSNumber numberWithInteger:responseMessage.failureError]}]);
            });
        }
        return;
    }
    
    if (self.completionCallback) {
        __weak KIMUserRegisterRequest * weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.completionCallback(weakSelf,nil);
        });
    }
}

@end
