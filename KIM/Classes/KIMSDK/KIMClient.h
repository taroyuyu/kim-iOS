//
//  KIMClient.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/26.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMUser.h"
#import "KIMOnlineModule.h"
#import "KIMRosterModule.h"
#import "KIMChatGroupModule.h"
#import "KIMChatModule.h"
#import "KIMVideoChatModule.h"
//KIMClient的通知会在主队列发送
extern NSString * const KIMClientStateChangedNotificationName;

@class KIMClient;
typedef void(^KIMClientSignInCompletionCallback)(KIMClient * imClient,NSError * error);

typedef NS_ENUM(NSUInteger,KIMClientLoginFailedType)
{
    KIMClientLoginFailedType_ParameterError,//参数错误
    KIMClientLoginFailedType_DoingLogingAction,//正在执行登陆操作
    KIMClientLoginFailedType_Canceled,
    KIMClientLoginFailedType_Logined,//已经登陆
    KIMClientLoginFailedType_NetworkError,//网络异常
    KIMClientLoginFailedType_ServerInternalError,//服务器内部错误
    KIMClientLoginFailedType_WrongAccountOrPassword,//用户名或者密码错误
};

typedef NS_ENUM(NSUInteger,KIMClientState)
{
    KIMClientState_Offline,//离线
    KIMClientState_RetrievingNodeServer,//正在获取服务节点
    KIMClientState_Loging,//正在登陆服务节点
    KIMClientState_Logined,//已登陆
    KIMClientState_ReLoging,//正在重连
};

@interface KIMClient : NSObject
@property(nonatomic,readonly)KIMUser * currentUser;
@property(nonatomic,readonly)KIMClientState state;
@property(nonatomic,readonly)KIMOnlineModule * onlineStateModule;
@property(nonatomic,readonly)KIMRosterModule * rosterModule;
@property(nonatomic,readonly)KIMChatModule * chatModule;
@property(nonatomic,readonly)KIMVideoChatModule * videoChatModule;
@property(nonatomic,readonly)KIMChatGroupModule * chatGroupModule;
-(instancetype)initWithPresidentAddr:(NSString*)presidentAddr presidentPort:(unsigned short)presidentPort andIceServers:(NSArray<RTCIceServer*>*)iceServers;
-(void)signInWithUserAccount:(NSString*)userAccount userPassword:(NSString*)userPassword longitude:(float)longitude latitude:(float)latitude andCompletion:(KIMClientSignInCompletionCallback)completion;
-(void)signOut;
-(void)signUpWithNodeServerAddr:(NSString*)nodeServerAddr nodeServerPort:(unsigned short)nodeServerPort userAccount:(NSString*)userAccount userPassword:(NSString*)userPassword userNickName:(NSString*)userNickName userGender:(KIMUserGender)userGender andCompletion:(void(^)(KIMClient * imClient,NSError * error))completion;
@end
