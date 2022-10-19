//
//  GroupMemberListViewController.m
//  HUTLife
//
//  Created by Kakawater on 2018/4/25.
//  Copyright © 2018年 Kakawater. All rights reserved.
//

#import "GroupMemberListViewController.h"
#import "GroupMemberCollectionViewCell.h"
#import "GroupMemberAddViewController.h"
@interface GroupMemberListViewController ()
@property(nonatomic,strong)NSMutableArray<KIMUser*> * groupMemberList;
@property(nonatomic,strong)NSMutableSet<KIMUser*> * userVCardCheckedSet;
@end

@implementation GroupMemberListViewController

static NSString * const GroupMemberCollectionViewCellReuseIdentifier = @"GroupMemberCollectionViewCell";
static NSString * const GroupMemberAddCellReuseIdentifier = @"GroupMemberAddCell";
+(instancetype)groupMemberListViewControllerWithChatGroup:(KIMChatGroup*)chatGroup
{
    GroupMemberListViewController * viewController = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"groupMemberListViewController"];
    [viewController setChatGroup:chatGroup];
    return viewController;
}
-(NSMutableArray<KIMUser*>*)groupMemberList
{
    if (self->_groupMemberList) {
        return self->_groupMemberList;
    }
    
    self->_groupMemberList = [NSMutableArray<KIMUser*> array];
    
    return self->_groupMemberList;
}

-(NSMutableSet<KIMUser*> *)userVCardCheckedSet
{
    if (self->_userVCardCheckedSet) {
        return self->_userVCardCheckedSet;
    }
    self->_userVCardCheckedSet = [NSMutableSet<KIMUser*> set];
    return self->_userVCardCheckedSet;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setTitle:@"群成员"];
    
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    //监听用户电子名片更新通知
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(userVCardUpdated:) name:KIMRosterModuleUserVCardUpdatedNotificationName object:nil];
    
    KIMChatGroupModule * chatGroupModule = [[(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient] chatGroupModule];
    
    [MBProgressHUD showMessage:@"正在获取群成员列表"];
    
    __weak GroupMemberListViewController * weakSelf = self;
    [chatGroupModule retriveChatGroupMemberListFromServer:self.chatGroup success:^(KIMChatGroupModule *chatGroupModule, NSArray<KIMUser *> *chatGroupMemberList) {
        [MBProgressHUD hideHUD];
        [weakSelf.groupMemberList removeAllObjects];
        [weakSelf.groupMemberList addObjectsFromArray:chatGroupMemberList];
        [weakSelf.collectionView reloadData];
    } failure:^(KIMChatGroupModule *chatGroupModule, RetriveChatGroupMemberListFromServerFailedType failedType) {
        [MBProgressHUD hideHUD];
        [MBProgressHUD showError:@"网络异常，获取群列表出错"];
    }];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:KIMRosterModuleUserVCardUpdatedNotificationName object:nil];
}

-(void)userVCardUpdated:(NSNotification*)notification
{
    [self.collectionView reloadData];
}

#pragma mark <UICollectionViewDataSource>
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.groupMemberList.count + 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == [[self groupMemberList] count]) {
        UICollectionViewCell * cell = [collectionView dequeueReusableCellWithReuseIdentifier:GroupMemberAddCellReuseIdentifier forIndexPath:indexPath];
        return cell;
    }
    GroupMemberCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:GroupMemberCollectionViewCellReuseIdentifier forIndexPath:indexPath];
    cell.userNameLabel.text = nil;
    cell.avatarView.image = nil;
    // Configure the cell
    KIMUser * groupMember = [[self groupMemberList] objectAtIndex:indexPath.row];
    cell.userNameLabel.text = groupMember.account;
    cell.avatarView.image = [UIImage imageNamed:@"branddefulthead"];
    KIMRosterModule * rosterModule = [[(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient] rosterModule];

    KIMUserVCard * userVCard = [rosterModule retriveUserVCardFromLocalCache:groupMember];

    if (userVCard) {
        if ([userVCard.nickName length]) {
            cell.userNameLabel.text = userVCard.nickName;
        }
        if (userVCard.avatar) {
            cell.avatarView.image = [UIImage imageWithData:userVCard.avatar];
        }
    }
    
    if (![self.userVCardCheckedSet containsObject:groupMember]) {
        if ([rosterModule sendUserVCardSyncMessage:groupMember]) {
            [self.userVCardCheckedSet addObject:groupMember];
        }
    }
    return cell;
}
- (IBAction)groupMemberAddButtonClicked:(UIButton *)sender {
    GroupMemberAddViewController * groupMemberAddViewController = [GroupMemberAddViewController groupMemberAddViewControllerWithChatGroup:self.chatGroup];
    [[self navigationController] pushViewController:groupMemberAddViewController animated:YES];
}
@end
