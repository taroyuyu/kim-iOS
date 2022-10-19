//
//  KIMOnlineModule.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/27.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMOnlineModule.h"
#import "KIMClient+Service.h"
#import "KakaImmessage.pbobjc.h"

NSString * const KIMUserOnlineUpdateNotificationName = @"KIMUserOnlineUpdateNotification";

@interface KIMOnlineModule()
@property(nonatomic,weak)KIMClient * imClient;
@property(nonatomic,strong)NSSet<NSString*>* messageTypes;
@property(nonatomic,strong)NSLock * stateLock;
@property(nonatomic,strong)NSMutableDictionary<NSString*,NSNumber*> * userOnlineDB;
@property(nonatomic,strong)NSTimer * fetchOnlineStateTimer;
@end
@implementation KIMOnlineModule
-(instancetype)init
{
    self = [super init];
    if (self) {
        NSMutableSet<NSString*> * messageTypeSet = [[NSMutableSet<NSString*> alloc] init];
        [messageTypeSet addObject:[[KIMProtoOnlineStateMessage descriptor]fullName]];
        self.messageTypes = [messageTypeSet copy];
        self.stateLock = [[NSLock alloc] init];
        self.userOnlineDB = [[NSMutableDictionary<NSString*,NSNumber*> alloc] init];
        self->_currentUserOnlineState = KIMOnlineState_Offline;//默认为离线状态
    }
    return self;
}
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
    
    if ([messageType isEqualToString: [[KIMProtoOnlineStateMessage descriptor] fullName]]) {
        [self handleOnlineStateMessage:(KIMProtoOnlineStateMessage*)message];
    }
}
-(void)handleOnlineStateMessage:(KIMProtoOnlineStateMessage*)message
{
    //更新用户在线状态
    KIMOnlineState onlineState = KIMOnlineState_Offline;
    switch ([message userState]) {
        case KIMProtoOnlineStateMessage_OnlineState_Online:
        {
            onlineState = KIMOnlineState_Online;
        }
            break;
        case KIMProtoOnlineStateMessage_OnlineState_Invisible:
        {
            onlineState = KIMOnlineState_Invisible;
        }
            break;
        case KIMProtoOnlineStateMessage_OnlineState_Offline:
        {
            onlineState = KIMOnlineState_Offline;
        }
            break;
        default:
        {
            onlineState = KIMOnlineState_Offline;
        }
            break;
    }
    [self.stateLock lock];
    [[self userOnlineDB] setValue:[NSNumber numberWithUnsignedInteger:onlineState] forKey:[message userAccount]];
    [self.stateLock unlock];
    //在主线程发送通知
    NSNotification * notification = [[NSNotification alloc] initWithName:KIMUserOnlineUpdateNotificationName object:nil userInfo:@{@"userAccount":message.userAccount}];
    if ([NSOperationQueue.mainQueue isEqual:NSOperationQueue.currentQueue]) {
        [[NSNotificationCenter defaultCenter] postNotification:notification];
    }else{
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        }];
    }
}
-(KIMOnlineState)getUserOnlineState:(KIMUser*)user
{
    [self.stateLock lock];
    NSNumber * onlineStateNumber = [[self userOnlineDB] objectForKey:[user account]];
    [self.stateLock unlock];
    
    if (nil == onlineStateNumber) {
        return KIMOnlineState_Offline;
    }else{
        return [onlineStateNumber unsignedIntegerValue];
    }
}
-(void)setCurrentUserOnlineState:(KIMOnlineState)currentUserOnlineState
{
    [self.stateLock lock];
    if (currentUserOnlineState == self->_currentUserOnlineState) {//当前在线状态未改变
        [self.stateLock unlock];
        return;
    }
    KIMProtoOnlineStateMessage * onlineStateMessage = [[KIMProtoOnlineStateMessage alloc] init];
    [onlineStateMessage setUserAccount:self.imClient.currentUser.account];
    KIMProtoOnlineStateMessage_OnlineState state = KIMProtoOnlineStateMessage_OnlineState_Offline;
    switch (currentUserOnlineState) {
        case KIMOnlineState_Online:
        {
            state = KIMProtoOnlineStateMessage_OnlineState_Online;
        }
            break;
        case KIMOnlineState_Invisible:
        {
            state = KIMProtoOnlineStateMessage_OnlineState_Invisible;
        }
            break;
        case KIMOnlineState_Offline:
        {
            state = KIMProtoOnlineStateMessage_OnlineState_Offline;
        }
            break;
        default:
        {
            state = KIMProtoOnlineStateMessage_OnlineState_Online;
        }
            break;
    }
    [onlineStateMessage setUserState:state];
    
    if([self.imClient sendMessage:onlineStateMessage]){
         self->_currentUserOnlineState = currentUserOnlineState;
    }
    [self.stateLock unlock];
}
-(void)imClientDidLogin:(KIMClient*)imClient withUser:(KIMUser*)user
{
    //尝试更新在线状态:在线
    KIMProtoOnlineStateMessage * onlineStateMessage = [[KIMProtoOnlineStateMessage alloc] init];
    [onlineStateMessage setUserAccount:self.imClient.currentUser.account];
    [onlineStateMessage setUserState:KIMProtoOnlineStateMessage_OnlineState_Online];
    if([self.imClient sendMessage:onlineStateMessage]){
        [self.stateLock lock];
        self->_currentUserOnlineState = KIMOnlineState_Online;
        [self.stateLock unlock];
    }
    
    if (!self.fetchOnlineStateTimer) {
        __weak KIMOnlineModule * weakSelf = self;
        self.fetchOnlineStateTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:1] interval:3 repeats:YES block:^(NSTimer * _Nonnull timer) {
            if (!weakSelf) {
                [timer invalidate];
                return;
            }
            [weakSelf.imClient sendMessage:[[KIMProtoPullFriendOnlineStateMessage alloc]init]];
        }];
        [[NSRunLoop mainRunLoop] addTimer:self.fetchOnlineStateTimer forMode:NSDefaultRunLoopMode];
    }
}
-(void)imClientDidLogout:(KIMClient*)imClient withUser:(KIMUser*)user
{
    [self.stateLock lock];
    //1.停止定时器
    if (self.fetchOnlineStateTimer) {
        [self.fetchOnlineStateTimer invalidate];
        self.fetchOnlineStateTimer = nil;
    }
    //2.重置在线状态消息:离线
    self->_currentUserOnlineState = KIMOnlineState_Offline;
    //3.清空好友在线列表
    [self.userOnlineDB removeAllObjects];
    [self.stateLock unlock];
}
@end
