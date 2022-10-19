//
//  ChatGroupInfoViewController.m
//  HUTLife
//
//  Created by Kakawater on 2018/4/24.
//  Copyright © 2018年 Kakawater. All rights reserved.
//

#import "ChatGroupInfoViewController.h"
#import "GroupChatViewController.h"
typedef NS_ENUM(NSUInteger,ChatGroupInfoViewControllerMode)
{
    ChatGroupInfoViewControllerMode_Joined,
    ChatGroupInfoViewControllerMode_UnJoined,
};

@interface ChatGroupInfoViewController ()
@property(nonatomic,assign)ChatGroupInfoViewControllerMode mode;
@property(nonatomic,strong)KIMChatGroup * chatGroup;
@property (weak, nonatomic) IBOutlet UIImageView *groupIconView;
@property (weak, nonatomic) IBOutlet UILabel *groupNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *groupIdLabel;
@property (weak, nonatomic) IBOutlet UIButton *actionButton;
@property(nonatomic,strong)NSCondition * groupInfoCondition;
@property(atomic,assign)BOOL isActiveViewController;
@end

@implementation ChatGroupInfoViewController
+(instancetype)chatGroupInfoViewControllerWithChatGroup:(KIMChatGroup*)chatGroup
{
    ChatGroupInfoViewController * viewController = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"chatGroupInfoViewController"];
    
    [viewController setChatGroup:chatGroup];
    
    return viewController;
}

-(NSCondition*)groupInfoCondition
{
    if (self->_groupInfoCondition) {
        return self->_groupInfoCondition;
    }
    
    self->_groupInfoCondition = [[NSCondition alloc] init];
    
    return self->_groupInfoCondition;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    KIMChatGroupModule * chatGroupModule = [[(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient] chatGroupModule];
    
    if([[chatGroupModule retriveChatGroupListFromLocalCache] containsObject:self.chatGroup]){
        self.mode = ChatGroupInfoViewControllerMode_Joined;
        [self.actionButton setTitle:@"进入群聊" forState:UIControlStateNormal];
    }else{
        self.mode = ChatGroupInfoViewControllerMode_UnJoined;
        [self.actionButton setTitle:@"申请加入" forState:UIControlStateNormal];
    }
    
    KIMChatGroupInfo * groupInfo = [chatGroupModule retriveChatGroupInfoFromLocalCache:[self chatGroup]];
    
    if (groupInfo) {
        [[self groupNameLabel] setText:[groupInfo groupName]];
        [[self groupIdLabel]setText:self.chatGroup.groupId];
    }
    
    //监听群信息更新通知
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(chatGroupInfoUpdated:) name:KIMChatGroupModuleChatGroupInfoUpdatedNotificationName object:nil];
    if([chatGroupModule sendChatGroupInfoSyncMessage:self.chatGroup]){
        [MBProgressHUD showMessage:@"正在获取群信息"];
        __weak ChatGroupInfoViewController * weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [weakSelf.groupInfoCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:4]];
            
            if (weakSelf.isActiveViewController) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf loadChatGroupInfo];
                    [MBProgressHUD hideHUD];
                });
            }
        });
    }
}

-(void)loadChatGroupInfo
{
    KIMChatGroupModule * chatGroupModule = [[(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient] chatGroupModule];
    KIMChatGroupInfo * groupInfo = [chatGroupModule retriveChatGroupInfoFromLocalCache:[self chatGroup]];
    
    if (groupInfo) {
        [[self groupNameLabel] setText:[groupInfo groupName]];
        [[self groupIdLabel]setText:self.chatGroup.groupId];
    }
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.isActiveViewController = YES;
    
    //监听群信息更新通知
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(chatGroupInfoUpdated:) name:KIMChatGroupModuleChatGroupInfoUpdatedNotificationName object:nil];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    self.isActiveViewController = NO;
    
    [NSNotificationCenter.defaultCenter removeObserver:self name:KIMChatGroupModuleChatGroupInfoUpdatedNotificationName object:nil];
}

-(void)chatGroupInfoUpdated:(NSNotification*)notification
{
    [self.groupInfoCondition signal];
}

- (IBAction)actionButtonClicked:(UIButton *)sender {
    
    switch (self.mode) {
        case ChatGroupInfoViewControllerMode_Joined:
        {
            [[self navigationController] pushViewController:[GroupChatViewController groupChatViewController:self.chatGroup] animated:YES];
        }
            break;
        case ChatGroupInfoViewControllerMode_UnJoined:
        {
            KIMChatGroupModule * chatGroupModule = [[(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient] chatGroupModule];
            if([chatGroupModule sendChatGroupJoinApplicationToChatGroup:self.chatGroup withIntroduction:@"I want Join"]){
                [MBProgressHUD showSuccess:@"入群申请已发送"];
            }else{
                [MBProgressHUD showError:@"网络异常，入群申请发送失败"];
            }
        }
            break;
    }
}

@end
