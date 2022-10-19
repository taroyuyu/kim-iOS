//
//  KIMVideoChatRequest+KIMVideoChatModule.h
//  HUTLife
//
//  Created by taroyuyu on 2018/5/4.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMVideoChatRequest.h"
@protocol KIMMediaSessionDelegate;
@interface KIMVideoChatRequest (KIMVideoChatModule)
@property(nonatomic,assign)BOOL isAcked;
@property(nonatomic,strong)NSString * requestIdentifier;
@property(nonatomic,strong)NSString * sponsorSessionId;
@property(nonatomic,weak)NSObject<KIMMediaSessionDelegate> * mediaSessionDelegate;
@end
