//
//  MessageListViewController.m
//  HUTLife
//
//  Created by Lingyu on 16/3/7.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "MessageListViewController.h"
#import "ChatViewController.h"
#import "GroupChatViewController.h"
#import "FriendApplicationListViewController.h"
#import "ChatSessionCell.h"
#import "ChatGroupSessionCell.h"
#import "FriendApplicationNotificationCell.h"
#import "MessageModel.h"
#import "ChatSessionMessageModel.h"
#import "ChatGroupSessionMessageModel.h"
#import "FriendApplicationNotificationMessageModel.h"
@interface MessageListViewController ()
@property(nonatomic,assign)BOOL isActiveViewController;
@property(nonatomic,strong)NSMutableArray<MessageModel*> *messageList;
@end

@implementation MessageListViewController

static NSString * const ChatSessionCellIdentifier = @"ChatSessionCell";
static NSString * const ChatGroupSessionCellIdentifier = @"ChatGroupSessionCell";
static NSString * const FriendApplicationNotificationCellIdentifier = @"FriendApplicationNotificationCell";


+(instancetype)messageListController
{
    return [[MessageListViewController alloc] initWithStyle:UITableViewStylePlain];
}

-(NSMutableArray<MessageModel*>*)messageList
{
    if (self->_messageList) {
        return self->_messageList;
    }
    
    self->_messageList = [NSMutableArray<MessageModel*> array];
    
    return self->_messageList;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.tabBarItem setTitle:@"消息"];
    
    [[self tableView] setRowHeight:72];
    
    //注册Cell
    [self.tableView registerClass:[ChatSessionCell class] forCellReuseIdentifier:ChatSessionCellIdentifier];
    [self.tableView registerClass:[ChatGroupSessionCell class] forCellReuseIdentifier:ChatGroupSessionCellIdentifier];
    [self.tableView registerClass:[FriendApplicationNotificationCell class] forCellReuseIdentifier:FriendApplicationNotificationCellIdentifier];
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    //监听客户端状态通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imClientStateChanged:) name:KIMClientStateChangedNotificationName object:nil];
    //监听用户电子名片更新通知
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(userVCardUpdated:) name:KIMRosterModuleUserVCardUpdatedNotificationName object:nil];
    //监听聊天消息
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(imClientReceivedChatMessage:) name:KIMChatModuleReceivedChatMessageNotificationName object:nil];
    //监听群消息
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(imClientReceivedChatGroupMessage:) name:KIMChatModuleReceivedGroupChatMessageNotificationName object:nil];
    //监听好友申请
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(receivedApplicationOrReply:) name:KIMRosterModuleReceivedFriendApplicationNotificationName object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(receivedApplicationOrReply:) name:KIMRosterModuleReceivedFriendApplicationReplyNotificationName object:nil];
    
    [self setTitleWithClientState:((AppDelegate*)UIApplication.sharedApplication.delegate).imClient.state];
    
    //监听通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
}

-(void)imClientStateChanged:(NSNotification*)notification
{
    KIMClientState previousState = [[notification.userInfo objectForKey:@"previous"] unsignedIntegerValue];
    KIMClientState currentState = [[notification.userInfo objectForKey:@"now"] unsignedIntegerValue];
    if (currentState == previousState) {
        return;
    }
    [self setTitleWithClientState:currentState];
}

-(void)setTitleWithClientState:(KIMClientState)clientState
{
    switch (clientState) {
        case KIMClientState_Offline:
        {
            [self.navigationItem setTitle:@"消息(未连接)"];
            [self syncData];
        }
            break;
        case KIMClientState_RetrievingNodeServer:
        case KIMClientState_Loging:
        case KIMClientState_ReLoging:
        {
            [self.navigationItem setTitle:@"连接中..."];
        }
            break;
        case KIMClientState_Logined:
        {
            [self.navigationItem setTitle:@"消息"];
            [self loadData];
            [self.tableView reloadData];
        }
            break;
        default:
            break;
    }
}

-(void)userVCardUpdated:(NSNotification*)notification
{
    if (!self.isActiveViewController) {
        return;
    }
    [self.tableView reloadData];
}

-(void)imClientReceivedChatMessage:(NSNotification*)notification
{
    NSString * peerAccount = nil;
    
    KIMClient * imClient = [(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient];
    
    if([imClient.currentUser.account isEqualToString:[notification.userInfo objectForKey:@"receiver"]]){
        peerAccount = [notification.userInfo objectForKey:@"sender"];
    }else{
        peerAccount = [notification.userInfo objectForKey:@"receiver"];
    }
    
    ChatSessionMessageModel * messageModel = nil;
    
    for (MessageModel * message in self.messageList) {
        if (message.type == MessageType_ChatSession) {
            if([[(ChatSessionMessageModel*)message peerAccount] isEqualToString:peerAccount]){
                messageModel = (ChatSessionMessageModel*)message;
                break;
            }
        }
    }
    [self.messageList removeObject:messageModel];
    
    if (!messageModel) {
        messageModel = [[ChatSessionMessageModel alloc] init];
        [messageModel setPeerAccount:peerAccount];
        KIMUser * peerUser = [[KIMUser alloc]initWithUserAccount:messageModel.peerAccount];
        KIMUserVCard * userVCard = [imClient.rosterModule retriveUserVCardFromLocalCache:peerUser];
        if (userVCard) {
            messageModel.nickName = userVCard.nickName;;
            messageModel.avatar = userVCard.avatar;
        }
    }
    
    [messageModel setContent:[notification.userInfo objectForKey:@"content"]];
    [messageModel setUnReadCount:messageModel.unReadCount+1];
    [self.messageList insertObject:messageModel atIndex:0];
    
    if (self.isActiveViewController) {
        [self.tableView reloadData];
    }
    
    [self updateUnreadCount];
}

-(void)imClientReceivedChatGroupMessage:(NSNotification*)notification
{
    
    KIMClient * imClient = [(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient];
    
    NSString * groupId = [notification.userInfo objectForKey:@"groupId"];
    
    ChatGroupSessionMessageModel * messageModel = nil;
    
    for (MessageModel * message in self.messageList) {
        if (message.type == MessageType_ChatGroupSession) {
            if([[(ChatGroupSessionMessageModel*)message groupId] isEqualToString:groupId]){
                messageModel = (ChatGroupSessionMessageModel*)message;
                break;
            }
        }
    }
    [self.messageList removeObject:messageModel];
    
    if (!messageModel) {
        messageModel = [[ChatGroupSessionMessageModel alloc] init];
        [messageModel setGroupId:groupId];
        KIMChatGroup * chatGroup = [[KIMChatGroup alloc] initWithGroupId:groupId];
        KIMChatGroupInfo * chatGroupInfo = [imClient.chatGroupModule retriveChatGroupInfoFromLocalCache:chatGroup];
        if (chatGroupInfo) {
            messageModel.groupName = chatGroupInfo.groupName;;
        }
    }
    
    [messageModel setContent:[notification.userInfo objectForKey:@"content"]];
    [messageModel setUnReadCount:messageModel.unReadCount+1];
    
    [self.messageList insertObject:messageModel atIndex:0];
    
    if (self.isActiveViewController) {
        [self.tableView reloadData];
    }
    
    [self updateUnreadCount];
}

-(void)receivedApplicationOrReply:(NSNotification*)notification
{
    
    NSNumber * applicationId = [notification.userInfo objectForKey:@"applicationId"];
    
    FriendApplicationNotificationMessageModel * messageModel = nil;
    
    for (MessageModel * message in self.messageList) {
        if (message.type == MessageType_FriendApplication) {
            messageModel = (FriendApplicationNotificationMessageModel*)message;
            break;
        }
    }
    
    [self.messageList removeObject:messageModel];
    
    if (!messageModel) {
        messageModel = [[FriendApplicationNotificationMessageModel alloc] init];
        [messageModel setApplicationId:applicationId];
        
        NSString * peerAccount = nil;
        
        KIMClient * imClient = [(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient];
        
        if([imClient.currentUser.account isEqualToString:[notification.userInfo objectForKey:@"sponsor"]]){
            peerAccount = [notification.userInfo objectForKey:@"target"];
            [messageModel setPeerRole:FriendApplicationPeerRole_Target];
        }else{
            peerAccount = [notification.userInfo objectForKey:@"sponsor"];
            [messageModel setPeerRole:FriendApplicationPeerRole_Sponsor];
        }
        [messageModel setPeerAccount:peerAccount];
        [messageModel setIntroduction:[notification.userInfo objectForKey:@"introduction"]];
    }
    
    [messageModel setUnReadCount:messageModel.unReadCount+1];
    [self.messageList insertObject:messageModel atIndex:0];
    
    if (self.isActiveViewController) {
        [self.tableView reloadData];
    }
    
    [self updateUnreadCount];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[self tableView] reloadData];
    
    [self setIsActiveViewController:YES];
    
    [self updateUnreadCount];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self setIsActiveViewController:NO];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return self.messageList.count;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch ([[self.messageList objectAtIndex:indexPath.row] type]) {
        case MessageType_ChatSession:
        {
            ChatSessionCell * chatSessionCell = [tableView dequeueReusableCellWithIdentifier:ChatSessionCellIdentifier];
            [chatSessionCell setModel:(ChatSessionMessageModel*)[self.messageList objectAtIndex:indexPath.row]];
            return chatSessionCell;
        }
            break;
        case MessageType_ChatGroupSession:
        {
            ChatGroupSessionCell * chatGroupSessionCell = [tableView dequeueReusableCellWithIdentifier:ChatGroupSessionCellIdentifier];
            [chatGroupSessionCell setModel:(ChatGroupSessionMessageModel*)[self.messageList objectAtIndex:indexPath.row]];
            return chatGroupSessionCell;
        }
            break;
        case MessageType_FriendApplication:
        {
            FriendApplicationNotificationCell * friendApplicationNotificationCell = [tableView dequeueReusableCellWithIdentifier:FriendApplicationNotificationCellIdentifier];
            [friendApplicationNotificationCell setModel:(FriendApplicationNotificationMessageModel*)[self.messageList objectAtIndex:indexPath.row]];
            return friendApplicationNotificationCell;
        }
            break;
        default:
            return nil;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [[self.messageList objectAtIndex:indexPath.row] setUnReadCount:0];
    [self updateUnreadCount];
    switch ([[self.messageList objectAtIndex:indexPath.row] type]) {
        case MessageType_ChatSession:
        {
            ChatSessionMessageModel * model = (ChatSessionMessageModel*)[self.messageList objectAtIndex:indexPath.row];
            ChatViewController *chatController = [ChatViewController new];
            [chatController setPeerUser:[[KIMUser alloc]initWithUserAccount:model.peerAccount]];
            [[self navigationController] pushViewController:chatController animated:YES];
        }
            break;
        case MessageType_ChatGroupSession:
        {
            ChatGroupSessionMessageModel * model = (ChatGroupSessionMessageModel*)[self.messageList objectAtIndex:indexPath.row];
            GroupChatViewController * groupChatViewController = [GroupChatViewController groupChatViewController:[[KIMChatGroup alloc]initWithGroupId:model.groupId]];
            [[self navigationController] pushViewController:groupChatViewController animated:YES];
        }
            break;
        case MessageType_FriendApplication:
        {
            FriendApplicationListViewController * friendApplicationListViewController = [[FriendApplicationListViewController alloc] init];
            [[self navigationController] pushViewController:friendApplicationListViewController animated:YES];
        }
            break;
        default:
            break;
    }
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    NSMutableArray<UITableViewRowAction*> *rowActionArray = [NSMutableArray<UITableViewRowAction*> array];
    
    UITableViewRowAction *deleAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"删除" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        MessageModel * model = [self.messageList objectAtIndex:indexPath.row];

        //从messageArray中移除
        [[self messageList] removeObject:model];
        
        [tableView reloadData];
    }];
    
    [rowActionArray addObject:deleAction];
    
    return rowActionArray;
    
}


- (void)applicationWillEnterForeground:(NSNotification*)notification
{
    
}
- (void)applicationDidEnterBackground:(NSNotification*)notification
{
    //保存数据
    [self syncData];
}

- (void)applicationWillTerminate:(NSNotification*)notification
{
    //保存数据
    [self syncData];
}
-(NSString*)recentMessageListKey
{
    KIMClient * imClient = [(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient];
    return [NSString stringWithFormat:@"RecentMessageList-%@",imClient.currentUser.account];
}
-(void)syncData
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:self.messageList] forKey:[self recentMessageListKey]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
-(void)loadData
{
    [self.messageList removeAllObjects];
    ;
    [self.messageList addObjectsFromArray:[NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:[self recentMessageListKey]]]];
}
-(void)updateUnreadCount
{
    NSInteger unReadCount = 0;
    for (MessageModel * model in self.messageList) {
        unReadCount += model.unReadCount;
    }
    [UIApplication sharedApplication].applicationIconBadgeNumber = unReadCount;
    if(unReadCount){
        [[[self navigationController] tabBarItem] setBadgeValue:[NSString stringWithFormat:@"%ld",unReadCount]];
    }else{
        [[[self navigationController] tabBarItem] setBadgeValue:nil];
    }
}
-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
