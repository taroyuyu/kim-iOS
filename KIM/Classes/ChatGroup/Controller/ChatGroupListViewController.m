//
//  ChatGroupListViewController.m
//  HUTLife
//
//  Created by Kakawater on 2018/4/23.
//  Copyright © 2018年 Kakawater. All rights reserved.
//

#import <objc/runtime.h>
#import "ChatGroupListViewController.h"
#import "CreateChatGroupViewController.h"
#import "ChatGroupInfoViewController.h"
#import "GroupChatViewController.h"
static NSString *GroupInfoTableViewCellIdentifier =@"GroupInfoTableViewCell";

@interface ChatGroupListViewController ()
@property(nonatomic,strong)UIBarButtonItem *addChatGroupBarButtonItem;
@property(nonatomic,strong)NSArray<KIMChatGroup*> * groupList;
@property(nonatomic,strong)NSMutableSet<KIMChatGroup*> * groupInfoCheckedSet;
@property(nonatomic,weak)UITextField * searchGroupIdField;
@property(nonatomic,weak)UIAlertAction * searchGroupAction;
@end

@implementation ChatGroupListViewController

-(UIBarButtonItem*)addChatGroupBarButtonItem
{
    if (self->_addChatGroupBarButtonItem) {
        return self->_addChatGroupBarButtonItem;
    }
    
    self->_addChatGroupBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addChatGroupBarButtonItemClicked:)];
    
    return self->_addChatGroupBarButtonItem;
}

-(NSMutableSet<KIMChatGroup*> *)groupInfoCheckedSet
{
    if (self->_groupInfoCheckedSet) {
        return self->_groupInfoCheckedSet;
    }
    
    self->_groupInfoCheckedSet = [NSMutableSet<KIMChatGroup*> set];
    
    return self->_groupInfoCheckedSet;
}

-(void)addChatGroupBarButtonItemClicked:(UIBarButtonItem*)barButtonItem
{
    UIAlertController * alertController = [UIAlertController alertControllerWithTitle:@"添加群" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction * searchChatGroupAction = [UIAlertAction actionWithTitle:@"查找群" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {

        UIAlertController * groupIdInputController = [UIAlertController alertControllerWithTitle:@"添加群" message:@"请输入群Id" preferredStyle:UIAlertControllerStyleAlert];

        [groupIdInputController addTextFieldWithConfigurationHandler:^(UITextField *textField){
            textField.placeholder = @"群Id";
            [self setSearchGroupIdField:textField];
            [textField addTarget:self action:@selector(searchGroupIdFieldEditingChanged:) forControlEvents:UIControlEventEditingChanged];
        }];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        UIAlertAction *searchAction = [UIAlertAction actionWithTitle:@"查找" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            KIMChatGroup * chatGroup = [[KIMChatGroup alloc] initWithGroupId:[[[self searchGroupIdField]text]stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
            [[self navigationController] pushViewController:[ChatGroupInfoViewController chatGroupInfoViewControllerWithChatGroup:chatGroup] animated:YES];
        }];
        [searchAction setEnabled:NO];
        [self setSearchGroupAction:searchAction];
        [groupIdInputController addAction:cancelAction];
        [groupIdInputController addAction:searchAction];

        [self presentViewController:groupIdInputController animated:YES completion:nil];
    }];
    UIAlertAction * createChatGroupAction = [UIAlertAction actionWithTitle:@"创建群" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        CreateChatGroupViewController * createChatGroupController = [CreateChatGroupViewController createChatGroupViewController];
        [[self navigationController] pushViewController:createChatGroupController animated:YES];
    }];
    UIAlertAction * cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:searchChatGroupAction];
    [alertController addAction:createChatGroupAction];
    [alertController addAction:cancelAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

-(void)searchGroupIdFieldEditingChanged:(UITextField *)textField
{
    
    if (nil == textField || textField != [self searchGroupIdField]) {
        return;
    }
    
    if ([[[textField text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length]) {
        [[self searchGroupAction] setEnabled:YES];
    }else{
        [[self searchGroupAction] setEnabled:NO];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setTitle:@"群聊"];
    
    [[self navigationItem] setRightBarButtonItem:[self addChatGroupBarButtonItem]];
    
    [[self tableView] registerClass:[UITableViewCell class] forCellReuseIdentifier:GroupInfoTableViewCellIdentifier];
    
    [self loadChatGroupList];
}

-(void)loadChatGroupList
{
    KIMChatGroupModule * chatGroupModule = [[(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient] chatGroupModule];
    self.groupList = [chatGroupModule retriveChatGroupListFromLocalCache];
    self.groupList = [self.groupList sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"groupId" ascending:YES]]];
    [self.tableView reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    //监听用户群列表更新通知
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(chatGroupListUpdated:) name:KIMChatGroupModuleChatGroupListUpdatedNotificationName object:nil];
    //监听群信息更新通知
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(chetGroupInfoUpdated:) name:KIMChatGroupModuleChatGroupInfoUpdatedNotificationName object:nil];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [NSNotificationCenter.defaultCenter removeObserver:self name:KIMChatGroupModuleChatGroupListUpdatedNotificationName object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:KIMChatGroupModuleChatGroupInfoUpdatedNotificationName object:nil];
}

-(void)chatGroupListUpdated:(NSNotification*)notification
{
    [self loadChatGroupList];
}

-(void)chetGroupInfoUpdated:(NSNotification*)notification
{
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.groupList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{

    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:GroupInfoTableViewCellIdentifier forIndexPath:indexPath];

    KIMChatGroup * chatGroup = [[self groupList] objectAtIndex:[indexPath row]];
    [[cell textLabel] setText:[chatGroup groupId]];
    if (![[cell imageView] image]) {
        [[cell imageView] setImage:[UIImage imageNamed:@"chatGroupIcon"]];
    }

    KIMChatGroupModule * chatGroupModule = [[(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient] chatGroupModule];

    KIMChatGroupInfo * groupInfo = [chatGroupModule retriveChatGroupInfoFromLocalCache:chatGroup];

    if (groupInfo) {
        [[cell textLabel] setText:[groupInfo groupName]];
    }
    
    if (![self.groupInfoCheckedSet containsObject:chatGroup]) {
        if([chatGroupModule sendChatGroupInfoSyncMessage:chatGroup]){
            [self.groupInfoCheckedSet addObject:chatGroup];
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [[self navigationController] pushViewController:[GroupChatViewController groupChatViewController:[[self groupList]objectAtIndex:indexPath.row]] animated:YES];
}
@end
