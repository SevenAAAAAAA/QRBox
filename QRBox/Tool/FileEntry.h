//
//  FileEntry.h
//  QRBox
//
//  Created by 蒙俊竹 on 2025/8/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FileEntry : NSObject <NSCoding,NSSecureCoding>

@property (nonatomic, assign) BOOL isDir;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSData * _Nullable data;

@end

NS_ASSUME_NONNULL_END
