//
//  FileEntry.h
//  QRBox
//
//  Created by 蒙俊竹 on 2025/8/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, FileEntryType) {
    FileEntryTypeMeta         = 0,    // 元数据包
    FileEntryTypeStart        = 1,    // 文件开始标记
    FileEntryTypeData         = 2,    // 文件数据块
    FileEntryTypeEnd          = 3,    // 文件结束标记
    FileEntryTypeDirectory    = 4,    // 目录
    FileEntryTypeFinish       = 5     // 全部传输完成
};

@interface FileEntry : NSObject <NSCoding,NSSecureCoding>

@property (nonatomic, assign) FileEntryType type;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) UInt64 fileSize;
@property (nonatomic, assign) UInt64 offset;
@property (nonatomic) NSData * _Nullable chunkData;
@property (nonatomic, assign) BOOL isDir;

@end

NS_ASSUME_NONNULL_END
