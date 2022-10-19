//
//  KIMNodeRequest.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/26.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMRequest.h"
@class KIMNodeRequest;
typedef void(^KIMNodeRequestCompletion)(KIMNodeRequest * request,NSError * error,NSArray<NSDictionary*> * serverList);

@interface KIMNodeRequest : KIMRequest
@property(nonatomic,strong)NSString * userAccount;
@property(nonatomic,assign)float longitude;
@property(nonatomic,assign)float latitude;
-(instancetype)initWithServerAddr:(NSString*const)serverAddr serverPort:(const unsigned short)serverPort userAccount:(NSString*const)userAccount longitude:(const float)longitude latitude:(const float)latitude andCompletion:(KIMNodeRequestCompletion)completion;
@end
