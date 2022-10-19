//
//  KIMUserVCard.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/27.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMUser.h"
@interface KIMUserVCard : NSObject
@property(nonatomic,strong)KIMUser * user;
@property(nonatomic,strong)NSString * nickName;
@property(nonatomic,strong)NSData * avatar;
@property(nonatomic,assign)KIMUserGender gender;
@property(nonatomic,strong)NSString * mood;
@end
