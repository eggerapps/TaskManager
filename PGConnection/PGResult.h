//
//  PGResult.h
//  TaskManager
//
//  Created by Jakob Egger on 2020-05-12.
//  Copyright © 2020 eggerapps. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PGResult : NSObject
@property(readonly) NSInteger numRows;
@property(readonly) NSArray<NSString*> *columnNames;

-(NSString*_Nullable)stringAtRow:(NSInteger)row column:(NSInteger)column;
-(NSString*_Nullable)stringAtRow:(NSInteger)row columnName:(NSString*)columnName;

@end

NS_ASSUME_NONNULL_END
