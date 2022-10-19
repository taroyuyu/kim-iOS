//
//  KIMClientService.h
//  HUTLife
//
//  Created by taroyuyu on 2018/6/1.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#ifndef KIMClientService_h
#define KIMClientService_h

@class GPBMessage;
@class KIMClient;
@class KIMUser;
@protocol KIMClientService
@required
-(void)setIMClient:(KIMClient*)imClient;
-(NSSet<NSString*>*)messageTypeSet;
-(void)handleMessage:(GPBMessage *)message;
@optional
-(void)imClientDidLogin:(KIMClient*)imClient withUser:(KIMUser*)user;
-(void)imClientDidLogout:(KIMClient*)imClient withUser:(KIMUser*)user;
@end

#endif /* KIMClientService_h */
