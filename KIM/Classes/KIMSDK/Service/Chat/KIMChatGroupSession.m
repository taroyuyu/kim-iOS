//
//  KIMChatGroupSession.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/31.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMChatGroupSession.h"
#import "KIMChatModule+Internal.h"
@interface KIMChatGroupSession()
@property(nonatomic,strong)KIMUser * currentUser;
@property(nonatomic,strong)KIMChatGroup * currentChatGroup;
@property(nonatomic,weak)KIMChatModule * chatModule;
@end

@implementation KIMChatGroupSession
-(instancetype)initWithCurrentUser:(KIMUser*)currentUser andChatGroup:(KIMChatGroup*)chatGroup chatModule:(KIMChatModule*)chatModule
{
    if (!(currentUser && chatGroup && chatModule)) {
        return nil;
    }
    
    self = [super init];
    
    if (self) {
        self.currentUser = currentUser;
        self.currentChatGroup = chatGroup;
        self.chatModule = chatModule;
    }
    
    return self;
    
}
NSString * KIMChatGroupSessionCurrentUserKey = @"CurrentUser";
NSString * KIMChatGroupSessionCurrentChatGroupKey = @"CurrentChatGroup";
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (self.currentUser) {
        [aCoder encodeObject:self.currentUser forKey:KIMChatGroupSessionCurrentUserKey];
    }
    
    if (self.currentChatGroup) {
        [aCoder encodeObject:self.currentChatGroup forKey:KIMChatGroupSessionCurrentChatGroupKey];
    }
}
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    
    if (self) {
        self.currentUser = [aDecoder decodeObjectForKey:KIMChatGroupSessionCurrentUserKey];
        self.currentChatGroup = [aDecoder decodeObjectForKey:KIMChatGroupSessionCurrentChatGroupKey];
    }
    
    return self;
}
-(KIMChatGroupMessage*)sendTextMessage:(NSString*)textMessage
{
    if (!textMessage.length) {
        return nil;
    }
    
    KIMChatGroupMessage * chatGroupMessage = [[KIMChatGroupMessage alloc] init];
    chatGroupMessage.type = KIMChatGroupMessageType_Text;
    chatGroupMessage.state = KIMChatGroupMessageState_Sending;
    chatGroupMessage.sender = self.currentUser;
    chatGroupMessage.group = self.currentChatGroup;
    chatGroupMessage.content = textMessage;
    chatGroupMessage.timestamp = [NSDate date];
    if (![self.chatModule sendChatGroupMessage:chatGroupMessage fromSession:self]) {
        return nil;
    }
    
    return chatGroupMessage;
}
-(void)didReceiveMessage:(KIMChatGroupMessage*)chatGroupMessage FromChatModule:(KIMChatModule*)chatModule
{
    if (chatModule != [self chatModule]) {
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(didChatGroupSessionReceivedMessage:message:)]) {
        if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
            [self.delegate didChatGroupSessionReceivedMessage:self message:chatGroupMessage];
        }else{
            __weak KIMChatGroupSession * weakSelf = self;
            [NSOperationQueue.mainQueue addOperationWithBlock:^{
                [weakSelf.delegate didChatGroupSessionReceivedMessage:weakSelf message:chatGroupMessage];
            }];
        }
    }
}
/**
 * @description 加载最新的消息
 * @param maxCount 本次最多加载多少条
 */
-(void)loadLastedMessageWithMaxCount:(NSUInteger)maxCount completion:(void(^)(KIMChatGroupSession * chatGroupSession,NSArray<KIMChatGroupMessage*> * messageList))completionBlock
{
    if (!completionBlock) {
        return;
    }
    __weak KIMChatGroupSession * weakSelf = self;
    [self.chatModule loadLastedChatGroupMessage:self.currentChatGroup maxCount:maxCount completion:^(KIMChatModule * chatModule,NSArray<KIMChatGroupMessage *> *messageList) {
        if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
            completionBlock(weakSelf,messageList);
        }else{
            [NSOperationQueue.mainQueue addOperationWithBlock:^{
                completionBlock(weakSelf,messageList);
            }];
        }
    }];
}
/**
 * @description 加载消息
 * @param maxCount 本次最多加载多少条
 * @param maxMessageId 消息Id的最大值
 */
-(void)loadMessage:(NSUInteger)maxCount withMaxMessageId:(uint64_t)maxMessageId completion:(void(^)(KIMChatGroupSession * chatGroupSession,NSArray<KIMChatGroupMessage*> * messageList))completionBlock
{
    if (!completionBlock) {
        return;
    }
    __weak KIMChatGroupSession * weakSelf = self;
    [self.chatModule loadChatGroupMessage:self.currentChatGroup maxCount:maxCount maxMessageId:maxMessageId completion:^(KIMChatModule * chatModule,NSArray<KIMChatGroupMessage *> *messageList) {
        if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
            completionBlock(weakSelf,messageList);
        }else{
            [NSOperationQueue.mainQueue addOperationWithBlock:^{
                completionBlock(weakSelf,messageList);
            }];
        }
    }];
}
- (id)copyWithZone:(nullable NSZone *)zone
{
    KIMChatGroupSession * copy = [[KIMChatGroupSession allocWithZone:zone] initWithCurrentUser:[self.currentUser copy] andChatGroup:[self.currentChatGroup copy] chatModule:self.chatModule];
    return copy;
}
-(BOOL)isEqual:(KIMChatGroupSession*)chatGroupSession
{
    if (self.class != chatGroupSession.class) {
        return NO;
    }
    return self.hash == chatGroupSession.hash;;
}
-(NSUInteger)hash
{
    return [[NSString stringWithFormat:@"%@-%@",self.currentUser.account,self.currentChatGroup.groupId] hash];
}

@end
