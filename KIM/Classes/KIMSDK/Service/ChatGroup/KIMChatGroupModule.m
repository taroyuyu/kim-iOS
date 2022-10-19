//
//  KIMChatGroupModule.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/4/11.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMChatGroupModule.h"
#import "KakaImmessage.pbobjc.h"
#import "KIMClient+Service.h"
#import <CoreData/CoreData.h>
#import <sys/time.h>
#import "KIMDB.h"
#import "KIMDBGroup+CoreDataProperties.h"
#import "KIMDBGroupListItem+CoreDataProperties.h"
#import "KIMDBGroupMemberItem+CoreDataProperties.h"
#import "KIMDBGroupJoinApplication+CoreDataProperties.h"
#import "KIMDBGroupChatMessage+CoreDataProperties.h"
#import "KIMGroupCreateRequest.h"
#import "KIMGroupDisbandRequest.h"
#import "KIMGroupQuitRequest.h"
#import "KIMGroupMemberListRequest.h"
#import "KIMGroupInfoUpdateRequest.h"

NSString * const KIMChatGroupModuleReceivedChatGroupJoinApplicationNotificationName = @"KIMChatGroupModuleReceivedChatGroupJoinApplicationNotification";
NSString * const KIMChatGroupModuleReceivedChatGroupJoinApplicationReplyNotificationName = @"KIMChatGroupModuleReceivedChatGroupJoinApplicationReplyNotification";
NSString * const KIMChatGroupModuleChatGroupListUpdatedNotificationName = @"KIMChatGroupModuleChatGroupListUpdatedNotification";
NSString * const KIMChatGroupModuleChatGroupInfoUpdatedNotificationName = @"KIMChatGroupModuleChatGroupInfoUpdatedNotification";

typedef NS_ENUM(NSUInteger,KIMChatGroupModuleState)
{
    KIMChatGroupModuleState_Stop,//停止运作
    KIMChatGroupModuleState_Runing,//正在运作
};

@interface KIMChatGroupModule()
@property(nonatomic,strong)NSLock * moduleStateLock;
@property(nonatomic,assign)KIMChatGroupModuleState moduleState;
@property(nonatomic,weak)KIMClient * imClient;
@property(nonatomic,strong)NSSet<NSString*>* messageTypes;
@property(nonatomic,strong)NSDateFormatter *dateFormatter;
#pragma mark - 数据存储相关
@property(nonatomic,strong)NSManagedObjectModel * kimDBModel;
@property(nonatomic,strong)NSPersistentStoreCoordinator *kimpDBPersistentStoreCoordinator;
@property(nonatomic,strong)NSManagedObjectContext *kimDBContext;
#pragma mark - 用户相关
@property(nonatomic,strong)KIMUser * currentUser;
@property(nonatomic,strong)NSMutableDictionary<NSString*,NSObject*> * pendingRequestSet;
@end
@implementation KIMChatGroupModule
-(instancetype)init
{
    self = [super init];
    if (self) {
        self.moduleStateLock = [[NSLock alloc] init];
        self.moduleState = KIMChatGroupModuleState_Stop;
        NSMutableSet<NSString*> * messageTypeSet = [[NSMutableSet<NSString*> alloc] init];
        [messageTypeSet addObject:[[KIMProtoChatGroupCreateResponse descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoChatGroupDisbandResponse descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoChatGroupJoinResponse descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoChatGroupQuitResponse descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoUpdateChatGroupInfoResponse descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoFetchChatGroupInfoResponse descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoFetchChatGroupMemberListResponse descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoFetchChatGroupListResponse descriptor]fullName]];
        self.messageTypes = [messageTypeSet copy];
        self.dateFormatter = [[NSDateFormatter alloc] init];
        self.dateFormatter.dateFormat = @"YYYY-MM-dd HH:mm:ss";
        self.dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
        
        //数据存储相关
        self.kimDBModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"KIM" withExtension:@"momd"]];
        self.kimpDBPersistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self kimDBModel]];
        
        NSString * dbFileNameAbsolutePath = [NSString stringWithFormat:@"%@/%@",[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) firstObject],KIMDBFileName];
        NSError *error;
        [self.kimpDBPersistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL fileURLWithPath:dbFileNameAbsolutePath] options:nil error:&error];
        self.kimDBContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        
        [self.kimDBContext setPersistentStoreCoordinator:self.kimpDBPersistentStoreCoordinator];
        
        //用户相关
        self.pendingRequestSet = [NSMutableDictionary<NSString*,NSObject*> dictionary];
        
        //监听通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    }
    return self;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - KIMSession+Service
-(void)setIMClient:(KIMClient*)imClient
{
    self.imClient = imClient;
}
-(NSSet<NSString*>*)messageTypeSet
{
    return self.messageTypes;
}
-(void)handleMessage:(GPBMessage *)message
{
    NSString * const messageType = [[message descriptor] fullName];
    if(![self->_messageTypes containsObject:messageType]){
        return;
    }
    
    if ([messageType isEqualToString: [[KIMProtoChatGroupCreateResponse descriptor] fullName]]) {
        [self handleChatGroupCreateResponse:(KIMProtoChatGroupCreateResponse*)message];
    }else if ([messageType isEqualToString: [[KIMProtoChatGroupDisbandResponse descriptor] fullName]]) {
        [self handleChatGroupDisbandResponse:(KIMProtoChatGroupDisbandResponse*)message];
    }else if([messageType isEqualToString: [[KIMProtoChatGroupJoinRequest descriptor]fullName]]){
        [self handleChatGroupJoinRequest:(KIMProtoChatGroupJoinRequest *)message];
    }else if ([messageType isEqualToString: [[KIMProtoChatGroupJoinResponse descriptor] fullName]]) {
        [self handleChatGroupJoinResponse:(KIMProtoChatGroupJoinResponse*)message];
    }else if ([messageType isEqualToString: [[KIMProtoChatGroupQuitResponse descriptor] fullName]]) {
        [self handleChatGroupQuitResponse:(KIMProtoChatGroupQuitResponse*)message];
    }else if ([messageType isEqualToString: [[KIMProtoUpdateChatGroupInfoResponse descriptor] fullName]]) {
        [self handleUpdateChatGroupInfoResponse:(KIMProtoUpdateChatGroupInfoResponse*)message];
    }else if ([messageType isEqualToString: [[KIMProtoFetchChatGroupInfoResponse descriptor] fullName]]) {
        [self handleFetchChatGroupInfoResponse:(KIMProtoFetchChatGroupInfoResponse*)message];
    }else if ([messageType isEqualToString: [[KIMProtoFetchChatGroupMemberListResponse descriptor] fullName]]) {
        [self handleFetchChatGroupMemberListResponse:(KIMProtoFetchChatGroupMemberListResponse*)message];
    }else if ([messageType isEqualToString: [[KIMProtoFetchChatGroupListResponse descriptor] fullName]]) {
        [self handleFetchChatGroupListResponse:(KIMProtoFetchChatGroupListResponse*)message];
    }
}

#pragma mark - 消息签名
-(NSString*)nextMessageIdentifier
{
    //1.获取设备标识符
    NSString * deviceIdentifier = [self.imClient currentDeviceIdentifier];
    //2.获取当前时间，以毫秒为单位
    struct timeval tv;
    gettimeofday(&tv, 0);
    uint64_t timestamp = (uint64_t) tv.tv_sec * 1000 + (uint64_t) tv.tv_usec / 1000;
    return [NSString stringWithFormat:@"%@ - %llu",deviceIdentifier,timestamp];
}

-(int64_t)nextApplicationId
{
    //1.从数据库中获取下一条消息可用的消息Id
    NSFetchRequest *fetchRequest = [KIMDBGroupJoinApplication fetchRequest];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND applicantionId < 0",self.currentUser.account];
    [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"applicantionId" ascending:NO]]];
    [fetchRequest setFetchLimit:1];
    NSArray<KIMDBGroupJoinApplication *> * applicationSet = [[self kimDBContext] executeFetchRequest:fetchRequest error:nil];
    
    if ([applicationSet count]) {
        int64_t applicationId = [[applicationSet firstObject] applicantionId];
        if (applicationId < 0) {
            return applicationId + 1;
        }else{
            return INT64_MIN;
        }
    }else{
        return INT64_MIN;
    }
    return 0;
}

#pragma mark - 创建群

-(void)createChatGroupWitGroupName:(NSString*)groupName groupDescription:(NSString*)groupDescription success:(CreateChatGroupSuccess)successCallback failure:(CreateChatGroupFailed)failedCallback
{
    if (!groupName.length && groupDescription) {
        if (failedCallback) {
            failedCallback(self,CreateChatGroupFailedType_ParameterError);
        }
        return;
    }
    [self.moduleStateLock lock];
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        if (failedCallback) {
            failedCallback(self,CreateChatGroupFailedType_ModuleStoped);
        }
        return;
    }
    
    NSString * messageIdentifier = [self nextMessageIdentifier];
    
    //1.创建回调
    __weak KIMChatGroupModule * weakSelf = self;
    KIMGroupCreateRequest * chatCreateRequest = [[KIMGroupCreateRequest alloc] initWithGroupName:groupName groupDescription:groupDescription completion:^(KIMGroupCreateRequest *request,NSString * groupId,KIMGroupCreateRequestState state) {
        
        switch (state) {
            case KIMGroupCreateRequestState_Success:
            {
                if (successCallback) {
                    successCallback(weakSelf,[[KIMChatGroup alloc] initWithGroupId:groupId]);
                }
            }
                break;
            case KIMGroupCreateRequestState_Timeout:
            {
                if (failedCallback) {
                    failedCallback(weakSelf,CreateChatGroupFailedType_Timeout);
                }
            }
                break;
            case KIMGroupCreateRequestState_ServerInternalError:
            {
                if (failedCallback) {
                    failedCallback(weakSelf,CreateChatGroupFailedType_ServerInteralError);
                }
            }
                break;
            default:
                break;
        }
        
    } andCallbackQueue:NSOperationQueue.currentQueue];
    
    [self.pendingRequestSet setObject:chatCreateRequest forKey:messageIdentifier];
    
    //2.发送ChatGroupCreateRequest消息
    KIMProtoChatGroupCreateRequest * chatGroupCreateRequestMessage = [[KIMProtoChatGroupCreateRequest alloc] init];
    chatGroupCreateRequestMessage.groupName = groupName;
    chatGroupCreateRequestMessage.groupDescrption = groupDescription;
    chatGroupCreateRequestMessage.sign = messageIdentifier;
    
    if ([self.imClient sendMessage:chatGroupCreateRequestMessage]) {
        [self.moduleStateLock unlock];
        
        //启动定时器
        __weak KIMChatGroupModule * weakSelf = self;
        NSTimer * timeoutTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:4] interval:0 repeats:NO block:^(NSTimer * _Nonnull timer) {
            //1.判断此请求是否处理完毕
            KIMGroupCreateRequest * request = (KIMGroupCreateRequest*)[weakSelf.pendingRequestSet objectForKey:messageIdentifier];
            [weakSelf.pendingRequestSet removeObjectForKey:messageIdentifier];
            if (!request) {//请求处理完毕
                [timer invalidate];
                return;
            }
            
            if ([request.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                request.completion(request,nil,KIMGroupCreateRequestState_Timeout);
            }else{
                [request.callbackQueue addOperationWithBlock:^{
                    request.completion(request,nil,KIMGroupCreateRequestState_Timeout);
                }];
            }
        }];
        [[NSRunLoop mainRunLoop] addTimer:timeoutTimer forMode:NSDefaultRunLoopMode];
        
    }else{
        [self.pendingRequestSet removeObjectForKey:messageIdentifier];
        [self.moduleStateLock unlock];
        if (failedCallback) {
            failedCallback(self,CreateChatGroupFailedType_NetworkError);
        }
    }
}
-(void)handleChatGroupCreateResponse:(KIMProtoChatGroupCreateResponse*)message
{
    [self.moduleStateLock lock];
    
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    
    if ([message.sign hasPrefix:self.imClient.currentDeviceIdentifier]) {//由当前设备发出
        KIMGroupCreateRequest * request = (KIMGroupCreateRequest*)[self.pendingRequestSet objectForKey:message.sign];
        [self.pendingRequestSet removeObjectForKey:message.sign];
        
        switch (message.result) {
            case KIMProtoChatGroupCreateResponse_ChatGroupCreateResponseResult_Success:
            {
                //将群信息同步到数据库
                KIMDBGroup * groupModel = [NSEntityDescription insertNewObjectForEntityForName:KIMDBGroupEntityName inManagedObjectContext:[self kimDBContext]];
                
                [groupModel setGroupId:message.groupId];
                [groupModel setGroupName:request.groupName];
                [groupModel setGroupDescription:request.groupDescription];
                [groupModel setGroupMaster:self.currentUser.account];
                //将此群添加到当前用户的群列表中
                KIMDBGroupListItem * groupListItem = [NSEntityDescription insertNewObjectForEntityForName:KIMDBGroupListItemEntityName inManagedObjectContext:self.kimDBContext];
                groupListItem.userDomain = self.currentUser.account;
                groupListItem.groupId = groupModel.groupId;
                [self.moduleStateLock unlock];
                //2.执行回调
                if ([request.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                    request.completion(request,nil,KIMGroupCreateRequestState_Success);
                }else{
                    [request.callbackQueue addOperationWithBlock:^{
                        request.completion(request,nil,KIMGroupCreateRequestState_Success);
                    }];
                }
            }
                break;
            case KIMProtoChatGroupCreateResponse_ChatGroupCreateResponseResult_Failed:
            default:
            {
                [self.moduleStateLock unlock];
                if ([request.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                    request.completion(request,nil,KIMGroupCreateRequestState_ServerInternalError);
                }else{
                    [request.callbackQueue addOperationWithBlock:^{
                        request.completion(request,nil,KIMGroupCreateRequestState_ServerInternalError);
                    }];
                }
            }
                break;
        }
        
        
    }else{//不是由本设备发出的
        [self.moduleStateLock unlock];
    }
}

#pragma mark - 解散群
-(void)disbandChatGroup:(KIMChatGroup*)chatGroup success:(DisbandChatGroupSuccess)successCallback failure:(DisbandChatGroupFailed)failedCallback
{
    if (!chatGroup) {
        if (failedCallback) {
            failedCallback(self,chatGroup,DisbandChatGroupFailedType_ParameterError);
        }
        return;
    }
    [self.moduleStateLock lock];
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        if (failedCallback) {
            failedCallback(self,chatGroup,DisbandChatGroupFailedType_ModuleStoped);
        }
        return;
    }
    
    NSString * messageIdentifier = [self nextMessageIdentifier];
    
    //1.创建回调
    __weak KIMChatGroupModule * weakSelf = self;
    KIMGroupDisbandRequest * groupDisbandRequest = [[KIMGroupDisbandRequest alloc] initWithChatGroup:chatGroup completion:^(KIMGroupDisbandRequest *request, KIMGroupDisbandRequestState state) {
    
        switch (state) {
            case KIMGroupDisbandRequestState_Success:
            {
                if (successCallback) {
                    successCallback(weakSelf,chatGroup);
                }
            }
                break;
            case KIMGroupDisbandRequestState_Timeout:
            {
                if (failedCallback) {
                    failedCallback(weakSelf,chatGroup,DisbandChatGroupFailedType_Timeout);
                }
            }
                break;
            case KIMGroupDisbandRequestState_ServerInternalError:
            {
                if (failedCallback) {
                    failedCallback(weakSelf,chatGroup,DisbandChatGroupFailedType_ServerInteralError);
                }
            }
                break;
            default:
                break;
        }
        
    } andCallbackQueue:NSOperationQueue.currentQueue];
    
    [self.pendingRequestSet setObject:groupDisbandRequest forKey:messageIdentifier];
    
    //发送ChatGroupDisbandRequest消息
    KIMProtoChatGroupDisbandRequest * chatGroupDisbandRequestMessage = [[KIMProtoChatGroupDisbandRequest alloc] init];
    chatGroupDisbandRequestMessage.groupId = chatGroup.groupId;
    chatGroupDisbandRequestMessage.operatorId = self.currentUser.account;
    chatGroupDisbandRequestMessage.sign = messageIdentifier;
    
    if ([self.imClient sendMessage:chatGroupDisbandRequestMessage]) {
        [self.moduleStateLock unlock];
        
        //启动定时器
        __weak KIMChatGroupModule * weakSelf = self;
        NSTimer * timeoutTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:4] interval:0 repeats:NO block:^(NSTimer * _Nonnull timer) {
            //1.判断此请求是否处理完毕
            KIMGroupDisbandRequest * request = (KIMGroupDisbandRequest*)[weakSelf.pendingRequestSet objectForKey:messageIdentifier];
            [weakSelf.pendingRequestSet removeObjectForKey:messageIdentifier];
            if (!request) {//请求处理完毕
                [timer invalidate];
                return;
            }
            
            if ([request.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                request.completion(request,KIMGroupDisbandRequestState_Timeout);
            }else{
                [request.callbackQueue addOperationWithBlock:^{
                    request.completion(request,KIMGroupDisbandRequestState_Timeout);
                }];
            }
        }];
        [[NSRunLoop mainRunLoop] addTimer:timeoutTimer forMode:NSDefaultRunLoopMode];
    }else{
        [self.pendingRequestSet removeObjectForKey:messageIdentifier];
        [self.moduleStateLock unlock];
        if (failedCallback) {
            failedCallback(self,chatGroup,DisbandChatGroupFailedType_NetworkError);
        }
    }
}

-(void)handleChatGroupDisbandResponse:(KIMProtoChatGroupDisbandResponse*)message
{
    [self.moduleStateLock lock];
    
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    
    if ([message.sign hasPrefix:self.imClient.currentDeviceIdentifier]) {//由当前设备发出
        KIMGroupDisbandRequest * request = (KIMGroupDisbandRequest*)[self.pendingRequestSet objectForKey:message.sign];
        [self.pendingRequestSet removeObjectForKey:message.sign];
        
        switch (message.result) {
            case KIMProtoChatGroupDisbandResponse_ChatGroupDisbandResponseResult_Success:
            {
                //1.将此chatGroup从所有用户的群列表中移除
                NSFetchRequest * groupListItemQuery = [KIMDBGroupListItem fetchRequest];
                [groupListItemQuery setPredicate:[NSPredicate predicateWithFormat:@"groupId == %@",message.groupId]];
                NSArray<KIMDBGroupListItem*> * groupListItemSet = [[self kimDBContext] executeFetchRequest:groupListItemQuery error:nil];
                for (KIMDBGroupListItem * groupListItemModel in groupListItemSet) {
                    [[self kimDBContext] deleteObject:groupListItemModel];
                }
                [self.moduleStateLock unlock];
                //2.执行回调
                if ([request.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                    request.completion(request,KIMGroupDisbandRequestState_Success);
                }else{
                    [request.callbackQueue addOperationWithBlock:^{
                        request.completion(request,KIMGroupDisbandRequestState_Success);
                    }];
                }
            }
                break;
            case KIMProtoChatGroupDisbandResponse_ChatGroupDisbandResponseResult_Failed:
            default:
            {
                [self.moduleStateLock unlock];
                //2.执行回调
                if ([request.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                    request.completion(request,KIMGroupDisbandRequestState_ServerInternalError);
                }else{
                    [request.callbackQueue addOperationWithBlock:^{
                        request.completion(request,KIMGroupDisbandRequestState_ServerInternalError);
                    }];
                }
            }
                break;
        }
        
    }else{//不是由本设备发出的
        [self.moduleStateLock unlock];
    }
}

#pragma mark - 加入群

-(BOOL)sendChatGroupJoinApplicationToChatGroup:(KIMChatGroup*)chatGroup withIntroduction:(NSString*)introduction
{
    if (!chatGroup) {
        return NO;
    }
    [self.moduleStateLock lock];
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return NO;
    }
    
    ino64_t applicationId = [self nextApplicationId];
    NSString * messageIdentifier = nil;
    do{
        messageIdentifier = [self nextMessageIdentifier];
    }while([self.pendingRequestSet objectForKey:messageIdentifier]);
    
    //1.保存到本地数据库
    KIMDBGroupJoinApplication * groupJoinApplication = [NSEntityDescription insertNewObjectForEntityForName:KIMDBGroupJoinApplicationEntityName inManagedObjectContext:[self kimDBContext]];
    groupJoinApplication.userDomain = self.currentUser.account;
    groupJoinApplication.applicantionId = applicationId;
    groupJoinApplication.groupId = chatGroup.groupId;
    groupJoinApplication.applicant = self.currentUser.account;
    groupJoinApplication.introduction = introduction;
    groupJoinApplication.state = KIMGroupJoinApplicationState_Pending;
    groupJoinApplication.submissionTime = [NSDate date];
    
    [self.pendingRequestSet setObject:[NSNumber numberWithLongLong:applicationId] forKey:messageIdentifier];
    
    //2.发送请求
    KIMProtoChatGroupJoinRequest * joinRequest = [[KIMProtoChatGroupJoinRequest alloc] init];
    joinRequest.groupId = chatGroup.groupId;
    joinRequest.userAccount = self.currentUser.account;
    joinRequest.introduction = introduction;
    joinRequest.sign = messageIdentifier;
    
    if (![self.imClient sendMessage:joinRequest]) {
        //删除此记录
        [self.kimDBContext deleteObject:groupJoinApplication];
        [self.moduleStateLock unlock];
        return NO;
    }else{
        [self.moduleStateLock unlock];
        return YES;
    }
}

-(void)handleChatGroupJoinRequest:(KIMProtoChatGroupJoinRequest*)message
{
    [self.moduleStateLock lock];
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    
    NSNumber * applicationIdNumber = (NSNumber*)[self.pendingRequestSet objectForKey:message.sign];
    if (nil != applicationIdNumber) {
        //同步到数据库
        NSFetchRequest *fetchRequest = [KIMDBGroupJoinApplication fetchRequest];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND applicantionId == %lld",self.currentUser.account,applicationIdNumber.longLongValue];
        [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"applicantionId" ascending:NO]]];
        [fetchRequest setFetchLimit:1];
        NSArray<KIMDBGroupJoinApplication *> * applicationSet = [[self kimDBContext] executeFetchRequest:fetchRequest error:nil];
        applicationSet.firstObject.applicantionId = message.applicantId;
        [self.moduleStateLock unlock];
    }else{
        //1.将消息保存到本地数据库
        KIMDBGroupJoinApplication * groupJoinApplication = [NSEntityDescription insertNewObjectForEntityForName:KIMDBGroupJoinApplicationEntityName inManagedObjectContext:[self kimDBContext]];
        groupJoinApplication.userDomain = self.currentUser.account;
        groupJoinApplication.applicantionId = message.applicantId;
        groupJoinApplication.groupId = message.groupId;
        groupJoinApplication.applicant = message.userAccount;
        groupJoinApplication.introduction = message.introduction;
        groupJoinApplication.state = KIMGroupJoinApplicationState_Pending;
        groupJoinApplication.submissionTime = [self.dateFormatter dateFromString:message.submissionTime];
        
        [self.moduleStateLock unlock];
        
        NSString * introduction = message.introduction == nil ? @"" : message.introduction;
        //2.通知用户
        NSNotification * notification = [[NSNotification alloc] initWithName:KIMChatGroupModuleReceivedChatGroupJoinApplicationNotificationName object:nil userInfo:@{@"applicant":groupJoinApplication.applicant,@"groupId":groupJoinApplication.groupId ,@"introduction":introduction,@"applicationId":[NSNumber numberWithUnsignedLongLong:message.applicantId]}];
        if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        }else{
            [NSOperationQueue.mainQueue addOperationWithBlock:^{
                [[NSNotificationCenter defaultCenter] postNotification:notification];
            }];
        }
    }
}

-(BOOL)acceptGroipJoinApplication:(KIMGroupJoinApplication*)groupJoinApplication
{
    if (!groupJoinApplication) {
        return NO;
    }
    [self.moduleStateLock lock];
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return NO;
    }
    
    //1.查询此入群申请记录是否存在
    NSFetchRequest *applicationFetchRequest = [KIMDBGroupJoinApplication fetchRequest];
    applicationFetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND applicantionId == %lld",self.currentUser.account,groupJoinApplication.applicantId];
    [applicationFetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"applicantionId" ascending:NO]]];
    [applicationFetchRequest setFetchLimit:1];
    NSArray<KIMDBGroupJoinApplication *> * applicationSet = [[self kimDBContext] executeFetchRequest:applicationFetchRequest error:nil];
    
    if (![applicationSet firstObject] || [applicationSet.firstObject state] !=KIMGroupJoinApplicationState_Pending) {//此入群申请记录不存在或此入群申请已经被处理
        [self.moduleStateLock unlock];
        return NO;
    }
    
    //2.验证身份
    NSFetchRequest * groupInfoFetchRequest = [KIMDBGroup fetchRequest];
    groupInfoFetchRequest.predicate = [NSPredicate predicateWithFormat:@"groupId == %lld",groupJoinApplication.chatGroup.groupId];
    [groupInfoFetchRequest setFetchLimit:1];
    NSArray<KIMDBGroup *> * groupSet = [[self kimDBContext] executeFetchRequest:groupInfoFetchRequest error:nil];
    
    if (![groupSet.firstObject.groupMaster isEqualToString:self.currentUser.account]) {
        [self.moduleStateLock unlock];
        return NO;
    }
    
    //3.修改此入群申请的状态
    [[applicationSet firstObject] setState:KIMGroupJoinApplicationState_Allowm];
    
    //4.发送答复
    
    KIMProtoChatGroupJoinResponse * chatGroupJoinResponseMessage = [[KIMProtoChatGroupJoinResponse alloc] init];
    chatGroupJoinResponseMessage.groupId = groupJoinApplication.chatGroup.groupId;
    chatGroupJoinResponseMessage.userAccount = groupJoinApplication.applicant.account;
    chatGroupJoinResponseMessage.result = KIMProtoChatGroupJoinResponse_ChatGroupJoinResponseResult_Allow;
    chatGroupJoinResponseMessage.operatorId = self.currentUser.account;
    chatGroupJoinResponseMessage.applicantId = groupJoinApplication.applicantId;
    
    if([self.imClient sendMessage:chatGroupJoinResponseMessage]){
        [self.moduleStateLock unlock];
        return YES;
    }else{//发送失败
        //将此入群申请的状态还原
        [[applicationSet firstObject] setState:KIMGroupJoinApplicationState_Pending];
        [self.moduleStateLock unlock];
        return NO;
    }
}

-(BOOL)rejectGroipJoinApplication:(KIMGroupJoinApplication*)groupJoinApplication
{
    if (!groupJoinApplication) {
        return NO;
    }
    [self.moduleStateLock lock];
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return NO;
    }
    
    //1.查询此入群申请记录是否存在
    NSFetchRequest *applicationFetchRequest = [KIMDBGroupJoinApplication fetchRequest];
    applicationFetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND applicantionId == %lld",self.currentUser.account,groupJoinApplication.applicantId];
    [applicationFetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"applicantionId" ascending:NO]]];
    [applicationFetchRequest setFetchLimit:1];
    NSArray<KIMDBGroupJoinApplication *> * applicationSet = [[self kimDBContext] executeFetchRequest:applicationFetchRequest error:nil];
    
    if (![applicationSet firstObject] || [applicationSet.firstObject state] !=KIMGroupJoinApplicationState_Pending) {//此入群申请记录不存在或此入群申请已经被处理
        [self.moduleStateLock unlock];
        return NO;
    }
    
    //2.验证身份
    NSFetchRequest * groupInfoFetchRequest = [KIMDBGroup fetchRequest];
    groupInfoFetchRequest.predicate = [NSPredicate predicateWithFormat:@"groupId == %lld",groupJoinApplication.chatGroup.groupId];
    [groupInfoFetchRequest setFetchLimit:1];
    NSArray<KIMDBGroup *> * groupSet = [[self kimDBContext] executeFetchRequest:groupInfoFetchRequest error:nil];
    
    if (![groupSet.firstObject.groupMaster isEqualToString:self.currentUser.account]) {
        [self.moduleStateLock unlock];
        return NO;
    }
    
    //3.修改此入群申请的状态
    [[applicationSet firstObject] setState:KIMGroupJoinApplicationState_Reject];
    
    //4.发送答复
    
    KIMProtoChatGroupJoinResponse * chatGroupJoinResponseMessage = [[KIMProtoChatGroupJoinResponse alloc] init];
    chatGroupJoinResponseMessage.groupId = groupJoinApplication.chatGroup.groupId;
    chatGroupJoinResponseMessage.userAccount = groupJoinApplication.applicant.account;
    chatGroupJoinResponseMessage.result = KIMProtoChatGroupJoinResponse_ChatGroupJoinResponseResult_Reject;
    chatGroupJoinResponseMessage.operatorId = self.currentUser.account;
    chatGroupJoinResponseMessage.applicantId = groupJoinApplication.applicantId;
    
    if([self.imClient sendMessage:chatGroupJoinResponseMessage]){
        [self.moduleStateLock unlock];
        return YES;
    }else{//发送失败
        //将此入群申请的状态还原
        [[applicationSet firstObject] setState:KIMGroupJoinApplicationState_Pending];
        [self.moduleStateLock unlock];
        return NO;
    }
}

-(void)handleChatGroupJoinResponse:(KIMProtoChatGroupJoinResponse*)message
{
    [self.moduleStateLock lock];
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    
    //1查询此入群申请是否存在
    NSFetchRequest *applicationFetchRequest = [KIMDBGroupJoinApplication fetchRequest];
    applicationFetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND applicantionId == %lld",self.currentUser.account,message.applicantId];
    [applicationFetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"applicantionId" ascending:NO]]];
    [applicationFetchRequest setFetchLimit:1];
    NSArray<KIMDBGroupJoinApplication *> * applicationSet = [[self kimDBContext] executeFetchRequest:applicationFetchRequest error:nil];
    
    if ([applicationSet firstObject]) {//此好友申请记录存在则直接更新
        switch ([message result]) {
            case KIMProtoChatGroupJoinResponse_ChatGroupJoinResponseResult_Allow:
            {
                applicationSet.firstObject.state = KIMGroupJoinApplicationState_Allowm;
            }
                break;
            case KIMProtoChatGroupJoinResponse_ChatGroupJoinResponseResult_Reject:
            {
                applicationSet.firstObject.state = KIMGroupJoinApplicationState_Reject;
            }
                break;
            default:
                break;
        }
    }else{//此好友申请记录不存在
        KIMDBGroupJoinApplication * groupJoinApplication = [NSEntityDescription insertNewObjectForEntityForName:KIMDBGroupJoinApplicationEntityName inManagedObjectContext:[self kimDBContext]];
        groupJoinApplication.userDomain = self.currentUser.account;
        groupJoinApplication.applicantionId = message.applicantId;
        groupJoinApplication.groupId = message.groupId;
        groupJoinApplication.applicant = message.userAccount;
        
        switch ([message result]) {
            case KIMProtoChatGroupJoinResponse_ChatGroupJoinResponseResult_Allow:
            {
                groupJoinApplication.state = KIMGroupJoinApplicationState_Allowm;
            }
                break;
            case KIMProtoChatGroupJoinResponse_ChatGroupJoinResponseResult_Reject:
            {
                groupJoinApplication.state = KIMGroupJoinApplicationState_Reject;
            }
                break;
            default:
                break;
        }
    }
    
    [self.moduleStateLock unlock];
    
    NSNotification * notification = nil;
    if (message.result == KIMProtoChatGroupJoinResponse_ChatGroupJoinResponseResult_Allow) {
        NSString * reply = @"Allow";
        notification = [[NSNotification alloc] initWithName:KIMChatGroupModuleReceivedChatGroupJoinApplicationReplyNotificationName object:nil userInfo:@{@"applicatn":message.userAccount,@"groupId":message.groupId,@"reply":reply,@"applicationId":[NSNumber numberWithUnsignedLongLong:message.applicantId]}];
    }else if(message.result == KIMProtoChatGroupJoinResponse_ChatGroupJoinResponseResult_Reject){
        NSString * reply = @"Reject";
        notification = [[NSNotification alloc] initWithName:KIMChatGroupModuleReceivedChatGroupJoinApplicationReplyNotificationName object:nil userInfo:@{@"applicatn":message.userAccount,@"groupId":message.groupId,@"reply":reply,@"applicationId":[NSNumber numberWithUnsignedLongLong:message.applicantId]}];
    }else if(message.result == KIMProtoChatGroupJoinResponse_ChatGroupJoinResponseResult_ServerInternalError){
        NSLog(@"%s message.result = KIMProtoChatGroupJoinResponse_ChatGroupJoinResponseResult_ServerInternalError",__FUNCTION__);
    }else if(message.result == KIMProtoChatGroupJoinResponse_ChatGroupJoinResponseResult_InfomationNotMatch){
        NSLog(@"%s message.result = KIMProtoChatGroupJoinResponse_ChatGroupJoinResponseResult_InfomationNotMatch",__FUNCTION__);
        
    }else if(message.result == KIMProtoChatGroupJoinResponse_ChatGroupJoinResponseResult_AuthorizationNotMath){
        NSLog(@"%s message.result = KIMProtoChatGroupJoinResponse_ChatGroupJoinResponseResult_AuthorizationNotMath",__FUNCTION__);
    }else{
        NSLog(@"%s unknown message.result type",__FUNCTION__);
    }
    
    //2.通知用户
    if (notification) {
        if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        }else{
            [NSOperationQueue.mainQueue addOperationWithBlock:^{
                [[NSNotificationCenter defaultCenter] postNotification:notification];
            }];
        }
    }else{
        NSLog(@"%s, notification竟然为空",__FUNCTION__);
    }
}

#pragma mark - 邀请用户入群

-(BOOL)inviteUser:(KIMUser*)user toChatGroup:(KIMChatGroup*)chatGroup
{
    
    if (!chatGroup) {
        return NO;
    }
    [self.moduleStateLock lock];
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return NO;
    }
    
    NSString * introduction = [NSString stringWithFormat:@"invited by %@",self.currentUser.account];
    
    ino64_t applicationId = [self nextApplicationId];
    NSLog(@"applicationId = %lld",applicationId);
    NSString * messageIdentifier = nil;
    do{
        messageIdentifier = [self nextMessageIdentifier];
    }while([self.pendingRequestSet objectForKey:messageIdentifier]);
    
    //1.保存到本地数据库
    KIMDBGroupJoinApplication * groupJoinApplication = [NSEntityDescription insertNewObjectForEntityForName:KIMDBGroupJoinApplicationEntityName inManagedObjectContext:[self kimDBContext]];
    groupJoinApplication.userDomain = self.currentUser.account;
    groupJoinApplication.applicantionId = applicationId;
    groupJoinApplication.groupId = chatGroup.groupId;
    groupJoinApplication.applicant = user.account;
    groupJoinApplication.introduction = introduction;
    groupJoinApplication.state = KIMGroupJoinApplicationState_Pending;
    groupJoinApplication.submissionTime = [NSDate date];
    
    [self.pendingRequestSet setObject:[NSNumber numberWithLongLong:applicationId] forKey:messageIdentifier];
    
    //2.发送请求
    KIMProtoChatGroupJoinRequest * joinRequest = [[KIMProtoChatGroupJoinRequest alloc] init];
    joinRequest.groupId = chatGroup.groupId;
    joinRequest.userAccount = user.account;
    joinRequest.operatorId = self.currentUser.account;
    joinRequest.introduction = introduction;
    joinRequest.sign = messageIdentifier;
    
    if (![self.imClient sendMessage:joinRequest]) {
        //删除此记录
        [self.kimDBContext deleteObject:groupJoinApplication];
        [self.moduleStateLock unlock];
        return NO;
    }else{
        [self.moduleStateLock unlock];
        return YES;
    }
}

#pragma mark - 离开群
-(void)quitChatGroup:(KIMChatGroup*)chatGroup success:(QuitChatGroupSuccess)successCallback failure:(QuitChatGroupFailed)failedCallback
{
    if (!chatGroup) {
        if (failedCallback) {
            failedCallback(self,chatGroup,QuitChatGroupFailedType_ParameterError);
        }
        return;
    }
    
    [self.moduleStateLock lock];
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        if (failedCallback) {
            failedCallback(self,chatGroup,QuitChatGroupFailedType_ModuleStoped);
        }
        return;
    }
    
    NSString * messageIdentifier = [self nextMessageIdentifier];
    
    //1.创建回调
    __weak KIMChatGroupModule * weakSelf = self;
    KIMGroupQuitRequest * groupQuitRequest = [[KIMGroupQuitRequest alloc] initWithChatGroup:chatGroup completion:^(KIMGroupQuitRequest *request, KIMGroupQuitRequestState state) {
        switch (state) {
            case KIMGroupQuitRequestState_Success:
            {
                if (successCallback) {
                    successCallback(weakSelf,chatGroup);
                }
            }
                break;
            case KIMGroupQuitRequestState_Timeout:
            {
                if (failedCallback) {
                    failedCallback(weakSelf,chatGroup,QuitChatGroupFailedType_Timeout);
                }
            }
                break;
            case KIMGroupQuitRequestState_ServerInternalError:
            {
                if (failedCallback) {
                    failedCallback(weakSelf,chatGroup,QuitChatGroupFailedType_ServerInteralError);
                }
            }
                break;
            default:
                break;
        }
    } andCallbackQueue:NSOperationQueue.currentQueue];
    
    [self.pendingRequestSet setObject:groupQuitRequest forKey:messageIdentifier];
    
    //2.发送ChatGroupQuitRequest消息
    KIMProtoChatGroupQuitRequest * chatGroupQuitRequestMessage = [[KIMProtoChatGroupQuitRequest alloc] init];
    chatGroupQuitRequestMessage.userAccount = self.currentUser.account;
    chatGroupQuitRequestMessage.groupId = chatGroup.groupId;
    chatGroupQuitRequestMessage.sign = messageIdentifier;
    
    if ([self.imClient sendMessage:chatGroupQuitRequestMessage]) {
        [self.moduleStateLock unlock];
        
        //启动定时器
        __weak KIMChatGroupModule * weakSelf = self;
        NSTimer * timeoutTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:4] interval:0 repeats:NO block:^(NSTimer * _Nonnull timer) {
            //1.判断此请求是否处理完毕
            KIMGroupQuitRequest * request = (KIMGroupQuitRequest*)[weakSelf.pendingRequestSet objectForKey:messageIdentifier];
            [weakSelf.pendingRequestSet removeObjectForKey:messageIdentifier];
            if (!request) {//请求处理完毕
                [timer invalidate];
                return;
            }
            
            if ([request.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                request.completion(request,KIMGroupQuitRequestState_Timeout);
            }else{
                [request.callbackQueue addOperationWithBlock:^{
                    request.completion(request,KIMGroupQuitRequestState_Timeout);
                }];
            }
        }];
        [[NSRunLoop mainRunLoop] addTimer:timeoutTimer forMode:NSDefaultRunLoopMode];
    }else{
        [self.pendingRequestSet removeObjectForKey:messageIdentifier];
        [self.moduleStateLock unlock];
        if (failedCallback) {
            failedCallback(self,chatGroup,QuitChatGroupFailedType_NetworkError);
        }
    }
}
-(void)handleChatGroupQuitResponse:(KIMProtoChatGroupQuitResponse*)message
{
    [self.moduleStateLock lock];
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    
    if ([message.sign hasPrefix:self.imClient.currentDeviceIdentifier]) {//由当前设备发出
        KIMGroupQuitRequest * request = (KIMGroupQuitRequest*)[self.pendingRequestSet objectForKey:message.sign];
        [self.pendingRequestSet removeObjectForKey:message.sign];
        
        switch (message.result) {
            case KIMProtoChatGroupQuitResponse_ChatGroupQuitResponseResult_Success:
            {
                //1.将此群从用户的群列表中移除
                NSFetchRequest * groupListItemQuery = [KIMDBGroupListItem fetchRequest];
                [groupListItemQuery setPredicate:[NSPredicate predicateWithFormat:@"userDomain == %@  AND groupId == %@",message.groupId,message.groupId]];
                NSArray<KIMDBGroupListItem*> * groupListItemSet = [[self kimDBContext] executeFetchRequest:groupListItemQuery error:nil];
                for (KIMDBGroupListItem * groupListItemModel in groupListItemSet) {
                    [[self kimDBContext] deleteObject:groupListItemModel];
                }
                
                [self.moduleStateLock unlock];
                //2.执行回调
                if ([request.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                    request.completion(request,KIMGroupQuitRequestState_Success);
                }else{
                    [request.callbackQueue addOperationWithBlock:^{
                        request.completion(request,KIMGroupQuitRequestState_Success);
                    }];
                }
            }
                break;
            case KIMProtoChatGroupQuitResponse_ChatGroupQuitResponseResult_Failed:
            {
                [self.moduleStateLock unlock];
                //2.执行回调
                if ([request.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                    request.completion(request,KIMGroupQuitRequestState_ServerInternalError);
                }else{
                    [request.callbackQueue addOperationWithBlock:^{
                        request.completion(request,KIMGroupQuitRequestState_ServerInternalError);
                    }];
                }
            }
                break;
            default:
                [self.moduleStateLock unlock];
                break;
        }
        
    }else{//不是由本设备发出的
        [self.moduleStateLock unlock];
    }
}

-(NSMutableArray<KIMChatGroup*>*)retriveChatGroupListFromLocalCache
{
    NSMutableArray<KIMChatGroup*> *chatGroupSet = [NSMutableArray<KIMChatGroup*> array];

    NSFetchRequest * groupListQuery = [KIMDBGroupListItem fetchRequest];
    [groupListQuery setPredicate:[NSPredicate predicateWithFormat:@"userDomain == %@",self.currentUser.account]];

    NSArray<NSSortDescriptor *> *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"groupId" ascending:YES]];

    groupListQuery.sortDescriptors = sortDescriptors;


    NSError * queryError = nil;
    NSArray<KIMDBGroupListItem *> *chatGroupList = [[self kimDBContext] executeFetchRequest:groupListQuery error:&queryError];
    for (KIMDBGroupListItem * groupListItem in chatGroupList) {
        KIMChatGroup * chatGroup = [[KIMChatGroup alloc] init];
        [chatGroup setGroupId:[groupListItem groupId]];
        [chatGroupSet addObject:chatGroup];
    }
    
    return [chatGroupSet copy];
}

-(void)handleFetchChatGroupListResponse:(KIMProtoFetchChatGroupListResponse*)message
{

    [self.moduleStateLock lock];
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    
    //1.删除此用户的聊天群列表
    NSFetchRequest * groupListQuery = [KIMDBGroupListItem fetchRequest];
    [groupListQuery setPredicate:[NSPredicate predicateWithFormat:@"userDomain == %@",self.currentUser.account]];

    NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:groupListQuery];
    deleteRequest.resultType = NSBatchDeleteResultTypeObjectIDs;

    NSBatchDeleteResult *deleteResult = [[self kimDBContext] executeRequest:deleteRequest error:nil];
    NSArray<NSManagedObjectID *> *deletedObjectIDs = deleteResult.result;

    NSDictionary *deletedDict = @{NSDeletedObjectsKey : deletedObjectIDs};
    [NSManagedObjectContext mergeChangesFromRemoteContextSave:deletedDict intoContexts:@[self.kimDBContext]];

    NSMutableSet<KIMChatGroup*> *chatGroupList = [NSMutableSet<KIMChatGroup*> set];
    for (KIMProtoFetchChatGroupListResponse_GroupInfo * groupInfo in [message groupArray]) {
        //2.将聊天群的信息保存到数据库
        NSFetchRequest * groupQuery = [KIMDBGroup fetchRequest];
        [groupQuery setPredicate:[NSPredicate predicateWithFormat:@"groupId == %@",[groupInfo groupId]]];
        NSArray<KIMDBGroup*> * groupList = [[self kimDBContext] executeFetchRequest:groupQuery error:nil];

        if ([groupList count]) {
            for (KIMDBGroup * groupModel in groupList) {
                [groupModel setGroupName:[groupInfo groupName]];
            }
        }else{
            KIMDBGroup * groupModel = [NSEntityDescription insertNewObjectForEntityForName:@"Group" inManagedObjectContext:[self kimDBContext]];
            [groupModel setGroupId:[groupInfo groupId]];
            [groupModel setGroupName:[groupInfo groupName]];
        }
        //3.将聊天群的信息保存到用户的聊天群列表
        KIMDBGroupListItem * groupListItemModel = [NSEntityDescription insertNewObjectForEntityForName:@"GroupListItem" inManagedObjectContext:[self kimDBContext]];
        [groupListItemModel setUserDomain:self.currentUser.account];
        [groupListItemModel setGroupId:[groupInfo groupId]];

        KIMChatGroup * chatGroup = [[KIMChatGroup alloc] init];
        [chatGroup setGroupId:[groupInfo groupId]];
        [chatGroupList addObject:chatGroup];
    }
    
    [self.moduleStateLock unlock];
    
    NSNotification * notification = [NSNotification notificationWithName:KIMChatGroupModuleChatGroupListUpdatedNotificationName object:nil];
    if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
        [[NSNotificationCenter defaultCenter] postNotification:notification];
    }else{
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        }];
    }
    
}
-(NSSet<KIMUser*>*)retriveChatGroupMemberListFromLocalCache:(KIMChatGroup*)chatGroup
{
    NSMutableSet<KIMUser*> * memberSet = [NSMutableSet<KIMUser*> set];

    NSFetchRequest * groupMemberQuery = [KIMDBGroupMemberItem fetchRequest];

    [groupMemberQuery setPredicate:[NSPredicate predicateWithFormat:@"groupId == %@",[chatGroup groupId]]];

    [groupMemberQuery setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"userAccount" ascending:YES]]];

    NSArray<KIMDBGroupMemberItem*> * groupMemberList = [[self kimDBContext] executeFetchRequest:groupMemberQuery error:nil];

    for (KIMDBGroupMemberItem * groupMemberModel  in groupMemberList) {
        KIMUser * groupMember = [[KIMUser alloc] initWithUserAccount:[groupMemberModel userAccount]];
        [memberSet addObject:groupMember];
    }

    return [memberSet copy];
}



-(void)retriveChatGroupMemberListFromServer:(KIMChatGroup*)chatGroup success:(RetriveChatGroupMemberListFromServerSuccess)successCallback failure:(RetriveChatGroupMemberListFromServerFailed)failedCallback
{
    
    if (!chatGroup) {
        if (failedCallback) {
            failedCallback(self,RetriveChatGroupMemberListFromServerFailedType_ParameterError);
        }
        return;
    }
    
    [self.moduleStateLock lock];
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        if (failedCallback) {
            failedCallback(self,RetriveChatGroupMemberListFromServerFailedType_ModuleStoped);
        }
        return;
    }

    NSString * messageIdentifier = [self nextMessageIdentifier];
    
    //1.创建回调
    __weak KIMChatGroupModule * weakSelf = self;
    KIMGroupMemberListRequest * groupMemberListRequest = [[KIMGroupMemberListRequest alloc] initWithChatGroup:chatGroup completion:^(KIMGroupMemberListRequest *request, NSArray<KIMUser *> *memberList, KIMGroupMemberListRequestState state) {
        
        switch (state) {
            case KIMGroupMemberListRequestState_Success:
            {
                if (successCallback) {
                    successCallback(weakSelf,memberList);
                }
            }
                break;
            case KIMGroupMemberListRequestState_Timeout:
            {
                if (failedCallback) {
                    failedCallback(weakSelf,RetriveChatGroupMemberListFromServerFailedType_Timeout);
                }
            }
                break;
            case KIMGroupMemberListRequestState_ServerInternalError:
            {
                if (failedCallback) {
                    failedCallback(weakSelf,RetriveChatGroupMemberListFromServerFailedType_ServerInteralError);
                }
            }
                break;
            default:
                break;
        }
        
    } andCallbackQueue:NSOperationQueue.currentQueue];
    
    [self.pendingRequestSet setObject:groupMemberListRequest forKey:messageIdentifier];
    
    //发送FetchChatGroupMemberListRequest消息
    KIMProtoFetchChatGroupMemberListRequest * fetchChatGroupMemberListRequestMessage = [[KIMProtoFetchChatGroupMemberListRequest alloc] init];
    fetchChatGroupMemberListRequestMessage.groupId = chatGroup.groupId;
    fetchChatGroupMemberListRequestMessage.sign = messageIdentifier;
    if ([self.imClient sendMessage:fetchChatGroupMemberListRequestMessage]) {
        [self.moduleStateLock unlock];
        //启动定时器
        __weak KIMChatGroupModule * weakSelf = self;
        NSTimer * timeoutTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:4] interval:0 repeats:NO block:^(NSTimer * _Nonnull timer) {
            //1.判断此请求是否处理完毕
            KIMGroupMemberListRequest * request = (KIMGroupMemberListRequest*)[weakSelf.pendingRequestSet objectForKey:messageIdentifier];
            [weakSelf.pendingRequestSet removeObjectForKey:messageIdentifier];
            if (!request) {//请求处理完毕
                [timer invalidate];
                return;
            }
            
            if ([request.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                request.completion(request,nil,KIMGroupMemberListRequestState_Timeout);
            }else{
                [request.callbackQueue addOperationWithBlock:^{
                    request.completion(request,nil,KIMGroupMemberListRequestState_Timeout);
                }];
            }
        }];
        [[NSRunLoop mainRunLoop] addTimer:timeoutTimer forMode:NSDefaultRunLoopMode];
    }else{
        [self.pendingRequestSet removeObjectForKey:messageIdentifier];
        [self.moduleStateLock unlock];
        if (failedCallback) {
            failedCallback(self,RetriveChatGroupMemberListFromServerFailedType_NetworkError);
        }
    }
}
-(void)handleFetchChatGroupMemberListResponse:(KIMProtoFetchChatGroupMemberListResponse*)message
{
    [self.moduleStateLock lock];
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    
    if (KIMProtoFetchChatGroupMemberListResponse_FetchChatGroupMemberListResponseResult_Success != message.result) {
        if ([message.sign hasPrefix:self.imClient.currentDeviceIdentifier]) {//由当前设备发出
            KIMGroupMemberListRequest * request = (KIMGroupMemberListRequest*)[self.pendingRequestSet objectForKey:message.sign];
            [self.pendingRequestSet removeObjectForKey:message.sign];
            [self.moduleStateLock unlock];
            //2.执行回调
            if ([request.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                request.completion(request,nil,KIMGroupMemberListRequestState_ServerInternalError);
            }else{
                [request.callbackQueue addOperationWithBlock:^{
                    request.completion(request,nil,KIMGroupMemberListRequestState_ServerInternalError);
                }];
            }
        }else{
            [self.moduleStateLock unlock];
        }
    }else{
        //1.清除旧的群成员列表
        NSFetchRequest * groupMemberListQuery = [KIMDBGroupMemberItem fetchRequest];
        [groupMemberListQuery setPredicate:[NSPredicate predicateWithFormat:@"groupId == %@",[message groupId]]];
        
        NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:groupMemberListQuery];
        deleteRequest.resultType = NSBatchDeleteResultTypeObjectIDs;
        
        NSBatchDeleteResult *deleteResult = [[self kimDBContext] executeRequest:deleteRequest error:nil];
        NSArray<NSManagedObjectID *> *deletedObjectIDs = deleteResult.result;
        
        NSDictionary *deletedDict = @{NSDeletedObjectsKey : deletedObjectIDs};
        [NSManagedObjectContext mergeChangesFromRemoteContextSave:deletedDict intoContexts:@[self.kimDBContext]];
     
        NSMutableArray<KIMUser*> * memberList = [NSMutableArray<KIMUser*> array];
        
        //2.添加新的群成员列表
        for (KIMProtoFetchChatGroupMemberListResponse_ChatGroupMemberInfo * groupMemberInfo in [message groupMemberArray]) {
            KIMDBGroupMemberItem * groupMemberModel = [NSEntityDescription insertNewObjectForEntityForName:@"GroupMemberItem" inManagedObjectContext:[self kimDBContext]];
            [groupMemberModel setGroupId:[message groupId]];
            [groupMemberModel setUserAccount:[groupMemberInfo userAccount]];
            [memberList addObject:[[KIMUser alloc]initWithUserAccount:[groupMemberInfo userAccount]]];
        }
        if ([message.sign hasPrefix:self.imClient.currentDeviceIdentifier]) {//由当前设备发出
            KIMGroupMemberListRequest * request = (KIMGroupMemberListRequest*)[self.pendingRequestSet objectForKey:message.sign];
            [self.pendingRequestSet removeObjectForKey:message.sign];
            [self.moduleStateLock unlock];
            //2.执行回调
            if ([request.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                request.completion(request,memberList,KIMGroupMemberListRequestState_Success);
            }else{
                [request.callbackQueue addOperationWithBlock:^{
                    request.completion(request,memberList,KIMGroupMemberListRequestState_Success);
                }];
            }
        }else{
            [self.moduleStateLock unlock];
        }
    }

}
-(KIMChatGroupInfo*)retriveChatGroupInfoFromLocalCache:(KIMChatGroup*)chatGroup
{
    if (!chatGroup) {
        return nil;
    }
    
    [self.moduleStateLock lock];
    
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return nil;
    }
    
    NSFetchRequest * groupQuery = [KIMDBGroup fetchRequest];
    [groupQuery setPredicate:[NSPredicate predicateWithFormat:@"groupId == %@",[chatGroup groupId]]];
    NSArray<KIMDBGroup*> * groupList = [[self kimDBContext] executeFetchRequest:groupQuery error:nil];

    if ([groupList count]) {
        KIMDBGroup * groupModel = [groupList firstObject];
        KIMChatGroupInfo * chatGroupInfo = [[KIMChatGroupInfo alloc] init];
        chatGroupInfo.chatGroup = chatGroup;
        chatGroupInfo.groupName = groupModel.groupName;
        chatGroupInfo.groupMaster = [[KIMUser alloc] initWithUserAccount:groupModel.groupMaster];
        chatGroupInfo.groupDescription = groupModel.groupDescription;
        [self.moduleStateLock unlock];
        return chatGroupInfo;
    }else{
        [self.moduleStateLock unlock];
        return nil;
    }
}

-(BOOL)sendChatGroupInfoSyncMessage:(KIMChatGroup*)chatGroup
{
    if (!chatGroup) {
        return NO;
    }
    
    [self.moduleStateLock lock];
    
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return NO;
    }
    
    KIMProtoFetchChatGroupInfoRequest * fetchChatGroupInfoRequest = [[KIMProtoFetchChatGroupInfoRequest alloc] init];
    [fetchChatGroupInfoRequest setGroupId:chatGroup.groupId];
    
     if([self.imClient sendMessage:fetchChatGroupInfoRequest]){
         [self.moduleStateLock unlock];
         return YES;
     }else{
         [self.moduleStateLock unlock];
         return NO;
     }
}

-(void)handleFetchChatGroupInfoResponse:(KIMProtoFetchChatGroupInfoResponse*)message
{
    
    [self.moduleStateLock lock];
    
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    
    //1.将群信息保存到数据库
    NSFetchRequest * groupQuery = [KIMDBGroup fetchRequest];
    [groupQuery setPredicate:[NSPredicate predicateWithFormat:@"groupId == %@",[message groupId]]];
    NSArray<KIMDBGroup*> * groupList = [[self kimDBContext] executeFetchRequest:groupQuery error:nil];
    KIMDBGroup * groupModel = nil;
    if ([groupList count]) {
        groupModel = [groupList firstObject];
    }else{
        groupModel = [NSEntityDescription insertNewObjectForEntityForName:@"Group" inManagedObjectContext:[self kimDBContext]];
    }
    [groupModel setGroupId:[message groupId]];
    [groupModel setGroupName:[message groupName]];
    [groupModel setGroupMaster:[message groupMaster]];
    [groupModel setGroupDescription:[message groupDescrption]];
    
    [self.moduleStateLock unlock];
    
    //2.通知用户
    NSNotification * notification = [NSNotification notificationWithName:KIMChatGroupModuleChatGroupInfoUpdatedNotificationName object:nil userInfo:@{@"groupId":message.groupId}];
    if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
        [[NSNotificationCenter defaultCenter] postNotification:notification];
    }else{
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        }];
    }
}

-(void)updateChatGroupInfo:(KIMChatGroupInfo*)chatGroupInfo success:(UpdateChatGroupInfoSuccess)successCallback failure:(UpdateChatGroupInfoFailed)failedCallback;
{
    if (!chatGroupInfo.chatGroup) {
        if (failedCallback) {
            failedCallback(self,UpdateChatGroupInfoFailedType_ParameterError);
        }
        return;
    }
    
    [self.moduleStateLock lock];
    
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        if (failedCallback) {
            failedCallback(self,UpdateChatGroupInfoFailedType_ModuleStoped);
        }
        return;
    }
    
    NSString * messageIdentifier = [self nextMessageIdentifier];
    
    //1.注册回调
    __weak KIMChatGroupModule * weakSelf = self;
    KIMGroupInfoUpdateRequest * groupInfoRequest = [[KIMGroupInfoUpdateRequest alloc] initWithChatGroupInfo:chatGroupInfo completion:^(KIMGroupInfoUpdateRequest *request, KIMGroupInfoUpdateRequestState state) {
        switch (state) {
            case KIMGroupInfoUpdateRequestState_Success:
            {
                if (successCallback) {
                    successCallback(weakSelf);
                }
            }
                break;
            case KIMGroupInfoUpdateRequestState_Timeout:
            {
                if (failedCallback) {
                    failedCallback(weakSelf,UpdateChatGroupInfoFailedType_Timeout);
                }
            }
                break;
            case KIMGroupInfoUpdateRequestState_InfomationNotMatch:
            {
                if (failedCallback) {
                    failedCallback(weakSelf,UpdateChatGroupInfoFailedType_InfomationNotMatch);
                }
            }
                break;
            case KIMGroupInfoUpdateRequestState_AuthorizationNotMath:
            {
                if (failedCallback) {
                    failedCallback(weakSelf,UpdateChatGroupInfoFailedType_AuthorizationNotMath);
                }
            }
                break;
            case KIMGroupInfoUpdateRequestState_ServerInternalError:
            default:
                if (failedCallback) {
                    failedCallback(weakSelf,UpdateChatGroupInfoFailedType_ServerInteralError);
                }
                break;
        }
    } andCallbackQueue:NSOperationQueue.currentQueue];
    
    [self.pendingRequestSet setObject:groupInfoRequest forKey:messageIdentifier];
    
    
    //2.发送UpdateChatGroupInfoRequest消息
    KIMProtoUpdateChatGroupInfoRequest * updateChatGroupInfoRequest = [[KIMProtoUpdateChatGroupInfoRequest alloc] init];
    updateChatGroupInfoRequest.groupId = chatGroupInfo.chatGroup.groupId;
    updateChatGroupInfoRequest.groupName = chatGroupInfo.groupName;
    updateChatGroupInfoRequest.groupDescrption = chatGroupInfo.groupDescription;
    updateChatGroupInfoRequest.sign = messageIdentifier;
    if ([self.imClient sendMessage:updateChatGroupInfoRequest]) {
        [self.moduleStateLock unlock];
        //启动定时器
        __weak KIMChatGroupModule * weakSelf = self;
        NSTimer * timeoutTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:4] interval:0 repeats:NO block:^(NSTimer * _Nonnull timer) {
            //1.判断此请求是否处理完毕
            KIMGroupInfoUpdateRequest * request = (KIMGroupInfoUpdateRequest*)[weakSelf.pendingRequestSet objectForKey:messageIdentifier];
            [weakSelf.pendingRequestSet removeObjectForKey:messageIdentifier];
            if (!request) {//请求处理完毕
                [timer invalidate];
                return;
            }
            
            if ([request.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                request.completion(request,KIMGroupInfoUpdateRequestState_Timeout);
            }else{
                [request.callbackQueue addOperationWithBlock:^{
                    request.completion(request,KIMGroupInfoUpdateRequestState_Timeout);
                }];
            }
        }];
        [[NSRunLoop mainRunLoop] addTimer:timeoutTimer forMode:NSDefaultRunLoopMode];
    }else{
        [self.pendingRequestSet removeObjectForKey:messageIdentifier];
        [self.moduleStateLock unlock];
        if (failedCallback) {
            failedCallback(self,UpdateChatGroupInfoFailedType_NetworkError);
        }
    }
}
-(void)handleUpdateChatGroupInfoResponse:(KIMProtoUpdateChatGroupInfoResponse*)message
{
    
    [self.moduleStateLock lock];
    
    if (KIMChatGroupModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    
    KIMGroupInfoUpdateRequest * request = (KIMGroupInfoUpdateRequest*)[self.pendingRequestSet objectForKey:message.sign];
    [self.pendingRequestSet removeObjectForKey:message.sign];
    
    if (!request) {
        [self.moduleStateLock unlock];
        return;
    }

    if (KIMProtoUpdateChatGroupInfoResponse_UpdateChatGroupInfoResponseResult_Success == [message result]) {
        //1.将群信息保存到数据库
        NSFetchRequest * groupQuery = [KIMDBGroup fetchRequest];
        [groupQuery setPredicate:[NSPredicate predicateWithFormat:@"groupId == %@",[message groupId]]];
        NSArray<KIMDBGroup*> * groupList = [[self kimDBContext] executeFetchRequest:groupQuery error:nil];
        KIMDBGroup * groupModel = nil;
        if ([groupList count]) {
            groupModel = [groupList firstObject];
        }else{
            groupModel = [NSEntityDescription insertNewObjectForEntityForName:@"Group" inManagedObjectContext:[self kimDBContext]];
        }
        groupModel.groupId = request.chatGroupInfo.chatGroup.groupId;
        groupModel.groupName = request.chatGroupInfo.groupName;
        groupModel.groupMaster = request.chatGroupInfo.groupMaster.account;
        groupModel.groupDescription = request.chatGroupInfo.groupDescription;
        [self.moduleStateLock unlock];
        //2.执行回调
        if ([request.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
            request.completion(request,KIMGroupInfoUpdateRequestState_Success);
        }else{
            [request.callbackQueue addOperationWithBlock:^{
                request.completion(request,KIMGroupInfoUpdateRequestState_Success);
            }];
        }
    }else{
        [self.moduleStateLock unlock];
        KIMGroupInfoUpdateRequestState state = KIMGroupInfoUpdateRequestState_ServerInternalError;
        switch (message.result) {
            case KIMProtoUpdateChatGroupInfoResponse_UpdateChatGroupInfoResponseResult_InfomationNotMatch:
            {
                state = KIMGroupInfoUpdateRequestState_InfomationNotMatch;
            }
                break;
            case KIMProtoUpdateChatGroupInfoResponse_UpdateChatGroupInfoResponseResult_AuthorizationNotMath:
            {
                state = KIMGroupInfoUpdateRequestState_AuthorizationNotMath;
            }
                break;
            case KIMProtoUpdateChatGroupInfoResponse_UpdateChatGroupInfoResponseResult_ServerInternalError:
            default:
                state = KIMGroupInfoUpdateRequestState_ServerInternalError;
                break;
        }
        //2.执行回调
        if ([request.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
            request.completion(request,state);
        }else{
            [request.callbackQueue addOperationWithBlock:^{
                request.completion(request,state);
            }];
        }
    }
}
#pragma mark - 用户切换
-(void)imClientDidLogin:(KIMClient*)imClient withUser:(KIMUser*)user
{
    [self.moduleStateLock lock];
    if (KIMChatGroupModuleState_Runing == self.moduleState && [user isEqual:self.currentUser]) {
        [self.moduleStateLock unlock];
        return;
    }else{
        
        if (KIMChatGroupModuleState_Stop != self.moduleState) {//客户端以新的用户上线，但是对于上一个模块的下线并未通知
            //清空此当前用户的登录信息
            [self clearUserDataWhenLogined];
        }
        //切换用户
        self.currentUser = user;
        self.imClient = imClient;
        self.moduleState = KIMChatGroupModuleState_Runing;
        //进行用户群列表同步
        [self.imClient sendMessage:[[KIMProtoFetchChatGroupListRequest alloc]init]];
        [self.moduleStateLock unlock];
    }
}
-(void)imClientDidLogout:(KIMClient*)imClient withUser:(KIMUser*)user
{
    [self.moduleStateLock lock];
    if (KIMChatGroupModuleState_Stop == self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    //清空此用户的登录信息
    [self clearUserDataWhenLogined];
    self.currentUser = nil;
    self.imClient = nil;
    self.moduleState = KIMChatGroupModuleState_Stop;
    [self.moduleStateLock unlock];
}
- (void)applicationWillEnterForeground:(NSNotification*)notification
{
    
}
- (void)applicationDidEnterBackground:(NSNotification*)notification
{
    //保存数据
    [self syncData];
}

- (void)applicationWillTerminate:(NSNotification*)notification
{
    //保存数据
    [self syncData];
}
#pragma mark - 数据持久化

-(void)syncData
{
    [self.kimDBContext save:nil];
}
-(void)clearUserDataWhenLogined
{
    [self.pendingRequestSet removeAllObjects];
}
@end
