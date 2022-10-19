//
//  KIMUser.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/27.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger,KIMUserGender)
{
    KIMUserGender_Male,//小哥哥
    KIMUserGender_Female,//小姐姐
    KIMUserGender_Unknown,//未知
};

@interface KIMUser : NSObject<NSCoding,NSCopying>
@property(nonatomic,strong)NSString * account;
-(instancetype)initWithUserAccount:(NSString*)userAccount;
@end
