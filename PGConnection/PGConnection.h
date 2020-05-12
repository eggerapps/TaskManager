//
//  PGConnection.h
//  TaskManager
//
//  Created by Jakob Egger on 2020-05-12.
//  Copyright © 2020 eggerapps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PGResult.h"

NS_ASSUME_NONNULL_BEGIN

@interface PGConnection : NSObject

+(PGConnection*_Nullable)connectionToDatabase:(NSString*)connectionString error:(NSError*_Nullable*_Nullable)error;
-(BOOL)connectToDatabase:(NSString*)connectionString error:(NSError*_Nullable*_Nullable)error;
-(void)disconnect;

-(BOOL)executeCommand:(NSString*)commandSQL withParams:(NSArray*_Nullable)params error:(NSError*_Nullable*_Nullable)error;
-(PGResult * _Nullable)executeQuery:(NSString*)commandSQL withParams:(NSArray*_Nullable)params error:(NSError*_Nullable*_Nullable)error;

@end

NS_ASSUME_NONNULL_END
