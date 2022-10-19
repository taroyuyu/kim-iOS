//
//  ChatToolBar.h
//  HUTLife
//
//  Created by Lingyu on 16/4/7.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ChatToolBar;

@protocol ChatToolBarDelegate <NSObject>
@optional
-(void)chatToolBar:(ChatToolBar*)toolBar didUserInputText:(NSString*)text;
-(void)chatToolBar:(ChatToolBar*)toolBar didToolButtonClicked:(UIButton*)toolButton;
@end

@interface ChatToolBar : UIView
@property(nonatomic,weak)NSObject<ChatToolBarDelegate> *delegate;
@property(nonatomic,strong)UITextField *textInput;
-(void)clearTextInput;
@end
