//
//  AmqpExchange.h
//  AmqpLib
//
//  Created by Mac on 09.06.2023.
//  Copyright © 2023 Facebook. All rights reserved.
//

#ifndef AmqpExchange_h
#define AmqpExchange_h

#import <Foundation/Foundation.h>

@interface AmqpExchange : NSObject

// Пользовательское наименование Exchange
@property (nonnull, nonatomic, readwrite)  NSString *name;

// Тип Exchange. (@"direct", @"fanout", @"headers", @"topic")
// Если име не совпадает ни с одним указанным, будет установлено имя по умолчанию @"fanout"
@property (nonnull, nonatomic, readwrite)  NSString *type;

// Флаг пассивного объявления. (Подробное описание представлено в AMQPConnection.h)
@property (nonatomic, nonatomic, readwrite)  BOOL passive;

// Флаг "долговечности".
@property (nonatomic, nonatomic, readwrite)  BOOL durable;

// Флаг автоматического удаления.
@property (nonatomic, nonatomic, readwrite)  BOOL autoDelete;

// Флаг внутреннего использования.
@property (nonatomic, nonatomic, readwrite)  BOOL internal;

// Имя альтернативного обменника, где будут размещены сообщения
// размещение которых в основном обменнике, по каким либо причинам, невозможно.
@property (nullable, nonatomic, readwrite)  NSString *alternateExchange;

-(nonnull instancetype)initWithParameters:(NSDictionary * _Nonnull) parameters;
-(void)setExchangeType:(NSString * _Nonnull) exchangeType;
-(NSString * _Nonnull)getExchangeType;

@end


#endif /* AmqpExchange_h */
