//
//  AmqpQueue.h
//  AmqpLib
//
//  Created by Mac on 09.06.2023.
//  Copyright © 2023 Facebook. All rights reserved.
//

#ifndef AmqpQueue_h
#define AmqpQueue_h

@interface AmqpQueue : NSObject

// Пользовательское наименование очереди
@property (nonnull, nonatomic, readwrite)  NSString *name;

// Флаг пассивного объявления. (Подробное описание представлено в AMQPConnection.h)
@property (nonatomic, nonatomic, readwrite)  BOOL passive;

// Флаг "долговечности".
@property (nonatomic, nonatomic, readwrite)  BOOL durable;

// Флаг автоматического удаления.
@property (nonatomic, nonatomic, readwrite)  BOOL autoDelete;

// Флаг внутреннего использования.
@property (nonatomic, nonatomic, readwrite)  BOOL exclusive;

// Список необязательных аргументов. (Подробное описание представлено в AMQPConnection.h)
@property (nullable, nonatomic, readwrite)  NSMutableDictionary *arguments;

-(nonnull instancetype)initWithParameters:(NSDictionary * _Nonnull) parameters;
-(nonnull instancetype)initWithParameters:(NSDictionary * _Nonnull) parameters andArguments: (NSDictionary * _Nullable) arguments;

-(void)removeAllArguments;

-(void)setQueueArguments:(NSDictionary * _Nonnull) arguments;

-(void)setQueueArgument:(id _Nonnull) object withKey: (NSString * _Nonnull) key;

-(void)removeArgumentForKey: (NSString * _Nonnull) key;

-(NSDictionary * _Nullable)getQueueArguments;

-(BOOL)isArguments;


@end


#endif /* AmqpQueue_h */
