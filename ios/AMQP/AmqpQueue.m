//
//  AmqpQueue.m
//  AmqpLib
//
//  Created by Mac on 09.06.2023.
//  Copyright © 2023 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AmqpQueue.h"


@implementation AmqpQueue

@synthesize name;
@synthesize passive;
@synthesize durable;
@synthesize autoDelete;
@synthesize exclusive;

-(nonnull instancetype)initWithParameters:(NSDictionary * _Nonnull) parameters{
    
    if ([parameters objectForKey:@"name"] && [[parameters objectForKey:@"name"] isKindOfClass:[NSString class]]){
        [self setName:[parameters objectForKey:@"name"]];
    }else{
        self.name = @"no_name";
    }
    
    if ([parameters objectForKey:@"passive"] && [[parameters objectForKey:@"passive"] isKindOfClass:[NSNumber class]]){
        [self setPassive:[[parameters objectForKey:@"passive"] boolValue]];
    }else{
        [self setPassive:NO];
    }
    
    if ([parameters objectForKey:@"durable"] && [[parameters objectForKey:@"durable"] isKindOfClass:[NSNumber class]]){
        [self setDurable:[[parameters objectForKey:@"durable"] boolValue]];
    }else{
        [self setDurable:NO];
    }
    
    if ([parameters objectForKey:@"auto_delete"] && [[parameters objectForKey:@"auto_delete"] isKindOfClass:[NSNumber class]]){
        [self setAutoDelete:[[parameters objectForKey:@"auto_delete"] boolValue]];
    }else{
        [self setAutoDelete:NO];
    }
    
    if ([parameters objectForKey:@"exclusive"] && [[parameters objectForKey:@"exclusive"] isKindOfClass:[NSNumber class]]){
        [self setExclusive:[[parameters objectForKey:@"exclusive"] boolValue]];
    }else{
        [self setExclusive:NO];
    }
    
    self.arguments = [[NSMutableDictionary alloc] init];

    return self;
 
}

-(nonnull instancetype)initWithParameters:(NSDictionary * _Nonnull) parameters andArguments: (NSDictionary * _Nullable) arguments{
    
    if ([parameters objectForKey:@"name"] && [[parameters objectForKey:@"name"] isKindOfClass:[NSString class]]){
        [self setName:[parameters objectForKey:@"name"]];
    }else{
        self.name = @"no_name";
    }
    
    if ([parameters objectForKey:@"passive"] && [[parameters objectForKey:@"passive"] isKindOfClass:[NSNumber class]]){
        [self setPassive:[[parameters objectForKey:@"passive"] boolValue]];
    }else{
        [self setPassive:NO];
    }
    
    if ([parameters objectForKey:@"durable"] && [[parameters objectForKey:@"durable"] isKindOfClass:[NSNumber class]]){
        [self setDurable:[[parameters objectForKey:@"durable"] boolValue]];
    }else{
        [self setDurable:NO];
    }
    
    if ([parameters objectForKey:@"auto_delete"] && [[parameters objectForKey:@"auto_delete"] isKindOfClass:[NSNumber class]]){
        [self setAutoDelete:[[parameters objectForKey:@"auto_delete"] boolValue]];
    }else{
        [self setAutoDelete:NO];
    }
    
    if ([parameters objectForKey:@"exclusive"] && [[parameters objectForKey:@"exclusive"] isKindOfClass:[NSNumber class]]){
        [self setExclusive:[[parameters objectForKey:@"exclusive"] boolValue]];
    }else{
        [self setExclusive:NO];
    }
    
    self.arguments = [[NSMutableDictionary alloc] init];
    
    if (arguments != nil && [arguments count] > 0){
        
        [self setQueueArguments:arguments];
    }
    
    return self;
}


-(void)removeAllArguments{
    [self.arguments removeAllObjects];
}

-(void)setQueueArgument:(id _Nonnull) object withKey: (NSString * _Nonnull) key{
    [self.arguments setObject: object forKey:key];
}

-(void)removeArgumentForKey: (NSString * _Nonnull) key{
    
    if ([self.arguments objectForKey:key]){
        [self.arguments removeObjectForKey:key];
    }
}

-(NSDictionary * _Nullable)getQueueArguments{
    if ([self isArguments]){return self.arguments;}
    return nil;
}

-(BOOL)isArguments{
    return ([self.arguments count]>0);
}

-(void)setQueueArguments:(NSDictionary *) arguments{
    
    // Время в милисекундах в течении которого сообщения будут сохраняться в очереди.
    if ([arguments objectForKey:@"x-message-ttl"] && [[arguments objectForKey:@"x-message-ttl"] isKindOfClass:[NSNumber class]]){
        
        [self.arguments setObject:[NSNumber numberWithUnsignedInt:[[arguments objectForKey:@"x-message-ttl"] unsignedIntValue]] forKey:@"x-message-ttl"];
    }
    
    // Время в миллисекундах по истечению которого происходит удаление очереди.
    if ([arguments objectForKey:@"x-expires"] && [[arguments objectForKey:@"x-expires"] isKindOfClass:[NSNumber class]]){
        
        [self.arguments setObject:[NSNumber numberWithUnsignedInt:[[arguments objectForKey:@"x-expires"] unsignedIntValue]] forKey:@"x-expires"];
    }

    // Максимальное допустимое количество сообщений в очереди.
    if ([arguments objectForKey:@"x-max-lenght"] && [[arguments objectForKey:@"x-max-lenght"] isKindOfClass:[NSNumber class]]){
        
        [self.arguments setObject:[NSNumber numberWithUnsignedInt:[[arguments objectForKey:@"x-max-lenght"] unsignedIntValue]] forKey:@"x-max-lenght"];
    }
    
    // Максимальное допустимый суммарный размер полезной нагрузки сообщений в очереди.
    if ([arguments objectForKey:@"x-max-lenght-bytes"] && [[arguments objectForKey:@"x-max-lenght-bytes"] isKindOfClass:[NSNumber class]]){
        
        [self.arguments setObject:[NSNumber numberWithUnsignedInt:[[arguments objectForKey:@"x-max-lenght-bytes"] unsignedIntValue]] forKey:@"x-max-lenght-bytes"];
    }
    
    // Поведение в результате переполнения очереди.
    // Максимальное допустимый суммарный размер полезной нагрузки сообщений в очереди.
    if ([arguments objectForKey:@"x-overflow"] && [[arguments objectForKey:@"x-overflow"] isKindOfClass:[NSString class]]){
        
        [self.arguments setObject:[NSString stringWithString:[arguments objectForKey:@"x-overflow"]] forKey:@"x-overflow"];
    }
    
    // Exchange, в который направляются отвергнутые сообщения
    if ([arguments objectForKey:@"x-dead-letter-exchange"] && [[arguments objectForKey:@"x-dead-letter-exchange"] isKindOfClass:[NSString class]]){
        
        [self.arguments setObject:[NSString stringWithString:[arguments objectForKey:@"x-dead-letter-exchange"]] forKey:@"x-dead-letter-exchange"];
    }
    
    // Ключ маршрутизации для отвергнутых сообщений
    if ([arguments objectForKey:@"x-dead-letter-routing-key"] && [[arguments objectForKey:@"x-dead-letter-routing-key"] isKindOfClass:[NSString class]]){
        
        [self.arguments setObject:[NSString stringWithString:[arguments objectForKey:@"x-dead-letter-routing-key"]] forKey:@"x-dead-letter-routing-key"];
    }
    
    // Разрешает сортировку по приоритетам в очереди с максимальным значением приоритета 255
    if ([arguments objectForKey:@"x-max-priority"] && [[arguments objectForKey:@"x-max-priority"] isKindOfClass:[NSNumber class]]){
        
        [self.arguments setObject:[NSNumber numberWithUnsignedInt:[[arguments objectForKey:@"x-max-priority"] unsignedIntValue]] forKey:@"x-max-priority"];
    }
    
    // Определяет как сообщение будет распространяться по узлам.
    if ([arguments objectForKey:@"x-ha-policy"] && [[arguments objectForKey:@"x-ha-policy"] isKindOfClass:[NSString class]]){
        
        [self.arguments setObject:[NSString stringWithString:[arguments objectForKey:@"x-ha-policy"]] forKey:@"x-ha-policy"];
    }
    
    // Задает узлы, к которым будет относиться очередь
    if ([arguments objectForKey:@"x-ha-nodes"] && [[arguments objectForKey:@"x-ha-nodes"] isKindOfClass:[NSString class]]){
        
        [self.arguments setObject:[NSString stringWithString:[arguments objectForKey:@"x-ha-nodes"]] forKey:@"x-ha-nodes"];
    }
}

@end
