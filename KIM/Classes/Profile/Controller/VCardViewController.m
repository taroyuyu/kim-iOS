//
//  VCardViewController.m
//  HUTLife
//
//  Created by Lingyu on 16/4/17.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "VCardViewController.h"
#import "VCardEditViewController.h"
#import "vCardHeaderView.h"
#import "KIMUserVCard.h"
@interface VCardViewController ()
@property(nonatomic,strong)vCardHeaderView *headerView;
@property(nonatomic,strong)UIBarButtonItem *modifyBarButtonItem;
@property(nonatomic,strong)KIMUserVCard *userVCard;
@end

@implementation VCardViewController

-(vCardHeaderView*)headerView
{
    if (self->_headerView) {
        return self->_headerView;
    }
    
    CGSize navigationBarSize = CGSizeZero;
    if (![[[self navigationController] navigationBar] isHidden]) {
        navigationBarSize = [[[self navigationController] navigationBar] bounds].size;
    }
    
    CGFloat headerHeight = 200;
    self->_headerView = [[vCardHeaderView alloc] initWithFrame:CGRectMake(0, navigationBarSize.height+0,[[self view] bounds].size.width, headerHeight)];
    
    [self->_headerView setBackgroundColor:[UIColor colorWithRed:55/255.0 green:189/255.0 blue:255/255.0 alpha:1]];
    
    return self->_headerView;

}

-(UIBarButtonItem*)modifyBarButtonItem
{
    if (self->_modifyBarButtonItem) {
        return self->_modifyBarButtonItem;
    }
    
    self->_modifyBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"modifyIcon"] landscapeImagePhone:nil style:UIBarButtonItemStylePlain target:self action:@selector(modifyBarButtonClicked
                                                                                                                                                                                                )];
    return self->_modifyBarButtonItem;
}

-(void)modifyBarButtonClicked
{
    VCardEditViewController *editViewController = [VCardEditViewController vCardEditController];
    [editViewController setModel:[self userVCard]];
    [[self navigationController] pushViewController:editViewController animated:YES];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setTitle:@"名片"];
    
    [[self view] setBackgroundColor:[UIColor whiteColor]];
    
    [[self view] addSubview:[self headerView]];
    [[self navigationItem] setRightBarButtonItem:[self modifyBarButtonItem]];
    
    [self loadCurrentUserInfo];
}

-(void)loadCurrentUserInfo
{
    KIMRosterModule * rosterModule = ((AppDelegate*)UIApplication.sharedApplication.delegate).imClient.rosterModule;
    self.userVCard = [rosterModule retriveCurrentUserVCardFromLocalCache];
    if (self.userVCard) {
        [[self headerView] setModel:self.userVCard];
    }
}
-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    //监听用户电子名片更新通知
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(userVCardUpdated:) name:KIMRosterModuleUserVCardUpdatedNotificationName object:nil];
    
    [self loadCurrentUserInfo];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:KIMRosterModuleUserVCardUpdatedNotificationName object:nil];
}

-(void)userVCardUpdated:(NSNotification*)notification
{
    NSString * userAccount = [notification.userInfo objectForKey:@"user"];
    
    if ([userAccount isEqualToString:((AppDelegate*)UIApplication.sharedApplication.delegate).imClient.currentUser.account]) {
        [self loadCurrentUserInfo];
    }
}

@end
