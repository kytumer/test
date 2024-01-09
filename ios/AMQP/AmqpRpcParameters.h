//
//  AMQPDecFeatures.h
//  AMQ
//
//  Created by Mac on 01.06.2023.
//

#ifndef AMQPInputData_h
#define AMQPInputData_h

#import <Foundation/Foundation.h>
#import "AmqpMessage.h"

@interface AmqpRpcParameters : NSObject

// Обязательные параметры rpc запроса отправляемого серверу amqp
@property (nonatomic, readwrite, nullable) NSDictionary *parameters;
// Необязательные аргументы  rpc запроса
@property (nonatomic, readwrite, nullable) NSDictionary *arguments;

// Объект сообщения
@property (nonatomic, readwrite, nullable) AmqpMessage *message;

-(nonnull instancetype)init;

@end


#endif /* AMQPDecFeatures_h */
