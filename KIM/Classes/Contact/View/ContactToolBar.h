//
//  ContactToolBar.h
//  HUTLife
//
//  Created by Kakawater on 2018/4/23.
//  Copyright © 2018年 Kakawater. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ContactToolBar;

@protocol ContactToolBarDelegate
@optional
-(void)didContactToolBarSelectedFriendApplicationItem:(ContactToolBar*)toolBar;
-(void)didContactToolBarSelectedChatGroupItem:(ContactToolBar*)toolBar;
@end

@interface ContactToolBar : UIView
@property(nonatomic,weak)NSObject<ContactToolBarDelegate> * delegate;
@end
