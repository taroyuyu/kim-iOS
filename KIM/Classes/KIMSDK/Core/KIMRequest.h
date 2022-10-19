//
//  KIMRequest.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/26.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KIMRequest : NSObject
@property(nonatomic,strong)NSString * serverAddr;
@property(nonatomic,assign)unsigned short serverPort;
-(instancetype)initWithServerAddr:(NSString*const)serverAddr serverPort:(const unsigned short)serverPort;
-(void)cancel;
@end
