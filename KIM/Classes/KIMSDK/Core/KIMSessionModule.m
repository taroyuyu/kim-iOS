//
//  KIMSessionModule.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/25.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMSessionModule.h"
#import "KIMClientSocket.h"
#import "KIMTCPSocketManager.h"
#import "KakaImmessage.pbobjc.h"
@interface KIMSessionModule()<KIMClientSocketDelegate>
@property(nonatomic,strong)NSLock * stateLock;
@property(nonatomic,assign)KIMSessionModuleState state;
@property(nonatomic,strong)NSString *serverAddr;
@property(nonatomic,assign)unsigned short serverPort;
@property(nonatomic,strong)KIMClientSocket * clientSocket;
@property(nonatomic,strong)KIMTCPSocketManager * socketManager;
@property(nonatomic,strong)NSString * sessionId;
@property(nonatomic,strong)NSTimer * sessionIdRequestTimeoutTimer;
@property(nonatomic,strong)NSTimer * heartBeatTimer;
@property(nonatomic,strong)NSDateFormatter * kimDateFormatter;
@end
@implementation KIMSessionModule
-(instancetype) initWithServerAddr:(NSString *)serverAddr andPort:(unsigned short)serverPort
{
    self = [super init];
    
    if (self) {
        self.serverAddr = serverAddr;
        self.serverPort = serverPort;
        self.state = KIMSessionModuleState_Ready;
        self.socketManager = [[KIMTCPSocketManager alloc] init];
        [self.socketManager start];
    }
    
    return self;
}
-(NSLock*)stateLock
{
    if (self->_stateLock) {
        return self->_stateLock;
    }
    
    self->_stateLock = [[NSLock alloc] init];
    
    return self->_stateLock;
}
-(NSDateFormatter*)kimDateFormatter
{
    if (self->_kimDateFormatter) {
        return self->_kimDateFormatter;
    }
    
    self->_kimDateFormatter = [[NSDateFormatter alloc] init];
    [self->_kimDateFormatter setDateFormat:@"YYYY-MM-dd HH:mm:ss"];
    [self->_kimDateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
    
    return self->_kimDateFormatter;
}
-(void)setState:(KIMSessionModuleState)state
{
    if (self.state == state) {
        return;
    }
    self->_state = state;
    
    if ([self.delegate respondsToSelector:@selector(sessionModule:didChangedState:)]) {
        __weak KIMSessionModule * weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [weakSelf.delegate sessionModule:weakSelf didChangedState:weakSelf.state];
        });
    }
}
-(void)start
{
    if (KIMSessionModuleState_Ready == self.state) {
        [self.stateLock lock];
        if (KIMSessionModuleState_Ready != self.state) {
            [self.stateLock unlock];
            return;
        }
        __weak KIMSessionModule * weakSelf = self;
        //构建连接
        self.clientSocket = [[KIMClientSocket alloc] initWithServerAddr:self.serverAddr andPort:self.serverPort];
        self.clientSocket.socketDelegate = self;
        if (!self.clientSocket) {
            [self.stateLock unlock];
            return;
        }
        self.state = KIMSessionModuleState_Connecting;
        [self.stateLock unlock];
        [self.clientSocket connectToServerWithCompletion:^(KIMClientSocket *clientSocket, NSError *error) {
            [weakSelf.stateLock lock];
            if (weakSelf.state != KIMSessionModuleState_Connecting) {
                [weakSelf.stateLock unlock];
                return;
            }
            if (error) {//连接失败
                weakSelf.state = KIMSessionModuleState_Ready;
                [weakSelf.stateLock unlock];
                return;
            }else{//连接成功，发送会话请求消息
                weakSelf.state = KIMSessionModuleState_SessionBuilding;
                [weakSelf.socketManager addClientSocket:clientSocket];
                [clientSocket sendMessage:[KIMProtoRequestSessionIDMessage new]];
                weakSelf.sessionIdRequestTimeoutTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:4] interval:4 repeats:YES block:^(NSTimer * _Nonnull timer) {
                    [weakSelf.stateLock lock];
                    if (weakSelf.state == KIMSessionModuleState_SessionBuilding) {
                        [clientSocket sendMessage:[KIMProtoRequestSessionIDMessage new]];
                        
                    }else{
                        [timer invalidate];
                        weakSelf.sessionIdRequestTimeoutTimer = nil;
                    }
                    [weakSelf.stateLock unlock];
                }];
                [[NSRunLoop mainRunLoop] addTimer:weakSelf.sessionIdRequestTimeoutTimer forMode:NSDefaultRunLoopMode];
                [weakSelf.stateLock unlock];
            }
        }];
    }
}
-(void)stop
{
    if (KIMSessionModuleState_Ready != self.state) {
        [self.stateLock lock];
            if (KIMSessionModuleState_Ready == self.state) {
                [self.stateLock unlock];
                return;
            }
        
        switch (self.state) {
            case KIMSessionModuleState_Connecting:
            {
            }
                break;
            case KIMSessionModuleState_SessionBuilding:
            {
                if (self.sessionIdRequestTimeoutTimer) {
                    [self.sessionIdRequestTimeoutTimer invalidate];
                    self.sessionIdRequestTimeoutTimer = nil;
                }
            }
                break;
            case KIMSessionModuleState_SessionBuilded:
            {
                if (self.heartBeatTimer) {
                    [self.heartBeatTimer invalidate];
                    self.heartBeatTimer = nil;
                }
                self.sessionId = nil;
            }
                break;
            case KIMSessionModuleState_Ready:
            {
                return;
            }
                break;
        }
        
        
        [self.socketManager removeClientSocket:self.clientSocket];
        self.clientSocket = nil;
        self.state = KIMSessionModuleState_Ready;
        
        [self.stateLock unlock];
    }
}

-(void)clientSocket:(KIMClientSocket*)clientSocket didSocketStateChanged:(KIMClientSocketState)socketState
{
    if (socketState == KIMClientSocketState_Disconnected) {
        [self.socketManager removeClientSocket:clientSocket];
    }
    if (socketState == KIMClientSocketState_Disconnected && self.state != KIMSessionModuleState_Ready) {//连接断开
        [self.stateLock lock];
        
        if (self.state == KIMSessionModuleState_SessionBuilding) {
            //停止sessionIdTimeoutTimer
            if (self.sessionIdRequestTimeoutTimer) {
                [self.sessionIdRequestTimeoutTimer invalidate];
                self.sessionIdRequestTimeoutTimer = nil;
            }
        }else if(self.state == KIMSessionModuleState_SessionBuilded){
            //停止心跳定时器
            if (self.heartBeatTimer) {
                [self.heartBeatTimer invalidate];
                self.heartBeatTimer = nil;
            }
            self.sessionId = nil;
        }
        
        //2.重新连接服务器
        __weak KIMSessionModule * weakSelf = self;
        self.clientSocket = [[KIMClientSocket alloc] initWithServerAddr:self.serverAddr andPort:self.serverPort];
        self.clientSocket.socketDelegate = self;
        if (!self.clientSocket) {
            [self.stateLock unlock];
            return;
        }
        //构建连接
        self.state = KIMSessionModuleState_Connecting;
        [self.stateLock unlock];
        
        [self.clientSocket connectToServerWithCompletion:^(KIMClientSocket *clientSocket, NSError *error) {
            [weakSelf.stateLock lock];
            if (weakSelf.state != KIMSessionModuleState_Connecting) {
                [weakSelf.stateLock unlock];
                return;
            }
            if (error) {//连接失败
                weakSelf.state = KIMSessionModuleState_Ready;
                [weakSelf.stateLock unlock];
                return;
            }else{//连接成功，发送会话请求消息
                weakSelf.state = KIMSessionModuleState_SessionBuilding;
                [weakSelf.socketManager addClientSocket:clientSocket];
                [clientSocket sendMessage:[KIMProtoRequestSessionIDMessage new]];
                weakSelf.heartBeatTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:4] interval:0 repeats:YES block:^(NSTimer * _Nonnull timer) {
                    [weakSelf.stateLock lock];
                    if (weakSelf.state == KIMSessionModuleState_SessionBuilding) {
                        [clientSocket sendMessage:[KIMProtoRequestSessionIDMessage new]];
                        
                    }else{
                        [timer invalidate];
                        weakSelf.sessionIdRequestTimeoutTimer = nil;
                    }
                    [weakSelf.stateLock unlock];
                }];
                [[NSRunLoop mainRunLoop] addTimer:weakSelf.heartBeatTimer forMode:NSDefaultRunLoopMode];
                [weakSelf.stateLock unlock];
            };
        }];
    }
}
-(void)clientSocket:(KIMClientSocket*)clientSocket didReceivedMessage:(GPBMessage*)message
{
    [self.stateLock lock];
    if (self.state == KIMSessionModuleState_SessionBuilding) {
        if ([message.descriptor.fullName isEqualToString:[[KIMProtoResponseSessionIDMessage descriptor]fullName]]) {
            KIMProtoResponseSessionIDMessage * responseSessionIDMessage = (KIMProtoResponseSessionIDMessage*)message;
            switch (responseSessionIDMessage.status) {
                case KIMProtoResponseSessionIDMessage_Status_Success://会话构建成功
                {
                    [self.sessionIdRequestTimeoutTimer invalidate];
                    self.sessionIdRequestTimeoutTimer = nil;
                    self.sessionId = responseSessionIDMessage.sessionId;
                    self.state = KIMSessionModuleState_SessionBuilded;
                    //创建心跳定时器
                    __weak KIMSessionModule * weakSelf = self;
                    self.heartBeatTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:4] interval:4 repeats:YES block:^(NSTimer * _Nonnull timer) {
                        KIMProtoHeartBeatMessage * heartBeatMessage = [[KIMProtoHeartBeatMessage alloc] init];
                        [heartBeatMessage setSessionId:weakSelf.sessionId];
                        [heartBeatMessage setTimestamp:[weakSelf.kimDateFormatter stringFromDate:[NSDate date]]];
                        [weakSelf.clientSocket sendMessage:heartBeatMessage];
                    }];
                    [[NSRunLoop mainRunLoop] addTimer:self.heartBeatTimer forMode:NSDefaultRunLoopMode];
                }
                    break;
                case KIMProtoResponseSessionIDMessage_Status_ServerInterlnalError:
                {
                    
                }
                    break;
            }
        }
    }else if(self.state == KIMSessionModuleState_SessionBuilded){
        if ([self.delegate respondsToSelector:@selector(sessionModule:didReceivedMessage:)]) {
            __weak KIMSessionModule * weakSelf = self;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [weakSelf.delegate sessionModule:weakSelf didReceivedMessage:message];
            });
        }
    }
    [self.stateLock unlock];
}
-(void)sendMessage:(GPBMessage*)message
{
    [self.stateLock lock];
    if (KIMSessionModuleState_SessionBuilded == self.state) {
        
        GPBFieldDescriptor * sessionIdField = [[message descriptor] fieldWithName:@"sessionId"];
        if (sessionIdField) {
            GPBSetMessageStringField(message, sessionIdField,self.sessionId);
        }
        [self.clientSocket sendMessage:message];
    }
    [self.stateLock unlock];
}
@end
