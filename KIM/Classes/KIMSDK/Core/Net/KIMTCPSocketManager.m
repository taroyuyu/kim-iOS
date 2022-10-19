//
//  KIMTCPSocketManager.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/25.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMTCPSocketManager.h"
#import "KIMClientSocket+KIMTCPSocketManager.h"
#import <sys/select.h>
#import <sys/time.h>
#include <signal.h>
@interface KIMTCPSocketManager()
@property(nonatomic,assign)int workThreadWakeUpFd;
@property(nonatomic,assign)int workThreadWakeUpCtlFd;
@property(nonatomic,strong)NSLock * stateLock;
@property(atomic,assign)KIMTCPSocketManagerState state;
@property(nonatomic,strong)NSLock * clientSocketSetLock;
@property(nonatomic,strong)NSMutableSet<KIMClientSocket*> * clientSocketSet;
@property(nonatomic,strong)NSThread * workThread;;
@property(nonatomic,strong)NSCondition * workThreadStopCondition;
@end

@implementation KIMTCPSocketManager
-(instancetype)init
{
    self = [super init];
    
    if (self) {
        int fds[2] = {-1,-1};
        if(pipe(fds)){//创建管道失败
            return nil;
        }
        
        [self setClientSocketSet:[NSMutableSet<KIMClientSocket*> setWithCapacity:1000]];
        
        self.workThreadWakeUpFd = fds[0];
        self.workThreadWakeUpCtlFd = fds[1];
        
        [self setState:KIMTCPSocketManagerState_Stop];
    }
    
    return self;
}
-(void)dealloc
{
    //1.停止工作线程
    [self stop];
    //2.关闭管道
    close(self.workThreadWakeUpCtlFd);
    close(self.workThreadWakeUpFd);
}

-(NSLock*)stateLock
{
    if (self->_stateLock) {
        return self->_stateLock;
    }
    
    self->_stateLock = [[NSLock alloc] init];
    
    return self->_stateLock;
}

-(NSLock*)clientSocketSetLock
{
    if (self->_clientSocketSetLock) {
        return self->_clientSocketSetLock;
    }
    
    self->_clientSocketSetLock = [[NSLock alloc] init];
    
    return self->_clientSocketSetLock;
}
-(NSCondition*)workThreadStopCondition
{
    if (self->_workThreadStopCondition) {
        return self->_workThreadStopCondition;
    }
    
    self->_workThreadStopCondition = [[NSCondition alloc] init];
    
    return self->_workThreadStopCondition;
}
-(void)addClientSocket:(KIMClientSocket*)clientSocket
{
    [self.clientSocketSetLock lock];
    [self.clientSocketSet addObject:clientSocket];
    [clientSocket setSocketManager:self];
    [self.clientSocketSetLock unlock];
    [self notifyToSend];
}
-(void)removeClientSocket:(KIMClientSocket*)clientSocket
{
    [self.clientSocketSetLock lock];
    [self.clientSocketSet removeObject:clientSocket];
    [clientSocket setSocketManager:nil];
    [self.clientSocketSetLock unlock];
}
-(void)start
{
    if (KIMTCPSocketManagerState_Stop == self.state) {
        [self.stateLock lock];
        if (KIMTCPSocketManagerState_Stop != self.state) {
            [self.stateLock unlock];
            return;
        }
        //启动工作线程
        __weak KIMTCPSocketManager * weakSelf = self;
        self.workThread = [[NSThread alloc] initWithBlock:^{
            tcpSocketManagerWorkThreadEntry(weakSelf);
        }];
        [self.workThread start];
        self.state = KIMTCPSocketManagerState_Running;
        [self.stateLock unlock];
    }
}
-(void)stop
{
    if (KIMTCPSocketManagerState_Running == self.state) {//停止工作线程
        [self.stateLock lock];
            if (KIMTCPSocketManagerState_Running != self.state) {
                [self.stateLock unlock];
                return;
            }
            [self.workThread cancel];
            //唤醒工作线程
            [self notifyToSend];
            [self.workThreadStopCondition wait];
            self.state = KIMTCPSocketManagerState_Stop;
            [self.stateLock unlock];
    }
}

-(void)notifyToSend
{
    //唤醒工作线程
    const uint64_t count = 1;
    if(sizeof(count) != write(self.workThreadWakeUpCtlFd, &count, sizeof(count))){//会造成程序奔溃
    }
}
void tcpSocketManagerWorkThreadEntry(KIMTCPSocketManager* socketManager)
{
    while (![[NSThread currentThread] isCancelled]) {
        fd_set readfds,writefds;
        int readfds_maxfd = 0;
        int writefds_maxfd = 0;
        FD_ZERO(&readfds);
        FD_ZERO(&writefds);
        
        [socketManager.clientSocketSetLock lock];
        NSArray<KIMClientSocket*> * clientSocketSet = [socketManager.clientSocketSet sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"socketfd" ascending:YES]]];
        [socketManager.clientSocketSetLock unlock];
        NSMutableDictionary<NSNumber*,KIMClientSocket*> * listeningReadSocket = [NSMutableDictionary<NSNumber*,KIMClientSocket*> dictionary];
        NSMutableDictionary<NSNumber*,KIMClientSocket*> * listeningWriteSocket = [NSMutableDictionary<NSNumber*,KIMClientSocket*> dictionary];
        
        for (KIMClientSocket * clientSocket in clientSocketSet) {
            
            if (KIMClientSocketState_Connected != clientSocket.socketState) {
                continue;
            }
            
            FD_SET(clientSocket.socketfd,&readfds);
            [listeningReadSocket setObject:clientSocket forKey:[NSNumber numberWithInt:clientSocket.socketfd]];
            readfds_maxfd = clientSocket.socketfd;
            
            if (clientSocket.hasDataForSend) {
                FD_SET(clientSocket.socketfd,&writefds);
                [listeningWriteSocket setObject:clientSocket forKey:[NSNumber numberWithInt:clientSocket.socketfd]];
                writefds_maxfd = clientSocket.socketfd;
            }
        }
        
        FD_SET(socketManager.workThreadWakeUpFd,&readfds);
        if (socketManager.workThreadWakeUpCtlFd >= readfds_maxfd) {
            readfds_maxfd = socketManager.workThreadWakeUpCtlFd;
        }
        
        struct timeval timeout;
        timeout.tv_sec = 0;
        timeout.tv_usec = 100;
        int ready = select(MAX(readfds_maxfd, writefds_maxfd)+1,&readfds,&writefds,NULL,NULL);
        if(ready > 0){
            for (int fd = 0; fd <= readfds_maxfd; ++fd) {
                if(FD_ISSET(fd,&readfds)){
                    if (fd != socketManager.workThreadWakeUpFd) {
                        KIMClientSocket * clientSocket = [listeningReadSocket objectForKey:[NSNumber numberWithInt:fd]];
                        [clientSocket tryToRetrieveData];
                    }else{
                        uint64_t count = 0;
                        read(fd, &count, sizeof(count));
                    }
                }
            }
            
            for (int fd = 0; fd <= writefds_maxfd; ++fd) {
                if(FD_ISSET(fd,&writefds)){
                    KIMClientSocket * clientSocket = [listeningWriteSocket objectForKey:[NSNumber numberWithInt:fd]];
                    [clientSocket tryToSendData];
                }
            }
        }
    }
    [socketManager.workThreadStopCondition signal];
    [NSThread exit];
}
@end
