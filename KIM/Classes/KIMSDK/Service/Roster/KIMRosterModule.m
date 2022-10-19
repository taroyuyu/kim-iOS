//
//  KIMRosterModule.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/27.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMRosterModule.h"
#import "KIMClient+Service.h"
#import "KIMRosterDeleteFriendRequest.h"
#import "KIMRosterUpdateUserVCardRequest.h"
#import "KakaImmessage.pbobjc.h"
#import <CoreData/CoreData.h>
#import <sys/time.h>
#import "KIMDB.h"
#import "KIMDBUser+CoreDataProperties.h"
#import "KIMDBFriendItem+CoreDataProperties.h"
#import "KIMDBFriendApplicantion+CoreDataProperties.h"

NSString * const KIMRosterModuleReceivedFriendApplicationNotificationName = @"KIMRosterModuleReceivedFriendApplicationNotification";
NSString * const KIMRosterModuleReceivedFriendApplicationReplyNotificationName = @"KIMRosterModuleReceivedFriendApplicationReplyNotification";
NSString * const KIMRosterModuleFriendListUpdatedNotificationName = @"KIMRosterModuleFriendListUpdatedNotification";
NSString * const KIMRosterModuleUserVCardUpdatedNotificationName = @"KIMRosterModuleUserVCardUpdatedNotification";

static NSString * KIMUserFriendListVersionDBKey = @"KIMUserFriendListVersionDB";

typedef NS_ENUM(NSUInteger,KIMRosterModuleState)
{
    KIMRosterModuleState_Stop,//停止运作
    KIMRosterModuleState_Runing,//正在运作
};

@interface KIMRosterModule()
@property(nonatomic,strong)NSLock * moduleStateLock;
@property(nonatomic,assign)KIMRosterModuleState moduleState;
@property(nonatomic,weak)KIMClient * imClient;
@property(nonatomic,strong)NSSet<NSString*>* messageTypes;
@property(nonatomic,strong)NSDateFormatter *dateFormatter;
#pragma mark - 数据存储相关
@property(nonatomic,strong)NSManagedObjectModel * kimDBModel;
@property(nonatomic,strong)NSPersistentStoreCoordinator *kimpDBPersistentStoreCoordinator;
@property(nonatomic,strong)NSManagedObjectContext *kimDBContext;
@property(nonatomic,strong)NSMutableDictionary<NSString*,NSNumber*> * userFriendListVersionDB;
#pragma mark - 用户相关
@property(nonatomic,strong)KIMUser * currentUser;
@property(nonatomic,strong)NSMutableDictionary<NSString*,NSNumber*> * pendingFriendApplicationSet;
@property(nonatomic,strong)NSMutableDictionary<NSString*,KIMRosterDeleteFriendRequest*> * pendingRosterDeleteFriendRequestSet;
@property(nonatomic,strong)KIMRosterUpdateUserVCardRequest * updatingUserVCardRequest;
@property(nonatomic,strong)NSTimer * updatingUserVCardRequestTimeoutTimer;
@end

@implementation KIMRosterModule
-(instancetype)init
{
    self = [super init];
    if (self) {
        NSMutableSet<NSString*> * messageTypeSet = [[NSMutableSet<NSString*> alloc] init];
        [messageTypeSet addObject:[[KIMProtoBuildingRelationshipRequestMessage descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoBuildingRelationshipAnswerMessage descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoDestoryingRelationshipResponseMessage descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoFriendListResponseMessage descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoUserVCardResponseMessage descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoUpdateUserVCardMessageResponse descriptor]fullName]];
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
        self.pendingFriendApplicationSet = [NSMutableDictionary<NSString*,NSNumber*> dictionary];
        self.pendingRosterDeleteFriendRequestSet = [NSMutableDictionary<NSString*,KIMRosterDeleteFriendRequest*> dictionary];
        
        //监听通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
        
        //模块状态
        self.moduleStateLock = [[NSLock alloc] init];
        self.moduleState = KIMRosterModuleState_Stop;
    }
    return self;
}
-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
-(NSMutableDictionary<NSString*,NSNumber*> *)userFriendListVersionDB
{
    if (self->_userFriendListVersionDB) {
        return self->_userFriendListVersionDB;
    }
    
    self->_userFriendListVersionDB = [NSMutableDictionary<NSString*,NSNumber*> dictionary];
    [self->_userFriendListVersionDB addEntriesFromDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:KIMUserFriendListVersionDBKey]];
    return self->_userFriendListVersionDB;
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
    if(![self.messageTypes containsObject:messageType]){
        return;
    }
    if ([messageType isEqualToString: [[KIMProtoBuildingRelationshipRequestMessage descriptor] fullName]]) {
        [self handleBuildingRelationshipRequestMessage:(KIMProtoBuildingRelationshipRequestMessage*)message];
    }else if ([messageType isEqualToString: [[KIMProtoBuildingRelationshipAnswerMessage descriptor] fullName]]) {
        [self handleBuildingRelationshipAnswerMessage:(KIMProtoBuildingRelationshipAnswerMessage*)message];
    }else if ([messageType isEqualToString: [[KIMProtoDestoryingRelationshipResponseMessage descriptor] fullName]]) {
        [self handleDestoryingRelationshipResponseMessage:(KIMProtoDestoryingRelationshipResponseMessage*)message];
    }else if ([messageType isEqualToString: [[KIMProtoFriendListResponseMessage descriptor] fullName]]) {
        [self handleFriendListResponseMessage:(KIMProtoFriendListResponseMessage*)message];
    }else if ([messageType isEqualToString: [[KIMProtoUserVCardResponseMessage descriptor] fullName]]) {
        [self handleUserVCardResponseMessage:(KIMProtoUserVCardResponseMessage*)message];
    }else if ([messageType isEqualToString: [[KIMProtoUpdateUserVCardMessageResponse descriptor] fullName]]) {
        [self handleUpdateUserVCardMessageResponse:(KIMProtoUpdateUserVCardMessageResponse*)message];
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
    NSFetchRequest *fetchRequest = [KIMDBFriendApplicantion fetchRequest];
    
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND applicationId < 0",self.currentUser.account];
    [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"applicationId" ascending:NO]]];
    [fetchRequest setFetchLimit:1];
    NSArray<KIMDBFriendApplicantion *> * applicationSet = [[self kimDBContext] executeFetchRequest:fetchRequest error:nil];
    
    if ([applicationSet count]) {
        int64_t applicationId = [[applicationSet firstObject] applicationId];
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

#pragma mark - 好友申请

-(BOOL)sendFriendApplicationToUser:(KIMUser*)targetUser withIntroduction:(NSString*)introduction
{
    [self.moduleStateLock lock];
    if (KIMRosterModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return NO;
    }
    
    ino64_t applicationId = [self nextApplicationId];
    NSString * messageIdentifier = nil;
    do{
        messageIdentifier = [self nextMessageIdentifier];
    }while([self.pendingFriendApplicationSet objectForKey:messageIdentifier]);
    
    //1.保存到本地数据库
    KIMDBFriendApplicantion * friendApplication = [NSEntityDescription insertNewObjectForEntityForName:KIMDBFriendApplicantionEntityName inManagedObjectContext:[self kimDBContext]];
    [friendApplication setUserDomain:self.currentUser.account];
    [friendApplication setSponsorAccount:self.currentUser.account];
    [friendApplication setTargetAccount:targetUser.account];
    [friendApplication setIntroduction:introduction];
    [friendApplication setState:KIMFriendApplicationState_Pending];
    [friendApplication setSubmissionTime:[NSDate date]];
    [friendApplication setApplicationId:applicationId];
    
    [self.pendingFriendApplicationSet setObject:[NSNumber numberWithLongLong:applicationId] forKey:messageIdentifier];
    
    //2.发送请求
    KIMProtoBuildingRelationshipRequestMessage * requestMessage = [[KIMProtoBuildingRelationshipRequestMessage alloc] init];
    [requestMessage setSponsorAccount:self.currentUser.account];
    [requestMessage setTargetAccount:targetUser.account];
    [requestMessage setIntroduction:introduction];
    [requestMessage setSign:messageIdentifier];
    if (![self.imClient sendMessage:requestMessage]) {
        //删除此记录
        [self.kimDBContext deleteObject:friendApplication];
        [self.moduleStateLock unlock];
        return NO;
    }else{
        [self.moduleStateLock unlock];
        return YES;
    }
}
-(void)handleBuildingRelationshipRequestMessage:(KIMProtoBuildingRelationshipRequestMessage*)message
{
    [self.moduleStateLock lock];
    if (KIMRosterModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    NSNumber * applicationIdNumber = [self.pendingFriendApplicationSet objectForKey:message.sign];
    if (nil != applicationIdNumber) {
        //同步到数据库
        NSFetchRequest * friendApplicationFetchRequest = [KIMDBFriendApplicantion fetchRequest];
        friendApplicationFetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND applicationId== %lld",self.currentUser.account,[applicationIdNumber longLongValue]];
        [friendApplicationFetchRequest setFetchLimit:1];
        NSArray<KIMDBFriendApplicantion *> *apllicationSet = [[self kimDBContext] executeFetchRequest:friendApplicationFetchRequest error:nil];
        [[apllicationSet firstObject] setApplicationId:[message applicantId]];
    }else{
        //1.将消息保存到本地数据库
        KIMDBFriendApplicantion * friendApplication = [NSEntityDescription insertNewObjectForEntityForName:KIMDBFriendApplicantionEntityName inManagedObjectContext:self.kimDBContext];
        [friendApplication setUserDomain:self.currentUser.account];
        [friendApplication setApplicationId:[message applicantId]];
        [friendApplication setSponsorAccount:[message sponsorAccount]];
        [friendApplication setTargetAccount:[message targetAccount]];
        [friendApplication setIntroduction:[message introduction]];
        
        [friendApplication setState:KIMFriendApplicationState_Pending];
        [friendApplication setSubmissionTime:[[self dateFormatter]dateFromString:[message submissionTime]]];
        
        NSString * introduction = message.introduction == nil ? @"" : message.introduction;
        //2.通知用户
        NSNotification * notification = [[NSNotification alloc] initWithName:KIMRosterModuleReceivedFriendApplicationNotificationName object:nil userInfo:@{@"sponsor":friendApplication.sponsorAccount,@"target":friendApplication.targetAccount,@"introduction":introduction,@"applicationId":[NSNumber numberWithUnsignedLongLong:message.applicantId]}];
        if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        }else{
            [NSOperationQueue.mainQueue addOperationWithBlock:^{
                [[NSNotificationCenter defaultCenter] postNotification:notification];
            }];
        }
    }
    [self.moduleStateLock unlock];
    return;
}
-(BOOL)acceptFriendApplication:(KIMFriendApplication*)friendApplication
{
    [self.moduleStateLock lock];
    if (KIMRosterModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return NO;
    }
    
    //1.查询此好友申请记录是否存在
    NSFetchRequest * applicationFetchRequest = [KIMDBFriendApplicantion fetchRequest];
    [applicationFetchRequest setPredicate:[NSPredicate predicateWithFormat:@"userDomain == %@ AND applicationId==%llu",self.currentUser.account,[friendApplication applicantId]]];
    [applicationFetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"applicationId" ascending:NO]]];
    NSError * fetchApplicationError = nil;
    NSArray<KIMDBFriendApplicantion*> * applicationArray = [[self kimDBContext] executeFetchRequest:applicationFetchRequest error:&fetchApplicationError];
    
    if (![applicationArray firstObject] || [applicationArray.firstObject state] !=KIMFriendApplicationState_Pending) {//此好友申请记录不存在或此好友申请已经被处理
        [self.moduleStateLock unlock];
        return NO;
    }
    
    //2.验证身份
    if (![applicationArray.firstObject.targetAccount isEqualToString:self.currentUser.account]) {//身份不符合
        [self.moduleStateLock unlock];
        return NO;
    }
    
    //3.修改此好友申请的状态
    [[applicationArray firstObject] setState:KIMFriendApplicationState_Allowm];
    
    //4.发送答复
    KIMProtoBuildingRelationshipAnswerMessage * replyMessage = [[KIMProtoBuildingRelationshipAnswerMessage alloc] init];
    [replyMessage setApplicantId:friendApplication.applicantId];
    [replyMessage setSponsorAccount:friendApplication.sponsor.account];
    [replyMessage setTargetAccount:friendApplication.target.account];
    [replyMessage setAnswer:KIMProtoBuildingRelationshipAnswerMessage_BuildingRelationshipAnswer_Accept];
    if([self.imClient sendMessage:replyMessage]){
        [self.moduleStateLock unlock];
        return YES;
    }else{//发送失败
        //将此好友申请的状态还原
        [[applicationArray firstObject] setState:KIMFriendApplicationState_Pending];
        [self.moduleStateLock unlock];
        return NO;
    }
}
-(BOOL)rejectFriendApplication:(KIMFriendApplication*)friendApplication
{
    [self.moduleStateLock lock];
    if (KIMRosterModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return NO;
    }
    
    //1.查询此好友申请记录是否存在
    NSFetchRequest * applicationFetchRequest = [KIMDBFriendApplicantion fetchRequest];
    [applicationFetchRequest setPredicate:[NSPredicate predicateWithFormat:@"userDomain == %@ AND applicationId==%llu",self.currentUser.account,[friendApplication applicantId]]];
    [applicationFetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"applicationId" ascending:NO]]];
    NSError * fetchApplicationError = nil;
    NSArray<KIMDBFriendApplicantion*> * applicationArray = [[self kimDBContext] executeFetchRequest:applicationFetchRequest error:&fetchApplicationError];
    
    if (![applicationArray firstObject] || [applicationArray.firstObject state] !=KIMFriendApplicationState_Pending) {//此好友申请记录不存在或此好友申请已经被处理
        [self.moduleStateLock unlock];
        return NO;
    }
    
    //2.验证身份
    if (![applicationArray.firstObject.targetAccount isEqualToString:self.currentUser.account]) {//身份不符合
        [self.moduleStateLock unlock];
        return NO;
    }
    
    //3.修改此好友申请的状态
    [[applicationArray firstObject] setState:KIMFriendApplicationState_Reject];
    
    //4.发送答复
    KIMProtoBuildingRelationshipAnswerMessage * replyMessage = [[KIMProtoBuildingRelationshipAnswerMessage alloc] init];
    [replyMessage setApplicantId:friendApplication.applicantId];
    [replyMessage setSponsorAccount:friendApplication.sponsor.account];
    [replyMessage setTargetAccount:friendApplication.target.account];
    [replyMessage setAnswer:KIMProtoBuildingRelationshipAnswerMessage_BuildingRelationshipAnswer_Reject];
    if([self.imClient sendMessage:replyMessage]){
        [self.moduleStateLock unlock];
        return YES;
    }else{//发送失败
        //将此好友申请的状态还原
        [[applicationArray firstObject] setState:KIMFriendApplicationState_Pending];
        [self.moduleStateLock unlock];
        return NO;
    }
}
-(void)handleBuildingRelationshipAnswerMessage:(KIMProtoBuildingRelationshipAnswerMessage*)message
{
    [self.moduleStateLock lock];
    if (KIMRosterModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    //1查询此好友申请记录是否存在
    NSFetchRequest * applicationFetchRequest = [KIMDBFriendApplicantion fetchRequest];
    [applicationFetchRequest setPredicate:[NSPredicate predicateWithFormat:@"userDomain == %@ AND applicationId==%llu",self.currentUser.account,[message applicantId]]];
    [applicationFetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"applicationId" ascending:NO]]];
    NSError * fetchApplicationError = nil;
    NSArray<KIMDBFriendApplicantion*> * applicationArray = [[self kimDBContext] executeFetchRequest:applicationFetchRequest error:&fetchApplicationError];
    
    if ([applicationArray firstObject]) {//此好友申请记录存在则直接更新
        switch ([message answer]) {
            case KIMProtoBuildingRelationshipAnswerMessage_BuildingRelationshipAnswer_Accept:
            {
                [[applicationArray firstObject] setAnswer:KIMFriendApplicationState_Allowm];
            }
                break;
            case KIMProtoBuildingRelationshipAnswerMessage_BuildingRelationshipAnswer_Reject:
            default:
            {
                [[applicationArray firstObject] setAnswer:KIMFriendApplicationState_Reject];
            }
                break;
        }
    }else{//此好友申请记录不存在
        KIMDBFriendApplicantion * friendApplication = [NSEntityDescription insertNewObjectForEntityForName:KIMDBFriendApplicantionEntityName inManagedObjectContext:[self kimDBContext]];
        [friendApplication setUserDomain:self.currentUser.account];
        [friendApplication setApplicationId:[message applicantId]];
        [friendApplication setSponsorAccount:[message sponsorAccount]];
        [friendApplication setTargetAccount:[message targetAccount]];
        switch ([message answer]) {
            case KIMProtoBuildingRelationshipAnswerMessage_BuildingRelationshipAnswer_Accept:
            {
                [friendApplication setAnswer:KIMFriendApplicationState_Allowm];
            }
                break;
            case KIMProtoBuildingRelationshipAnswerMessage_BuildingRelationshipAnswer_Reject:
                default:
            {
                [friendApplication setAnswer:KIMFriendApplicationState_Reject];
            }
                break;
        }
    }
    
    NSString * reply = message.answer == KIMProtoBuildingRelationshipAnswerMessage_BuildingRelationshipAnswer_Accept ? @"Accept" : @"Reject";
    //2.通知用户
    NSNotification * notification = [[NSNotification alloc] initWithName:KIMRosterModuleReceivedFriendApplicationReplyNotificationName object:nil userInfo:@{@"sponsor":message.sponsorAccount,@"target":message.targetAccount,@"reply":reply,@"applicationId":[NSNumber numberWithUnsignedLongLong:message.applicantId]}];
    if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
        [[NSNotificationCenter defaultCenter] postNotification:notification];
    }else{
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        }];
    }
    
    //3.尝试更新好友列表
    [self checkFriendListNeedsUpdate];
    [self.moduleStateLock unlock];
}

-(NSArray<KIMFriendApplication*>*)fetchPendingFriendApplications
{
    NSMutableArray<KIMFriendApplication*> * friendApplicationList = [NSMutableArray<KIMFriendApplication*> array];
    
    NSFetchRequest * applicationFetchRequest = [KIMDBFriendApplicantion fetchRequest];
    applicationFetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND state== %lu",self.currentUser.account,KIMFriendApplicationState_Pending];
    [applicationFetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"applicationId" ascending:NO]]];
    
    NSArray<KIMDBFriendApplicantion *> * applicationSet = [[self kimDBContext] executeFetchRequest:applicationFetchRequest error:nil];
    
    if (applicationSet) {
        for (KIMDBFriendApplicantion * applicatonModel in applicationSet) {
            KIMFriendApplication * application = [[KIMFriendApplication alloc] init];
            [application setSponsor:[[KIMUser alloc]initWithUserAccount:applicatonModel.sponsorAccount]];
            [application setTarget:[[KIMUser alloc]initWithUserAccount:applicatonModel.targetAccount]];
            if ([[applicatonModel sponsorAccount] isEqualToString:self.currentUser.account]) {
                [application setPeerUser:[application target]];
            }else{
                [application setPeerUser:[application sponsor]];
            }
            [application setIntroduction:[applicatonModel introduction]];
            [application setApplicantId:[applicatonModel applicationId]];
            [application setSubmissionTime:[applicatonModel submissionTime]];
            [application setState:[applicatonModel state]];
            [friendApplicationList addObject:application];
        }
    }
    
    return [friendApplicationList copy];
}
-(NSArray<KIMFriendApplication*>*)fetchAllFriendApplications
{
    NSMutableArray<KIMFriendApplication*> * friendApplicationList = [NSMutableArray<KIMFriendApplication*> array];
    
    NSFetchRequest * applicationFetchRequest = [KIMDBFriendApplicantion fetchRequest];
    applicationFetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND applicationId > 0",self.currentUser.account];
    [applicationFetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"applicationId" ascending:NO]]];
    
    NSArray<KIMDBFriendApplicantion *> * applicationSet = [[self kimDBContext] executeFetchRequest:applicationFetchRequest error:nil];
    
    if (applicationSet) {
        for (KIMDBFriendApplicantion * applicatonModel in applicationSet) {
            KIMFriendApplication * application = [[KIMFriendApplication alloc] init];
            [application setSponsor:[[KIMUser alloc]initWithUserAccount:applicatonModel.sponsorAccount]];
            [application setTarget:[[KIMUser alloc]initWithUserAccount:applicatonModel.targetAccount]];
            if ([[applicatonModel sponsorAccount] isEqualToString:self.currentUser.account]) {
                [application setPeerUser:[application target]];
            }else{
                [application setPeerUser:[application sponsor]];
            }
            [application setIntroduction:[applicatonModel introduction]];
            [application setApplicantId:[applicatonModel applicationId]];
            [application setSubmissionTime:[applicatonModel submissionTime]];
            [application setState:[applicatonModel state]];
            [friendApplicationList addObject:application];
        }
    }
    
    return [friendApplicationList copy];
}
#pragma mark - 好友删除
-(void)deleteFriend:(KIMUser*)pendingDeleteFriend success:(DeleteFriendSuccess)successCallback failure:(DeleteFriendFailed)failedCallback
{
    if (!pendingDeleteFriend.account.length) {
        if (failedCallback) {
            failedCallback(self,pendingDeleteFriend,DeleteFriendFailureType_ParameterError);
        }
        return;
    }
    [self.moduleStateLock lock];
    if (KIMRosterModuleState_Runing != self.moduleState) {
        if (failedCallback) {
            failedCallback(self,pendingDeleteFriend,DeleteFriendFailureType_ModuleStoped);
        }
        [self.moduleStateLock unlock];
        return;
    }
    //1.查询好友列表中是否存在此好友
    NSFetchRequest * friendItemRequest = [KIMDBFriendItem fetchRequest];
    [friendItemRequest setPredicate:[NSPredicate predicateWithFormat:@"userDomain==%@ AND friendAccount == %@",self.currentUser.account,pendingDeleteFriend.account]];
    NSError * fetchFriendItemError = nil;
    NSArray<KIMDBFriendApplicantion*> * friendItemArray = [[self kimDBContext] executeFetchRequest:friendItemRequest error:&fetchFriendItemError];
    
    if (fetchFriendItemError) {
        if (failedCallback) {
            failedCallback(self,pendingDeleteFriend,DeleteFriendFailureType_ClientInteralError);
        }
        [self.moduleStateLock unlock];
        return;
    }
    
    if (!friendItemArray.count) {//好友列表中不存在此好友
        if (failedCallback) {
            failedCallback(self,pendingDeleteFriend,DeleteFriendFailureType_FriendRelationNotExitBefore);
        }
        [self.moduleStateLock unlock];
        return;
    }
    
    //2.发送删除好友请求
    NSString * messageIdentifier = [self nextMessageIdentifier];
    KIMRosterDeleteFriendRequest * deleteFriendRequest = [[KIMRosterDeleteFriendRequest alloc] initWithUser:pendingDeleteFriend completion:^(KIMRosterDeleteFriendRequest *request, KIMRosterDeleteFriendRequestState state) {
        
        switch (state) {
            case KIMRosterDeleteFriendRequestState_Success:
            {
                if (successCallback) {
                    successCallback(self,pendingDeleteFriend);
                }
            }
                break;
            case KIMRosterDeleteFriendRequestState_Timeout:
            {
                if(failedCallback){
                    failedCallback(self,pendingDeleteFriend,DeleteFriendFailureType_Timeout);
                }
            }
                break;
            case KIMRosterDeleteFriendRequestState_ServerInternalError:
            {
                if(failedCallback){
                    failedCallback(self,pendingDeleteFriend,DeleteFriendFailureType_ServerInteralError);
                }
            }
                break;
            default:
                break;
        }
        
    } andCallbackQueue:[NSOperationQueue currentQueue]];;
    
    [self.pendingRosterDeleteFriendRequestSet setObject:deleteFriendRequest forKey:messageIdentifier];
    KIMProtoDestroyingRelationshipRequestMessage * deleteMessage = [[KIMProtoDestroyingRelationshipRequestMessage alloc] init];
    [deleteMessage setSponsorAccount:self.imClient.currentUser.account];
    [deleteMessage setTargetAccount:pendingDeleteFriend.account];
    [deleteMessage setSign:messageIdentifier];
    
    if([self.imClient sendMessage:deleteMessage]){
        [self.moduleStateLock unlock];
        //启动定时器
        __weak KIMRosterModule * weakSelf = self;
        NSTimer * timeoutTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:4] interval:0 repeats:NO block:^(NSTimer * _Nonnull timer) {
           //1.判断此请求是否处理完毕
            KIMRosterDeleteFriendRequest * request = [weakSelf.pendingRosterDeleteFriendRequestSet objectForKey:messageIdentifier];
            [weakSelf.pendingRosterDeleteFriendRequestSet removeObjectForKey:messageIdentifier];
            if (!request) {//请求处理完毕
                [timer invalidate];
                return;
            }
            
            if ([request.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                request.completion(request,KIMRosterDeleteFriendRequestState_Timeout);
            }else{
                [request.callbackQueue addOperationWithBlock:^{
                    request.completion(request,KIMRosterDeleteFriendRequestState_Timeout);
                }];
            }
        }];
        [[NSRunLoop mainRunLoop] addTimer:timeoutTimer forMode:NSDefaultRunLoopMode];
    }else{
        [self.pendingRosterDeleteFriendRequestSet removeObjectForKey:messageIdentifier];
        [self.moduleStateLock unlock];
        if (failedCallback) {
            failedCallback(self,pendingDeleteFriend,DeleteFriendFailureType_NetworkError);
        }
    }
}
-(void)handleDestoryingRelationshipResponseMessage:(KIMProtoDestoryingRelationshipResponseMessage*)message
{
    [self.moduleStateLock lock];
    
    if (KIMRosterModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    
    if ([message.sign hasPrefix:self.imClient.currentDeviceIdentifier]) {//由当前设备发出
        KIMRosterDeleteFriendRequest * deleteFriendRequest = [self.pendingRosterDeleteFriendRequestSet objectForKey:message.sign];
        [self.pendingRosterDeleteFriendRequestSet removeObjectForKey:message.sign];
        switch (message.response) {
            case KIMProtoDestoryingRelationshipResponseMessage_DestoryingRelationshipResponse_IllegalOperation://非法操作,说明关系实现并不存在着，总之就是删除成功
            case KIMProtoDestoryingRelationshipResponseMessage_DestoryingRelationshipResponse_Success:
            {
                //1.从好友列表中删除此好友
                NSFetchRequest * friendItemRequest = [KIMDBFriendItem fetchRequest];
                [friendItemRequest setPredicate:[NSPredicate predicateWithFormat:@"userDomain==%@ AND friendAccount == %@",self.currentUser.account,deleteFriendRequest.targetUser.account]];
                NSError * fetchFriendItemError = nil;
                NSArray<KIMDBFriendApplicantion*> * friendItemArray = [[self kimDBContext] executeFetchRequest:friendItemRequest error:&fetchFriendItemError];
                [[self kimDBContext] deleteObject:[friendItemArray firstObject]];
                //2.执行回调，报告用户:删除成功
                [self.moduleStateLock unlock];
                if ([deleteFriendRequest.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                    deleteFriendRequest.completion(deleteFriendRequest,KIMRosterDeleteFriendRequestState_Success);
                }else{
                    [deleteFriendRequest.callbackQueue addOperationWithBlock:^{
                        deleteFriendRequest.completion(deleteFriendRequest,KIMRosterDeleteFriendRequestState_Success);
                    }];
                }
                //3.发送好友列表更新通知
                NSNotification * notification = [[NSNotification alloc] initWithName:KIMRosterModuleFriendListUpdatedNotificationName object:nil userInfo:@{@"owner":self.currentUser.account}];
                if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
                    [[NSNotificationCenter defaultCenter] postNotification:notification];
                }else{
                    [NSOperationQueue.mainQueue addOperationWithBlock:^{
                        [[NSNotificationCenter defaultCenter] postNotification:notification];
                    }];
                }
            }
                break;
            case KIMProtoDestoryingRelationshipResponseMessage_DestoryingRelationshipResponse_ServerInteralError:
            {
                //执行回调，报告用户删除失败：服务器内部错误
                [self.moduleStateLock unlock];
                if ([deleteFriendRequest.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                    deleteFriendRequest.completion(deleteFriendRequest,KIMRosterDeleteFriendRequestState_ServerInternalError);
                }else{
                    [deleteFriendRequest.callbackQueue addOperationWithBlock:^{
                        deleteFriendRequest.completion(deleteFriendRequest,KIMRosterDeleteFriendRequestState_ServerInternalError);
                    }];
                }
            }
                break;
            default:{
                [self.moduleStateLock unlock];
            }
                break;
        }
        
    }else{//不是由本设备发出的
        switch (message.response) {
            case KIMProtoDestoryingRelationshipResponseMessage_DestoryingRelationshipResponse_Success:
            {
                if ([message.sponsorAccount isEqualToString:self.currentUser.account]) {//当前用户在其它设备上删除一个特定好友
                    //1.从好友列表中删除此好友
                    NSFetchRequest * friendItemRequest = [KIMDBFriendItem fetchRequest];
                    [friendItemRequest setPredicate:[NSPredicate predicateWithFormat:@"userDomain==%@ AND friendAccount == %@",self.currentUser.account,message.targetAccount]];
                    NSError * fetchFriendItemError = nil;
                    NSArray<KIMDBFriendApplicantion*> * friendItemArray = [[self kimDBContext] executeFetchRequest:friendItemRequest error:&fetchFriendItemError];
                    [[self kimDBContext] deleteObject:[friendItemArray firstObject]];
                    //2.发送好友列表更新通知
                    [self.moduleStateLock unlock];
                    NSNotification * notification = [[NSNotification alloc] initWithName:KIMRosterModuleFriendListUpdatedNotificationName object:nil userInfo:nil];
                    if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
                        [[NSNotificationCenter defaultCenter] postNotification:notification];
                    }else{
                        [NSOperationQueue.mainQueue addOperationWithBlock:^{
                            [[NSNotificationCenter defaultCenter] postNotification:notification];
                        }];
                    }
                }else if([message.targetAccount isEqualToString:self.currentUser.account]){//有好友解除了和当前用户的好友关系
                    //1.从好友列表中删除此好友
                    NSFetchRequest * friendItemRequest = [KIMDBFriendItem fetchRequest];
                    [friendItemRequest setPredicate:[NSPredicate predicateWithFormat:@"userDomain==%@ AND friendAccount == %@",self.currentUser.account,message.sponsorAccount]];
                    NSError * fetchFriendItemError = nil;
                    NSArray<KIMDBFriendApplicantion*> * friendItemArray = [[self kimDBContext] executeFetchRequest:friendItemRequest error:&fetchFriendItemError];
                    [[self kimDBContext] deleteObject:[friendItemArray firstObject]];
                    //2.发送好友列表更新通知
                    [self.moduleStateLock unlock];
                    NSNotification * notification = [[NSNotification alloc] initWithName:KIMRosterModuleFriendListUpdatedNotificationName object:nil userInfo:nil];
                    if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
                        [[NSNotificationCenter defaultCenter] postNotification:notification];
                    }else{
                        [NSOperationQueue.mainQueue addOperationWithBlock:^{
                            [[NSNotificationCenter defaultCenter] postNotification:notification];
                        }];
                    }
                }
            }
                break;
            default:
            {
                [self.moduleStateLock unlock];
            }
                break;
        }
    }
}
#pragma mark - 好友列表
-(void)handleFriendListResponseMessage:(KIMProtoFriendListResponseMessage*)message
{
    [self.moduleStateLock lock];
    if (KIMRosterModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    //1.判断好友列表是否需要更新
    uint64_t currentUserFriendListVersion = [[self.userFriendListVersionDB objectForKey:self.currentUser.account] unsignedLongLongValue];
    ;
    if (message.currentVersion > currentUserFriendListVersion) {//需要更新
        //删除旧的好友列表
        NSFetchRequest *deleteFetch = [KIMDBFriendItem fetchRequest];
        deleteFetch.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@",self.currentUser.account];
        NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:deleteFetch];
        deleteRequest.resultType = NSBatchDeleteResultTypeObjectIDs;
        
        NSBatchDeleteResult *deleteResult = [[self kimDBContext] executeRequest:deleteRequest error:nil];
        NSArray<NSManagedObjectID *> *deletedObjectIDs = deleteResult.result;
        
        NSDictionary *deletedDict = @{NSDeletedObjectsKey : deletedObjectIDs};
        [NSManagedObjectContext mergeChangesFromRemoteContextSave:deletedDict intoContexts:@[self.kimDBContext]];
        
        //添加新的好友列表
        for (KIMProtoFriendListItem * friendListItem in [message friendArray]) {
            KIMDBFriendItem * friendItem = [NSEntityDescription insertNewObjectForEntityForName:KIMDBFriendItemEntityName inManagedObjectContext:[self kimDBContext]];
            [friendItem setUserDomain:self.currentUser.account];
            [friendItem setFriendAccount:[friendListItem friendAccount]];
        }
        
        //更新好友列表的版本号
        [self.userFriendListVersionDB setObject:[NSNumber numberWithUnsignedLongLong:message.currentVersion] forKey:self.currentUser.account];
        
        //发送通知：好友列表存在更新
        NSNotification * notification = [[NSNotification alloc] initWithName:KIMRosterModuleFriendListUpdatedNotificationName object:nil userInfo:@{@"owner":self.currentUser.account}];
        if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        }else{
            [NSOperationQueue.mainQueue addOperationWithBlock:^{
                [[NSNotificationCenter defaultCenter] postNotification:notification];
            }];
        }
    }
    [self.moduleStateLock unlock];
    return;
}
-(NSSet<KIMUser*>*)retriveFriendListFromLocalCache
{
    NSFetchRequest *fetchRequest = [KIMDBFriendItem fetchRequest];
    
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@",self.currentUser.account];
    
    NSArray<NSSortDescriptor *> *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"friendAccount" ascending:YES]];
    
    fetchRequest.sortDescriptors = sortDescriptors;
    NSArray<KIMDBFriendItem *> *friendItemList = [[self kimDBContext] executeFetchRequest:fetchRequest error:nil];
    
    NSMutableSet<KIMUser*> * friendSet = [NSMutableSet<KIMUser*> set];
    for (KIMDBFriendItem * friendItem in friendItemList) {
        KIMUser * user = [[KIMUser alloc] initWithUserAccount:friendItem.friendAccount];
        [friendSet addObject:user];
    }
    
    return [friendSet copy];
}

//尝试更新好友列表
-(void)checkFriendListNeedsUpdate
{
    uint64_t currentUserFriendListVersion = [[self.userFriendListVersionDB objectForKey:self.currentUser.account] unsignedLongLongValue];
    KIMProtoFriendListRequestMessage * friendListRequestMessage = [[KIMProtoFriendListRequestMessage alloc] init];
    [friendListRequestMessage setCurrentVersion:currentUserFriendListVersion];
    [self.imClient sendMessage:friendListRequestMessage];
}

#pragma mark - 用户信息
-(KIMUserVCard*)retriveCurrentUserVCardFromLocalCache
{
    return [self retriveUserVCardFromLocalCache:self.currentUser];
}
-(KIMUserVCard*)retriveUserVCardFromLocalCache:(KIMUser*)targetUser
{
    NSFetchRequest *fetchRequest = [KIMDBUser fetchRequest];
    
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"account == %@",targetUser.account];
    
    NSArray<KIMDBUser *> *userSet = [[self kimDBContext] executeFetchRequest:fetchRequest error:nil];
    if ([userSet count]) {
        KIMDBUser * userModel = [userSet firstObject];
        KIMUserVCard * userVCard = [[KIMUserVCard alloc] init];
        userVCard.user = [[KIMUser alloc] initWithUserAccount:userModel.account];
        [userVCard setNickName:[userModel nickName]];
        [userVCard setAvatar:[userModel avatar]];
        [userVCard setGender:[userModel gender]];
        [userVCard setMood:[userModel mood]];
        return userVCard;
    }else{
        return nil;
    }
}

-(BOOL)sendUserVCardSyncMessage:(KIMUser*)user
{
    if (!user.account.length) {
        return NO;
    }
    [self.moduleStateLock lock];
    if (KIMRosterModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return NO;
    }
    //1.查询此用户电子名片的修改时间
    NSDate * userVCardMTime = [NSDate date];
    NSFetchRequest *fetchRequest = [KIMDBUser fetchRequest];
    
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"account == %@",user.account];
    
    NSArray<KIMDBUser *> *userSet = [[self kimDBContext] executeFetchRequest:fetchRequest error:nil];
    if ([userSet count]) {//存在，则更新
        userVCardMTime = [[userSet firstObject] mtime];
    }
    
    //2.发送同步消息
    KIMProtoFetchUserVCardMessage * fetchUserVCardMessage = [[KIMProtoFetchUserVCardMessage alloc] init];
    [fetchUserVCardMessage setUserId:user.account];
    [fetchUserVCardMessage setCurrentVersion:[self.dateFormatter stringFromDate:userVCardMTime]];
    if ([self.imClient sendMessage:fetchUserVCardMessage]) {
        [self.moduleStateLock unlock];
        return YES;
    }else{
        [self.moduleStateLock unlock];
        return NO;
    }
}

-(void)handleUserVCardResponseMessage:(KIMProtoUserVCardResponseMessage*)message
{
    [self.moduleStateLock lock];
    if (KIMRosterModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    
    NSFetchRequest *fetchRequest = [KIMDBUser fetchRequest];
    
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"account == %@",[message userId]];
    
    NSArray<KIMDBUser *> *userSet = [[self kimDBContext] executeFetchRequest:fetchRequest error:nil];
    KIMDBUser * userModel = nil;
    if ([userSet count]) {//存在，则更新
        userModel = [userSet firstObject];
    }else{//不存在，则添加
        userModel = [NSEntityDescription insertNewObjectForEntityForName:KIMDBUserEntityName inManagedObjectContext:[self kimDBContext]];
    }
    
    NSDate * serverVersion = [self.dateFormatter dateFromString:message.currentVersion];
    
    if ([userModel.mtime isEqual:serverVersion]) {//相同则说明未更新
        [self.moduleStateLock unlock];
        return;
    }
    //不相同则表示需要更新
    [userModel setAccount:[message userId]];
    [userModel setNickName:[message nickname]];
    [userModel setAvatar:[message avator]];
    switch ([message gender]) {
        case KIMProtoUserGenderType_Male:
        {
            [userModel setGender:KIMUserGender_Male];
        }
            break;
        case KIMProtoUserGenderType_Female:
        {
            [userModel setGender:KIMUserGender_Female];
        }
            break;
        case KIMProtoUserGenderType_Unkown:
        default:
        {
            [userModel setGender:KIMUserGender_Unknown];
        }
            break;
    }
    [userModel setMood:[message mood]];
    [userModel setMtime:serverVersion];
    [self.moduleStateLock unlock];
    
    //发送通知：用户信息更新
    NSNotification * notification = [[NSNotification alloc] initWithName:KIMRosterModuleUserVCardUpdatedNotificationName object:nil userInfo:@{@"user":userModel.account}];
    if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
        [[NSNotificationCenter defaultCenter] postNotification:notification];
    }else{
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        }];
    }
}

-(void)updateCurrentUserVCard:(KIMUserVCard*)userVCard success:(UpdateCurrentUserVCardSuccess)successCallback failure:(UpdateCurrentUserVCardFailed)failedCallback
{
    [self.moduleStateLock lock];
    if (KIMRosterModuleState_Runing != self.moduleState) {
        if (failedCallback) {
            failedCallback(self,UpdateCurrentUserVCardFailedType_ModuleStoped);
        }
        [self.moduleStateLock unlock];
        return;
    }
    
    //1.检查是否有正在进行中的更新操作
    if (self.updatingUserVCardRequest) {
        if (failedCallback) {
            failedCallback(self,UpdateCurrentUserVCardFailedType_Updating);
        }
        [self.moduleStateLock unlock];
        return;
    }
    
    //2.检查参数
    if (![userVCard.user.account isEqualToString:self.currentUser.account]) {
        failedCallback(self,UpdateCurrentUserVCardFailedType_UserUnMatch);
        [self.moduleStateLock unlock];
        return;
    }
    
    //3.创建请求
    self.updatingUserVCardRequest = [[KIMRosterUpdateUserVCardRequest alloc] initWithUserVCard:userVCard completion:^(KIMRosterUpdateUserVCardRequest *request, KIMRosterUpdateUserVCardRequestState state) {
        
        switch (state) {
            case KIMRosterUpdateUserVCardRequestState_Success:
            {
                if (successCallback) {
                    successCallback(self);
                }
            }
                break;
            case KIMRosterUpdateUserVCardRequestState_Timeout:
            {
                if (failedCallback) {
                    failedCallback(self,UpdateCurrentUserVCardFailedType_Timeout);
                }
            }
                break;
            case KIMRosterUpdateUserVCardRequestState_ServerInternalError:
            default:
            {
                if (failedCallback) {
                    failedCallback(self,UpdateCurrentUserVCardFailedType_ServerInteralError);
                }
            }
                break;
        }
        
    } andCallbackQueue:NSOperationQueue.currentQueue];
    
    
    //4.发送请求消息
    KIMProtoUpdateUserVCardMessage * updateUserVCardMessage = [[KIMProtoUpdateUserVCardMessage alloc] init];
    [updateUserVCardMessage setNickname:[userVCard nickName]];
    switch ([userVCard gender]) {
        case KIMUserGender_Male:
        {
            [updateUserVCardMessage setGender:KIMProtoUserGenderType_Male];
        }
            break;
        case KIMUserGender_Female:
        {
            [updateUserVCardMessage setGender:KIMProtoUserGenderType_Female];
        }
            break;
        case KIMUserGender_Unknown:
        default:
        {
            [updateUserVCardMessage setGender:KIMProtoUserGenderType_Unkown];
        }
            break;
    }
    [updateUserVCardMessage setAvator:[userVCard avatar]];
    [updateUserVCardMessage setMood:[userVCard mood]];
    
    if (![self.imClient sendMessage:updateUserVCardMessage]) {
        self.updatingUserVCardRequest = nil;
        if (failedCallback) {
            failedCallback(self,UpdateCurrentUserVCardFailedType_NetworkError);
        }
    }else{
        //启动定时器
        __weak KIMRosterModule * weakSelf = self;
        self.updatingUserVCardRequestTimeoutTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:4] interval:0 repeats:NO block:^(NSTimer * _Nonnull timer) {
            //1.判断此更新是否执行完毕
            if (!weakSelf.updatingUserVCardRequest) {//请求处理完毕
                [timer invalidate];
                return;
            }
            
            if ([weakSelf.updatingUserVCardRequest.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                weakSelf.updatingUserVCardRequest.completion(weakSelf.updatingUserVCardRequest,KIMRosterUpdateUserVCardRequestState_Timeout);
            }else{
                KIMRosterUpdateUserVCardRequest * request = weakSelf.updatingUserVCardRequest;
                [weakSelf.updatingUserVCardRequest.callbackQueue addOperationWithBlock:^{
                    request.completion(request,KIMRosterUpdateUserVCardRequestState_Timeout);
                }];
            }
            weakSelf.updatingUserVCardRequest = nil;
            [weakSelf.updatingUserVCardRequestTimeoutTimer invalidate];
            weakSelf.updatingUserVCardRequestTimeoutTimer = nil;
            [timer invalidate];
        }];
        [[NSRunLoop mainRunLoop] addTimer:self.updatingUserVCardRequestTimeoutTimer forMode:NSDefaultRunLoopMode];
    }
    
    [self.moduleStateLock unlock];
    return;
}
-(void)handleUpdateUserVCardMessageResponse:(KIMProtoUpdateUserVCardMessageResponse*)message
{
    [self.moduleStateLock lock];
    if (KIMRosterModuleState_Runing != self.moduleState || !self.updatingUserVCardRequest) {
        [self.moduleStateLock unlock];
        return;
    }
    [self.updatingUserVCardRequestTimeoutTimer invalidate];
    self.updatingUserVCardRequestTimeoutTimer = nil;
    KIMUserVCard * updatingUserVCard = self.updatingUserVCardRequest.userVCard;
    
    switch (message.state) {
        case KIMProtoUpdateUserVCardMessageResponse_UpdateUserVCardStateType_Success:
        {
            //1.更新用户信息
            NSFetchRequest *fetchRequest = [KIMDBUser fetchRequest];
            
            fetchRequest.predicate = [NSPredicate predicateWithFormat:@"account == %@",updatingUserVCard.user.account];
            
            NSArray<KIMDBUser *> *userSet = [[self kimDBContext] executeFetchRequest:fetchRequest error:nil];
            KIMDBUser * userModel = nil;
            if ([userSet count]) {//存在，则更新
                userModel = [userSet firstObject];
            }else{//不存在，则添加
                userModel = [NSEntityDescription insertNewObjectForEntityForName:KIMDBUserEntityName inManagedObjectContext:[self kimDBContext]];
                userModel.account = updatingUserVCard.user.account;
            }
            [userModel setNickName:[updatingUserVCard nickName]];
            [userModel setAvatar:[updatingUserVCard avatar]];
            [userModel setGender:[updatingUserVCard gender]];
            [userModel setMood:[updatingUserVCard mood]];
            [userModel setMtime:[NSDate date]];
            //2.执行回调
            [self.moduleStateLock unlock];
            if ([self.updatingUserVCardRequest.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                self.updatingUserVCardRequest.completion(self.updatingUserVCardRequest, KIMRosterUpdateUserVCardRequestState_Success);
            }else{
                KIMRosterUpdateUserVCardRequest * request = self.updatingUserVCardRequest;
                [self.updatingUserVCardRequest.callbackQueue addOperationWithBlock:^{
                    request.completion(request, KIMRosterUpdateUserVCardRequestState_Success);
                }];
            }
            //3.发送通知：用户信息更新
            NSNotification * notification = [[NSNotification alloc] initWithName:KIMRosterModuleUserVCardUpdatedNotificationName object:nil userInfo:@{@"user":userModel.account}];
            if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
                [[NSNotificationCenter defaultCenter] postNotification:notification];
            }else{
                [NSOperationQueue.mainQueue addOperationWithBlock:^{
                    [[NSNotificationCenter defaultCenter] postNotification:notification];
                }];
            }
        }
            break;
        case KIMProtoUpdateUserVCardMessageResponse_UpdateUserVCardStateType_Failure:
        default:
        {
            //执行回调
            [self.moduleStateLock unlock];
            if ([self.updatingUserVCardRequest.callbackQueue isEqual:NSOperationQueue.currentQueue]) {
                self.updatingUserVCardRequest.completion(self.updatingUserVCardRequest, KIMRosterUpdateUserVCardRequestState_ServerInternalError);
            }else{
                KIMRosterUpdateUserVCardRequest * request = self.updatingUserVCardRequest;
                [self.updatingUserVCardRequest.callbackQueue addOperationWithBlock:^{
                    request.completion(request, KIMRosterUpdateUserVCardRequestState_ServerInternalError);
                }];
            }

        }
            break;
    }
    
    self.updatingUserVCardRequest = nil;
}

#pragma mark - 用户切换
-(void)imClientDidLogin:(KIMClient*)imClient withUser:(KIMUser*)user
{
    [self.moduleStateLock lock];
    if (KIMRosterModuleState_Runing == self.moduleState && [user isEqual:self.currentUser]) {
        [self.moduleStateLock unlock];
        return;
    }else{
        
        if (KIMRosterModuleState_Stop != self.moduleState) {//客户端以新的用户上线，但是对于上一个模块的下线并未通知
            //清空此当前用户的登录信息
            [self clearUserDataWhenLogined];
        }
        //切换用户
        self.currentUser = user;
        self.imClient = imClient;
        self.moduleState = KIMRosterModuleState_Runing;
        //获取当前用户的好友列表版本
        uint64_t currentUserFriendListVersion = [[self.userFriendListVersionDB objectForKey:self.currentUser.account] unsignedLongLongValue];
        //发送好友列表同步消息
        KIMProtoFriendListRequestMessage * friendListRequestMessage = [[KIMProtoFriendListRequestMessage alloc] init];
        [friendListRequestMessage setCurrentVersion:currentUserFriendListVersion];
        [self.imClient sendMessage:friendListRequestMessage];
        //检查当前用户的电子名片
        NSDate * userVCardMTime = [NSDate date];
        NSFetchRequest *fetchRequest = [KIMDBUser fetchRequest];
        
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"account == %@",user.account];
        
        NSArray<KIMDBUser *> *userSet = [[self kimDBContext] executeFetchRequest:fetchRequest error:nil];
        if ([userSet count]) {//存在，则更新
            userVCardMTime = [[userSet firstObject] mtime];
        }
        KIMProtoFetchUserVCardMessage * fetchUserVCardMessage = [[KIMProtoFetchUserVCardMessage alloc] init];
        [fetchUserVCardMessage setUserId:user.account];
        [fetchUserVCardMessage setCurrentVersion:[self.dateFormatter stringFromDate:userVCardMTime]];
        [self.imClient sendMessage:fetchUserVCardMessage];
        [self.moduleStateLock unlock];
    }
}
-(void)imClientDidLogout:(KIMClient*)imClient withUser:(KIMUser*)user
{
    [self.moduleStateLock lock];
    if (KIMRosterModuleState_Stop == self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    //清空此用户的登录信息
    [self clearUserDataWhenLogined];
    self.currentUser = nil;
    self.imClient = nil;
    self.moduleState = KIMRosterModuleState_Stop;
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
    [[NSUserDefaults standardUserDefaults] setObject:self.userFriendListVersionDB forKey:KIMUserFriendListVersionDBKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
-(void)clearUserDataWhenLogined
{
    [self.pendingFriendApplicationSet removeAllObjects];
    [self.pendingRosterDeleteFriendRequestSet removeAllObjects];
    self.updatingUserVCardRequest = nil;
    [self.updatingUserVCardRequestTimeoutTimer invalidate];
    self.updatingUserVCardRequestTimeoutTimer = nil;
}
@end
