//
//  AMQP_message.h
//  AMQ
//
//  Created by Mac on 05.06.2023.
//


#ifndef AMQP_message_h
#define AMQP_message_h

#import <Foundation/Foundation.h>

@interface AmqpMessage : NSObject

// Необязательные свойства, которые необходимо присвоить создаваемому объекту сообщения amqp
@property (nonatomic, readwrite, nullable) NSMutableDictionary *property;
// Тело сообщения amqp
@property (nonatomic, readwrite, nullable) NSData *body;

// канал по которому было получено сообщение
@property (nonatomic, readwrite) uint16_t channel;
// тег слушателя, которому было доставлено сообщение
@property (nonatomic, readwrite, nullable) NSString *consumer_tag;
// тег сообщения
@property (nonatomic, readwrite) uint64_t delivery_tag;
// флаг, указывающий, доставляется ли это сообщение повторно
@property (nonatomic, readwrite) BOOL redelivered;
// Обменник в котором было опубликовано сообщение
@property (nonatomic, readwrite, nullable) NSString * exchange;
// ключ маршрутизации, с которым было опубликовано это сообщение
@property (nonatomic, readwrite, nullable) NSString * routing_key;

// Переменные используются только в методе AMQP_BASIC_RETURN
// Код ответа. Коды ответов AMQ определены как константы.
@property (nonatomic, readwrite) uint16_t reply_code;
// Текст ответа. Краткое описание произошедшего.
@property (nonatomic, readwrite, nullable) NSString * reply_text;

// Переменные используются только в методе AMQP_BASIC_GET
// Количество сообщений, присутствующих в очереди.
@property (nonatomic, readwrite) uint32_t message_count;

-(nonnull instancetype)init;

@end

#endif /* AMQP_message_h */
