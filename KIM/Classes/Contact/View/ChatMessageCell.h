//
//  ChatMessageCell.h
//  HUTLife
//
//  Created by Kakawater on 2018/4/25.
//  Copyright © 2018年 Kakawater. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ChatMessage.h"
typedef NS_ENUM(NSUInteger,ChatMessageCellStyle)
{
    ChatMessageCellStyle_Received,
    ChatMessageCellStyle_Sended
};

@interface ChatMessageCell : UITableViewCell
@property(nonatomic,strong)ChatMessage * model;
@property(nonatomic,assign)ChatMessageCellStyle stype;
+(CGFloat)rowHeightWithtextMessage:(ChatMessage*)model andMaxWidth:(CGFloat)maxWidth;
-(void)loadModelInfo;
@end
