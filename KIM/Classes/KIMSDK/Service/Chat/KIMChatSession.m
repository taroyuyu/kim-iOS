//
//  KIMChatSession.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/31.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMChatSession.h"
#import "KIMChatModule+Internal.h"
@interface KIMChatSession()
@property(nonatomic,strong)KIMUser * currentUser;
@property(nonatomic,strong)KIMUser * opponent;
@property(nonatomic,weak)KIMChatModule * chatModule;
@end

@implementation KIMChatSession
-(instancetype)initWithCurrentUser:(KIMUser*)currentUser andOpponent:(KIMUser*)opponent chatModule:(KIMChatModule*)chatModule
{
    if (!(currentUser && opponent && chatModule)) {
        return nil;
    }
    
    self = [super init];
    
    if (self) {
        self.currentUser = currentUser;
        self.opponent = opponent;
        self.chatModule = chatModule;
    }
    
    return self;
}
NSString * KIMChatSessionCurrentUserKey = @"CurrentUser";
NSString * KIMChatSessionOpponentKey = @"Opponent";
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    
    if (self) {
        self.currentUser = [aDecoder decodeObjectForKey:KIMChatSessionCurrentUserKey];
        self.opponent = [aDecoder decodeObjectForKey:KIMChatSessionOpponentKey];
    }
    
    return self;
}
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (self.currentUser) {
        [aCoder encodeObject:self.currentUser forKey:KIMChatSessionCurrentUserKey];
    }
    
    if (self.opponent) {
        [aCoder encodeObject:self.opponent forKey:KIMChatSessionOpponentKey];
    }
}
-(KIMChatMessage*)sendTextMessage:(NSString*)textMessage
{
    if (!textMessage.length) {
        return nil;
    }
    KIMChatMessage * chatMessage = [[KIMChatMessage alloc] init];
    chatMessage.type = KIMChatMessageType_Text;
    chatMessage.state = KIMChatMessageState_Sending;
    chatMessage.sender = self.currentUser;
    chatMessage.receiver = self.opponent;
    chatMessage.content = textMessage;
    chatMessage.timestamp = [NSDate date];
    if (![self.chatModule sendChatMessage:chatMessage fromSession:self]) {
        return nil;
    }
    return chatMessage;
}
-(void)didReceiveMessage:(KIMChatMessage*)chatMessage FromChatModule:(KIMChatModule*)chatModule
{
    if (chatModule != [self chatModule]) {
        return;
    }
    
    if ([[self delegate] respondsToSelector:@selector(didChatSessionReceivedMessage:message:)]) {
        if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
            [self.delegate didChatSessionReceivedMessage:self message:chatMessage];
        }else{
            __weak KIMChatSession * weakSelf = self;
            [NSOperationQueue.mainQueue addOperationWithBlock:^{
                [weakSelf.delegate didChatSessionReceivedMessage:weakSelf message:chatMessage];
            }];
        }
    }
}
-(void)loadLastedMessageWithMaxCount:(NSUInteger)maxCount completion:(void(^)(KIMChatSession * chatSession,NSArray<KIMChatMessage*> * messageList))completionBlock
{
    if (!completionBlock) {
        return;
    }
    __weak KIMChatSession * weakSelf = self;
    [self.chatModule loadLastedChatMessageWithUser:self.opponent maxCount:maxCount completion:^(KIMChatModule * chatModule,NSArray<KIMChatMessage *> *messageList) {
        if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
            completionBlock(weakSelf,messageList);
        }else{
            [NSOperationQueue.mainQueue addOperationWithBlock:^{
                completionBlock(weakSelf,messageList);
            }];
        }
    }];
}
-(void)loadMessage:(NSUInteger)maxCount withMaxMessageId:(uint64_t)maxMessageId completion:(void(^)(KIMChatSession * chatSession,NSArray<KIMChatMessage*> * messageList))completionBlock
{
    if (!completionBlock) {
        return;
    }
    __weak KIMChatSession * weakSelf = self;
    [self.chatModule loadChatMessageWithUser:self.opponent maxCount:maxCount maxMessageId:maxMessageId completion:^(KIMChatModule * chatModule,NSArray<KIMChatMessage *> *messageList) {
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
    KIMChatSession * copy = [[KIMChatSession allocWithZone:zone] initWithCurrentUser:[self.currentUser copy] andOpponent:[self.opponent copy] chatModule:self.chatModule];
    return copy;
}
-(BOOL)isEqual:(KIMChatSession*)chatSession
{
    if (self.class != chatSession.class) {
        return NO;
    }
    return self.hash == chatSession.hash;
}
-(NSUInteger)hash
{
    return [[NSString stringWithFormat:@"%@-%@",self.currentUser.account,self.opponent.account] hash];
}
@end
