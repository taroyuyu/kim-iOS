//
//  FriendApplicationListViewController.m
//  HUTLife
//
//  Created by Kakawater on 2018/4/23.
//  Copyright © 2018年 Kakawater. All rights reserved.
//

#import "FriendApplicationListViewController.h"
#import "FriendApplicationCell.h"

static NSString * const FriendApplicationCellIdentifier = @"FriendApplicationCell";
@interface FriendApplicationListViewController ()
@property(nonatomic,strong)NSMutableSet<KIMUser*> * userVCardCheckedSet;
@property(nonatomic,strong)NSArray<KIMFriendApplication*> * applicationList;
@end

@implementation FriendApplicationListViewController

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
    [self setTitle:@"新朋友"];
    [[self tableView] setRowHeight:72];
    //注册MessageViewCell
    [[self tableView] registerClass:[FriendApplicationCell class] forCellReuseIdentifier:FriendApplicationCellIdentifier];
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
}

-(void)loadApplicationAndFresh
{
    self.applicationList = [((AppDelegate*)UIApplication.sharedApplication.delegate).imClient.rosterModule fetchAllFriendApplications];
    [self.tableView reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    //1.获取好友申请
    [self loadApplicationAndFresh];
    
    //注册通知：监听好友申请
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(receivedFriendApplication:) name:KIMRosterModuleReceivedFriendApplicationNotificationName object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(receivedFriendApplicationReply:) name:KIMRosterModuleReceivedFriendApplicationReplyNotificationName object:nil];
    //监听用户电子名片更新通知
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(userVCardUpdated:) name:KIMRosterModuleUserVCardUpdatedNotificationName object:nil];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [NSNotificationCenter.defaultCenter removeObserver:self name:KIMRosterModuleReceivedFriendApplicationNotificationName object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:KIMRosterModuleReceivedFriendApplicationReplyNotificationName object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:KIMRosterModuleUserVCardUpdatedNotificationName object:nil];
}

-(void)receivedFriendApplication:(NSNotification*)notification
{
    [self loadApplicationAndFresh];
}

-(void)receivedFriendApplicationReply:(NSNotification*)notification
{
    [self loadApplicationAndFresh];
}

-(void)userVCardUpdated:(NSNotification*)notification
{
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.applicationList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    FriendApplicationCell *cell = [tableView dequeueReusableCellWithIdentifier:FriendApplicationCellIdentifier forIndexPath:indexPath];
    
    KIMFriendApplication * application = [self.applicationList objectAtIndex:indexPath.row];
    
    KIMClient * imClient = ((AppDelegate*)UIApplication.sharedApplication.delegate).imClient;
    
    KIMUser * opponent = [application.sponsor isEqual:imClient.currentUser] ? application.target : application.sponsor;

    cell.peerUserName.text = opponent.account;
    cell.avatar.image = [UIImage imageNamed:@"normal_avatar"];
    
    if ([opponent isEqual:application.target]) {
        cell.introduction.text = @"好友申请已发送";
    }else{
        cell.introduction.text = application.introduction;
    }

    KIMRosterModule * rosterModule = imClient.rosterModule;
    KIMUserVCard * userVCard = [rosterModule retriveUserVCardFromLocalCache:opponent];
    if (userVCard) {
        if ([userVCard.nickName hasContent]) {
            cell.peerUserName.text = userVCard.nickName;
        }
        
        if (userVCard.avatar) {
            cell.avatar.image = [UIImage imageWithData:userVCard.avatar];
        }
    }
    
    if (![self.userVCardCheckedSet containsObject:opponent]) {
        if([rosterModule sendUserVCardSyncMessage:opponent]){
            [self.userVCardCheckedSet addObject:opponent];
        }
    }
        switch (application.state) {
            case KIMFriendApplicationState_Pending:
            {
                [cell.handleButton setTitle:@"待处理" forState:UIControlStateNormal];
                [cell.handleButton setBackgroundColor:[UIColor colorWithRed:112/255.0 green:215/255.0 blue:108/255.0 alpha:1.f]];
                [cell.handleButton setEnabled:NO];
            }
                break;
            case KIMFriendApplicationState_Allowm:
            {
                [cell.handleButton setTitle:@"已同意" forState:UIControlStateNormal];
                [cell.handleButton setBackgroundColor:[UIColor grayColor]];
                [cell.handleButton setEnabled:NO];
            }
                break;
            case KIMFriendApplicationState_Reject:
            {
                [cell.handleButton setTitle:@"已拒绝" forState:UIControlStateNormal];
                [cell.handleButton setBackgroundColor:[UIColor grayColor]];
                [cell.handleButton setEnabled:NO];
            }
                break;
            default:
                break;
        }

    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    KIMFriendApplication * application = [self.applicationList objectAtIndex:indexPath.row];
    
    KIMClient * imClient = ((AppDelegate*)UIApplication.sharedApplication.delegate).imClient;
    
    KIMUser * opponent = [application.sponsor isEqual:imClient.currentUser] ? application.target : application.sponsor;
    
    if (KIMFriendApplicationState_Pending != application.state || [opponent isEqual:application.target]) {
        return;
    }
    
    KIMRosterModule * rosterModule = imClient.rosterModule;
    KIMUserVCard * opponentUserVCard = [rosterModule retriveUserVCardFromLocalCache:opponent];

    NSString * title = [NSString stringWithFormat:@"%@ 想添加你为好友",opponent.account];

    if ([opponentUserVCard.nickName hasContent]) {
        title = [NSString stringWithFormat:@"%@ 想添加你为好友",opponentUserVCard.nickName];
    }

    UIAlertController * friendApplicationHandleController = [UIAlertController alertControllerWithTitle:title message:application.introduction preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *acceptAction = [UIAlertAction actionWithTitle:@"同意" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if([rosterModule acceptFriendApplication:application]){
            application.state = KIMFriendApplicationState_Allowm;
        }
    }];

    UIAlertAction * rejectAction = [UIAlertAction actionWithTitle:@"拒绝" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if ([rosterModule rejectFriendApplication:application]) {
            application.state = KIMFriendApplicationState_Reject;
        }
    }];
    
    UIAlertAction * cancleAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {

    }];

    [friendApplicationHandleController addAction:acceptAction];
    [friendApplicationHandleController addAction:rejectAction];
    [friendApplicationHandleController addAction:cancleAction];

    [self presentViewController:friendApplicationHandleController animated:YES completion:^{
        [[self tableView] reloadData];
    }];
}
@end
