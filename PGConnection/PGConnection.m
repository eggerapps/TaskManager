//
//  PGConnection.m
//  TaskManager
//
//  Created by Jakob Egger on 2020-05-12.
//  Copyright © 2020 eggerapps. All rights reserved.
//

#import "PGConnection.h"
#import "PGResult.h"
#import "NSError+ConvenienceConstructors.h"
#import "libpq-fe.h"

@interface PGResult()
-(instancetype)initWithPGresult:(PGresult*)res;
@end

@interface PGConnection() {
	PGconn *conn;
}
@end

@implementation PGConnection

+(PGConnection*)connectionToDatabase:(NSString*)connectionString error:(NSError**)error {
	PGConnection* connection = [[PGConnection alloc] init];
	if ([connection connectToDatabase:connectionString error:error]) {
		return connection;
	} else {
		return nil;
	}
}

-(BOOL)connectToDatabase:(NSString*)connectionString error:(NSError**)error {
	conn = PQconnectdb(connectionString.UTF8String);
	if (PQstatus(conn) != CONNECTION_OK) {
		[NSError set: error
			  domain: @"PGConnection"
				code: 1
			  format: @"Connection to PostgreSQL server failed.\n%s", PQerrorMessage(conn)];
		PQfinish(conn);
		conn = NULL;
		return NO;
	}
	return YES;
}

-(void)disconnect {
	if (conn) {
		PQfinish(conn);
		conn = NULL;
	}
}

-(BOOL)executeCommand:(NSString*)commandSQL withParams:(NSArray*)params error:(NSError**)error {
	const char *values[params.count];
	int i = 0;
	for (id param in params) {
		NSString *str;
		if ([param isKindOfClass:[NSString class]]) {
			str = param;
		} else if ([param isKindOfClass:[NSNull class]]) {
			str = nil;
		} else if ([param respondsToSelector:@selector(stringValue)]) {
			str = [param stringValue];
		} else {
			[NSError set:error domain:@"PGConnection" code:1 format:@"Parameter class %@ not supported", [param className]];
			return NO;
		}
		values[i++] = str.UTF8String;
	}
	PGresult *res = PQexecParams(conn, commandSQL.UTF8String, i, NULL, values, NULL, NULL, 0);
	BOOL success;
	switch (PQresultStatus(res)) {
		case PGRES_COMMAND_OK:
			success = YES;
			break;
		case PGRES_FATAL_ERROR:
			[NSError set:error domain:@"PGConnection" code:1 format:@"Command execution failed:\n%s", PQresultErrorMessage(res)];
			success = NO;
			break;
		default:
			[NSError set:error domain:@"PGConnection" code:1 format:@"Unexpected result status: %s", PQresStatus(PQresultStatus(res))];
			success = NO;			
	}
	PQclear(res);
	return success;
}

-(PGResult*)executeQuery:(NSString*)commandSQL withParams:(NSArray*)params error:(NSError**)error {
	const char *values[params.count];
	int i = 0;
	for (id param in params) {
		NSString *str;
		if ([param isKindOfClass:[NSString class]]) {
			str = param;
		} else if ([param isKindOfClass:[NSNull class]]) {
			str = nil;
		} else if ([param respondsToSelector:@selector(stringValue)]) {
			str = [param stringValue];
		} else {
			[NSError set:error domain:@"PGConnection" code:1 format:@"Parameter class %@ not supported", [param className]];
			return nil;
		}
		values[i++] = str.UTF8String;
	}
	PGresult *res = PQexecParams(conn, commandSQL.UTF8String, i, NULL, values, NULL, NULL, 0);
	PGResult *result;
	switch (PQresultStatus(res)) {
		case PGRES_TUPLES_OK:
			result = [[PGResult alloc] initWithPGresult:res];
			break;
		case PGRES_FATAL_ERROR:
			PQclear(res);
			[NSError set:error domain:@"PGConnection" code:1 format:@"Command execution failed:\n%s", PQresultErrorMessage(res)];
			result = nil;
			break;
		default:
			PQclear(res);
			[NSError set:error domain:@"PGConnection" code:1 format:@"Unexpected result status: %s", PQresStatus(PQresultStatus(res))];
			result = nil;			
	}
	return result;
}


-(void)dealloc {
	if (conn) PQfinish(conn);
}

@end
