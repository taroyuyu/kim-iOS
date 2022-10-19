//
//  ChatTextMessageCell.m
//  HUTLife
//
//  Created by Lingyu on 16/4/8.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "ChatTextMessageCell.h"
#import "ChatTextMessageView.h"
#import "KIMChatMessage.h"
#import "KIMUserVCard.h"
#import "KIMUser.h"
@interface ChatTextMessageCell ()
@property(nonatomic,strong)ChatTextMessageView *textMessageView;
@end

@implementation ChatTextMessageCell
static CGSize AvatarViewSize;
static CGFloat AvatarViewMarginEdge;
static CGFloat AvatarViewMarginTop;
static CGFloat ContentBackgroundViewMarginTop;
static CGFloat ContentBackgroundViewMarginAvatarView;
static CGFloat ContentBackgroundViewMarginEdge;
static CGFloat ContentBackgroundBubbleWidth;
static CGFloat ContentBackgroundPadding;
static UIFont *TextFont;
+(void)load
{
    [super load];
    AvatarViewSize = CGSizeMake(40, 40);
    AvatarViewMarginEdge = 10;
    AvatarViewMarginTop = 10;
    ContentBackgroundViewMarginTop = AvatarViewMarginTop;
    ContentBackgroundViewMarginAvatarView = 2;
    ContentBackgroundViewMarginEdge = AvatarViewSize.width + AvatarViewMarginEdge;
    ContentBackgroundBubbleWidth = 24;
    ContentBackgroundPadding = 3;
    TextFont = [UIFont systemFontOfSize:17];
}
//根据ChatTextMessageModel和最大宽度返回ChatTextMessageCell的rowHeight属性
+(CGFloat)rowHeightWithtextMessage:(KIMChatMessage*)model andMaxWidth:(CGFloat)maxWidth;
{
    NSString *textMessage = [model content];
    
    //计算textMessageView
    
    CGFloat MaxHeight = CGFLOAT_MAX;
    CGFloat contentNeedsHeight = [model.content boundingRectWithSize:CGSizeMake(maxWidth, MaxHeight) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:TextFont} context:nil].size.height;
    /**
    CGRect textMessageLabelNeedBounds = [ChatTextMessageView needRectWithtextMessage:textMessage andMaxWidth:textMessageLabelMaxWidth];

    CGFloat rowHeight = textMessageLabelNeedBounds.size.height + ContentBackgroundViewMarginTop + ContentBackgroundPadding * 2;
    **/
    return 0;
    
}
+(instancetype)textMessageCellWithTableView:(UITableView*)tableView andModel:(KIMChatMessage*)model
{
    static NSString *textMessageCellIdentifier = @"textMessageCell";
    
    ChatTextMessageCell *textMessageCell = [tableView dequeueReusableCellWithIdentifier:textMessageCellIdentifier];
    
    if (nil==textMessageCell) {
        textMessageCell = [[ChatTextMessageCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:textMessageCellIdentifier];
        
    }
    [textMessageCell setModel:model];
    
    return textMessageCell;
    
}
-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    
    if (self) {
        [self loadSubviews];
        [self setSelectionStyle:UITableViewCellSelectionStyleNone];
    }
    
    return self;
}


-(void)loadSubviews
{
    [self addSubview:[self avatarView]];
    [self addSubview:[self textMessageView]];
}

-(void)setType:(ChatTextMessageCellType)type
{
    self->_type = type;
    
    //更新textMessageView的背景颜色
    switch (type) {
        case ChatTextMessageCellTypeSend:
            [self->_textMessageView setImage:[UIImage imageNamed:@"chat_bubble_me"]];
            break;
        case ChatTextMessageCellTypeReceived:
            [self->_textMessageView setImage:[UIImage imageNamed:@"chat_bubble_reply"]];
            break;
    }
}

-(void)setModel:(KIMChatMessage *)model
{
    self->_model = model;
    [self loadModelInfo];
}

-(UIImageView*)avatarView
{
    if (self->_avatarView) {
        return self->_avatarView;
    }
    
    /**
    self->_avatarView = [UIImageView new];
    [self->_avatarView setBounds:CGRectMake(0, 0, avatorViewWidth, avatorViewWidth)];
    [[self->_avatarView layer] setCornerRadius:avatorViewWidth/2];
    [self->_avatarView setClipsToBounds:YES];
    */
    return self->_avatarView;
}

-(ChatTextMessageView*)textMessageView
{
    if (self->_textMessageView) {
        return self->_textMessageView;
    }
    
    self->_textMessageView = [ChatTextMessageView new];
    return self->_textMessageView;
}

-(void)loadModelInfo
{
//    KIMUser * currentUser = [[(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient] currentUser];
//    if ([[[[self model] sender] userAccount] isEqualToString:[currentUser userAccount]]) {
//        [self setType:ChatTextMessageCellTypeSend];
//    }else{
//        [self setType:ChatTextMessageCellTypeReceived];
//    }
//    
//    KIMRosterModule * rosterModel = [[(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient] rosterModule];
//    KIMUserVCard * userVCard = nil;
//    userVCard = [rosterModel retriveUserVCardFromLocalCache:[[self model]sender]];
//    
//    if (userVCard) {
//        [[self avatarView] setImage:[UIImage imageWithData:[userVCard avatar]]];
//    }else{
//        [rosterModel retriveUserVCardFromServer:[[self model]sender] success:^(KIMRosterModule *rosterModule, KIMUserVCard *userVCard) {
//                [[self avatarView] setImage:[UIImage imageWithData:[userVCard avatar]]];
//        } failure:nil];
//    }
//    
//    switch ([self type]) {
//        case ChatTextMessageCellTypeSend:
//        {
//            
//        }
//            break;
//        case ChatTextMessageCellTypeReceived:
//        {
//            
//        }
//            break;
//    }
//
//    
//    [[self textMessageView] setTextMessage:[[self model] content]];
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize contentSize = [self bounds].size;
    
    //根据type进行布局
    /**
    switch (_type) {
        case ChatTextMessageCellTypeSend:
        {
            //布局avator
            CGFloat avatorViewMarginTop = interval;
            CGFloat avatorViewMarginRight = interval;
            CGSize avatorViewSize = [[self avatarView] bounds].size;
            [[self avatarView] setFrame:CGRectMake(contentSize.width-avatorViewMarginRight-avatorViewSize.width, avatorViewMarginTop, avatorViewSize.width, avatorViewSize.height)];
            
            //布局textMessageView
            CGFloat textMessageLabelMarginTop = interval;
            CGFloat textMessageLabelMaxWidth = contentSize.width - avatorViewSize.width - 3 * interval;
            CGRect textMessageLabelNeedBounds = [ChatTextMessageView needRectWithtextMessage:[[self textMessageView] textMessage] andMaxWidth:textMessageLabelMaxWidth];
            CGFloat textMessageLabelWidth = textMessageLabelNeedBounds.size.width;
            CGFloat textMessageLabelHeight = textMessageLabelNeedBounds.size.height;
            CGFloat textMessageLabelMarginLeft = contentSize.width - (avatorViewSize.width + avatorViewMarginRight + interval + textMessageLabelWidth);
            [[self textMessageView] setFrame:CGRectMake(textMessageLabelMarginLeft, textMessageLabelMarginTop, textMessageLabelWidth, textMessageLabelHeight)];
        }
            break;
        case ChatTextMessageCellTypeReceived:
        {
            //布局avator
            CGFloat avatorViewMarginTop = interval;
            CGFloat avatorViewMarginLeft = interval;
            CGSize avatorViewSize = [[self avatarView] bounds].size;
            [[self avatarView] setFrame:CGRectMake(avatorViewMarginLeft, avatorViewMarginTop, avatorViewSize.width, avatorViewSize.height)];
            
            //布局textMessageView
            CGFloat textMessageLabelMarginTop = interval;
            CGFloat textMessageLabelMarginLeft = CGRectGetMaxX([[self avatarView] frame]) + interval;
            CGFloat textMessageLabelMaxWidth = contentSize.width - textMessageLabelMarginLeft - interval;
            CGRect textMessageLabelNeedBounds = [ChatTextMessageView needRectWithtextMessage:[[self textMessageView] textMessage] andMaxWidth:textMessageLabelMaxWidth];
            CGFloat textMessageLabelWidth = textMessageLabelNeedBounds.size.width;
            CGFloat textMessageLabelHeight = textMessageLabelNeedBounds.size.height;
            [[self textMessageView] setFrame:CGRectMake(textMessageLabelMarginLeft, textMessageLabelMarginTop, textMessageLabelWidth, textMessageLabelHeight)];
            
        }
            break;
    }
    
     */
}

@end
