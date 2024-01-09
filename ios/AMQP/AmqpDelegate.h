//
//  AMQPDelegate.h
//  AMQ
//
//  Created by Mac on 24.05.2023.
//

#ifndef AmqpDelegate_h
#define AmqpDelegate_h

#import <Foundation/Foundation.h>
#import "EventEmitter.h"
#import "AmqpMessage.h"

@class AMQPConnectoin;

@protocol AmqpDelegate <NSObject>

// Callback функция для обработки ошибки подключения
- (void) errorWhenAMQPConnection: (AMQPConnectoin *) connection faildWithErrorCode: (unsigned int) errorCode errorString: (NSString *) errorString;

// Callback функция для обработки внутренней ошибки библиотеки amqp
- (void) libraryErrorWhenAMQPConnection: (AMQPConnectoin *) connection faildWithErrorCode: (unsigned int) errorCode errorString: (NSString *) errorString;

// Callback функция для обработки ошибки канала
- (void) channelErrorWhenAMQPConnection: (AMQPConnectoin *) connection channel: (unsigned int) channelNum faildWithErrorCode: (unsigned int) errorCode errorString: (NSString *) errorString;

// Callback функция для обработки входящих сообщений
- (void) receivedFromAMQPConnection: (AMQPConnectoin *) connection message: (AmqpMessage *) incoming_message;

// Callback функция для обработки сообщений полученных из мотода basic.return
- (void) returnFromAMQPConnection: (AMQPConnectoin *) connection message: (AmqpMessage *) return_message;

@end


#endif /* AMQPDelegate_h */
