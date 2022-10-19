//
//  KIMClientSocket.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/25.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMClientSocket.h"
#import "KIMCircleBuffer.h"
#import "KIMMessageAdapter.h"
#import "KIMTCPSocketManager+KIMClientSocket.h"
#import <sys/socket.h>
#import <arpa/inet.h>
#import <sys/select.h>
#import <sys/time.h>
#import <sys/ioctl.h>
@interface KIMClientSocket()
@property(nonatomic,strong)NSLock * socketStateLock;
@property(nonatomic,assign)KIMClientSocketState socketState;
@property(nonatomic,strong)NSString * serverAddr;
@property(nonatomic,assign)unsigned short serverPort;
@property(nonatomic,assign)int socketfd;
@property(nonatomic,strong)KIMCircleBuffer * inputBuffer;
@property(nonatomic,strong)KIMCircleBuffer * outputBuffer;
@property(nonatomic,strong)KIMMessageAdapter * messageAdapter;
@property(nonatomic,weak)KIMTCPSocketManager * socketManager;
@property(nonatomic,assign)BOOL hasDataForSend;
@end

@implementation KIMClientSocket
-(instancetype)initWithServerAddr:(NSString*)serverAddr andPort:(unsigned short)serverPort
{
    self = [super init];
    
    if (self) {
        self.serverAddr = serverAddr;
        self.serverPort = serverPort;
        
        self.socketfd = socket(AF_INET,SOCK_STREAM,IPPROTO_TCP);
        
        if(-1 == self.socketfd){//创建socket失败
            return nil;
        }
        
        const int value = 1;
        setsockopt(self.socketfd, SOL_SOCKET, SO_NOSIGPIPE, &value, sizeof(int));
        
        self.socketState = KIMClientSocketState_Ready;
    }
    
    return self;
}
-(void)dealloc
{
    if (-1 != self.socketfd) {
        close(self.socketfd);
        self.socketfd = -1;
    }
}
-(KIMCircleBuffer*)inputBuffer
{
    if (self->_inputBuffer) {
        return self->_inputBuffer;
    }
    
    self->_inputBuffer = [[KIMCircleBuffer alloc] initWithInitialCapacity:512];
    
    return self->_inputBuffer;
}
-(KIMCircleBuffer*)outputBuffer
{
    if (self->_outputBuffer) {
        return self->_outputBuffer;
    }
    
    self->_outputBuffer = [[KIMCircleBuffer alloc] initWithInitialCapacity:512];
    
    return self->_outputBuffer;
}
-(KIMMessageAdapter*)messageAdapter
{
    if (self->_messageAdapter) {
        return self->_messageAdapter;
    }
    
    self->_messageAdapter = [[KIMMessageAdapter alloc] init];
    
    return self->_messageAdapter;
}
-(NSLock*)socketStateLock
{
    if (self->_socketStateLock) {
        return self->_socketStateLock;
    }
    
    self->_socketStateLock = [[NSLock alloc] init];
    
    return self->_socketStateLock;
}
-(void)setSocketState:(KIMClientSocketState)socketState
{
    if (socketState == self.socketState) {
        return;
    }
    
    self->_socketState = socketState;
    
    if ([self.socketDelegate respondsToSelector:@selector(clientSocket:didSocketStateChanged:)]) {
        __weak KIMClientSocket * weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [weakSelf.socketDelegate clientSocket:weakSelf didSocketStateChanged:socketState];
        });
    }
}
-(void)connectToServerWithCompletion:(void(^)(KIMClientSocket* clientSocket,NSError * error))completionCallback
{
    if (self.socketState == KIMClientSocketState_Ready) {
        [self.socketStateLock lock];
            if (self.socketState != KIMClientSocketState_Ready) {
                if (completionCallback) {
                    KIMClientSocketError error = KIMClientSocketError_Disconnected;
                    switch (self.socketState) {
                        case KIMClientSocketState_Connecting:
                        {
                            error = KIMClientSocketError_Connecting;
                        }
                            break;
                        case KIMClientSocketState_Connected:
                        {
                            error = KIMClientSocketError_Connected;
                        }
                            break;
                        case KIMClientSocketState_Disconnected:
                        {
                            error = KIMClientSocketError_Disconnected;
                        }
                            break;
                        case KIMClientSocketState_Ready:
                        {
                            error = KIMClientSocketError_InternalError;
                        }
                            break;
                    }
                    completionCallback(self,[NSError errorWithDomain:NSStringFromClass(self.class) code:error userInfo:nil]);
                }
                [self.socketStateLock unlock];
                return;
            }
            self.socketState = KIMClientSocketState_Connecting;
            __weak KIMClientSocket * weakSelf = self;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                struct sockaddr_in serverInetAddr;
                memset(&serverInetAddr, 0, sizeof(serverInetAddr));
                serverInetAddr.sin_family = AF_INET;
                serverInetAddr.sin_addr.s_addr = inet_addr([weakSelf.serverAddr UTF8String]);
                serverInetAddr.sin_port = htons(weakSelf.serverPort);
                
                //设置为非阻塞
                int flags;
                flags = fcntl(weakSelf.socketfd, F_GETFL, 0);
                fcntl(weakSelf.socketfd, F_SETFL, flags | O_NONBLOCK);
                
                //连接
                if (-1 == connect(weakSelf.socketfd, (struct sockaddr*)&serverInetAddr, sizeof(serverInetAddr))) {
                    
                    int errorNumber = errno;
                    if (EINPROGRESS == errorNumber) {//连接正在进行中
                        fd_set connectingfds;
                        FD_ZERO(&connectingfds);
                        FD_SET(weakSelf.socketfd, &connectingfds);
                        
                        struct timeval timeout;
                        timeout.tv_sec = 3;//将连接超时的时间设置为3秒
                        timeout.tv_usec = 0;
                        
                        int ret = select(weakSelf.socketfd+1,NULL,&connectingfds,NULL,&timeout);
                        if (-1 == ret) {//select出错
                            //重新设置为阻塞
                            fcntl(weakSelf.socketfd, F_SETFL, flags);
                            [weakSelf.socketStateLock lock];
                            weakSelf.socketState = KIMClientSocketState_Ready;
                            [weakSelf.socketStateLock unlock];
                            //在主队列中调用回调函数
                            if (completionCallback) {
                                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                    completionCallback(weakSelf,[NSError errorWithDomain:@"KIMClientSocket" code:KIMClientSocketError_InternalError userInfo:nil]);
                                });
                            }
                        }else if(0 == ret || !FD_ISSET(weakSelf.socketfd,&connectingfds)){//连接超时
                            //重新设置为阻塞
                            fcntl(weakSelf.socketfd, F_SETFL, flags);
                            [weakSelf.socketStateLock lock];
                            weakSelf.socketState = KIMClientSocketState_Ready;
                            [weakSelf.socketStateLock unlock];
                            //在主队列中调用回调函数
                            if (completionCallback) {
                                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                    completionCallback(weakSelf,[NSError errorWithDomain:@"KIMClientSocket" code:KIMClientSocketError_Timeout userInfo:nil]);
                                });
                            }
                        }else{
                            int socketError = 0;
                            socklen_t socketErrorLen = sizeof(socketError);
                            getsockopt(weakSelf.socketfd, SOL_SOCKET, SO_ERROR, &socketError, &socketErrorLen);
                            
                            if(0 == socketError){//连接成功
                                //重新设置为阻塞
                                fcntl(weakSelf.socketfd, F_SETFL, flags);
                                [weakSelf.socketStateLock lock];
                                weakSelf.socketState = KIMClientSocketState_Connected;
                                [weakSelf.socketStateLock unlock];
                                //在主队列中调用回调函数
                                if (completionCallback) {
                                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                        completionCallback(weakSelf,nil);
                                    });
                                }
                            }else{//连接失败
                                //重新设置为阻塞
                                fcntl(weakSelf.socketfd, F_SETFL, flags);
                                [weakSelf.socketStateLock lock];
                                weakSelf.socketState = KIMClientSocketState_Ready;
                                [weakSelf.socketStateLock unlock];
                                //在主队列中调用回调函数
                                if (completionCallback) {
                                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                        completionCallback(weakSelf,[NSError errorWithDomain:@"KIMClientSocket" code:KIMClientSocketError_InternalError userInfo:nil]);
                                    });
                                }
                            }
                        }
                    }else{//连接失败
                        //重新设置为阻塞
                        fcntl(weakSelf.socketfd, F_SETFL, flags);
                        [weakSelf.socketStateLock lock];
                        weakSelf.socketState = KIMClientSocketState_Ready;
                        [weakSelf.socketStateLock unlock];
                        //在全局队列中调用回调函数
                        if (completionCallback) {
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                completionCallback(weakSelf,[NSError errorWithDomain:@"KIMClientSocket" code:KIMClientSocketError_InternalError userInfo:nil]);
                            });
                        }
                    }
                    
                }else{//连接成功
                    //重新设置为阻塞
                    fcntl(weakSelf.socketfd, F_SETFL, flags);
                    [weakSelf.socketStateLock lock];
                    weakSelf.socketState = KIMClientSocketState_Connected;
                    [weakSelf.socketStateLock unlock];
                    //在主队列中调用回调函数
                    if (completionCallback) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            completionCallback(weakSelf,nil);
                        });
                    }
                }
                
            });
        [self.socketStateLock unlock];
    }else{
        if (completionCallback) {
            KIMClientSocketError error = KIMClientSocketError_Disconnected;
            switch (self.socketState) {
                case KIMClientSocketState_Connecting:
                {
                    error = KIMClientSocketError_Connecting;
                }
                    break;
                case KIMClientSocketState_Connected:
                {
                    error = KIMClientSocketError_Connected;
                }
                    break;
                case KIMClientSocketState_Disconnected:
                {
                    error = KIMClientSocketError_Disconnected;
                }
                    break;
                case KIMClientSocketState_Ready:
                {
                    error = KIMClientSocketError_InternalError;
                }
                    break;
            }
            completionCallback(self,[NSError errorWithDomain:NSStringFromClass(self.class) code:error userInfo:nil]);
        }
    }
}
-(void)close
{
    [self.socketStateLock lock];
    if (KIMClientSocketState_Disconnected == self.socketState) {
        [self.socketStateLock unlock];
        return;
    }
    if (-1 != self.socketfd) {
        close(self.socketfd);
    }
    self.socketState = KIMClientSocketState_Disconnected;
    [self.socketStateLock unlock];
}
-(void)sendMessage:(GPBMessage*)message
{
    [self.messageAdapter encapsulateMessageToByteStream:message outputBuffer:self.outputBuffer];
    [self setHasDataForSend:YES];
    [self.socketManager notifyToSend];
}

-(void)tryToRetrieveData
{
    static u_int8_t buffer[1024] = {0};
    ssize_t readCount = 0;
    
    //读取连接上的数据，并处理
    while (-1 != readCount) {
        readCount = recv(self.socketfd, buffer, sizeof(buffer),MSG_DONTWAIT);
        if (-1 == readCount) {
            
            switch (errno) {
                case ECONNRESET://连接被重置
                case ENOTCONN://TCP连接未建立
                case ETIMEDOUT://TCP连接超时
                {
                    //关闭连接
                    [self.socketStateLock lock];
                    close(self.socketfd);
                    self.socketfd = -1;
                    self.socketState = KIMClientSocketState_Disconnected;
                    [self.socketStateLock unlock];
                }
                    break;
                case EFAULT://buffer指向了非法的地址空间(进程地址空间以外的地方)
                case EBADF://fd并不是一个文件描述符
                case ENOTSOCK://fd并不是一个socket文件描述符
                {
                    //关闭连接
                    [self.socketStateLock lock];
                    close(self.socketfd);
                    self.socketfd = -1;
                    self.socketState = KIMClientSocketState_Disconnected;
                    [self.socketStateLock unlock];
                }
                    break;
                case EINTR:{//中断
                    readCount = 0;
                    continue;
                }
                    break;
                default:
                    //本次读取操作结束
                    return;
            }
        } else if(0 == readCount){//对方关闭了写
            //尝试从输入缓冲区中提取消息
            GPBMessage * message = nil;
            while([self.messageAdapter tryToretriveMessage:self.inputBuffer message:&message])
            {
                if ([self.socketDelegate respondsToSelector:@selector(clientSocket:didReceivedMessage:)]) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        __weak KIMClientSocket * weakSelf = self;
                        [weakSelf.socketDelegate clientSocket:weakSelf didReceivedMessage:message];
                    });
                }
            }
            //关闭连接
            [self.socketStateLock lock];
            close(self.socketfd);
            self.socketfd = -1;
            self.socketState = KIMClientSocketState_Disconnected;
            [self.socketStateLock unlock];
            
        }else {
            //将字节流放入输入缓冲区
            [self.inputBuffer appendContent:buffer bufferLength:readCount];
            //尝试从输入缓冲区中提取消息
            GPBMessage * message = nil;
            while([self.messageAdapter tryToretriveMessage:self.inputBuffer message:&message])
            {
                if ([self.socketDelegate respondsToSelector:@selector(clientSocket:didReceivedMessage:)]) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        __weak KIMClientSocket * weakSelf = self;
                        [weakSelf.socketDelegate clientSocket:weakSelf didReceivedMessage:message];
                            
                    });
                }
            }
        }
    }
}
-(void)tryToSendData
{
    //1.判断缓冲区中是否还待发送的数据
    if ([self.outputBuffer used] > 0) {//缓冲区中存在待发送的数据
        static u_int8_t *buffer = nil;
        static size_t currentBufferSize = 0;
        static size_t currentBufferSendCursor = 0;
        static size_t lastLeftSendCount = 0;
        //检查是否有待发送的数据未发送完毕
        if(!lastLeftSendCount){
            //1.获得socket发送缓冲区的容量
            size_t socketOutputBuffer_Capacity;
            socklen_t output_buf_size_len = sizeof(socketOutputBuffer_Capacity);
            if (getsockopt(self.socketfd, SOL_SOCKET, SO_SNDBUF,
                           (void *) &socketOutputBuffer_Capacity,
                           &output_buf_size_len) == -1) {
                //错误处理
            }
            //2.获得socket发送缓存区已使用的容量
            size_t socketOutputBuffer_Used;
            if (EINVAL == ioctl(self->_socketfd, SO_NWRITE, &socketOutputBuffer_Used)) {
                //错误处理
                //关闭连接
                [self.socketStateLock lock];
                close(self.socketfd);
                self.socketfd = -1;
                self.socketState = KIMClientSocketState_Disconnected;
                [self.socketStateLock unlock];
                return;
            }
            //3.计算socket发送缓冲区的剩余容量
            size_t socketOutputBuffer_Free = socketOutputBuffer_Capacity - socketOutputBuffer_Used;
            
            //4.计算本次write操作所能写入的最大字节数
            const size_t writeBytes =
            socketOutputBuffer_Free < [self.outputBuffer used] ? socketOutputBuffer_Free
            : [self.outputBuffer used];
            //5.更新缓冲区: 若本次write操作所能写入的最大字节数大于buffer,则删除旧的缓冲区，并分配新的缓冲区
            if (writeBytes > currentBufferSize) {
                if (NULL != buffer) {
                    free(buffer);//一定要使用delete[],因为buffer本质上是指向一个数组
                    buffer = NULL;
                }
                buffer = malloc(sizeof(u_int8_t)*writeBytes);
                currentBufferSize = writeBytes;
            }
            //6.从输出缓冲区中获取数据，数目最多为socket发送缓冲区的空闲空间
            lastLeftSendCount = [self.outputBuffer retriveWithBuffer:buffer bufferLength:writeBytes];
            currentBufferSendCursor = 0;
        }
        //7.写入socket的发送缓冲区
        while (lastLeftSendCount) {
            ssize_t ret = send(self.socketfd, &buffer[currentBufferSendCursor],lastLeftSendCount, MSG_DONTWAIT);
            if(0 <= ret){
                lastLeftSendCount-=ret;
                currentBufferSendCursor+=ret;
            }else{
                switch (errno) {
                    case EINTR:
                    {
                        continue;
                    }
                    case EAGAIN:
                    case ENOBUFS:
                    {
                        //本次写入完毕
                        return;
                    }
                        break;
                    case EBADF:
                    case ENOTSOCK:
                    case EFAULT://buffer指向了非法的地址空间(进程地址空间以外的地方)
                    {
                        //清除buffer
                        if (NULL != buffer) {
                            free(buffer);
                            buffer = NULL;
                        }
                        currentBufferSize = 0;
                        currentBufferSendCursor = 0;
                        lastLeftSendCount = 0;
                        //取消监听socket的发送缓冲区的事件
                        self.hasDataForSend = NO;
                        //关闭连接
                        [self.socketStateLock lock];
                        close(self.socketfd);
                        self.socketfd = -1;
                        self.socketState = KIMClientSocketState_Disconnected;
                        [self.socketStateLock unlock];
                        return;
                    }
                        break;
                    case ENETUNREACH://目标网络不可达
                    case EHOSTUNREACH://目标主机不可达
                    {
                        //清除buffer
                        if(NULL != buffer){
                            free(buffer);
                            buffer = NULL;
                        }
                        currentBufferSize = 0;
                        currentBufferSendCursor = 0;
                        lastLeftSendCount = 0;
                        
                        //取消监听socket的发送缓冲区的事件
                        self.hasDataForSend = NO;

                        //关闭连接
                        [self.socketStateLock lock];
                        close(self.socketfd);
                        self.socketfd = -1;
                        self.socketState = KIMClientSocketState_Disconnected;
                        [self.socketStateLock unlock];
                        return;
                    }
                        break;
                    case ENETDOWN://本地网络接口关闭
                    {
                        //清除buffer
                        if(NULL != buffer){
                            free(buffer);
                            buffer = NULL;
                        }
                        currentBufferSize = 0;
                        currentBufferSendCursor = 0;
                        lastLeftSendCount = 0;
                        //取消监听socket的发送缓冲区的事件
                        self.hasDataForSend = NO;
                        //关闭连接
                        [self.socketStateLock lock];
                        close(self.socketfd);
                        self.socketfd = -1;
                        self.socketState = KIMClientSocketState_Disconnected;
                        [self.socketStateLock unlock];
                        return;
                        
                    }
                    case EPIPE://连接关闭
                    case ECONNRESET:
                    {
                        //清除buffer
                        if(NULL != buffer){
                            free(buffer);
                            buffer = NULL;
                        }
                        currentBufferSize = 0;
                        currentBufferSendCursor = 0;
                        lastLeftSendCount = 0;
                        //通知consigor
                        //取消监听socket的发送缓冲区的事件
                        self.hasDataForSend = NO;
                        //关闭连接
                        [self.socketStateLock lock];
                        close(self.socketfd);
                        self.socketfd = -1;
                        self.socketState = KIMClientSocketState_Disconnected;
                        [self.socketStateLock unlock];
                        return;
                    }
                        break;
                    default:
                        //本次写入操作结束
                        return;
                }
            }
        }
    } else {//缓冲区中不存在待发送的数据
        //取消监听socket的发送缓冲区的事件
        self.hasDataForSend = NO;
    }
}
@end
