//
//  KIMUserRegisterRequest.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/26.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMRequest.h"
#import "KIMUser.h"

@class KIMUserRegisterRequest;
typedef void(^KIMUserRegisterRequestCompletion)(KIMUserRegisterRequest * request,NSError * error);

@interface KIMUserRegisterRequest : KIMRequest
@property(nonatomic,strong)NSString * userAccount;
@property(nonatomic,strong)NSString * userPassword;
@property(nonatomic,strong)NSString * userNickName;
@property(nonatomic,assign)KIMUserGender gender;
-(instancetype)initWithServerAddr:(NSString *const)serverAddr serverPort:(const unsigned short)serverPort userAccount:(NSString*)userAccount userPassword:(NSString*)userPassword userNickName:(NSString*)userNickName userGender:(KIMUserGender)userGender andCompletion:(KIMUserRegisterRequestCompletion)completion;
@end
