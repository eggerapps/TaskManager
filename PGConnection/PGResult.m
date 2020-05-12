//
//  PGResult.m
//  TaskManager
//
//  Created by Jakob Egger on 2020-05-12.
//  Copyright © 2020 eggerapps. All rights reserved.
//

#import "PGResult.h"
#import "libpq-fe.h"

@interface PGResult() {
	PGresult *res;
}
@end

@implementation PGResult

-(instancetype)initWithPGresult:(PGresult*)res {
	self = [super init];
	if (self) {
		self->res = res;
	}
	return self;
}

-(NSString*_Nullable)stringAtRow:(NSInteger)row column:(NSInteger)column {
	if (row < 0 || row >= PQntuples(res)) {
		// invalid row
		return nil;
	}
	if (column < 0 || column >= PQnfields(res)) {
		// invalid column
		return nil;
	}
	if (PQgetisnull(res, (int)row, (int)column)) {
		return nil;
	} else {
		return @(PQgetvalue(res, (int)row, (int)column));
	}
}

-(NSString*_Nullable)stringAtRow:(NSInteger)row columnName:(nonnull NSString *)columnName {
	return [self stringAtRow:row column:PQfnumber(res, columnName.UTF8String)];
}

-(NSArray<NSString *> *)columnNames {
	NSMutableArray *array = [NSMutableArray new];
	for (int i = 0; i < PQnfields(res); i++) {
		[array addObject:@(PQfname(res, i))];
	}
	return array;
}

-(NSInteger)numRows {
	return PQntuples(res);
}

-(void)dealloc {
	PQclear(res);
}
@end
