//
//  ChatToolBar.m
//  HUTLife
//
//  Created by Lingyu on 16/4/7.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "ChatToolBar.h"

@interface ChatToolBar ()<UITextFieldDelegate>
@property(nonatomic,strong)UIButton *voiceInputButton;
@property(nonatomic,strong)UIButton *toolButton;
@end

@implementation ChatToolBar

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {
        [self setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"chat_bottom_bg"]]];
        [self loadSubviews];
    }
    
    return self;
}

-(void)loadSubviews
{
    [self addSubview:[self voiceInputButton]];
    [self addSubview:[self toolButton]];
    [self addSubview:[self textInput]];
}

-(UIButton*)voiceInputButton
{
    if (self->_voiceInputButton) {
        return self->_voiceInputButton;
    }
    
    self->_voiceInputButton = [UIButton new];
    [self->_voiceInputButton setBackgroundImage:[UIImage imageNamed:@"input_ico_voice_nor"] forState:UIControlStateNormal];
    [self->_voiceInputButton addTarget:self action:@selector(voiceButtonCliked) forControlEvents:UIControlEventTouchUpInside];
    return self->_voiceInputButton;
}
-(void)voiceButtonCliked
{
    NSLog(@"语音按钮被点击");
}

-(UITextField*)textInput
{
    if (self->_textInput) {
        return self->_textInput;
    }
    
    self->_textInput = [UITextField new];
    [self->_textInput setBorderStyle:UITextBorderStyleRoundedRect];
    [self->_textInput setReturnKeyType:UIReturnKeySend];
    [self->_textInput setDelegate:self];
    return self->_textInput;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if ([[self delegate] respondsToSelector:@selector(chatToolBar:didUserInputText:)]) {
        [[self delegate] chatToolBar:self didUserInputText:[textField text]];
    }
    return YES;
}

-(UIButton*)toolButton
{
    if (self->_toolButton) {
        return self->_toolButton;
    }
    
    self->_toolButton = [UIButton new];
    [self->_toolButton setBackgroundImage:[UIImage imageNamed:@"input_ico_add_nor"] forState:UIControlStateNormal];
    [self->_toolButton addTarget:self action:@selector(toolButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    return self->_toolButton;
}

-(void)toolButtonClicked:(UIButton*)toolButton
{
    if ([[self delegate] respondsToSelector:@selector(chatToolBar:didToolButtonClicked:)]) {
        [[self delegate] chatToolBar:self  didToolButtonClicked:toolButton];
    }
}

-(BOOL)resignFirstResponder
{
    [[self textInput] resignFirstResponder];
    [[self voiceInputButton] resignFirstResponder];
    [[self toolButton] resignFirstResponder];
    return [super resignFirstResponder];
}

-(void)clearTextInput
{
    [[self textInput] setText:nil];
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize contentSize = [self bounds].size;
    
    CGFloat interval = 5;
    
    //布局voiceInputButton
    CGSize voiceInputButtonSize = CGSizeMake(27, 27);
    [[self voiceInputButton] setBounds:CGRectMake(0, 0, voiceInputButtonSize.width, voiceInputButtonSize.width)];
    [[self voiceInputButton] setCenter:CGPointMake(interval + voiceInputButtonSize.width/2 ,contentSize.height/2)];
    
    //布局toolButton
    CGSize toolButtonSize = CGSizeMake(27, 27);
    [[self toolButton] setBounds:CGRectMake(0, 0, toolButtonSize.width, toolButtonSize.height)];
    [[self toolButton] setCenter:CGPointMake(contentSize.width - interval - toolButtonSize.width/2, contentSize.height/2)];
    
    //布局textInput
    [[self textInput] setFrame:CGRectMake(CGRectGetMaxX([[self voiceInputButton] frame]) + 2 * interval, interval, [[self toolButton] frame].origin.x - 4 * interval - CGRectGetMaxX([[self voiceInputButton] frame]), contentSize.height-2*interval)];
}
@end
