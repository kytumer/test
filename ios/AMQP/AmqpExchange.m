//
//  AmqpExchange.m
//  AmqpLib
//
//  Created by Mac on 09.06.2023.
//  Copyright © 2023 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AmqpExchange.h"



@implementation AmqpExchange

@synthesize name;
@synthesize passive;
@synthesize durable;
@synthesize autoDelete;
@synthesize internal;

-(nonnull instancetype)initWithParameters:(NSDictionary *) parameters{
    
    if ([parameters objectForKey:@"name"] && [[parameters objectForKey:@"name"] isKindOfClass:[NSString class]]){
        [self setName:[parameters objectForKey:@"name"]];
    }else{
        self.name = @"no_name";
    }

    if ([parameters objectForKey:@"type"] && [[parameters objectForKey:@"type"] isKindOfClass:[NSString class]]){
        
        [self setExchangeType:[parameters objectForKey:@"type"]];
    }else{
        self.type = @"fanout";
    }
    
    if ([parameters objectForKey:@"alternate_exchange"] && [[parameters objectForKey:@"alternate_exchange"] isKindOfClass:[NSString class]]){
        [self setAlternateExchange:[parameters objectForKey:@"alternate_exchange"]];
    }else{
        [self setAlternateExchange:nil];
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
    
    if ([parameters objectForKey:@"internal"] && [[parameters objectForKey:@"internal"] isKindOfClass:[NSNumber class]]){
        [self setInternal:[[parameters objectForKey:@"internal"] boolValue]];
    }else{
        [self setInternal:NO];
    }
    
    return self;
}


// Тип Exchange. (@"direct", @"fanout", @"headers", @"topic")
-(void)setExchangeType:(NSString *) exchangeType{
    
    if ([exchangeType isEqualToString:@"direct"]){
        self.type = @"direct";
    }
    else if ([exchangeType isEqualToString:@"headers"]){
        self.type = @"headers";
    }
    else if ([exchangeType isEqualToString:@"topic"]){
        self.type = @"topic";
    }
    else{
        self.type = @"fanout";
    }
    
    self.type = exchangeType;
}

-(NSString *)getExchangeType{
    return self.type;
}


@end
