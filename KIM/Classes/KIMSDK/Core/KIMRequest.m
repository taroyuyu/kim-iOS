//
//  KIMRequest.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/26.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMRequest.h"
#import "KIMRequest+Internal.h"
#import "KIMTCPSocketManager.h"
#import "KIMClientSocket.h"
typedef NS_ENUM(NSUInteger,KIMRequestState)
{
    KIMRequestState_Ready,
    KIMRequestState_Connecting,
    KIMRequestState_WaitingResponse,
    KIMRequestState_Done,
    KIMRequestState_Canceled,
    KIMRequestState_Failed,
};

@interface KIMRequest()<KIMClientSocketDelegate>
@property(nonatomic,strong)NSLock * stateLock;
@property(nonatomic,assign)KIMRequestState state;
@property(nonatomic,strong)KIMClientSocket * clientSocket;
@property(nonatomic,weak)KIMTCPSocketManager * socketManager;
@property(nonatomic,strong)NSTimer * requestTimeoutTimer;
@end

@implementation KIMRequest
-(instancetype)initWithServerAddr:(NSString*const)serverAddr serverPort:(const unsigned short)serverPort
{
    self = [super init];
    
    if (self && [serverAddr length]) {
        self.serverAddr = serverAddr;
        self.serverPort = serverPort;
        self.stateLock = [[NSLock alloc] init];
        self.state = KIMRequestState_Ready;
    }
    
    return self;
}
-(void)executeWithSocketManager:(KIMTCPSocketManager*)socketManager
{
    [self.stateLock lock];
    if (KIMRequestState_Ready != self.state) {
        [self.stateLock unlock];
        return;
    }
    self.socketManager = socketManager;
    //创建socket
    self.clientSocket = [[KIMClientSocket alloc] initWithServerAddr:self.serverAddr andPort:self.serverPort];
    [self.clientSocket setSocketDelegate:self];
    //连接服务器
    self.state = KIMRequestState_Connecting;
    [self.stateLock unlock];
    __weak KIMRequest * weakSelf = self;
    [self.clientSocket connectToServerWithCompletion:^(KIMClientSocket *clientSocket, NSError *error) {
        [weakSelf.stateLock lock];
        if (KIMRequestState_Connecting != weakSelf.state) {
            [weakSelf.stateLock unlock];
            return;
        }
        
        if (error) {//连接服务器失败
            weakSelf.state = KIMRequestState_Failed;
            [weakSelf.stateLock unlock];
            [weakSelf failedWithError:KIMRequestConnectionToServerFailed];
            return;
        }
        
        //连接服务器成功,则将其加入到tcpSocketManager中
        [weakSelf.socketManager addClientSocket:weakSelf.clientSocket];
        //发送请求
        [weakSelf.clientSocket sendMessage:weakSelf.requestMessage];
        weakSelf.state = KIMRequestState_WaitingResponse;
        [weakSelf.stateLock unlock];
        
        self.requestTimeoutTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:4] interval:0 repeats:NO block:^(NSTimer * _Nonnull timer) {
            [weakSelf.stateLock lock];
            if (KIMRequestState_WaitingResponse != weakSelf.state) {
                [weakSelf.stateLock unlock];
                return;
            }
            weakSelf.state = KIMRequestState_Failed;
            [weakSelf.clientSocket close];
            [weakSelf.socketManager removeClientSocket:self.clientSocket];
            weakSelf.clientSocket = nil;
            weakSelf.socketManager = nil;
            [weakSelf.requestTimeoutTimer invalidate];
            weakSelf.requestTimeoutTimer = nil;
            [weakSelf failedWithError:KIMRequestTimeout];
            
        }];
        [[NSRunLoop mainRunLoop] addTimer:self.requestTimeoutTimer forMode:NSDefaultRunLoopMode];
    }];
}
-(void)clientSocket:(KIMClientSocket*)clientSocket didSocketStateChanged:(KIMClientSocketState)socketState
{
    
    if (socketState == KIMClientSocketState_Disconnected) {//连接断开
        [self.stateLock lock];
        if (KIMRequestState_WaitingResponse == self.state) {
            [self.socketManager removeClientSocket:self.clientSocket];
            self.clientSocket = nil;
            self.socketManager = nil;
            self.state = KIMRequestState_Failed;
            [self.stateLock unlock];
            [self failedWithError:KIMRequesConnectionBroken];
            return;
        }
        [self.stateLock unlock];
        return;
    }
}
-(void)clientSocket:(KIMClientSocket*)clientSocket didReceivedMessage:(GPBMessage*)message
{
    [self.stateLock lock];
    if (KIMRequestState_WaitingResponse != self.state) {
        [self.stateLock unlock];
        return;
    }
    self.state = KIMRequestState_Done;
    [self.clientSocket close];
    [self.socketManager removeClientSocket:self.clientSocket];
    self.clientSocket = nil;
    self.socketManager = nil;
    [self.stateLock unlock];
    [self handleResponse:message];
}
-(void)cancel
{
    [self.stateLock lock];
    switch (self.state) {
        case KIMRequestState_Connecting:
        {
            [self.clientSocket close];
            [self.socketManager removeClientSocket:self.clientSocket];
            self.clientSocket = nil;
            self.socketManager = nil;
            self.state = KIMRequestState_Canceled;
            [self.stateLock unlock];
            [self failedWithError:KIMRequestCanceled];
            return;
        }
            break;
        case KIMRequestState_WaitingResponse:
        {
            [self.clientSocket close];
            [self.socketManager removeClientSocket:self.clientSocket];
            self.clientSocket = nil;
            self.socketManager = nil;
            self.state = KIMRequestState_Canceled;
            [self.stateLock unlock];
            [self failedWithError:KIMRequestCanceled];
            return;
        }
            break;
        case KIMRequestState_Ready:
        case KIMRequestState_Done:
        case KIMRequestState_Canceled:
        case KIMRequestState_Failed:
        {
            [self.stateLock unlock];
            return;
        }
        default:
        {
            [self.stateLock unlock];
            return;
        }
            break;
    }
}
@end
