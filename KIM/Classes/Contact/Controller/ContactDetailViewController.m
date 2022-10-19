//
//  ContactDetailViewController.m
//  HUTLife
//
//  Created by Lingyu on 16/4/6.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "ContactDetailViewController.h"
#import "ChatViewController.h"
#import "VideoChatViewController.h"
#import "ContactDetailHeadView.h"
#import "KIMUser.h"
@interface ContactDetailViewController ()
@property(nonatomic,strong)ContactDetailHeadView *detailHeaderView;
@property(nonatomic,strong)UIButton *chatButton;
@property(nonatomic,strong)UIButton * videoChatButton;
@end

@implementation ContactDetailViewController


+(instancetype)contactDetailControllerWithModel:(KIMUser*)model;
{
    ContactDetailViewController *detailController = [[ContactDetailViewController alloc] initWithNibName:nil bundle:nil];
    if (detailController) {
        [detailController setUserModel:model];
    }
    return detailController;
}

-(ContactDetailHeadView*)detailHeaderView
{
    if (self->_detailHeaderView) {
        return self->_detailHeaderView;
    }
    
    CGSize navigationBarSize = CGSizeZero;
    if (![[[self navigationController] navigationBar] isHidden]) {
        navigationBarSize = [[[self navigationController] navigationBar] bounds].size;
    }
    
    CGSize statusBarSize = [[UIApplication sharedApplication] statusBarFrame].size;
    
    CGFloat headerHeight = 200;
    self->_detailHeaderView = [[ContactDetailHeadView alloc] initWithFrame:CGRectMake(0, navigationBarSize.height+statusBarSize.height,[[self view] bounds].size.width, headerHeight)];
    
    [self->_detailHeaderView setBackgroundColor:[UIColor colorWithRed:55/255.0 green:189/255.0 blue:255/255.0 alpha:1]];
    
    return self->_detailHeaderView;
}

-(UIButton*)chatButton
{
    if (self->_chatButton) {
        return self->_chatButton;
    }
    
    self->_chatButton = [UIButton new];
    [self->_chatButton setTitle:@"发消息" forState:UIControlStateNormal];
    [self->_chatButton setBackgroundColor:[UIColor colorWithRed:69/255.0 green:83/255.0 blue:125/255.0 alpha:1]];
    [self->_chatButton addTarget:self action:@selector(chatbuttonClicked:) forControlEvents:UIControlEventTouchUpInside];
    return self->_chatButton;
}

-(UIButton*)videoChatButton
{
    if (self->_videoChatButton) {
        return self->_videoChatButton;
    }
    
    self->_videoChatButton = [UIButton new];
    [self->_videoChatButton setTitle:@"视频通话" forState:UIControlStateNormal];
    [self->_videoChatButton setBackgroundColor:[UIColor colorWithRed:255/255.0 green:217/255.0 blue:96/255.0 alpha:1]];
    [self->_videoChatButton addTarget:self action:@selector(videoChatButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    return self->_videoChatButton;
}

-(void)chatbuttonClicked:(UIButton*)button
{
    ChatViewController *chatController = [ChatViewController new];
    [chatController setPeerUser:[self userModel]];
    [[self navigationController] pushViewController:chatController animated:YES];
}

-(void)videoChatButtonClicked:(UIButton*)button
{
    
    UIAlertController * alertController = [UIAlertController alertControllerWithTitle:@"请选择通话类型" message:@"选择之后，本次通话过程中不可以切换" preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"语音通话" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self presentViewController:[VideoChatViewController callToFriend:self.userModel sessionType:KIMVideoChatRequestSessionType_Voice] animated:YES completion:^{
            [[self navigationController] popViewControllerAnimated:NO];
        }];
        
    }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"视频通话" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self presentViewController:[VideoChatViewController callToFriend:self.userModel sessionType:KIMVideoChatRequestSessionType_Video] animated:YES completion:^{
            [[self navigationController] popViewControllerAnimated:NO];
        }];
    }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [[alertController popoverPresentationController] setSourceView:self.view];
    CGSize actionSheetSize = CGSizeMake(0, 0);
    [[alertController popoverPresentationController] setSourceRect:CGRectMake(self.videoChatButton.frame.origin.x + self.videoChatButton.frame.size.width / 2,self.videoChatButton.frame.origin.y, actionSheetSize.width, actionSheetSize.height)];
    [self presentViewController:alertController animated:YES completion:nil];
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[self navigationItem] setTitle:@"详细资料"];
    [[self view] setBackgroundColor:[UIColor whiteColor]];
    
    [[self view] addSubview:[self detailHeaderView]];
    
    const CGFloat EdgeInterval = 20;
    const CGFloat ButtonHeight = 40;
    const CGFloat VideoButtonMarginBottom = 80;
    [[self videoChatButton] setFrame:CGRectMake(EdgeInterval, self.view.bounds.size.height - VideoButtonMarginBottom - ButtonHeight, self.view.bounds.size.width-EdgeInterval*2, ButtonHeight)];
    [[self chatButton] setFrame:CGRectMake(self.videoChatButton.frame.origin.x,self.videoChatButton.frame.origin.y - EdgeInterval - ButtonHeight, self.videoChatButton.bounds.size.width,
    self.videoChatButton.bounds.size.height)];
    [[self view] addSubview:[self chatButton]];
    [[self view] addSubview:[self videoChatButton]];
    [self loadModeInfo];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    //监听用户电子名片更新通知
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(userVCardUpdated:) name:KIMRosterModuleUserVCardUpdatedNotificationName object:nil];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:KIMRosterModuleUserVCardUpdatedNotificationName object:nil];
}

-(void)userVCardUpdated:(NSNotification*)notification
{
    NSString * userAccount = [notification.userInfo objectForKey:@"user"];
    
    if ([userAccount isEqualToString:self.userModel.account]) {
        [self loadModeInfo];
    }
}

-(void)loadModeInfo
{
    KIMRosterModule * rosterModule = ((AppDelegate*)UIApplication.sharedApplication.delegate).imClient.rosterModule;
    KIMUserVCard * userVCard = [rosterModule retriveUserVCardFromLocalCache:self.userModel];
    
    if (userVCard) {
        [[self detailHeaderView] setModel:userVCard];
    }
}

@end
