//
//  TCPServerTool.h
//  QRBox
//
//  Created by 蒙俊竹 on 2025/8/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TCPServerTool;

typedef NS_ENUM(NSInteger, ConnectStatus) {
    ConnectStatusConnected    = 0,
    ConnectStatusDisconnected = 1
};

@protocol TCPServerToolDelegate <NSObject>

- (void)socket:(TCPServerTool *)tool receiveData:(NSData *)contentData;
- (void)socket:(TCPServerTool *)tool status:(ConnectStatus)status withError:(nullable NSError *)err ;;
- (void)socket:(TCPServerTool *)tool withTag:(long)tag;

@end

@interface TCPServerTool : NSObject

@property (nonatomic, weak) id<TCPServerToolDelegate> delegate;

+ (instancetype)shareInstance;
- (BOOL)listenOnPort:(uint16_t)port delegate:(id<TCPServerToolDelegate>)delegate;
- (void)sendData:(NSData *)contentData to:(NSString *)client withTag:(long)tag;
- (void)disconnect;

@end

NS_ASSUME_NONNULL_END
