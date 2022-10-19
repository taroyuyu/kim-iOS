//
//  KIMRequestSession.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/26.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMRequest.h"

@interface KIMRequestSession : NSObject
+(instancetype)sharedSession;
-(void)submitRequest:(KIMRequest*)request;
@end
