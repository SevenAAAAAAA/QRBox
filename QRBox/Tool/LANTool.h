//
//  LANTool.h
//  QRBox
//
//  Created by 蒙俊竹 on 2025/8/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LANTool : NSObject

+ (NSString *)getIPAddress:(BOOL)preferIPv4;
+ (BOOL)isValidatIP:(NSString *)ipAddress;
+ (NSDictionary *)getIPAddresses;
+ (NSString *)localIpAddressForCurrentDevice;   // 获取本机wifi环境下本机ip地址
+ (NSString *)getWifiName;  // 获取本机wifi名称

@end

NS_ASSUME_NONNULL_END
