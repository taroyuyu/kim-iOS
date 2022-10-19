//
//  KIMChatGroupModule.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/4/11.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMClientService.h"
#import "KIMChatGroup.h"
#import "KIMUser.h"
#import "KIMChatGroupInfo.h"
#import "KIMGroupJoinApplication.h"

/**
 * KIMChatGroupModule的通知将会在主线程发送
 */
extern NSString * const KIMChatGroupModuleReceivedChatGroupJoinApplicationNotificationName;
extern NSString * const KIMChatGroupModuleReceivedChatGroupJoinApplicationReplyNotificationName;
extern NSString * const KIMChatGroupModuleChatGroupListUpdatedNotificationName;
extern NSString * const KIMChatGroupModuleChatGroupInfoUpdatedNotificationName;

@class KIMChatGroupModule;

typedef void(^RetriveChatGroupMemberListFromServerSuccess)(KIMChatGroupModule * chatGroupModule,NSArray<KIMUser*> * chatGroupMemberList);
typedef NS_ENUM(NSUInteger,RetriveChatGroupMemberListFromServerFailedType)
{
    RetriveChatGroupMemberListFromServerFailedType_ModuleStoped,//模块停止工作
    RetriveChatGroupMemberListFromServerFailedType_ParameterError,//参数错误
    RetriveChatGroupMemberListFromServerFailedType_ClientInteralError,//客户端内部错误
    RetriveChatGroupMemberListFromServerFailedType_NetworkError,//网络连接错误
    RetriveChatGroupMemberListFromServerFailedType_Timeout,//超时
    RetriveChatGroupMemberListFromServerFailedType_ServerInteralError//服务器内部错误
};
typedef void(^RetriveChatGroupMemberListFromServerFailed)(KIMChatGroupModule * chatGroupModule,RetriveChatGroupMemberListFromServerFailedType failedType);
typedef void(^UpdateChatGroupInfoSuccess)(KIMChatGroupModule* chatGroupModule);
typedef NS_ENUM(NSUInteger,UpdateChatGroupInfoFailedType)
{
    UpdateChatGroupInfoFailedType_ModuleStoped,//模块停止工作
    UpdateChatGroupInfoFailedType_ParameterError,//参数错误
    UpdateChatGroupInfoFailedType_ClientInteralError,//客户端内部错误
    UpdateChatGroupInfoFailedType_NetworkError,//网络连接错误
    UpdateChatGroupInfoFailedType_Timeout,//超时
    UpdateChatGroupInfoFailedType_InfomationNotMatch,
    UpdateChatGroupInfoFailedType_AuthorizationNotMath,//权限不足,
    UpdateChatGroupInfoFailedType_ServerInteralError,//服务器内部错误
};
typedef void(^UpdateChatGroupInfoFailed)(KIMChatGroupModule * chatGroupModule,UpdateChatGroupInfoFailedType failedType);
typedef void(^CreateChatGroupSuccess)(KIMChatGroupModule * chatGroupModule,KIMChatGroup * chatGroup);
typedef NS_ENUM(NSUInteger,CreateChatGroupFailedType)
{
    CreateChatGroupFailedType_ModuleStoped,//模块停止工作
    CreateChatGroupFailedType_ParameterError,//参数错误
    CreateChatGroupFailedType_ClientInteralError,//客户端内部错误
    CreateChatGroupFailedType_NetworkError,//网络连接错误
    CreateChatGroupFailedType_Timeout,//超时
    CreateChatGroupFailedType_ServerInteralError,//服务器内部错误
};
typedef void(^CreateChatGroupFailed)(KIMChatGroupModule * chatGroupModle,CreateChatGroupFailedType failedType);

typedef void(^DisbandChatGroupSuccess)(KIMChatGroupModule * chatGroupModel,KIMChatGroup * dismissedChatGroup);
typedef NS_ENUM(NSUInteger,DisbandChatGroupFailedType)
{
    DisbandChatGroupFailedType_ModuleStoped,//模块停止工作
    DisbandChatGroupFailedType_ParameterError,//参数错误
    DisbandChatGroupFailedType_ClientInteralError,//客户端内部错误
    DisbandChatGroupFailedType_NetworkError,//网络连接错误
    DisbandChatGroupFailedType_Timeout,//超时
    DisbandChatGroupFailedType_ServerInteralError,//服务器内部错误
};
typedef void(^DisbandChatGroupFailed)(KIMChatGroupModule * chatGroupModule,KIMChatGroup * chatGroup,DisbandChatGroupFailedType failedType);

typedef void(^QuitChatGroupSuccess)(KIMChatGroupModule * chatGroupModel,KIMChatGroup * chatGroup);
typedef NS_ENUM(NSUInteger,QuitChatGroupFailedType)
{
    QuitChatGroupFailedType_ModuleStoped,//模块停止工作
    QuitChatGroupFailedType_ParameterError,//参数错误
    QuitChatGroupFailedType_ClientInteralError,//客户端内部错误
    QuitChatGroupFailedType_NetworkError,//网络连接错误
    QuitChatGroupFailedType_Timeout,//超时
    QuitChatGroupFailedType_ServerInteralError,//服务器内部错误
};

typedef void(^QuitChatGroupFailed)(KIMChatGroupModule * chatGroupModule,KIMChatGroup * chatGroup,QuitChatGroupFailedType failedType);

@interface KIMChatGroupModule : NSObject<KIMClientService>
#pragma mark - 群管理
/**
 *@description 创建群
 */
-(void)createChatGroupWitGroupName:(NSString*)groupName groupDescription:(NSString*)groupDescription success:(CreateChatGroupSuccess)successCallback failure:(CreateChatGroupFailed)failedCallback;
/**
 *@description 解散群
 */
-(void)disbandChatGroup:(KIMChatGroup*)chatGroup success:(DisbandChatGroupSuccess)successCallback failure:(DisbandChatGroupFailed)failedCallback;
/**
 *@description 接受入群申请
 */
-(BOOL)acceptGroipJoinApplication:(KIMGroupJoinApplication*)groupJoinApplication;
/**
 *@description 拒绝入群申请
 */
-(BOOL)rejectGroipJoinApplication:(KIMGroupJoinApplication*)groupJoinApplication;
/**
 *@description 邀请用户入群
 */
-(BOOL)inviteUser:(KIMUser*)user toChatGroup:(KIMChatGroup*)chatGroup;
#pragma mark - 群成员基本操作
/**
 *@description 发送入群申请
 */
-(BOOL)sendChatGroupJoinApplicationToChatGroup:(KIMChatGroup*)chatGroup withIntroduction:(NSString*)introduction;
/**
 *@description 退出群
 */
-(void)quitChatGroup:(KIMChatGroup*)chatGroup success:(QuitChatGroupSuccess)successCallback failure:(QuitChatGroupFailed)failedCallback;
/**
 *@description 获取群列表
 */
-(NSMutableArray<KIMChatGroup*>*)retriveChatGroupListFromLocalCache;
/**
 *@description 获取群成员列表
 */
-(NSSet<KIMUser*>*)retriveChatGroupMemberListFromLocalCache:(KIMChatGroup*)chatGroup;
-(void)retriveChatGroupMemberListFromServer:(KIMChatGroup*)chatGroup success:(RetriveChatGroupMemberListFromServerSuccess)successCallback failure:(RetriveChatGroupMemberListFromServerFailed)failedCallback;
-(KIMChatGroupInfo*)retriveChatGroupInfoFromLocalCache:(KIMChatGroup*)chatGroup;
-(BOOL)sendChatGroupInfoSyncMessage:(KIMChatGroup*)chatGroup;
-(void)updateChatGroupInfo:(KIMChatGroupInfo*)chatGroupInfo success:(UpdateChatGroupInfoSuccess)successCallback failure:(UpdateChatGroupInfoFailed)failedCallback;
@end
