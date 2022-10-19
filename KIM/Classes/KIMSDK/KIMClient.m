//
//  KIMClient.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/26.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMClient.h"
#import "KIMSessionModule.h"
#import "KIMRequestSession.h"
#import "KIMNodeRequest.h"
#import "KIMUserRegisterRequest.h"
#import "KakaImmessage.pbobjc.h"
#import "KIMClient+Service.h"
NSString * const KIMClientStateChangedNotificationName = @"KIMClientStateChangedNotification";

@interface KIMClient()<KIMSessionModuleDelegate>
@property(nonatomic,strong)NSLock * stateLock;
@property(nonatomic,assign)KIMClientState state;
@property(nonatomic,strong)NSString * presidentAddr;
@property(nonatomic,assign)unsigned short presidentPort;
#pragma mark - 业务模块相关
@property(nonatomic,strong)NSLock * serviceModuleSetLock;
@property(nonatomic,strong)NSMutableSet<NSObject<KIMClientService>*> * serviceModuleSet;
@property(nonatomic,strong)NSMutableDictionary<NSString *,NSMutableSet<NSObject<KIMClientService>*>*>* messageHandlerSet;;
@property(nonatomic,strong)NSOperationQueue * serviceModuleQueue;
#pragma mark - 业务模块
@property(nonatomic,strong)KIMOnlineModule * onlineStateModule;
@property(nonatomic,strong)KIMRosterModule * rosterModule;
@property(nonatomic,strong)KIMChatGroupModule * chatGroupModule;
@property(nonatomic,strong)KIMChatModule * chatModule;
@property(nonatomic,strong)KIMVideoChatModule * videoChatModule;
@property(nonatomic,strong)NSArray<RTCIceServer*> * iceServerList;
#pragma mark - 用户登陆相关
@property(nonatomic,strong)KIMNodeRequest * nodeRequest;
@property(nonatomic,strong)KIMClientSignInCompletionCallback signInCompletionCallback;
@property(nonatomic,strong)NSOperationQueue * signInQueue;
@property(nonatomic,strong)KIMSessionModule * sessionModule;
@property(nonatomic,strong)NSString * userAccount;
@property(nonatomic,strong)NSString * userPassword;
#pragma mark - 用户注册相关
@property(nonatomic,strong)NSLock * userRegisterRequestSetLock;
@property(nonatomic,strong)NSMutableSet<KIMUserRegisterRequest*> * userRegisterRequestSet;
@end

@implementation KIMClient
-(instancetype)initWithPresidentAddr:(NSString*)presidentAddr presidentPort:(unsigned short)presidentPort andIceServers:(NSArray<RTCIceServer*>*)iceServers
{
    if (![presidentAddr length]) {
        return nil;
    }
    
    self = [super init];
    
    if (self) {
        self.presidentAddr = presidentAddr;
        self.presidentPort = presidentPort;
        self.stateLock = [[NSLock alloc] init];
        self.state = KIMClientState_Offline;
        //业务模块相关
        self.serviceModuleSetLock = [[NSLock alloc] init];
        self.serviceModuleSet = [NSMutableSet<NSObject<KIMClientService>*> set];
        self.messageHandlerSet = [NSMutableDictionary<NSString *,NSMutableSet<NSObject<KIMClientService>*>*> dictionary];
        self.serviceModuleQueue = [[NSOperationQueue alloc] init];
        //业务模块
        self.onlineStateModule = [[KIMOnlineModule alloc] init];
        self.rosterModule = [[KIMRosterModule alloc] init];
        self.chatGroupModule = [[KIMChatGroupModule alloc] init];
        self.chatModule = [[KIMChatModule alloc] init];
        self.iceServerList = iceServers;
        self.videoChatModule = [[KIMVideoChatModule alloc] initWithIceServers:self.iceServerList];
        [self addServiceModule:self.onlineStateModule];
        [self addServiceModule:self.rosterModule];
        [self addServiceModule:self.chatGroupModule];
        [self addServiceModule:self.chatModule];
        [self addServiceModule:self.videoChatModule];
        //用户注册相关
        self.userRegisterRequestSetLock = [[NSLock alloc] init];
        self.userRegisterRequestSet = [NSMutableSet<KIMUserRegisterRequest*> set];
    }
    
    return self;
}

#pragma mark - 模块相关
-(void)addServiceModule:(NSObject<KIMClientService>*)serviceModule
{
    [self.serviceModuleSetLock lock];
    if ([self.serviceModuleSet containsObject:serviceModule]) {
        [self.serviceModuleSetLock unlock];
        return;
    }
    for (NSString * messageType in [serviceModule messageTypeSet]) {
        NSMutableSet<NSObject<KIMClientService>*> * serviceModuleSet = [self.messageHandlerSet objectForKey:messageType];
        if(nil == serviceModuleSet){
            serviceModuleSet = [[NSMutableSet<NSObject<KIMClientService>*> alloc] init];
        }
        [serviceModuleSet addObject:serviceModule];
        [self.messageHandlerSet setObject:serviceModuleSet forKey:messageType];
    }
    [self.serviceModuleSet addObject:serviceModule];
    [serviceModule setIMClient:self];
    [self.serviceModuleSetLock unlock];
}
-(void)removeServiceModule:(NSObject<KIMClientService>*)serviceModule
{
    [self.serviceModuleSetLock lock];
    if (![self.serviceModuleSet containsObject:serviceModule]) {
        [self.serviceModuleSetLock unlock];
        return;
    }
    for (NSString * messageType in [serviceModule messageTypeSet]) {
        NSMutableSet<NSObject<KIMClientService>*> * serviceModuleSet = [self.messageHandlerSet objectForKey:messageType];
        if(nil != serviceModuleSet){
            [serviceModuleSet removeObject:serviceModule];
        }
    }
    [self.serviceModuleSet removeObject:serviceModule];
    [serviceModule setIMClient:nil];
    [self.serviceModuleSetLock unlock];
}

-(void)dispatchMessageToServiceModule:(GPBMessage*)message
{
    [self.serviceModuleSetLock lock];
    NSString * messageFullName = message.descriptor.fullName;
    NSSet<NSObject<KIMClientService>*> * serviceModuleSet = [self.messageHandlerSet objectForKey:messageFullName];
    if (nil != serviceModuleSet) {
        for (NSObject<KIMClientService>* serviceModule in serviceModuleSet) {
            [self.serviceModuleQueue addOperationWithBlock:^{
                [serviceModule handleMessage:message];
            }];
        }
    }
    [self.serviceModuleSetLock unlock];
}

-(KIMUser*)currentUser
{
    return [[KIMUser alloc] initWithUserAccount:self.userAccount];
}
-(void)setState:(KIMClientState)state
{
    
    if (self.state == state) {
        return;
    }
    KIMClientState previous = self->_state;
    self->_state = state;
    
    //通知业务模块
    switch (state) {
        case KIMClientState_Logined:
        {
            for (NSObject<KIMClientService> * serviceModule in self.serviceModuleSet) {
                __weak KIMClient * weakSelf = self;
                KIMUser * user = [self.currentUser copy];
                [self.serviceModuleQueue addOperationWithBlock:^{
                    [serviceModule imClientDidLogin:weakSelf withUser:user];
                }];
            }
        }
            break;
        case KIMClientState_Offline:
        case KIMClientState_ReLoging:
        {
            for (NSObject<KIMClientService> * serviceModule in self.serviceModuleSet) {
                __weak KIMClient * weakSelf = self;
                KIMUser * user = [self.currentUser copy];
                
                [self.serviceModuleQueue addOperationWithBlock:^{
                    [serviceModule imClientDidLogout:weakSelf withUser:user];
                }];
            }
        }
            break;
        default:
            break;
    }

    //在主线程发布通知
    NSNotification * notification = [[NSNotification alloc] initWithName:KIMClientStateChangedNotificationName object:nil userInfo:@{@"previous":[NSNumber numberWithUnsignedInteger:previous],@"now":[NSNumber numberWithUnsignedInteger:self->_state]}];
    if ([NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue]) {
        [[NSNotificationCenter defaultCenter] postNotification:notification];
    }else{
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        }];
    }
}

-(void)signInWithUserAccount:(NSString*)userAccount userPassword:(NSString*)userPassword longitude:(float)longitude latitude:(float)latitude andCompletion:(KIMClientSignInCompletionCallback)completion
{
    if (![userAccount length] || ![userPassword length]) {
        if (completion) {
            completion(self,[NSError errorWithDomain:NSStringFromClass(self.class) code:KIMClientLoginFailedType_ParameterError userInfo:nil]);
        }
        return;
    }
    [self.stateLock lock];
    if (KIMClientState_Offline != self.state) {
        //告知调用方，当前正在执行其它操作
        KIMClientLoginFailedType failedType = KIMClientLoginFailedType_DoingLogingAction;
        if (KIMClientState_Logined != self.state) {
            failedType = KIMClientLoginFailedType_DoingLogingAction;
        }else{
            failedType = KIMClientLoginFailedType_Logined;
        }
        [self.stateLock unlock];
        if (completion) {
            completion(self,[NSError errorWithDomain:NSStringFromClass(self.class) code:failedType userInfo:nil]);
        }
        return;
    }
    self.userAccount = userAccount;
    self.userPassword = userPassword;
    //1.请求服务节点
    self.state = KIMClientState_RetrievingNodeServer;
    self.signInCompletionCallback = completion;
    self.signInQueue = [NSOperationQueue currentQueue];
    [self.stateLock unlock];
    __weak KIMClient * weakSelf = self;
    self.nodeRequest = [[KIMNodeRequest alloc] initWithServerAddr:self.presidentAddr serverPort:self.presidentPort userAccount:userAccount longitude:longitude latitude:latitude andCompletion:^(KIMNodeRequest *request, NSError *error, NSArray<NSDictionary *> *serverList) {
        [weakSelf.stateLock lock];
        if (KIMClientState_RetrievingNodeServer != weakSelf.state) {
            [weakSelf.stateLock unlock];
            return;
        }
        weakSelf.nodeRequest = nil;
        if (error) {
            self.userAccount = nil;
            self.userPassword = nil;
            weakSelf.state = KIMClientState_Offline;
            [weakSelf.stateLock unlock];
            if (weakSelf.signInCompletionCallback) {
                if([[NSOperationQueue currentQueue] isEqual:weakSelf.signInQueue]){
                    weakSelf.signInCompletionCallback(weakSelf, [NSError errorWithDomain:@"KIMClient" code:KIMClientLoginFailedType_NetworkError userInfo:nil]);
                }else{
                    KIMClientSignInCompletionCallback signInCompletionCallback = weakSelf.signInCompletionCallback;
                    [weakSelf.signInQueue addOperationWithBlock:^{
                        signInCompletionCallback(weakSelf, [NSError errorWithDomain:@"KIMClient" code:KIMClientLoginFailedType_NetworkError userInfo:nil]);
                    }];
                }
            }
            weakSelf.signInCompletionCallback = nil;
            weakSelf.signInQueue = nil;
            return;
        }
        if (![serverList count]) {
            self.userAccount = nil;
            self.userPassword = nil;
            weakSelf.state = KIMClientState_Offline;
            [weakSelf.stateLock unlock];
            if (weakSelf.signInCompletionCallback) {
                
                if ([[NSOperationQueue currentQueue] isEqual:weakSelf.signInQueue]) {
                    weakSelf.signInCompletionCallback(weakSelf, [NSError errorWithDomain:@"KIMClient" code:KIMClientLoginFailedType_NetworkError userInfo:nil]);
                    weakSelf.signInCompletionCallback = nil;
                    weakSelf.signInQueue = nil;
                }else{
                    [weakSelf.signInQueue addOperationWithBlock:^{
                        
                        if(weakSelf.signInCompletionCallback){
                            NSLog(@"signInCompletionCallback exits");
                        }else{
                            NSLog(@"signInCompletionCallback not exits");
                        }
                        
                        weakSelf.signInCompletionCallback(weakSelf, [NSError errorWithDomain:@"KIMClient" code:KIMClientLoginFailedType_NetworkError userInfo:nil]);
                        weakSelf.signInCompletionCallback = nil;
                        weakSelf.signInQueue = nil;
                    }];
                }
            }
            return;
        }
        //登陆服务节点
        NSDictionary * nodeServerInfo = [serverList firstObject];
        weakSelf.sessionModule = [[KIMSessionModule alloc] initWithServerAddr:[nodeServerInfo objectForKey:@"ipAddr"] andPort:[[nodeServerInfo objectForKey:@"port"]unsignedShortValue]];
        weakSelf.sessionModule.delegate = weakSelf;
        weakSelf.state = KIMClientState_Loging;
        [weakSelf.stateLock unlock];
        [weakSelf.sessionModule start];
    }];
    [[KIMRequestSession sharedSession] submitRequest:self.nodeRequest];
}
-(void)signOut
{
    [self.stateLock lock];
    switch (self.state) {
        case KIMClientState_RetrievingNodeServer://当前正在请求服务节点
        {
            //取消服务节点请求
            [self.nodeRequest cancel];
            self.nodeRequest = nil;
            self.userAccount = nil;
            self.userPassword = nil;
            //执行回调
            if (self.signInCompletionCallback) {
                if ([[NSOperationQueue currentQueue] isEqual:self.signInQueue]) {
                    self.signInCompletionCallback(self, [NSError errorWithDomain:NSStringFromClass(self.class) code:KIMClientLoginFailedType_Canceled userInfo:nil]);
                }else{
                    __weak KIMClient * weakSelf = self;
                    [self.signInQueue addOperationWithBlock:^{
                        weakSelf.signInCompletionCallback(weakSelf, [NSError errorWithDomain:@"KIMClient" code:KIMClientLoginFailedType_Canceled userInfo:nil]);
                    }];
                }
            }
            self.signInCompletionCallback = nil;
            self.signInQueue = nil;
        }
            break;
        case KIMClientState_Loging://当前正在登陆
        {
            //销毁会话模块
            self.sessionModule = nil;
            self.userAccount = nil;
            self.userPassword = nil;
            //执行回调
            if (self.signInCompletionCallback) {
                if ([NSOperationQueue.currentQueue isEqual:self.signInQueue]) {
                    self.signInCompletionCallback(self, [NSError errorWithDomain:NSStringFromClass(self.class) code:KIMClientLoginFailedType_Canceled userInfo:nil]);
                }else{
                    __weak KIMClient * weakSelf = self;
                    [self.signInQueue addOperationWithBlock:^{
                        self.signInCompletionCallback(weakSelf, [NSError errorWithDomain:@"KIMClient" code:KIMClientLoginFailedType_Canceled userInfo:nil]);
                    }];
                }
            }
            self.signInCompletionCallback = nil;
            self.signInQueue = nil;
        }
            break;
        case KIMClientState_Logined://已经登陆
        {
            //销毁会话模块
            self.sessionModule = nil;
            self.userAccount = nil;
            self.userPassword = nil;
        }
            break;
        case KIMClientState_ReLoging://正在重新登陆
        {
            //销毁会话模块
            self.sessionModule = nil;
            self.userAccount = nil;
            self.userPassword = nil;
        }
            break;
        case KIMClientState_Offline://已离线
        default:
            break;
    }
    self.state = KIMClientState_Offline;
    [self.stateLock unlock];
}
-(void)sessionModule:(KIMSessionModule*)sessionModule didChangedState:(KIMSessionModuleState)state
{
    [self.stateLock lock];
    
    if (KIMClientState_Loging == self.state) {
        if (KIMSessionModuleState_SessionBuilded == state) {//会话构建成功
            //发送登陆请求
            KIMProtoLoginMessage * loginMessage = [[KIMProtoLoginMessage alloc] init];
            [loginMessage setUserAccount:self.userAccount];
            [loginMessage setUserPassword:self.userPassword];
            [sessionModule sendMessage:loginMessage];
        }else if(KIMSessionModuleState_Ready == state){//会话模块停止
            //销毁会话模块
            self.sessionModule = nil;
            self.userAccount = nil;
            self.userPassword = nil;
            self.state = KIMClientState_Offline;
            //执行回调
            if (self.signInCompletionCallback) {
                if ([NSOperationQueue.currentQueue isEqual:self.signInQueue]) {
                    self.signInCompletionCallback(self,[NSError errorWithDomain:NSStringFromClass(self.class) code:KIMClientLoginFailedType_NetworkError userInfo:nil]);
                    self.signInCompletionCallback = nil;
                }else{
                    __weak KIMClient * weakSelf = self;
                    [self.signInQueue addOperationWithBlock:^{
                        weakSelf.signInCompletionCallback(weakSelf,[NSError errorWithDomain:@"KIMClient" code:KIMClientLoginFailedType_NetworkError userInfo:nil]);
                        weakSelf.signInCompletionCallback = nil;
                    }];
                }
            }
        }
        [self.stateLock unlock];
    }else if(KIMClientState_Logined == self.state){
        
        if (KIMSessionModuleState_Ready == state) {//会话模块停止
            //销毁会话模块
            self.sessionModule = nil;
            self.userAccount = nil;
            self.userPassword = nil;
            self.state = KIMClientState_Offline;
        }else if(KIMSessionModuleState_SessionBuilded != state){//会话模块正在重连
            self.state = KIMClientState_ReLoging;
        }
        [self.stateLock unlock];
    }else if(KIMClientState_ReLoging == self.state){
        if (KIMSessionModuleState_Ready == state) {//会话模块停止
            //销毁会话模块
            self.sessionModule = nil;
            self.userAccount = nil;
            self.userPassword = nil;
            self.state = KIMClientState_Offline;
        }else if (KIMSessionModuleState_SessionBuilded == state) {//会话构建成功
            //发送登陆请求
            KIMProtoLoginMessage * loginMessage = [[KIMProtoLoginMessage alloc] init];
            [loginMessage setUserAccount:self.userAccount];
            [loginMessage setUserPassword:self.userPassword];
            [sessionModule sendMessage:loginMessage];
        }
        [self.stateLock unlock];
    }else{
        [self.stateLock unlock];
    }
}
-(void)sessionModule:(KIMSessionModule*)sessionModule didReceivedMessage:(GPBMessage*)message
{
    [self.stateLock lock];
    
    if (KIMClientState_Loging == self.state) {
        if (KIMSessionModuleState_SessionBuilded == sessionModule.state && [message.descriptor.fullName isEqualToString:KIMProtoResponseLoginMessage.descriptor.fullName]) {
            
            KIMProtoResponseLoginMessage * responseLoginMessage = (KIMProtoResponseLoginMessage*)message;
            if (KIMProtoResponseLoginMessage_LoginState_Success == responseLoginMessage.loginState) {//登陆成功
                self.state = KIMClientState_Logined;
                //执行回调
                if (self.signInCompletionCallback) {
                    if ([NSOperationQueue.currentQueue isEqual:self.signInQueue]) {
                        self.signInCompletionCallback(self,nil);
                        self.signInCompletionCallback = nil;
                        self.signInQueue = nil;
                    }else{
                    __weak KIMClient * weakSelf = self;
                        [self.signInQueue addOperationWithBlock:^{
                            weakSelf.signInCompletionCallback(weakSelf,nil);
                            weakSelf.signInCompletionCallback = nil;
                            weakSelf.signInQueue = nil;
                        }];
                    }
                }
            }else{//登陆失败
                //销毁会话模块
                self.sessionModule = nil;
                self.userAccount = nil;
                self.userPassword = nil;
                self.state = KIMClientState_Offline;
                //执行回调
                KIMClientLoginFailedType failedType = KIMClientLoginFailedType_ServerInternalError;
                switch (responseLoginMessage.failureError) {
                    case KIMProtoResponseLoginMessage_FailureError_WrongAccountOrPassword:
                    {
                        failedType = KIMClientLoginFailedType_WrongAccountOrPassword;
                    }
                        break;
                    case KIMProtoResponseLoginMessage_FailureError_ServerInternalError:
                    {
                        failedType = KIMClientLoginFailedType_ServerInternalError;
                    }
                        break;
                    default:
                        break;
                }
                
                if (self.signInCompletionCallback) {
                    if ([NSOperationQueue.currentQueue isEqual:self.signInQueue]) {
                        self.signInCompletionCallback(self,[NSError errorWithDomain:NSStringFromClass(self.class) code:failedType userInfo:nil]);
                        self.signInCompletionCallback = nil;
                    }else{
                        __weak KIMClient * weakSelf = self;
                        [self.signInQueue addOperationWithBlock:^{
                            weakSelf.signInCompletionCallback(weakSelf,[NSError errorWithDomain:@"KIMClient" code:failedType userInfo:nil]);
                            weakSelf.signInCompletionCallback = nil;
                        }];
                    }
                }
            }
        }
        [self.stateLock unlock];
    }else if(KIMClientState_ReLoging == self.state){
        if (KIMSessionModuleState_SessionBuilded == sessionModule.state && [message.descriptor.fullName isEqualToString:KIMProtoResponseLoginMessage.descriptor.fullName]) {
            KIMProtoResponseLoginMessage * responseLoginMessage = (KIMProtoResponseLoginMessage*)message;
            if (KIMProtoResponseLoginMessage_LoginState_Success == responseLoginMessage.loginState) {//重新登陆成功
                self.state = KIMClientState_Logined;
            }else{//登陆失败
                //销毁会话模块
                self.sessionModule = nil;
                self.userAccount = nil;
                self.userPassword = nil;
                self.state = KIMClientState_Offline;
            }
        }
        [self.stateLock unlock];
    }else if(KIMClientState_Logined == self.state){
        [self.stateLock unlock];
        //分发消息
        [self dispatchMessageToServiceModule:message];
    }else{
        [self.stateLock unlock];
    }
}


-(void)signUpWithNodeServerAddr:(NSString*)nodeServerAddr nodeServerPort:(unsigned short)nodeServerPort userAccount:(NSString*)userAccount userPassword:(NSString*)userPassword userNickName:(NSString*)userNickName userGender:(KIMUserGender)userGender andCompletion:(void(^)(KIMClient * imClient,NSError * error))completion
{
    [self.userRegisterRequestSetLock lock];
    NSOperationQueue * signUpQueue = [NSOperationQueue currentQueue];
    __weak KIMClient * weakSelf = self;
    KIMUserRegisterRequest * userRegisterRequest = [[KIMUserRegisterRequest alloc] initWithServerAddr:nodeServerAddr serverPort:nodeServerPort userAccount:userAccount userPassword:userPassword userNickName:userNickName userGender:userGender andCompletion:^(KIMUserRegisterRequest *request, NSError *error) {
        [weakSelf.userRegisterRequestSet removeObject:request];
        if (completion) {
            if ([signUpQueue isEqual:[NSOperationQueue currentQueue]]) {
                completion(weakSelf,error);
            }else{
                [signUpQueue addOperationWithBlock:^{
                    completion(weakSelf,error);
                }];
            }
        }
    }];
    [self.userRegisterRequestSet addObject:userRegisterRequest];
    [self.userRegisterRequestSetLock unlock];
    [[KIMRequestSession sharedSession] submitRequest:userRegisterRequest];
}

#pragma mark - KIMClient(Service)
-(BOOL)sendMessage:(GPBMessage*)message
{
    [self.stateLock lock];
    if (KIMClientState_Logined != self.state) {
        [self.stateLock unlock];
        return NO;
    }
    
    [self.sessionModule sendMessage:message];
    [self.stateLock unlock];
    return YES;
}
-(NSString*)currentDeviceIdentifier
{
    return [[[UIDevice currentDevice] identifierForVendor] UUIDString];
}
#pragma mark - KIMClient(VideoChatModule)
-(NSString*)currentSessionId
{
    return self.sessionModule.sessionId;
}
@end
