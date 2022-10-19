//
//  ContactListViewController.m
//  HUTLife
//
//  Created by Lingyu on 16/3/7.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "ContactListViewController.h"
#import "ContactToolBar.h"
#import "ContactCell.h"
#import "ContactDetailViewController.h"
#import "AddContactViewController.h"
#import "FriendApplicationListViewController.h"
#import "ChatGroupListViewController.h"
#import "KIMClient.h"
@interface ContactListViewController ()<UITableViewDataSource,UITableViewDelegate,ContactToolBarDelegate>
@property(nonatomic,strong)ContactToolBar * toolBar;
@property(nonatomic,strong)UITableView * contactListView;
/**
 *@description 通信录列表
 */
@property(nonatomic,strong)NSArray<KIMUser*> *contactList;
@property(nonatomic,strong)NSMutableSet<KIMUser*> * userVCardCheckedSet;
@property(nonatomic,strong)UIBarButtonItem *addFriendBarButtonItem;
@property(nonatomic,assign)BOOL isActiveViewController;
@end

@implementation ContactListViewController
+(instancetype)contactListController
{
    return [[ContactListViewController alloc] init];
}

-(ContactToolBar*)toolBar
{
    if (self->_toolBar) {
        return self->_toolBar;
    }
    
    self->_toolBar = [[ContactToolBar alloc] initWithFrame:CGRectZero];
    [self->_toolBar setDelegate:self];
    return self->_toolBar;
}

-(UITableView*)contactListView
{
    if (self->_contactListView) {
        return self->_contactListView;
    }
    
    self->_contactListView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    [self->_contactListView setDataSource:self];
    [self->_contactListView setDelegate:self];
    return self->_contactListView;
}

-(NSArray<KIMUser*> *)contactList
{
    if (self->_contactList) {
        return self->_contactList;
    }
    
    self->_contactList = [NSArray<KIMUser*> array];
    
    return self->_contactList;
}
-(NSMutableSet<KIMUser*> *)userVCardCheckedSet
{
    if (self->_userVCardCheckedSet) {
        return self->_userVCardCheckedSet;
    }
    
    self->_userVCardCheckedSet = [NSMutableSet<KIMUser*> set];
    
    return self->_userVCardCheckedSet;
}
-(UIBarButtonItem*)addFriendBarButtonItem
{
    if (self->_addFriendBarButtonItem) {
        return self->_addFriendBarButtonItem;
    }
    
    self->_addFriendBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addFriendBarButtonDidClicked)];
    
    return self->_addFriendBarButtonItem;
}

-(void)addFriendBarButtonDidClicked
{
    [[self navigationController] pushViewController:[AddContactViewController new] animated:YES];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setTitle:@"通讯录"];
    
    CGSize navigationBarSize = CGSizeZero;
    if (![[[self navigationController] navigationBar] isHidden]) {
        navigationBarSize = [[[self navigationController] navigationBar] bounds].size;
    }
    CGSize statusBarSize = [[UIApplication sharedApplication] statusBarFrame].size;
    
    CGFloat toolBarHeight = 100;
    
    [[self toolBar] setFrame:CGRectMake(0, navigationBarSize.height + statusBarSize.height, self.view.bounds.size.width, toolBarHeight)];
    
    [[self contactListView] setFrame:CGRectMake(0, CGRectGetMaxY([[self toolBar]frame]), self.view.bounds.size.width, self.view.bounds.size.height - CGRectGetMaxY([[self toolBar]frame]))];
    
    [[self view] addSubview:[self toolBar]];
    [[self view] addSubview:[self contactListView]];
    
    [[self contactListView] setRowHeight:60];
    [[self view] setBackgroundColor:[UIColor whiteColor]];
    [[self navigationItem] setRightBarButtonItem:[self addFriendBarButtonItem]];
}

-(void)loadFriendListAndFresh
{
    //获取好友列表
    KIMRosterModule * rosterModule = ((AppDelegate*)UIApplication.sharedApplication.delegate).imClient.rosterModule;
    NSArray<KIMUser*> * friendList = [[rosterModule retriveFriendListFromLocalCache] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"account" ascending:YES]]];
    
    if (friendList.count) {
        self.contactList = [friendList copy];
    }
    
    [self.contactListView reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self setIsActiveViewController:YES];
    
    [self loadFriendListAndFresh];
    
    //监听好友列表更新通知
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(friendListDidChanged:) name:KIMRosterModuleFriendListUpdatedNotificationName object:nil];
    //监听好友状态更新通知
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(friendOnlineStateChanged:) name:KIMUserOnlineUpdateNotificationName object:nil];
    //监听用户电子名片更新通知
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(userVCardUpdated:) name:KIMRosterModuleUserVCardUpdatedNotificationName object:nil];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self setIsActiveViewController:NO];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:KIMRosterModuleFriendListUpdatedNotificationName object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:KIMUserOnlineUpdateNotificationName object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:KIMRosterModuleUserVCardUpdatedNotificationName object:nil];
}

-(void)friendListDidChanged:(NSNotification*)notification
{
    [self loadFriendListAndFresh];
}
-(void)friendOnlineStateChanged:(NSNotification*)notification
{
    [[self contactListView] reloadData];
}

-(void)userVCardUpdated:(NSNotification*)notification
{
    [self.contactListView reloadData];
}
-(void)didContactToolBarSelectedFriendApplicationItem:(ContactToolBar*)toolBar
{
    FriendApplicationListViewController * friendApplicationListViewController = [[FriendApplicationListViewController alloc] init];
    [[self navigationController] pushViewController:friendApplicationListViewController animated:YES];
}
-(void)didContactToolBarSelectedChatGroupItem:(ContactToolBar*)toolBar
{
    ChatGroupListViewController * chatGroupListViewController = [[ChatGroupListViewController alloc] init];
    [[self navigationController] pushViewController:chatGroupListViewController animated:YES];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self contactList] count];
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    KIMUser *contactModel = [[self contactList] objectAtIndex:[indexPath row]];
    ContactCell *cell = [ContactCell cellWithTableView:tableView andModel:contactModel];
    cell.userName.text = contactModel.account;
    
    KIMRosterModule * rosterModule = ((AppDelegate*)UIApplication.sharedApplication.delegate).imClient.rosterModule;
    KIMOnlineModule * onlineStateModule = ((AppDelegate*)UIApplication.sharedApplication.delegate).imClient.onlineStateModule;
    switch([onlineStateModule getUserOnlineState:contactModel]){
        case KIMOnlineState_Online:
        {
            [cell.onlineState setText:@"在线"];
        }
            break;
        case KIMOnlineState_Invisible:
        case KIMOnlineState_Offline:
        default:
        {
            [cell.onlineState setText:@"离线请留言"];
        }
            break;
    }
    
    KIMUserVCard * userVCard = [rosterModule retriveUserVCardFromLocalCache:contactModel];
    if (userVCard) {
        cell.userAvator.image = [UIImage imageWithData:userVCard.avatar];
        if ([userVCard.nickName hasContent]) {
            cell.userName.text = userVCard.nickName;
        }
    }
    
    if(![self.userVCardCheckedSet containsObject:contactModel]){
        if([rosterModule sendUserVCardSyncMessage:contactModel]){
            [self.userVCardCheckedSet addObject:contactModel];
        }
    }
    
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    KIMUser *model = [(ContactCell*)[tableView cellForRowAtIndexPath:indexPath]model];
    ContactDetailViewController *detailController = [ContactDetailViewController contactDetailControllerWithModel:model];
    [[self navigationController] pushViewController:detailController animated:YES];
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    NSMutableArray<UITableViewRowAction*> *rowActionArray = [NSMutableArray<UITableViewRowAction*> array];
    
    __weak ContactListViewController * weakSelf = self;
    UITableViewRowAction *deleAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"删除" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        
        if(!weakSelf){
            return;
        }
        
        KIMUser * contact = [weakSelf.contactList objectAtIndex:indexPath.row];
        ContactCell * contactCell = (ContactCell*)[tableView cellForRowAtIndexPath:indexPath];

        NSString * title = [NSString stringWithFormat:@"删除好友: %@",contactCell.userName.text];

        UIAlertController * deleteFriendAlertController = [UIAlertController alertControllerWithTitle:title message:@"删除之后你们将不能互相发送信息以及其它操作" preferredStyle:UIAlertControllerStyleActionSheet];

        UIAlertAction * deleteAction = [UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [MBProgressHUD showMessage:@"正在删除"];
            KIMRosterModule * rosterModule = ((AppDelegate*)UIApplication.sharedApplication.delegate).imClient.rosterModule;
            [rosterModule deleteFriend:contact success:^(KIMRosterModule *rosterModule, KIMUser *deletedFriend) {
                if([weakSelf isActiveViewController]){
                    [MBProgressHUD hideHUD];
                    [MBProgressHUD showSuccess:@"删除成功"];
                }
            } failure:^(KIMRosterModule *rosterModule, KIMUser *pendingDeleteFriend, DeleteFriendFailureType failedType) {
                [MBProgressHUD hideHUD];
                switch (failedType) {
                    case DeleteFriendFailureType_ParameterError:
                    case DeleteFriendFailureType_ClientInteralError:
                    {
                        [MBProgressHUD showError:@"删除失败，客户端内部错误"];
                    }
                        break;
                    case DeleteFriendFailureType_ServerInteralError:
                    {
                        [MBProgressHUD showError:@"删除失败，服务器内部错误"];
                    }
                        break;
                    case DeleteFriendFailureType_NetworkError:
                    case DeleteFriendFailureType_Timeout:
                    {
                        [MBProgressHUD showError:@"删除失败，网络错误"];
                    }
                        break;
                    case DeleteFriendFailureType_ModuleStoped:
                    {
                        [MBProgressHUD showError:@"删除失败，客户端处于离线状态"];
                    }
                        break;
                    case DeleteFriendFailureType_FriendRelationNotExitBefore:
                    default:
                    {
                        [MBProgressHUD showError:@"删除失败，好友关系事先不存在"];
                    }
                        break;
                }
            }];
        }];

        UIAlertAction * cancleAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {

        }];
    
        [deleteFriendAlertController addAction:deleteAction];
        [deleteFriendAlertController addAction:cancleAction];
    
        [self presentViewController:deleteFriendAlertController animated:YES completion:^{
            [[self contactListView] reloadData];
        }];
    }];
    
    [rowActionArray addObject:deleAction];

    return rowActionArray;
}

@end
