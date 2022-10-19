//
//  CircleBuffer.m
//  KakaIM
//
//  Created by taroyuyu on 2018/4/6.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMCircleBuffer.h"
struct KIMCBNode
{
    struct KIMCBNode * next;
    struct KIMCBNode * previous;
#define NodeContentSize 512
    u_int8_t content[NodeContentSize];
};

struct KIMCBCursor
{
    struct KIMCBNode * node;
    size_t offset;
};

@implementation KIMCircleBuffer
{
    struct KIMCBCursor mReadCursor,mWriteCursor;
    size_t mCapacity;
    size_t mUsed;
    NSLock * bufferLock;
}

struct KIMCBNode * createNode()
{
    struct KIMCBNode * node = malloc(sizeof(struct KIMCBNode));
    node->next = NULL;
    node->previous = NULL;
    return node;
}
void releaseNode(struct KIMCBNode * node)
{
    free(node);
}

-(instancetype)initWithInitialCapacity:(size_t)initialCapacity
{
    self = [super init];
    
    if (initialCapacity <= 0) {
        initialCapacity = NodeContentSize;
    }
    
    size_t initialNodeCount = (initialCapacity%NodeContentSize == 0) ? (initialCapacity/NodeContentSize) : (initialCapacity/NodeContentSize + 1);
    self->mCapacity = initialNodeCount * NodeContentSize;
    self->mWriteCursor.node = createNode();
    self->mWriteCursor.node->next = self->mWriteCursor.node;
    self->mWriteCursor.node->previous = self->mWriteCursor.node;
    self->mWriteCursor.offset = 0;//指向下一个可写的位置
    self->mReadCursor.node = self->mWriteCursor.node;
    self->mReadCursor.offset = 0;//指向下一个可读的位置
    
    struct KIMCBNode * it = self->mWriteCursor.node;;
    for (size_t i = 1; i < initialNodeCount; ++i) {
        struct KIMCBNode * newNode = createNode();
        newNode->next = it->next;
        it->next->previous = newNode;
        it->next = newNode;
        newNode->previous = it;
        it = newNode;
    }
    return self;
}
-(void)dealloc
{
    [self->bufferLock lock];
    if (self->mCapacity > 0) {
        struct KIMCBNode * it = self->mWriteCursor.node->next;
        while (it != self->mWriteCursor.node) {
            struct KIMCBNode * tmp = it;
            it = it->next;
            releaseNode(tmp);
            self->mCapacity-=NodeContentSize;
        }
        releaseNode(it);
        self->mCapacity-=NodeContentSize;
        assert(0 == self->mCapacity);
    }
    [self->bufferLock unlock];
}
-(void)appendContent:(const void * )buffer bufferLength:(const size_t) bufferLength
{
    [self->bufferLock lock];
    const u_int8_t * src = (const u_int8_t *) buffer;
    
    size_t leftCopyLength = bufferLength;
    while (leftCopyLength > 0) {
        if (self->mWriteCursor.node != self->mReadCursor.node ||
            self->mWriteCursor.offset >= self->mReadCursor.offset) {//读、写游标不位于同一个节点，或者写指针的游标在读指针的游标的右边(第二个条件的=号是因为CircleBuffer中的ReadCursor和WriteCursor的offset最初是相等的，一旦整个CircleBuffer全部填满，就会新增一个节点(即始终指向下一个可写的位置)，故除了开始的时候，后面ReadCursor和WriteCursor的offset不可能相等)
            size_t nodeLeftFreeCapaicty = NodeContentSize - self->mWriteCursor.offset;//获取写游标当前所处节点的剩余空间
            uint8_t * dst = self->mWriteCursor.node->content + self->mWriteCursor.offset;
            size_t copyLength = MIN(nodeLeftFreeCapaicty,leftCopyLength);
            memcpy(dst, src, copyLength);//将数据拷贝到写游标所处的当前节点
            self->mUsed += copyLength;
            leftCopyLength -= copyLength;
            nodeLeftFreeCapaicty -=copyLength;
            src += copyLength;
            self->mWriteCursor.offset += copyLength;
            if (0 == nodeLeftFreeCapaicty) {//当前节点的剩余空间已经用完
                //1.若整个CircleBuffer还存在剩余空间，则跳转到下一个节点
                if ((self->mCapacity - self->mUsed) > 0) {
                    self->mWriteCursor.node = self->mWriteCursor.node->next;
                    self->mWriteCursor.offset = 0;
                } else {//否则新增加一个节点
                    struct KIMCBNode *newNode = createNode();
                    newNode->next = self->mWriteCursor.node->next;
                    self->mWriteCursor.node->next->previous = newNode;
                    newNode->previous = self->mWriteCursor.node;
                    self->mWriteCursor.node->next = newNode;
                    self->mWriteCursor.node = newNode;
                    self->mWriteCursor.offset = 0;
                    self->mCapacity += NodeContentSize;
                }
            }
        } else {//读、写游标位于同一个节点,且写指针的游标在读指针的游标的左边
            if ((self->mReadCursor.offset - self->mWriteCursor.offset) > leftCopyLength) {//CircleBuffer剩余空间足够存放
                uint8_t *dst = self->mWriteCursor.node->content + self->mWriteCursor.offset;
                size_t copyLength = leftCopyLength;
                memcpy(dst, src, copyLength);//将数据拷贝到写游标所处的当前节点
                leftCopyLength -= copyLength;
                src += copyLength;
                self->mUsed += copyLength;
                self->mWriteCursor.offset += copyLength;
            } else {//CircleBuffer剩余空间不足
                size_t moreSize = leftCopyLength + 1;
                size_t moreNodeCount = (moreSize % NodeContentSize == 0) ? (moreSize / NodeContentSize) : (
                                                                                                           moreSize / NodeContentSize + 1);
                struct KIMCBNode *it = self->mWriteCursor.node;
                for (size_t i = 0; i < moreNodeCount; ++i) {
                    struct KIMCBNode *newNode = createNode();
                    newNode->previous = it->previous;
                    it->previous->next = newNode;
                    it->previous = newNode;
                    newNode->next = it;
                    if(0 == i){
                        uint8_t * src = self->mWriteCursor.node->content;
                        uint8_t * dst = newNode->content;
                        size_t copyLength = self->mWriteCursor.offset - 0;
                        if(copyLength > 0){
                            memcpy(dst,src,copyLength);
                        }
                        self->mWriteCursor.node = newNode;
                    }
                }
                self->mCapacity += moreNodeCount * NodeContentSize;
            }
        }
    }
    
    [self->bufferLock unlock];
}
-(size_t)retriveWithBuffer:(const void *)buffer bufferLength:(const size_t) bufferCapacity
{
    [self->bufferLock lock];
    size_t availableReadLength = MIN(bufferCapacity,self->mUsed);
    
    //分段拷贝
    size_t leftCopyLength = availableReadLength;
    u_int8_t * dst = (u_int8_t*)buffer;
    
    while (leftCopyLength > 0 ) {
        void * src = self->mReadCursor.node->content + self->mReadCursor.offset;
        
        size_t nodeReadableLength = 0;
        if(self->mWriteCursor.node == self->mReadCursor.node && self->mWriteCursor.offset > self->mReadCursor.offset){
            nodeReadableLength = self->mWriteCursor.offset - self->mReadCursor.offset;
        }else{
            nodeReadableLength = NodeContentSize - self->mReadCursor.offset;
        }
        size_t  copyLength = MIN(nodeReadableLength,leftCopyLength);
        memcpy((void*)dst, src, copyLength);
        leftCopyLength-=copyLength;
        dst+=copyLength;
        self->mReadCursor.offset += copyLength;
        if (NodeContentSize == self->mReadCursor.offset) {
            self->mReadCursor.node = self->mReadCursor.node->next;
            self->mReadCursor.offset = 0;
        }
    }
    self->mUsed-= availableReadLength;
    [self->bufferLock unlock];
    
    return availableReadLength;
}
-(size_t)headWithBuffer:(const void *)buffer bufferLength:(const size_t) bufferLength
{
    [self->bufferLock lock];
    size_t availableReadLength = MIN(bufferLength,self->mUsed);
    //创建读指针的副本
    struct KIMCBCursor readCursor_backup = self->mReadCursor;
    
    //分段拷贝
    size_t leftCopyLength = availableReadLength;
    const u_int8_t * dst = (u_int8_t*)buffer;
    while (leftCopyLength > 0 ) {
        void * src = readCursor_backup.node->content + readCursor_backup.offset;
        size_t nodeReadableLength = 0;
        if(self->mWriteCursor.node == readCursor_backup.node && self->mWriteCursor.offset > readCursor_backup.offset){
            nodeReadableLength = self->mWriteCursor.offset - readCursor_backup.offset;
        }else{
            nodeReadableLength = NodeContentSize - readCursor_backup.offset;
        }
        size_t  copyLength = MIN(nodeReadableLength,leftCopyLength);
        memcpy((void*)dst, src, copyLength);
        leftCopyLength-=copyLength;
        dst+=copyLength;
        readCursor_backup.offset += copyLength;
        if (NodeContentSize == readCursor_backup.offset) {
            readCursor_backup.node = readCursor_backup.node->next;
            readCursor_backup.offset = 0;
        }
    }
    [self->bufferLock unlock];
    
    return availableReadLength;
}
-(size_t)used
{
    [self->bufferLock lock];
    size_t bufferUsed = self->mUsed;
    [self->bufferLock unlock];
    return bufferUsed;
}
@end
