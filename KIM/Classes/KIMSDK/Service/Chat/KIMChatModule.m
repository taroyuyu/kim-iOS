//
//  KIMChatModule.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/31.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMChatModule.h"
#import "KIMClient+Service.h"
#import "KakaImmessage.pbobjc.h"
#import <CoreData/CoreData.h>
#import <sys/time.h>
#import "KIMDB.h"
#import "KIMDBChatMessage+CoreDataProperties.h"
#import "KIMDBGroupChatMessage+CoreDataProperties.h"
#import "KIMChatSession+Internal.h"
#import "KIMChatGroupSession+Internal.h"

NSString * const KIMChatModuleReceivedChatMessageNotificationName = @"KIMChatModuleReceivedChatMessageNotification";
NSString * const KIMChatModuleReceivedGroupChatMessageNotificationName = @"KIMChatModuleReceivedGroupChatMessageNotification";

typedef NS_ENUM(NSUInteger,KIMChatModuleState)
{
    KIMChatModuleState_Stop,//停止运作
    KIMChatModuleState_Runing,//正在运作
};

@interface KIMChatModule()
#pragma mark - 模块相关属性
@property(nonatomic,strong)NSLock * moduleStateLock;
@property(nonatomic,assign)KIMChatModuleState moduleState;
@property(nonatomic,strong)NSDateFormatter *dateFormatter;
#pragma mark - KIMSession+Service相关
@property(nonatomic,weak)KIMClient * imClient;
@property(nonatomic,strong)NSSet<NSString*>* messageTypes;
#pragma mark - 数据存储相关
@property(nonatomic,strong)NSManagedObjectModel * kimDBModel;
@property(nonatomic,strong)NSPersistentStoreCoordinator *kimpDBPersistentStoreCoordinator;
@property(nonatomic,strong)NSManagedObjectContext *kimDBContext;
#pragma mark - 用户相关
@property(nonatomic,strong)KIMUser * currentUser;
@property(nonatomic,strong)NSMutableDictionary<NSString*,KIMChatSession*> * chatSessionSet;
@property(nonatomic,strong)NSMutableDictionary<NSString*,KIMChatGroupSession*> * chatGroupSessionSet;
@property(nonatomic,strong)NSMutableDictionary<NSString*,NSNumber*> * pendingMessageIdSet;
@property(nonatomic,strong)NSMutableDictionary<NSString*,NSNumber*> * pendingGroupMessageIdSet;
@property(nonatomic,strong)NSMutableSet<KIMChatSession*> * recentChatSessionList;
@property(nonatomic,strong)NSMutableSet<KIMChatGroupSession*> * recentChatGroupSessionList;
@end

@implementation KIMChatModule
-(instancetype)init
{
    self = [super init];
    if (self) {
        //模块相关属性
        self.moduleStateLock = [[NSLock alloc] init];
        self.moduleState = KIMChatModuleState_Stop;
        self.dateFormatter = [[NSDateFormatter alloc] init];
        self.dateFormatter.dateFormat = @"YYYY-MM-dd HH:mm:ss";
        self.dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
        //KIMSession+Service相关属性
        NSMutableSet<NSString*> * messageTypeSet = [[NSMutableSet<NSString*> alloc] init];
        [messageTypeSet addObject:[[KIMProtoChatMessage descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoGroupChatMessage descriptor]fullName]];
        self.messageTypes = [messageTypeSet copy];
        
        //数据存储相关
        self.kimDBModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"KIM" withExtension:@"momd"]];
        self.kimpDBPersistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self kimDBModel]];
        
        NSString * dbFileNameAbsolutePath = [NSString stringWithFormat:@"%@/%@",[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) firstObject],KIMDBFileName];
        NSError *error;
        [self.kimpDBPersistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL fileURLWithPath:dbFileNameAbsolutePath] options:nil error:&error];
        
        self.kimDBContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        
        [self.kimDBContext setPersistentStoreCoordinator:[self kimpDBPersistentStoreCoordinator]];
        
        //用户相关
        self.chatSessionSet = [NSMutableDictionary<NSString*,KIMChatSession*> dictionary];
        self.chatGroupSessionSet = [NSMutableDictionary<NSString*,KIMChatGroupSession*> dictionary];
        self.pendingMessageIdSet = [NSMutableDictionary<NSString*,NSNumber*> dictionary];
        self.pendingGroupMessageIdSet = [NSMutableDictionary<NSString*,NSNumber*> dictionary];
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
    if(![self.messageTypes containsObject:messageType]){
        return;
    }
    
    if ([messageType isEqualToString: [[KIMProtoChatMessage descriptor] fullName]]) {
        [self handleChatMessage:(KIMProtoChatMessage*)message];
    }else if ([messageType isEqualToString: [[KIMProtoGroupChatMessage descriptor] fullName]]) {
        [self handleGroupChatMessage:(KIMProtoGroupChatMessage*)message];
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
-(int64_t)nextMessageId
{
    //1.从数据库中获取下一条消息可用的消息Id
    NSFetchRequest *fetchRequest = [KIMDBChatMessage fetchRequest];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND messageId < 0",self.currentUser.account];
    [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"messageId" ascending:NO]]];
    [fetchRequest setFetchLimit:1];
    NSArray<KIMDBChatMessage *> *messageSet = [[self kimDBContext] executeFetchRequest:fetchRequest error:nil];
    if ([messageSet count]) {
        int64_t messageId = [[messageSet firstObject] messageId];
        if (messageId < 0) {
            return messageId + 1;
        }else{
            return INT64_MIN;
        }
    }else{
        return INT64_MIN;
    }
}

-(int64_t)nextGroupChatMessageId:(NSString*)groupId
{
    //1.从数据库中获取下一条消息可用的消息Id
    NSFetchRequest *fetchRequest = [KIMDBGroupChatMessage fetchRequest];
    
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND groupId == %@",self.currentUser.account,groupId];
    [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"messageId" ascending:NO]]];
    [fetchRequest setFetchLimit:1];
    NSArray<KIMDBGroupChatMessage *> *messageSet = [[self kimDBContext] executeFetchRequest:fetchRequest error:nil];
    if ([messageSet count]) {
        int64_t messageId = [[messageSet firstObject] messageId];
        if (messageId < 0) {
            return messageId + 1;
        }else{
            return INT64_MIN;
        }
    }else{
        return INT64_MIN;
    }
}

#pragma mark - 会话相关
-(KIMChatSession*)getSessionWithUser:(KIMUser*)opponent
{
    if (!opponent) {
        return nil;
    }
    [self.moduleStateLock lock];
    if (KIMChatModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return nil;
    }
    
    KIMChatSession * chatSession = [[self chatSessionSet] objectForKey:opponent.account];
    
    if (chatSession) {
        [self.moduleStateLock unlock];
        return chatSession;
    }else{
        chatSession = [[KIMChatSession alloc] initWithCurrentUser:self.currentUser andOpponent:opponent chatModule:self];
        [self.chatSessionSet setObject:chatSession forKey:opponent.account];
        [self.moduleStateLock unlock];
        return chatSession;
    }
}
-(KIMChatGroupSession*)getChatGroupSession:(KIMChatGroup*)chatGroup
{
    if (!chatGroup) {
        return nil;
    }
    [self.moduleStateLock lock];
    if (KIMChatModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return nil;
    }
    
    KIMChatGroupSession * chatGroupSession = [[self chatGroupSessionSet] objectForKey:[chatGroup groupId]];
    
    if (chatGroupSession) {
        [self.moduleStateLock unlock];
        return chatGroupSession;
    }else{
        chatGroupSession = [[KIMChatGroupSession alloc] initWithCurrentUser:self.currentUser andChatGroup:chatGroup chatModule:self];
        [self.chatGroupSessionSet setObject:chatGroupSession forKey:chatGroup.groupId];
        [self.moduleStateLock unlock];
        return chatGroupSession;
    }
}

#pragma mark - 单聊消息
-(BOOL)sendChatMessage:(KIMChatMessage*)chatMessage fromSession:(KIMChatSession*)chatSession
{
    if (![chatSession.currentUser.account isEqualToString:self.currentUser.account]) {
        return NO;
    }
    [self.moduleStateLock lock];
    if (KIMChatModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return NO;
    }
    [[self recentChatSessionList] addObject:chatSession];
    //1.将消息保存到数据库中
    int64_t messageId = [self nextMessageId];
    NSString * messageIdentifier = [self nextMessageIdentifier];
    NSDate * currentDate = [NSDate date];
    KIMDBChatMessage * chatMessageModel = [NSEntityDescription insertNewObjectForEntityForName:KIMDBChatMessageEntityName inManagedObjectContext:[self kimDBContext]];
    [chatMessageModel setUserDomain:self.currentUser.account];
    [chatMessageModel setSenderAccount:self.currentUser.account];
    [chatMessageModel setReceiverAccount:chatSession.opponent.account];
    [chatMessageModel setContent:chatMessage.content];
    [chatMessageModel setTimestamp:currentDate];
    [chatMessageModel setState:KIMChatMessageState_Sending];
    [chatMessageModel setMessageId:messageId];
    
    //2.发送消息
    KIMProtoChatMessage * message = [[KIMProtoChatMessage alloc] init];
    [message setSenderAccount:chatMessageModel.senderAccount];
    [message setReceiverAccount:chatMessageModel.receiverAccount];
    [message setContent:chatMessageModel.content];
    [message setTimestamp:[[self dateFormatter]stringFromDate:currentDate]];
    [message setSign:messageIdentifier];
    
    if ([self.imClient sendMessage:message]) {
        //3.记录messageId与messageIdentifier之间的映射关系
        [self.pendingMessageIdSet setObject:[NSNumber numberWithLongLong:messageId] forKey:messageIdentifier];
        chatMessage.messageId = messageId;
        [self.moduleStateLock unlock];
        return YES;
    }else{
        //4.删除此消息
        [self.kimDBContext deleteObject:chatMessageModel];
        [self.moduleStateLock unlock];
        return NO;
    }
}
-(void)handleChatMessage:(KIMProtoChatMessage*)message
{
    [self.moduleStateLock lock];
    if (KIMChatModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    
    NSNumber * messageIdNumber = [[self pendingMessageIdSet] objectForKey:[message sign]];
    [self.pendingMessageIdSet removeObjectForKey:message.sign];
    if (nil != messageIdNumber) {//此消息是由本设备所发出的
        [[self pendingMessageIdSet] removeObjectForKey:[message sign]];
        //1.同步到数据库:服务器已经接收到
        NSFetchRequest * chatMessageFetchRequest = [KIMDBChatMessage fetchRequest];
        chatMessageFetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND messageId == %lld",self.currentUser.account,[messageIdNumber longLongValue]];
        [chatMessageFetchRequest setFetchLimit:1];
        NSArray<KIMDBChatMessage *> *messageSet = [[self kimDBContext] executeFetchRequest:chatMessageFetchRequest error:nil];
        [[messageSet firstObject] setMessageId:[message messageId]];
        [[messageSet firstObject] setState:KIMChatMessageState_Received];
    }else{//此消息不是由本设备所发出的
        //1.同步到数据库
        KIMDBChatMessage * messageModel = [NSEntityDescription insertNewObjectForEntityForName:KIMDBChatMessageEntityName inManagedObjectContext:[self kimDBContext]];
        [messageModel setUserDomain:self.currentUser.account];
        [messageModel setMessageId:[message messageId]];
        [messageModel setSenderAccount:[message senderAccount]];
        [messageModel setReceiverAccount:[message receiverAccount]];
        [messageModel setContent:[message content]];
        [messageModel setTimestamp:[[self dateFormatter]dateFromString:[message timestamp]]];
        [messageModel setState:KIMChatMessageState_FromServer];
        //2.发布通知:接收到一条消息
        NSNotification * notification = [[NSNotification alloc] initWithName:KIMChatModuleReceivedChatMessageNotificationName object:nil userInfo:@{@"sender":messageModel.senderAccount,@"receiver":messageModel.receiverAccount,@"content":messageModel.content,@"messageId":[NSNumber numberWithUnsignedLongLong:message.messageId]}];
        if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        }else{
            [NSOperationQueue.mainQueue addOperationWithBlock:^{
                [[NSNotificationCenter defaultCenter] postNotification:notification];
            }];
        }
        //3.通知ChatSession
        NSString * opponentAccount = nil;
        
        if ([self.currentUser.account isEqualToString: [message receiverAccount]]) {
            opponentAccount = message.senderAccount;
        }else if([self.currentUser.account isEqualToString:[message senderAccount]]){
            opponentAccount = messageModel.receiverAccount;
        }else{
            [self.moduleStateLock unlock];
            [self.kimDBContext deleteObject:messageModel];
            return;
        }
        
        KIMChatSession * chatSession = [[self chatSessionSet] objectForKey:opponentAccount];
        
        if (!chatSession) {
            chatSession = [[KIMChatSession alloc] initWithCurrentUser:self.currentUser andOpponent:[[KIMUser alloc]initWithUserAccount:opponentAccount] chatModule:self];
            [[self chatSessionSet] setValue:chatSession forKey:opponentAccount];
        }
        
        [self.recentChatSessionList addObject:chatSession];
        
        KIMChatMessage * chatMessage = [[KIMChatMessage alloc] init];
        chatMessage.sender = [[KIMUser alloc] initWithUserAccount:messageModel.senderAccount];
        chatMessage.receiver = [[KIMUser alloc] initWithUserAccount:messageModel.receiverAccount];
        chatMessage.content = messageModel.content;
        chatMessage.timestamp = messageModel.timestamp;
        chatMessage.messageId = messageModel.messageId;
        chatMessage.state = KIMChatMessageState_FromServer;
        chatMessage.type = KIMChatMessageType_Text;
        
        [chatSession didReceiveMessage:chatMessage FromChatModule:self];
    }
    
    [self.moduleStateLock unlock];
    return;
}
-(void)loadLastedChatMessageWithUser:(KIMUser*)opponent maxCount:(NSUInteger)maxCount completion:(void(^)(KIMChatModule * chatModule,NSArray<KIMChatMessage*> * messageList))completionBlock
{
    
    if (!completionBlock) {
        return;
    }
    
    __weak KIMChatModule * weakSelf = self;
    NSString * userDomain = self.currentUser.account;
    [self.kimDBContext performBlock:^{
        NSFetchRequest * chatMessageFetchRequest = [KIMDBChatMessage fetchRequest];
        
        chatMessageFetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND (senderAccount == %@ OR receiverAccount == %@) AND messageId > 0",userDomain,opponent.account,opponent.account];
        [chatMessageFetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"messageId" ascending:NO]]];
        [chatMessageFetchRequest setFetchLimit:maxCount];
        NSArray<KIMDBChatMessage *> *messageSet = [[self kimDBContext] executeFetchRequest:chatMessageFetchRequest error:nil];
        
        if (![messageSet count]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(weakSelf,[NSArray<KIMChatMessage*> array]);
            });
        }else{
            NSMutableArray<KIMChatMessage*> * chatMessageList = [NSMutableArray<KIMChatMessage*> array];
            for (KIMDBChatMessage * chatMessageModel in messageSet) {
                
                KIMChatMessage * chatMessage = [[KIMChatMessage alloc] init];
                chatMessage.type = KIMChatMessageType_Text;
                chatMessage.state = chatMessageModel.state;
                chatMessage.sender = [[KIMUser alloc] initWithUserAccount:chatMessageModel.senderAccount];
                chatMessage.receiver = [[KIMUser alloc] initWithUserAccount:chatMessageModel.receiverAccount];
                chatMessage.content = chatMessageModel.content;
                chatMessage.timestamp = chatMessageModel.timestamp;
                chatMessage.messageId = chatMessageModel.messageId;
                
                [chatMessageList addObject:chatMessage];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(weakSelf,[chatMessageList copy]);
            });
        }
        
    }];
}
-(void)loadChatMessageWithUser:(KIMUser*)opponent maxCount:(NSUInteger)maxCount maxMessageId:(uint64_t)maxMessageId completion:(void(^)(KIMChatModule * chatModule,NSArray<KIMChatMessage*> * messageList))completionBlock
{
    if (!completionBlock) {
        return;
    }
    
    __weak KIMChatModule * weakSelf = self;
    NSString * userDomain = self.currentUser.account;
    [self.kimDBContext performBlock:^{
        
        NSFetchRequest * chatMessageFetchRequest = [KIMDBChatMessage fetchRequest];
        chatMessageFetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND (senderAccount == %@ OR receiverAccount == %@) AND 0 < messageId AND messageId < %llu",userDomain,opponent.account,opponent.account,maxMessageId];
        [chatMessageFetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"messageId" ascending:NO]]];
        [chatMessageFetchRequest setFetchLimit:maxCount];
        NSArray<KIMDBChatMessage *> *messageSet = [[self kimDBContext] executeFetchRequest:chatMessageFetchRequest error:nil];
        
        if (![messageSet count]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(weakSelf,[NSArray<KIMChatMessage*> array]);
            });
        }else{
            NSMutableArray<KIMChatMessage*> * chatMessageList = [NSMutableArray<KIMChatMessage*> array];
            for (KIMDBChatMessage * chatMessageModel in messageSet) {
                
                KIMChatMessage * chatMessage = [[KIMChatMessage alloc] init];
                chatMessage.type = KIMChatMessageType_Text;
                chatMessage.state = chatMessageModel.state;
                chatMessage.sender = [[KIMUser alloc] initWithUserAccount:chatMessageModel.senderAccount];
                chatMessage.receiver = [[KIMUser alloc] initWithUserAccount:chatMessageModel.receiverAccount];
                chatMessage.content = chatMessageModel.content;
                chatMessage.timestamp = chatMessageModel.timestamp;
                chatMessage.messageId = chatMessageModel.messageId;
                
                [chatMessageList addObject:chatMessage];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(weakSelf,[chatMessageList copy]);
            });
        }
    }];
}
#pragma mark - 群聊消息
-(BOOL)sendChatGroupMessage:(KIMChatGroupMessage*)chatGroupMessage fromSession:(KIMChatGroupSession*)chatGroupSession
{
    if (!(chatGroupMessage && [chatGroupSession.currentUser.account isEqualToString:self.currentUser.account])) {
        return NO;
    }
    [self.moduleStateLock lock];
    if (KIMChatModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return NO;
    }
    [self.recentChatGroupSessionList addObject:chatGroupSession];
    
    //1.同步到数据库
    NSDate * currentDate = [NSDate date];
    int64_t messageId = [self nextGroupChatMessageId:chatGroupSession.currentChatGroup.groupId];
    KIMDBGroupChatMessage * groupChatMessageModel = [NSEntityDescription insertNewObjectForEntityForName:KIMDBGroupChatMessageEntityName inManagedObjectContext:[self kimDBContext]];
    [groupChatMessageModel setUserDomain:self.currentUser.account];
    [groupChatMessageModel setGroupId:chatGroupSession.currentChatGroup.groupId];
    [groupChatMessageModel setSenderAccount:self.currentUser.account];
    [groupChatMessageModel setContent:chatGroupMessage.content];
    [groupChatMessageModel setTimestamp:currentDate];
    [groupChatMessageModel setState:KIMChatGroupMessageState_Sending];
    [groupChatMessageModel setMessageId:messageId];
    
    //2.发送GroupChatMessage
    NSString * messageIdentifier = [self nextMessageIdentifier];
    KIMProtoGroupChatMessage * message = [[KIMProtoGroupChatMessage alloc] init];
    [message setSender:groupChatMessageModel.senderAccount];
    [message setGroupId:groupChatMessageModel.groupId];
    [message setContent:groupChatMessageModel.content];
    [message setTimestamp:[[self dateFormatter]stringFromDate:currentDate]];
    [message setSign:messageIdentifier];
    if ([self.imClient sendMessage:message]) {
        //3.记录messageId与messageIdentifier之间的映射关系
        [[self pendingGroupMessageIdSet] setObject:[NSNumber numberWithLongLong:messageId] forKey:messageIdentifier];
        [self.moduleStateLock unlock];
        return YES;
    }else{
        [self.kimDBContext deleteObject:groupChatMessageModel];
        [self.moduleStateLock unlock];
        return NO;
    }
}
-(void)handleGroupChatMessage:(KIMProtoGroupChatMessage*)message
{
    [self.moduleStateLock lock];
    if (KIMChatModuleState_Runing != self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    
    NSNumber * messageIdNumber = [self.pendingGroupMessageIdSet valueForKey:message.sign];
    [self.pendingGroupMessageIdSet objectForKey:message.sign];
    
    if (nil != messageIdNumber) {//由本设备发出
        //同步到数据库
        NSFetchRequest * groupChatMessageFetchRequest = [KIMDBGroupChatMessage fetchRequest];
        groupChatMessageFetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND groupId == %@ AND messageId == %lld",self.currentUser.account,message.groupId,[messageIdNumber longLongValue]];
        [groupChatMessageFetchRequest setFetchLimit:1];
        NSArray<KIMDBGroupChatMessage *> *messageSet = [[self kimDBContext] executeFetchRequest:groupChatMessageFetchRequest error:nil];
        [[messageSet firstObject] setMessageId:[message msgId]];
        [[messageSet firstObject] setState:KIMChatGroupMessageState_Received];
    }else{
        //1.同步到数据库
        KIMDBGroupChatMessage * groupChatMessageModel = [NSEntityDescription insertNewObjectForEntityForName:KIMDBGroupChatMessageEntityName inManagedObjectContext:[self kimDBContext]];
        [groupChatMessageModel setUserDomain:self.currentUser.account];
        [groupChatMessageModel setGroupId:[message groupId]];
        [groupChatMessageModel setSenderAccount:[message sender]];
        [groupChatMessageModel setContent:[message content]];
        [groupChatMessageModel setTimestamp:[[self dateFormatter]dateFromString:[message timestamp]]];
        [groupChatMessageModel setState:KIMChatGroupMessageState_FromServer];
        [groupChatMessageModel setMessageId:message.msgId];
        
        //2.发布通知
        NSNotification * notification = [[NSNotification alloc] initWithName:KIMChatModuleReceivedGroupChatMessageNotificationName object:nil userInfo:@{@"sender":groupChatMessageModel.senderAccount,@"groupId":groupChatMessageModel.groupId,@"content":groupChatMessageModel.content,@"messageId":[NSNumber numberWithUnsignedLongLong:groupChatMessageModel.messageId]}];
        if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        }else{
            [NSOperationQueue.mainQueue addOperationWithBlock:^{
                [[NSNotificationCenter defaultCenter] postNotification:notification];
            }];
        }
        //3.通知ChatSession
        KIMChatGroupMessage * chatGroupMessage = [[KIMChatGroupMessage alloc] init];
        chatGroupMessage.group = [[KIMChatGroup alloc]initWithGroupId:message.groupId];
        chatGroupMessage.sender = [[KIMUser alloc] initWithUserAccount:message.sender];
        chatGroupMessage.content = message.content;
        chatGroupMessage.timestamp = groupChatMessageModel.timestamp;
        chatGroupMessage.messageId = groupChatMessageModel.messageId;
        chatGroupMessage.state = KIMChatGroupMessageState_FromServer;
        chatGroupMessage.type = KIMChatGroupMessageType_Text;
        
        KIMChatGroupSession * chatGroupSession = [[self chatGroupSessionSet] objectForKey:[message groupId]];
        
        if (!chatGroupSession) {
            chatGroupSession = [[KIMChatGroupSession alloc] initWithCurrentUser:self.currentUser andChatGroup:[[KIMChatGroup alloc]initWithGroupId:message.groupId] chatModule:self];
            [self.chatGroupSessionSet setObject:chatGroupSession forKey:message.groupId];
        }
        
        [self.recentChatGroupSessionList addObject:chatGroupSession];
        [chatGroupSession didReceiveMessage:chatGroupMessage FromChatModule:self];
    }
    
    [self.moduleStateLock unlock];
}
-(void)loadLastedChatGroupMessage:(KIMChatGroup*)chatGroup maxCount:(NSUInteger)maxCount completion:(void(^)(KIMChatModule * chatModule,NSArray<KIMChatGroupMessage*> * messageList))completionBlock
{
    if (!completionBlock) {
        return;
    }
    NSString * userDomain = self.currentUser.account;
    __weak KIMChatModule * weakSelf = self;
    [self.kimDBContext performBlock:^{
        NSFetchRequest * groupChatMessageFetchRequest = [KIMDBGroupChatMessage fetchRequest];
        
        groupChatMessageFetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND groupId == %@ AND messageId > 0 ",userDomain,chatGroup.groupId];
        [groupChatMessageFetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"messageId" ascending:NO]]];
        
        NSArray<KIMDBChatMessage *> *messageSet = [[self kimDBContext] executeFetchRequest:groupChatMessageFetchRequest error:nil];
        
        if (![messageSet count]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(weakSelf,[NSArray<KIMChatGroupMessage*> array]);
            });
        }else{
            NSMutableArray<KIMChatGroupMessage*> * chatGroupMessageList = [NSMutableArray<KIMChatGroupMessage*> array];
            for (KIMDBGroupChatMessage * messageModel in messageSet) {
                KIMChatGroupMessage * chatGroupMessage = [[KIMChatGroupMessage alloc] init];
                chatGroupMessage.type = KIMChatGroupMessageType_Text;
                chatGroupMessage.state = messageModel.state;
                chatGroupMessage.sender = [[KIMUser alloc] initWithUserAccount:messageModel.senderAccount];
                chatGroupMessage.group = [[KIMChatGroup alloc] initWithGroupId:messageModel.groupId];
                chatGroupMessage.content = messageModel.content;
                chatGroupMessage.timestamp = messageModel.timestamp;
                chatGroupMessage.messageId = messageModel.messageId;
                [chatGroupMessageList addObject:chatGroupMessage];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(weakSelf,[chatGroupMessageList copy]);
            });
        }
    }];
}
-(void)loadChatGroupMessage:(KIMChatGroup*)chatGroup maxCount:(NSUInteger)maxCount maxMessageId:(uint64_t)maxMessageId completion:(void(^)(KIMChatModule * chatModule,NSArray<KIMChatGroupMessage*> * messageList))completionBlock
{
    if (!completionBlock) {
        return;
    }
    NSString * userDomain = self.currentUser.account;
    __weak KIMChatModule * weakSelf = self;
    [self.kimDBContext performBlock:^{
        NSFetchRequest * groupChatMessageFetchRequest = [KIMDBGroupChatMessage fetchRequest];
        
        groupChatMessageFetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND groupId == %@ AND 0 < messageId AND messageId < %llu ",userDomain,chatGroup.groupId,maxMessageId];
        [groupChatMessageFetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"messageId" ascending:NO]]];
        
        NSArray<KIMDBChatMessage *> *messageSet = [[self kimDBContext] executeFetchRequest:groupChatMessageFetchRequest error:nil];
        
        if (![messageSet count]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(weakSelf,[NSArray<KIMChatGroupMessage*> array]);
            });
        }else{
            NSMutableArray<KIMChatGroupMessage*> * chatGroupMessageList = [NSMutableArray<KIMChatGroupMessage*> array];
            for (KIMDBGroupChatMessage * messageModel in messageSet) {
                KIMChatGroupMessage * chatGroupMessage = [[KIMChatGroupMessage alloc] init];
                chatGroupMessage.type = KIMChatGroupMessageType_Text;
                chatGroupMessage.state = messageModel.state;
                chatGroupMessage.sender = [[KIMUser alloc] initWithUserAccount:messageModel.senderAccount];
                chatGroupMessage.group = [[KIMChatGroup alloc] initWithGroupId:messageModel.groupId];
                chatGroupMessage.content = messageModel.content;
                chatGroupMessage.timestamp = messageModel.timestamp;
                chatGroupMessage.messageId = messageModel.messageId;
                [chatGroupMessageList addObject:chatGroupMessage];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(weakSelf,[chatGroupMessageList copy]);
            });
        }
    }];
}
#pragma mark - 用户切换
-(void)imClientDidLogin:(KIMClient*)imClient withUser:(KIMUser*)user
{
    [self.moduleStateLock lock];
    if (KIMChatModuleState_Runing == self.moduleState && [user isEqual:self.currentUser]) {
        [self.moduleStateLock unlock];
        return;
    }else{
        
        if (KIMChatModuleState_Stop != self.moduleState) {//客户端以新的用户上线，但是对于上一个模块的下线并未通知
            //清空此当前用户的登录信息
            [self clearUserDataWhenLogined];
        }
        //切换用户
        self.currentUser = user;
        self.imClient = imClient;
        self.moduleState = KIMChatModuleState_Runing;
        //加载用户数据
        [self loadData];
        //进行消息同步
        __weak KIMChatModule * weakSelf = self;
        NSString * userDomain = user.account;
        [self.kimDBContext performBlock:^{
            NSFetchRequest *fetchRequest = [KIMDBChatMessage fetchRequest];
            
            fetchRequest.predicate = [NSPredicate predicateWithFormat:@"userDomain == %@ AND messageId > 0",userDomain];
            [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"messageId" ascending:NO]]];
            [fetchRequest setFetchLimit:1];
            NSArray<KIMDBChatMessage *> *messageSet = [[self kimDBContext] executeFetchRequest:fetchRequest error:nil];
            int64_t syncPoint = 0;
            if (messageSet.firstObject) {
                syncPoint = messageSet.firstObject.messageId;
            }
            
            if ([weakSelf.currentUser.account isEqualToString:userDomain] && KIMChatModuleState_Runing == weakSelf.moduleState) {
                KIMProtoPullChatMessage * pullChatMessage = [[KIMProtoPullChatMessage alloc] init];
                pullChatMessage.messageId = syncPoint;
                [weakSelf.imClient sendMessage:pullChatMessage];
            }
        }];
        [self.moduleStateLock unlock];
    }
}
-(void)imClientDidLogout:(KIMClient*)imClient withUser:(KIMUser*)user
{
    //清空所有待确认的消息
    [self.moduleStateLock lock];
    if (KIMChatModuleState_Stop == self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    
    //保用数据
    [self syncData];
    //清空此用户的登录信息
    [self clearUserDataWhenLogined];
    self.currentUser = nil;
    self.imClient = nil;
    self.moduleState = KIMChatModuleState_Stop;
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
NSString * KIMRecentChatSessionListKey = @"KIMRecentChatSessionList";
NSString * KIMRecentChatGroupSessionListKey = @"KIMRecentChatGroupSessionList";
-(void)syncData
{
    [self.kimDBContext save:nil];
    //最近单聊列表
    NSMutableDictionary<NSString*,NSMutableSet<KIMChatSession*>*> * recentChatSessionListDB = nil;
    NSData * RecentChatSessionListDBData = [NSUserDefaults.standardUserDefaults objectForKey:KIMRecentChatSessionListKey];
    if (RecentChatSessionListDBData) {
        recentChatSessionListDB = [NSKeyedUnarchiver unarchiveObjectWithData:RecentChatSessionListDBData];
    }
    if (!recentChatSessionListDB) {
        recentChatSessionListDB = [NSMutableDictionary<NSString*,NSMutableSet<KIMChatSession*>*> dictionary];
    }
    if (!self.recentChatSessionList) {
        self.recentChatSessionList = [NSMutableSet<KIMChatSession*> set];
    }
    [recentChatSessionListDB setObject:self.recentChatSessionList forKey:self.currentUser.account];
    [NSUserDefaults.standardUserDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:recentChatSessionListDB] forKey:KIMRecentChatSessionListKey];
    //最近群聊列表
    NSMutableDictionary<NSString*,NSMutableSet<KIMChatGroupSession*>*> * recentChatGroupSessionListDB = nil;
    NSData * RecentChatGroupSessionListDBData = [NSUserDefaults.standardUserDefaults objectForKey:KIMRecentChatGroupSessionListKey];
    if (RecentChatGroupSessionListDBData) {
        recentChatGroupSessionListDB = [NSKeyedUnarchiver unarchiveObjectWithData:RecentChatGroupSessionListDBData];
    }
    
    if (!recentChatGroupSessionListDB) {
        recentChatGroupSessionListDB = [NSMutableDictionary<NSString*,NSMutableSet<KIMChatGroupSession*>*> dictionary];
    }
    [recentChatGroupSessionListDB setObject:self.recentChatGroupSessionList forKey:self.currentUser.account];
    [NSUserDefaults.standardUserDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:recentChatGroupSessionListDB] forKey:KIMRecentChatGroupSessionListKey];
}
-(void)loadData
{
    //最近单聊列表
    NSMutableDictionary<NSString*,NSMutableSet<KIMChatSession*>*> * recentChatSessionListDB = nil;
    NSData * RecentChatSessionListDBData = [NSUserDefaults.standardUserDefaults objectForKey:KIMRecentChatSessionListKey];
    if (RecentChatSessionListDBData) {
        recentChatSessionListDB = [NSKeyedUnarchiver unarchiveObjectWithData:RecentChatSessionListDBData];
    }
    if (!recentChatSessionListDB) {
        recentChatSessionListDB = [NSMutableDictionary<NSString*,NSMutableSet<KIMChatSession*>*> dictionary];
    }
    
    self.recentChatSessionList = [recentChatSessionListDB objectForKey:self.currentUser.account];
    if (!self.recentChatSessionList) {
        self.recentChatSessionList = [NSMutableSet<KIMChatSession*> set];
    }
    
    for (KIMChatSession * chatSession in self.recentChatSessionList) {
        [chatSession setChatModule:self];
        //建立映射关系
        [self.chatSessionSet setObject:chatSession forKey:chatSession.opponent.account];
    }
    
    
    //最近群聊列表
    NSMutableDictionary<NSString*,NSMutableSet<KIMChatGroupSession*>*> * recentChatGroupSessionListDB = nil;
    NSData * RecentChatGroupSessionListDBData = [NSUserDefaults.standardUserDefaults objectForKey:KIMRecentChatGroupSessionListKey];
    if (RecentChatGroupSessionListDBData) {
        recentChatGroupSessionListDB = [NSKeyedUnarchiver unarchiveObjectWithData:RecentChatGroupSessionListDBData];
    }
    
    if (!recentChatGroupSessionListDB) {
        recentChatGroupSessionListDB = [NSMutableDictionary<NSString*,NSMutableSet<KIMChatGroupSession*>*> dictionary];
    }
    
    self.recentChatGroupSessionList = [recentChatGroupSessionListDB objectForKey:self.currentUser.account];
    if (!self.recentChatGroupSessionList) {
        self.recentChatGroupSessionList = [NSMutableSet<KIMChatGroupSession*> set];
    }
    
    for (KIMChatGroupSession * chatGroupSession in self.recentChatGroupSessionList) {
        [chatGroupSession setChatModule:self];
        //建立映射关系
        [self.chatGroupSessionSet setObject:chatGroupSession forKey:chatGroupSession.currentChatGroup.groupId];
    }
    
}
-(void)clearUserDataWhenLogined
{
    [self.chatSessionSet removeAllObjects];
    [self.chatGroupSessionSet removeAllObjects];
    [self.pendingMessageIdSet removeAllObjects];
    [self.pendingGroupMessageIdSet removeAllObjects];
    [self.recentChatSessionList removeAllObjects];
    [self.recentChatGroupSessionList removeAllObjects];
}
@end
