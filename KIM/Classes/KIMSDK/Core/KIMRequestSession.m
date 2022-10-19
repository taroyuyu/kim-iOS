//
//  KIMRequestSession.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/26.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMRequestSession.h"
#import "KIMTCPSocketManager.h"
#import "KIMClientSocket.h"
#import "KIMRequest+KIMRequestSession.h"
@interface KIMRequestSession()
@property(nonatomic,strong)KIMTCPSocketManager * socketManager;
@end

@implementation KIMRequestSession

static KIMRequestSession * sharedSingleton = nil;

+(instancetype)sharedSession
{
    if (nil != sharedSingleton) {
        return sharedSingleton;
    }
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedSingleton = [[self alloc] init];
    });
    return sharedSingleton;
}
-(instancetype)init
{
    self = [super init];
    
    if (self) {
        self.socketManager = [[KIMTCPSocketManager alloc] init];
        [self.socketManager start];
    }
    
    return self;
}
-(void)submitRequest:(KIMRequest*)request
{
    //执行请求
    [request executeWithSocketManager:self.socketManager];
}
@end
