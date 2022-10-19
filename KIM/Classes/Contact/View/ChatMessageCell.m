//
//  ChatMessageCell.m
//  HUTLife
//
//  Created by Kakawater on 2018/4/25.
//  Copyright © 2018年 Kakawater. All rights reserved.
//

#import "ChatMessageCell.h"
static CGSize AvatarViewSize;
static CGFloat AvatarViewMarginEdge;
static CGFloat AvatarViewMarginTop;
static CGFloat ContentBackgroundViewMarginTop;
static CGFloat ContentBackgroundViewMarginAvatarView;
static CGFloat ContentBackgroundViewMarginEdge;
static CGFloat ContentBackgroundBubbleWidth;
static CGFloat ContentBackgroundPadding;
@interface ChatMessageCell()
@property(nonatomic,strong)UIImageView * avatarView;
@property(nonatomic,strong)UIImageView * contentBackgroundView;
@property(nonatomic,strong)UILabel * textContentView;
@end

@implementation ChatMessageCell
+(void)initialize
{
    [super initialize];
    
    AvatarViewSize = CGSizeMake(40, 40);
    AvatarViewMarginEdge = 10;
    AvatarViewMarginTop = 10;
    ContentBackgroundViewMarginTop = AvatarViewMarginTop * 2;
    ContentBackgroundViewMarginAvatarView = 2;
    ContentBackgroundViewMarginEdge = AvatarViewSize.width + AvatarViewMarginEdge;
    ContentBackgroundBubbleWidth = 6;
    ContentBackgroundPadding = 6;
}
+(CGFloat)rowHeightWithtextMessage:(ChatMessage*)model andMaxWidth:(CGFloat)maxWidth
{
    //1.计算文本内容的最大宽度
    const CGFloat TextContentMaxWidth = maxWidth - (AvatarViewMarginEdge + AvatarViewSize.width + ContentBackgroundViewMarginAvatarView + ContentBackgroundViewMarginEdge + ContentBackgroundPadding * 2 + ContentBackgroundBubbleWidth);
    const CGSize TextContentSize = [model.textContent boundingRectWithSize:CGSizeMake(TextContentMaxWidth, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:17]} context:nil].size;
    const CGFloat ContentBackgroundViewHeight = TextContentSize.height + ContentBackgroundPadding * 2;
    
    if ((ContentBackgroundViewHeight + ContentBackgroundViewMarginTop) < (AvatarViewSize.height + AvatarViewMarginTop)) {
        return AvatarViewSize.height + AvatarViewMarginTop;
    }else{
        return ContentBackgroundViewHeight + ContentBackgroundViewMarginTop;
    }
}
-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    
    if (self) {
        [self addSubview:[self avatarView]];
        [self addSubview:[self contentBackgroundView]];
        [self addSubview:[self textContentView]];
    }
    
    return self;
}
-(UIImageView *)avatarView
{
    if (self->_avatarView) {
        return self->_avatarView;
    }
    
    self->_avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, AvatarViewSize.width, AvatarViewSize.height)];
    self->_avatarView.layer.cornerRadius = AvatarViewSize.width/2;
    self->_avatarView.clipsToBounds = YES;
    return self->_avatarView;
}

-(UIImageView*)contentBackgroundView
{
    if (self->_contentBackgroundView) {
        return self->_contentBackgroundView;
    }
    
    self->_contentBackgroundView = [[UIImageView alloc] initWithFrame:CGRectZero];
    
    return self->_contentBackgroundView;
}

-(UILabel*)textContentView
{
    if (self->_textContentView) {
        return self->_textContentView;
    }
    
    self->_textContentView = [[UILabel alloc] initWithFrame:CGRectZero];
    [self->_textContentView setFont:[UIFont systemFontOfSize:17]];
    [self->_textContentView setNumberOfLines:0];
    return self->_textContentView;
}

-(void)setModel:(ChatMessage *)model
{
    self->_model = model;
    
    [self loadModelInfo];
}

-(void)setStype:(ChatMessageCellStyle)stype
{
    self->_stype = stype;
    
    switch (self->_stype) {
        case ChatMessageCellStyle_Sended:
        {
            self.contentBackgroundView.image = [UIImage imageNamed:@"icon_sender_text_node_normal"];
            self.contentBackgroundView.highlightedImage = [UIImage imageNamed:@"icon_sender_text_node_normal"];
            [self.textContentView setTextColor:[UIColor whiteColor]];
        }
            break;
        case ChatMessageCellStyle_Received:
        {
            self.contentBackgroundView.image = [UIImage imageNamed:@"icon_receiver_node_normal"];
            self.contentBackgroundView.highlightedImage = [UIImage imageNamed:@"icon_receiver_node_pressed"];
            [self.textContentView setTextColor: [UIColor blackColor]];
        }
            break;
        default:
        {
            self.contentBackgroundView.image = nil;
            self.contentBackgroundView.highlightedImage = nil;
        }
            break;
    }
}

-(void)loadModelInfo
{
    [[self avatarView] setImage:[UIImage imageWithData:self.model.senderAvatar]];
    switch (self.model.type) {
        case ChatMessageType_TextMessage:
        {
            self.textContentView.text = self.model.textContent;
        }
            break;
        case ChatMessageType_ImageMessage:
        {
            self.textContentView.text = nil;
        }
        default:
            break;
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    switch (self.stype) {
        case ChatMessageCellStyle_Sended:
        {
            [self layoutSendedStyle];
        }
            break;
        case ChatMessageCellStyle_Received:
        {
            [self layoutReceivedStyle];
        }
            break;
    }
}

-(void)layoutSendedStyle
{
    CGSize contentSize = self.bounds.size;
    //1.布局avatar
    self.avatarView.frame = CGRectMake(contentSize.width - (AvatarViewSize.width + AvatarViewMarginEdge), AvatarViewMarginTop, AvatarViewSize.width, AvatarViewSize.height);
    //2.布局contentBackgroundView
    const CGFloat TextContentMaxWidth = contentSize.width - (AvatarViewMarginEdge + AvatarViewSize.width + ContentBackgroundViewMarginAvatarView + ContentBackgroundViewMarginEdge + ContentBackgroundPadding * 2 + ContentBackgroundBubbleWidth);
    const CGSize TextContentSize = [self.model.textContent boundingRectWithSize:CGSizeMake(TextContentMaxWidth, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:17]} context:nil].size;
    self.contentBackgroundView.frame = CGRectMake(self.avatarView.frame.origin.x - ContentBackgroundViewMarginAvatarView - ContentBackgroundBubbleWidth - ContentBackgroundPadding * 2 - TextContentSize.width, ContentBackgroundViewMarginTop, TextContentSize.width + ContentBackgroundPadding * 2 + ContentBackgroundBubbleWidth,TextContentSize.height + ContentBackgroundPadding * 2);
    //3.布局textContentView
    self.textContentView.frame = CGRectMake(self.contentBackgroundView.frame.origin.x + ContentBackgroundPadding, self.contentBackgroundView.frame.origin.y+ContentBackgroundPadding,TextContentSize.width,TextContentSize.height);
}

-(void)layoutReceivedStyle
{
    CGSize contentSize = self.bounds.size;
    //1.布局avatar
    self.avatarView.frame = CGRectMake(AvatarViewMarginEdge, AvatarViewMarginTop, AvatarViewSize.width, AvatarViewSize.height);
    //2.布局contentBackgroundView
    const CGFloat TextContentMaxWidth = contentSize.width - (AvatarViewMarginEdge + AvatarViewSize.width + ContentBackgroundViewMarginAvatarView + ContentBackgroundViewMarginEdge + ContentBackgroundPadding * 2 + ContentBackgroundBubbleWidth);
    const CGSize TextContentSize = [self.model.textContent boundingRectWithSize:CGSizeMake(TextContentMaxWidth, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:17]} context:nil].size;
    self.contentBackgroundView.frame = CGRectMake(CGRectGetMaxX(self.avatarView.frame) + ContentBackgroundViewMarginAvatarView, ContentBackgroundViewMarginTop, TextContentSize.width + ContentBackgroundPadding * 2 + ContentBackgroundBubbleWidth , TextContentSize.height + ContentBackgroundPadding * 2);
    //3.布局textContentView
    self.textContentView.frame = CGRectMake(self.contentBackgroundView.frame.origin.x + ContentBackgroundBubbleWidth + ContentBackgroundPadding, self.contentBackgroundView.frame.origin.y + ContentBackgroundPadding,TextContentSize.width, TextContentSize.height);
    
}

@end
