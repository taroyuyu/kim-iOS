//
//  ChatTextMessageView.h
//  HUTLife
//
//  Created by Lingyu on 16/4/8.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ChatTextMessageView : UIImageView
@property(nonatomic,copy)NSString *textMessage;
//根据textMessage和最大宽度返回ChatTextMessageView的bounds属性
+(CGRect)needRectWithtextMessage:(NSString*)textMessage andMaxWidth:(CGFloat)maxWidth;
@end
