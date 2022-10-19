//
//  KIMRosterModule.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/27.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMClientService.h"
#import "KIMFriendApplication.h"
#import "KIMUserVCard.h"
/**
 * KIMRosterModule的通知将会在主线程发送
 */
extern NSString * const KIMRosterModuleReceivedFriendApplicationNotificationName;
extern NSString * const KIMRosterModuleReceivedFriendApplicationReplyNotificationName;
extern NSString * const KIMRosterModuleFriendListUpdatedNotificationName;
extern NSString * const KIMRosterModuleUserVCardUpdatedNotificationName;
@class KIMRosterModule;

typedef void(^DeleteFriendSuccess)(KIMRosterModule * rosterModule,KIMUser * deletedFriend);
typedef NS_ENUM(NSUInteger,DeleteFriendFailureType)
{
    DeleteFriendFailureType_ModuleStoped,//模块停止工作
    DeleteFriendFailureType_ParameterError,//参数错误
    DeleteFriendFailureType_ClientInteralError,//客户端内部错误
    DeleteFriendFailureType_ServerInteralError,//服务器内部错误
    DeleteFriendFailureType_NetworkError,//网络连接错误
    DeleteFriendFailureType_Timeout,//超时
    DeleteFriendFailureType_FriendRelationNotExitBefore,//好友关系事先不存在
};
typedef void(^DeleteFriendFailed)(KIMRosterModule * rosterModule,KIMUser * pendingDeleteFriend,DeleteFriendFailureType failedType);
typedef void(^UpdateCurrentUserVCardSuccess)(KIMRosterModule * rosterModule);

typedef NS_ENUM(NSUInteger,UpdateCurrentUserVCardFailedType){
    UpdateCurrentUserVCardFailedType_ModuleStoped,//模块停止工作
    UpdateCurrentUserVCardFailedType_Updating,//尚有更新操作正在执行
    UpdateCurrentUserVCardFailedType_UserUnMatch,//用户不匹配
    UpdateCurrentUserVCardFailedType_Timeout,//超时
    UpdateCurrentUserVCardFailedType_NetworkError,//网络连接错误
    UpdateCurrentUserVCardFailedType_ServerInteralError,//服务器内部错误
};
typedef void(^UpdateCurrentUserVCardFailed)(KIMRosterModule * rosterModule,UpdateCurrentUserVCardFailedType failedType);

@interface KIMRosterModule : NSObject<KIMClientService>
-(BOOL)sendFriendApplicationToUser:(KIMUser*)targetUser withIntroduction:(NSString*)introduction;
-(BOOL)acceptFriendApplication:(KIMFriendApplication*)friendApplication;
-(BOOL)rejectFriendApplication:(KIMFriendApplication*)friendApplication;
-(NSArray<KIMFriendApplication*>*)fetchPendingFriendApplications;
-(NSArray<KIMFriendApplication*>*)fetchAllFriendApplications;
-(void)deleteFriend:(KIMUser*)pendingDeleteFriend success:(DeleteFriendSuccess)successCallback failure:(DeleteFriendFailed)failedCallback;
-(NSSet<KIMUser*>*)retriveFriendListFromLocalCache;
-(KIMUserVCard*)retriveUserVCardFromLocalCache:(KIMUser*)targetUser;
-(KIMUserVCard*)retriveCurrentUserVCardFromLocalCache;
-(BOOL)sendUserVCardSyncMessage:(KIMUser*)user;
-(void)updateCurrentUserVCard:(KIMUserVCard*)userVCard success:(UpdateCurrentUserVCardSuccess)successCallback failure:(UpdateCurrentUserVCardFailed)failedCallback;
@end


