#import "RabbitMqConnection.h"
#import "AMQPConnectoin.h"
#import "AmqpConDelegate.h"
#import "AmqpExchange.h"
#import "AmqpQueue.h"

@interface RabbitMqConnection ()

@property (nonatomic, readwrite) AMQPConnectoin *amqp_conn;
@property (nonatomic, readwrite) AmqpConDelegate *delegate;

@property (nonatomic, readwrite) NSDictionary *config;
@property (nonatomic, readwrite) bool connected;
@property (nonatomic, readwrite) NSMutableArray *queues;
@property (nonatomic, readwrite) NSMutableArray *exchanges;
@property (nonatomic, readwrite) int  heartbeat;
@property (nonatomic, strong) dispatch_source_t timerSource;
@end

@implementation RabbitMqConnection


@synthesize bridge = _bridge;

// Для экспорта модуля с именем класса
RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(initialize:(NSDictionary *) config)
{
    self.config = config;
    self.connected = false;
    self.queues = [[NSMutableArray alloc] init];
    self.exchanges = [[NSMutableArray alloc] init];
    
    if (self.amqp_conn == nil){
        self.amqp_conn = [[AMQPConnectoin alloc] init];
    }
    
    if ([self.config objectForKey:@"host"] != nil && [[self.config objectForKey:@"host"] isKindOfClass:[NSString class]]){
        [self.amqp_conn setHostName:[NSString stringWithString:[self.config objectForKey:@"host"]]];
    }
    
    if ([self.config objectForKey:@"port"] != nil && [[self.config objectForKey:@"port"] isKindOfClass:[NSNumber class]]){
        [self.amqp_conn setPort:[[self.config objectForKey:@"port"] unsignedIntValue]];
    }
    
    if ([self.config objectForKey:@"userName"] != nil && [[self.config objectForKey:@"userName"] isKindOfClass:[NSString class]]){
        [self.amqp_conn setUserName:[NSString stringWithString:[self.config objectForKey:@"userName"]]];
    }

    if ([self.config objectForKey:@"password"] != nil && [[self.config objectForKey:@"password"] isKindOfClass:[NSString class]]){
        [self.amqp_conn setPassword:[NSString stringWithString:[self.config objectForKey:@"password"]]];
    }
    
    if ([self.config objectForKey:@"virtualHost"] != nil && [[self.config objectForKey:@"virtualHost"] isKindOfClass:[NSString class]]){
        [self.amqp_conn setVirtualHost:[NSString stringWithString:[self.config objectForKey:@"virtualHost"]]];
    }
    
    if ([self.config objectForKey:@"connectionName"] != nil && [[self.config objectForKey:@"connectionName"] isKindOfClass:[NSString class]]){
        [self.amqp_conn setConnectionName:[NSString stringWithString:[self.config objectForKey:@"connectionName"]]];
    }
    
    if ([self.config objectForKey:@"channelMax"] != nil && [[self.config objectForKey:@"channelMax"] isKindOfClass:[NSNumber class]]){
        [self.amqp_conn setChannelMax:[[self.config objectForKey:@"channelMax"] unsignedIntValue]];
    }
    
    if ([self.config objectForKey:@"frameMax"] != nil && [[self.config objectForKey:@"frameMax"] isKindOfClass:[NSNumber class]]){
        [self.amqp_conn setFrameMax:[[self.config objectForKey:@"frameMax"] unsignedLongValue]];
    }
    
    if ([self.config objectForKey:@"heartBeatTimeOut"] != nil && [[self.config objectForKey:@"heartBeatTimeOut"] isKindOfClass:[NSNumber class]]){
        [self.amqp_conn setHeartBeatTimeOut:[[self.config objectForKey:@"heartBeatTimeOut"] unsignedCharValue]];
    }
    
    if ([self.config objectForKey:@"connectTimeOut"] != nil && [[self.config objectForKey:@"connectTimeOut"] isKindOfClass:[NSNumber class]]){
        [self.amqp_conn setConnectTimeOut:[[self.config objectForKey:@"connectTimeOut"] unsignedIntValue]];
    }
    
    if ([self.config objectForKey:@"useSSL"] != nil && [[self.config objectForKey:@"useSSL"] isKindOfClass:[NSNumber class]]){
        [self.amqp_conn useSSL:[[self.config objectForKey:@"useSSL"] boolValue]];
    }
    
    self.delegate = [[AmqpConDelegate alloc]init];
    
    if (self.delegate != nil){
        [self.amqp_conn setDelegate:self.delegate];
    }
}

RCT_EXPORT_METHOD(connect)
{
    NSDictionary *rpc_reply;
    rpc_reply = [self.amqp_conn connect];
    
    if([rpc_reply objectForKey:@"success"]){
        [EventEmitter emitEventWithName:@"RabbitMqConnectionEvent" body:@{@"name":@"connected"}];
    }
    
    else if([rpc_reply objectForKey:@"error"]){
        
        NSString *error_code = nil;
        NSString *error_str = nil;
        
        if ([rpc_reply objectForKey:@"error_code"] && [[rpc_reply objectForKey:@"error_code"] isKindOfClass:[NSNumber class]]){
            
            error_code = [NSString stringWithFormat:@"reply-code=%u", [[rpc_reply objectForKey:@"error_code"] unsignedIntValue]];
        }else{
            error_code = [NSString stringWithFormat:@"reply-code=%u", 0];
        }
        
        if ([rpc_reply objectForKey:@"error"] && [[rpc_reply objectForKey:@"error"] isKindOfClass:[NSString class]]){
            error_str = [NSString stringWithFormat:@"reply-text=%@", [rpc_reply objectForKey:@"error"]];
        }else{
            error_str = @"reply-text=Unknown error";
        }
        
        
        [EventEmitter emitEventWithName:@"RabbitMqConnectionEvent" body:@{@"name": @"error", @"type": @"failedtoconnect", @"code": error_code, @"description": error_str}];
        
        error_code = nil;
        error_str = nil;
    }
}



RCT_EXPORT_METHOD(close){
    
    [self.amqp_conn disconnect];
}

RCT_EXPORT_METHOD(createChannel: (RCTResponseSenderBlock)successCallback
                  errorCallback: (RCTResponseSenderBlock)errorCallback)
{
    AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
    
    funcParam.parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithUnsignedInt: 1], @"channel",
                            nil];
    
    NSDictionary *rpc_reply;
    
    rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"channelOpen:" andArgumets:funcParam];
    
    
    if([rpc_reply objectForKey:@"success"]){
        
        NSMutableString *success_str = [NSMutableString stringWithString:@""];
        
        NSString *success;
        NSNumber *channel_number;
        NSString *channel_name;
        
        if ([rpc_reply objectForKey:@"success"] && [[rpc_reply objectForKey:@"success"] isKindOfClass:[NSString class]]){
            success = (NSString *)[rpc_reply objectForKey:@"success"];
        }else{
            success = @"Channel open: ok.";
        }
        
        [success_str appendString:success];
        
        if ([rpc_reply objectForKey:@"channel_number"] && [[rpc_reply objectForKey:@"channel_number"] isKindOfClass:[NSNumber class]]){
            channel_number = (NSNumber *)[rpc_reply objectForKey:@"channel_number"];
            
            [success_str appendString:[NSString stringWithFormat:@" Number: %u,", [channel_number unsignedIntValue]]];
        }
        
        if ([rpc_reply objectForKey:@"channel_name"] && [[rpc_reply objectForKey:@"channel_name"] isKindOfClass:[NSString class]]){
            channel_name = (NSString *)[rpc_reply objectForKey:@"channel_name"];
            
            [success_str appendString:[NSString stringWithFormat:@" name: %@.", channel_name]];
            
        }
        
        successCallback(@[success_str]);
        
        success_str = nil;
        success = nil;
        channel_number = nil;
        channel_name = nil;
    }
    
    else if([rpc_reply objectForKey:@"error"]){
        
        NSString *rpc_reply_error;
        NSNumber *rpc_reply_code;
        
        if ([rpc_reply objectForKey:@"error_code"] && [[rpc_reply objectForKey:@"error_code"] isKindOfClass:[NSNumber class]]){
            rpc_reply_code = (NSNumber *)[rpc_reply objectForKey:@"error_code"];
        }else{
            rpc_reply_code = [NSNumber numberWithUnsignedInt:0];
        }
        
        if ([rpc_reply objectForKey:@"error"] && [[rpc_reply objectForKey:@"error"] isKindOfClass:[NSString class]]){
            rpc_reply_error = (NSString *)[rpc_reply objectForKey:@"error"];
        }else{
            rpc_reply_error = @"Channel open: unknown error.";
        }
        
        [EventEmitter emitEventWithName:@"RabbitMqConnectionEvent" body:@{@"name": @"error", @"type": @"channel",  @"code": rpc_reply_code, @"description": rpc_reply_error}];
        
        rpc_reply_error = nil;
        rpc_reply_code = nil;
        
    }
    
    rpc_reply = nil;
    funcParam = nil;
}

RCT_EXPORT_METHOD(closeChannel: (RCTResponseSenderBlock)successCallback
                  errorCallback: (RCTResponseSenderBlock)errorCallback)
{
    AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
    
    funcParam.parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithUnsignedInt:1], @"channel",
                            nil];
    
    NSDictionary *rpc_reply;
    
    rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"channelClose:" andArgumets:funcParam];
    
    
    if([rpc_reply objectForKey:@"success"]){
        
        NSMutableString *success_str = [NSMutableString stringWithString:@""];
        
        NSString *success;
        NSString *close;
        
        if ([rpc_reply objectForKey:@"success"] && [[rpc_reply objectForKey:@"success"] isKindOfClass:[NSString class]]){
            success = (NSString *)[rpc_reply objectForKey:@"success"];
        }else{
            success = @"Channel close: ok.";
        }
        
        [success_str appendString:success];
        
        
        if ([rpc_reply objectForKey:@"close"] && [[rpc_reply objectForKey:@"close"] isKindOfClass:[NSString class]]){
            close = (NSString *)[rpc_reply objectForKey:@"close"];
            
            [success_str appendString:[NSString stringWithFormat:@" %@", close]];
            
        }
        
        successCallback(@[success_str]);
        
        success_str = nil;
        success = nil;
        close = nil;
    }
    
    else if([rpc_reply objectForKey:@"error"]){
        
        NSString *rpc_reply_error;
        
        if ([rpc_reply objectForKey:@"error"] && [[rpc_reply objectForKey:@"error"] isKindOfClass:[NSString class]]){
            rpc_reply_error = (NSString *)[rpc_reply objectForKey:@"error"];
        }else{
            rpc_reply_error = @"Channel open: unknown error.";
        }
        
        rpc_reply_error = nil;
        
    }
    
    rpc_reply = nil;
    funcParam = nil;
}

RCT_EXPORT_METHOD(isChannelOpen: (RCTResponseSenderBlock)successCallback
                  errorCallback: (RCTResponseSenderBlock)errorCallback)
{
    AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
    
    funcParam.parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithUnsignedInt:1], @"channel",
                            [NSNumber numberWithBool:YES], @"active",
                            nil];
    
    NSDictionary *rpc_reply;
    
    rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"channelFlow:" andArgumets:funcParam];
    
    if([rpc_reply objectForKey:@"success"]){
        NSLog(@"%@", [rpc_reply objectForKey:@"success"]);
        
        if ([rpc_reply objectForKey:@"channel_is"] && [[rpc_reply objectForKey:@"channel_is"] isKindOfClass:[NSNumber class]]){
            
            if ([[rpc_reply objectForKey:@"channel_is"] boolValue]){
                successCallback(@[@1]);
            }else{
                errorCallback(@[@0]);
            }
        }
    }
    
    else if([rpc_reply objectForKey:@"error"]){
        NSLog(@"Checking the channel: %@", [rpc_reply objectForKey:@"error"]);
    }
    
    rpc_reply = nil;
    funcParam = nil;
}


RCT_EXPORT_METHOD(getChannelCloseReason: (RCTResponseSenderBlock)successCallback)
{
    AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
    
    funcParam.parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithUnsignedInt:1], @"channel",
                            nil];
    
    NSDictionary *rpc_reply;
    
    rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"getChannelCloseReson:" andArgumets:funcParam];
    
    if([rpc_reply objectForKey:@"success"]){
        
        NSMutableString *success_str = [NSMutableString stringWithString:@"Channel with "];
        
        if ( [[rpc_reply objectForKey:@"success"] objectForKey:@"name"] && [[[rpc_reply objectForKey:@"success"] objectForKey:@"name"] isKindOfClass:[NSString class]]){
            
            [success_str appendString:[NSString stringWithFormat:@"name: %@,", [[rpc_reply objectForKey:@"success"] objectForKey:@"name"]]];
        }
        
        if ([[rpc_reply objectForKey:@"success"] objectForKey:@"number"] && [[[rpc_reply objectForKey:@"success"] objectForKey:@"number"] isKindOfClass:[NSNumber class]]){
            
            [success_str appendString:[NSString stringWithFormat:@" number: %u,", [[[rpc_reply objectForKey:@"success"] objectForKey:@"number"] unsignedIntValue]]];
        }
        
        if ([[rpc_reply objectForKey:@"success"] objectForKey:@"opening_time"] && [[[rpc_reply objectForKey:@"success"] objectForKey:@"opening_time"] isKindOfClass:[NSNumber class]]){
            
            NSDateFormatter *dateFormater = [[NSDateFormatter alloc] init];
            [dateFormater setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            
            NSDate *opening_time = [NSDate dateWithTimeIntervalSince1970: [[[rpc_reply objectForKey:@"success"] objectForKey:@"opening_time"] unsignedLongLongValue]];
            
            [success_str appendString:[NSString stringWithFormat:@" opened: %@,", [dateFormater stringFromDate: opening_time]]];
            
            opening_time = nil;
            dateFormater = nil;
        }
        
        if ([[rpc_reply objectForKey:@"success"] objectForKey:@"closing_time"] && [[[rpc_reply objectForKey:@"success"] objectForKey:@"closing_time"] isKindOfClass:[NSNumber class]]){
            
            NSDateFormatter *dateFormater = [[NSDateFormatter alloc] init];
            [dateFormater setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            
            NSDate *closing_time = [NSDate dateWithTimeIntervalSince1970: [[[rpc_reply objectForKey:@"success"] objectForKey:@"closing_time"] unsignedLongLongValue]];
            
            [success_str appendString:[NSString stringWithFormat:@" was closed: %@,", [dateFormater stringFromDate: closing_time]]];
            
            closing_time = nil;
            dateFormater = nil;
        }
        
        if ([[rpc_reply objectForKey:@"success"] objectForKey:@"reson_code"] && [[[rpc_reply objectForKey:@"success"] objectForKey:@"reson_code"] isKindOfClass:[NSNumber class]]){
            
            [success_str appendString:[NSString stringWithFormat:@" with the reply-code=%u", [[[rpc_reply objectForKey:@"success"] objectForKey:@"reson_code"] unsignedIntValue]]];
        }
        
        if ( [[rpc_reply objectForKey:@"success"] objectForKey:@"close_reson"] && [[[rpc_reply objectForKey:@"success"] objectForKey:@"close_reson"] isKindOfClass:[NSString class]]){
            
            [success_str appendString:[NSString stringWithFormat:@" for the reply-text= %@,", [[rpc_reply objectForKey:@"success"] objectForKey:@"close_reson"]]];
        }
        
        successCallback(@[success_str]);
        success_str = nil;
    }
    
    else if([rpc_reply objectForKey:@"error"]){
        NSLog(@"Channel error: %@", [rpc_reply objectForKey:@"error"]);
    }
    
    rpc_reply = nil;
    funcParam = nil;
}

#pragma mark - Exchange class

RCT_EXPORT_METHOD(addExchange:(NSDictionary * _Nonnull) config){
    
    if ([config objectForKey:@"name"] && [[config objectForKey:@"name"] isKindOfClass:[NSString class]]){
        
        AmqpExchange *exchange = [[AmqpExchange alloc] initWithParameters:config];
        
        [self.exchanges addObject:exchange];
    }
}

RCT_EXPORT_METHOD(declareExchange:(NSString * _Nonnull)exchange_name){
    
    AmqpExchange *exchange = [self getExchange:exchange_name];
    if (exchange != nil){
        
        AmqpExchange *exchange = [self getExchange:exchange_name];
        if (exchange != nil){
            
            AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
            
            funcParam.parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:1], @"channel",
                                    [NSString stringWithString:[exchange name]], @"exchange",
                                    [NSString stringWithString:[exchange type]], @"type",
                                    [NSNumber numberWithBool:[exchange passive]], @"passive",
                                    [NSNumber numberWithBool:[exchange durable]], @"durable",
                                    [NSNumber numberWithBool:[exchange autoDelete]], @"auto_delete",
                                    [NSNumber numberWithBool:[exchange internal]], @"internal",
                                    nil];
            
            if ([exchange alternateExchange] != nil){
                funcParam.arguments = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSString stringWithString:[exchange alternateExchange]], @"alternate-exchange",
                                       nil];
            }
            
            NSDictionary *rpc_reply;
            
            rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"exchangeDeclare:" andArgumets:funcParam];
            
            if([rpc_reply objectForKey:@"success"]){
                NSLog(@"%@", [rpc_reply objectForKey:@"success"]);
            }
            
            else if([rpc_reply objectForKey:@"error"]){
                NSLog(@"Exchange declare error: %@", [rpc_reply objectForKey:@"error"]);
            }
            
            rpc_reply = nil;
            funcParam = nil;
        }
    }else{
        NSLog(@"There is no Exchange with the specified name.");
    }
}

RCT_EXPORT_METHOD(bindExchange:(NSString *)exchange_name){
    
    AmqpExchange *exchange = [self getExchange:exchange_name];
    if (exchange != nil){
        
        
    }
}

RCT_EXPORT_METHOD(deleteExchange:(NSString *)exchange_name ifUnused: (BOOL) if_unused){
    
    //  Флаг "if_unused". Если TRUE, сервер удалит exchange только в том случае, если у него нет привязок к
    //                    очереди.
    
    AmqpExchange *exchange = [self getExchange:exchange_name];
    if (exchange != nil){

        AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
        
        funcParam.parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithUnsignedInt:1], @"channel",
                                [NSString stringWithString:exchange_name], @"exchange",
                                [NSNumber numberWithBool:if_unused], @"if_unused",
                                nil];
        
        NSDictionary *rpc_reply;
        
        rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"exchangeDelete:" andArgumets:funcParam];
        
        if([rpc_reply objectForKey:@"success"]){
            
            NSLog(@"%@", [rpc_reply objectForKey:@"success"]);
            
            [self.exchanges removeObject:exchange];
            
        }
        
        else if([rpc_reply objectForKey:@"error"]){
            NSLog(@"Exchange delete error: %@", [rpc_reply objectForKey:@"error"]);
            NSLog(@"Error code: %@", [rpc_reply objectForKey:@"error_code"]);
        }
        
        rpc_reply = nil;
        funcParam = nil;
     
    }else{
        NSLog(@"There is no Exchange with the specified name.");
    }
}

-(AmqpExchange *) getExchange:(NSString *)name {
    
    AmqpExchange *p_exchange = nil;
    
    if ([self.exchanges count] > 0){
        
        for (uint16_t i = 0; i<[self.exchanges count]; i++){
           
            p_exchange = (AmqpExchange *)self.exchanges[i];
            if ([[p_exchange name] isEqualToString:name]){
                break;
            }
        }
    }
    return p_exchange;

}


#pragma mark - Queue class

RCT_EXPORT_METHOD(addQueue:(NSDictionary *) config arguments:(NSDictionary *)arguments){
    
    if ([config objectForKey:@"name"] && [[config objectForKey:@"name"] isKindOfClass:[NSString class]]){
        
        AmqpQueue *queue = [[AmqpQueue alloc] initWithParameters:config andArguments:arguments];
        
        [self.queues addObject:queue];
    }
  
}


RCT_EXPORT_METHOD(declareQueue: (NSString * _Nonnull) queue_name successCallback:(RCTResponseSenderBlock)successCallback errorCallback: (RCTResponseSenderBlock)errorCallback){
      
    AmqpQueue *queue = [self getQueue:queue_name];
    
    if(queue != nil){
        
        AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
        
        funcParam.parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithUnsignedInt:1], @"channel",
                                [NSString stringWithString:[queue name]], @"queue",
                                [NSNumber numberWithBool:[queue passive]], @"passive",
                                [NSNumber numberWithBool:[queue durable]], @"durable",
                                [NSNumber numberWithBool:[queue autoDelete]], @"auto_delete",
                                [NSNumber numberWithBool:[queue exclusive]], @"exclusive",
                                nil];
        
        if ([queue isArguments]){
            funcParam.arguments = [NSDictionary dictionaryWithDictionary:[queue getQueueArguments]];
        }

        NSDictionary *rpc_reply;
        
        rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"queueDeclare:" andArgumets:funcParam];
        
        if([rpc_reply objectForKey:@"success"]){
            
            NSLog(@"%@", [rpc_reply objectForKey:@"success"]);
            
            NSDictionary *declareOK = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSString stringWithString:[rpc_reply objectForKey:@"queue_name"]], @"queueName",
                                       [NSNumber numberWithUnsignedInt:[[rpc_reply objectForKey:@"message_count"] unsignedIntValue]], @"messageCount",
                                       [NSNumber numberWithInt:[[rpc_reply objectForKey:@"consumer_count"] unsignedIntValue]], @"consumerCount",
                                       nil];
            
            successCallback(@[declareOK]);
            declareOK = nil;
        }
        
        else if([rpc_reply objectForKey:@"error"]){
            
            NSMutableString *error_str = [NSMutableString stringWithString:@"Queue declare error: "];
            
            if ( [rpc_reply objectForKey:@"error"] && [[rpc_reply objectForKey:@"error"] isKindOfClass:[NSString class]]){
                
                [error_str appendString:[rpc_reply objectForKey:@"error"]];
            }
            
            if ([rpc_reply objectForKey:@"error_code"] && [[rpc_reply objectForKey:@"error_code"] isKindOfClass:[NSNumber class]]){
                
                [error_str appendString:[NSString stringWithFormat:@". Error code: %u.", [[rpc_reply objectForKey:@"error_code"] unsignedIntValue]]];
            }
            
            errorCallback(@[error_str]);
            error_str = nil;
        }

        rpc_reply = nil;
        funcParam = nil;
  
    }else{
        errorCallback(@[@"There is no queue with the specified name."]);
    }
}

RCT_EXPORT_METHOD(bindQueue:(NSString *_Nonnull)exchange_name queueName:(NSString *_Nonnull)queue_name routingKey:(NSString * _Nullable)routing_key andArguments: (NSDictionary *_Nullable) arguments){
    
    AmqpQueue *queue = [self getQueue:queue_name];
    if (queue != nil){
        
        AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
        
        NSMutableDictionary *param = [[NSMutableDictionary alloc] init];
        
        [param setObject:[NSNumber numberWithUnsignedInt:1] forKey:@"channel"];
        [param setObject:[NSString stringWithString:exchange_name] forKey:@"exchange"];
        [param setObject:[NSString stringWithString:queue_name] forKey:@"queue"];
        
        if (routing_key != nil && [routing_key length] > 0){
            [param setObject:[NSString stringWithString:routing_key] forKey:@"routing_key"];
        }
        
        funcParam.parameters = [NSDictionary dictionaryWithDictionary:param];
        param = nil;
        
        // В аргументах привязки, обычно, задаются заголовки ("headers")
        // Для использования заголовков в маршрутизации необходимо чтобы Exchange type == @"headers"
        // Заголовки представляют из себя пары <ключ, значение>
        // Ключ и значение должны иметь тип String
        // "Заголовки" позволяют выполнять маршрутизацию сообщений игнорируя ключи маршрутизации.
        // Правильным, при создании заголовков, будет указать серверу способ их ипользования
        // включив в коллекцию "headers" зарезервированную пару:
        //       <x-match, all> - сообщение будет направлено в очередь только в том случае если все указанные
        //                        в нём заголовки в точности соответствуют заголовкам с которыми связана
        //                        очередь.
        //       <x-match, any> - сообщение будет направлено в очередь если оно содержит хотябы один из
        //                        заголовков с которыми связана очередь.
        // Пример коллекции "headers":    ключ      значение
        //                                <x-match, all>
        //                   <any string headers 1, any string 1>
        //                 <any string headers ..., any string ...>
        
        // Фотмат: Dictionary
        
        if (arguments != nil && [arguments count]>0){
            
            NSMutableDictionary *args = [[NSMutableDictionary alloc] init];
            
            for(id key in arguments){
                if([key isKindOfClass:[NSString class]]){
                    if ([arguments objectForKey:key] && [[arguments objectForKey:key] isKindOfClass:[NSString class]]){
                        [args setObject:[NSString stringWithString:[arguments objectForKey:key]] forKey:key];
                    }
                }
            }
            
            funcParam.arguments = [NSDictionary dictionaryWithDictionary:args];
            args = nil;
        }
        
        NSDictionary *rpc_reply;
        
        rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"queueBind:" andArgumets:funcParam];
        if([rpc_reply objectForKey:@"success"]){
            NSLog(@"%@", [rpc_reply objectForKey:@"success"]);
        }
        
        else if([rpc_reply objectForKey:@"error"]){
            NSLog(@"Queue bind error: %@", [rpc_reply objectForKey:@"error"]);
            NSLog(@"Error code: %@", [rpc_reply objectForKey:@"error_code"]);
        }
        
        rpc_reply = nil;
        funcParam = nil;
    }else{
        NSLog(@"There is no queue with the specified name.");
    }
}

RCT_EXPORT_METHOD(unbindQueue:(NSString *_Nonnull)exchange_name queueName:(NSString *_Nonnull)queue_name routingKey:(NSString * _Nullable)routing_key andArguments: (NSDictionary *_Nullable) arguments){
    
    AmqpQueue *queue = [self getQueue:queue_name];
    if (queue != nil){
        
        AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
        
        NSMutableDictionary *param = [[NSMutableDictionary alloc] init];
        
        [param setObject:[NSNumber numberWithUnsignedInt:1] forKey:@"channel"];
        [param setObject:[NSString stringWithString:exchange_name] forKey:@"exchange"];
        [param setObject:[NSString stringWithString:queue_name] forKey:@"queue"];
        
        if (routing_key != nil && [routing_key length] > 0){
            [param setObject:[NSString stringWithString:routing_key] forKey:@"routing_key"];
        }
        
        funcParam.parameters = [NSDictionary dictionaryWithDictionary:param];
        param = nil;
        
        if (arguments != nil && [arguments count]>0){
            
            NSMutableDictionary *args = [[NSMutableDictionary alloc] init];
            
            for(id key in arguments){
                if([key isKindOfClass:[NSString class]] && [key hasPrefix:@"x-"]){
                    if ([arguments objectForKey:key] && [[arguments objectForKey:key] isKindOfClass:[NSString class]]){
                        [args setObject:[NSString stringWithString:[arguments objectForKey:key]] forKey:key];
                    }
                }
            }
            
            funcParam.arguments = [NSDictionary dictionaryWithDictionary:args];
            args = nil;
        }
        
        NSDictionary *rpc_reply;
        
        rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"queueUnbind:" andArgumets:funcParam];
        if([rpc_reply objectForKey:@"success"]){
            NSLog(@"%@", [rpc_reply objectForKey:@"success"]);
        }
        
        else if([rpc_reply objectForKey:@"error"]){
            NSLog(@"Queue unbind error: %@", [rpc_reply objectForKey:@"error"]);
            NSLog(@"Error code: %@", [rpc_reply objectForKey:@"error_code"]);
        }
        
        rpc_reply = nil;
        funcParam = nil;
    }else{
        NSLog(@"There is no queue with the specified name.");
    }

}


RCT_EXPORT_METHOD(purgeQueue:(NSString *_Nonnull)queue_name){
    
    AmqpQueue *queue = [self getQueue:queue_name];
    if (queue != nil){
        
        AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
        
        funcParam.parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithUnsignedInt:1], @"channel",
                                [NSString stringWithString:queue_name], @"queue",
                                nil];
        
        NSDictionary *rpc_reply;
        
        rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"queuePurge:" andArgumets:funcParam];
        
        if([rpc_reply objectForKey:@"success"]){
            NSLog(@"%@", [rpc_reply objectForKey:@"success"]);
            NSLog(@"Message count: %lu", [[rpc_reply objectForKey:@"message_count"] unsignedIntegerValue]);
        }
        
        else if([rpc_reply objectForKey:@"error"]){
            NSLog(@"Queue purge error: %@", [rpc_reply objectForKey:@"error"]);
            NSLog(@"Error code: %@", [rpc_reply objectForKey:@"error_code"]);
        }
        
        rpc_reply = nil;
        funcParam = nil;
    }else{
        NSLog(@"There is no queue with the specified name.");
    }
}


RCT_EXPORT_METHOD(deleteQueue:(NSString * _Nonnull)queue_name ifUnused: (BOOL) if_unused ifEmpty: (BOOL) if_empty){
    
    // Флаг "if-unused". Если TRUE - сервер удалит очередь, только если у неё нет потребителей.
    // Флаг "if-empty". Если TRUE - сервер удалит очередь, только если в ней нет сообщений.
    
    AmqpQueue *queue = [self getQueue:queue_name];
    if (queue != nil){
        
        AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
        
        funcParam.parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithUnsignedInt:1], @"channel",
                                [NSString stringWithString:queue_name], @"queue",
                                [NSNumber numberWithBool:if_unused], @"if_unused",
                                [NSNumber numberWithBool:if_empty], @"if_empty",
                                nil];
        
        NSDictionary *rpc_reply;
        
        rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"queueDelete:" andArgumets:funcParam];
        
        if([rpc_reply objectForKey:@"success"]){
            
            NSLog(@"%@", [rpc_reply objectForKey:@"success"]);
            NSLog(@"Message count: %lu", [[rpc_reply objectForKey:@"message_count"] unsignedIntegerValue]);
            
            [self.queues removeObject:queue];
 
        }
        
        else if([rpc_reply objectForKey:@"error"]){
            NSLog(@"Queue delete error: %@", [rpc_reply objectForKey:@"error"]);
            NSLog(@"Error code: %@", [rpc_reply objectForKey:@"error_code"]);
        }

        rpc_reply = nil;
        funcParam = nil;
       
    }else{
        NSLog(@"There is no queue with the specified name.");
    }
}

-(AmqpQueue *) getQueue:(NSString *)name {
    
    AmqpQueue *p_queue = nil;
    
    if ([self.queues count] > 0){
        
        for (uint16_t i = 0; i<[self.queues count]; i++){
           
            p_queue = (AmqpQueue *)self.queues[i];
            if ([[p_queue name] isEqualToString:name]){
                break;
            }
        }
    }
    return p_queue;
}


#pragma mark - Basic class

RCT_EXPORT_METHOD(basicQos: (NSNumber *) prefetch_size prefetchCount: (NSNumber *) prefetch_count global: (BOOL) global){
    
    AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
    
    NSMutableDictionary *param = [[NSMutableDictionary alloc] init];
    
    [param setObject:[NSNumber numberWithUnsignedInt:1] forKey:@"channel"];
    [param setObject:[NSNumber numberWithBool:global] forKey:@"global"];
    
    if ([prefetch_size isKindOfClass:[NSNumber class]]){
        [param setObject:[NSNumber numberWithUnsignedInt:[prefetch_size unsignedIntValue]] forKey:@"prefetch_size"];
    }
    
    if ([prefetch_count isKindOfClass:[NSNumber class]]){
        [param setObject:[NSNumber numberWithUnsignedInt:[prefetch_count unsignedIntValue]] forKey:@"prefetch_count"];
    }
    
    if ([param count]>2){
        
        funcParam.parameters = [NSDictionary dictionaryWithDictionary:param];
        param = nil;
        
        NSDictionary *rpc_reply;
        
        rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"basicQos:" andArgumets:funcParam];
        
        if([rpc_reply objectForKey:@"success"]){
            
            NSLog(@"%@", [rpc_reply objectForKey:@"success"]);
        }
        
        else if([rpc_reply objectForKey:@"error"]){
            NSLog(@"Qos setup error: %@", [rpc_reply objectForKey:@"error"]);
            NSLog(@"Error code: %@", [rpc_reply objectForKey:@"error_code"]);
        }

        rpc_reply = nil;
        funcParam = nil;
    }
    
    param = nil;
}

RCT_EXPORT_METHOD(basicPublish: (NSString *_Nonnull) message exchangeName: (NSString *_Nonnull) exchange_name routingKey:(NSString * _Nullable)routing_key mandatory: (BOOL) mandatory andArguments: (NSDictionary *_Nullable) arguments){
    
    AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
    
    NSMutableDictionary *param = [[NSMutableDictionary alloc] init];
    
    funcParam.message.body = [message dataUsingEncoding:NSUTF8StringEncoding];
    
    [param setObject:[NSNumber numberWithUnsignedInt:1] forKey:@"channel"];
    [param setObject:[NSString stringWithString:exchange_name] forKey:@"exchange"];
    [param setObject:[NSNumber numberWithBool:mandatory] forKey:@"mandatory"];
    
    if (routing_key != nil && [routing_key length] > 0){
        [param setObject:[NSString stringWithString:routing_key] forKey:@"routing_key"];
    }

    funcParam.parameters = [NSDictionary dictionaryWithDictionary:param];
    param = nil;
    
    
    if (arguments != nil && [arguments count]>0){
        
        NSMutableDictionary *args = [[NSMutableDictionary alloc] init];
        
        // Свойство декларирует тип контента сообщения.
        // Фотмат: текстовый UTF8 (например: "text/plain" или charset="utf-8" или "application/json").
        if ([arguments objectForKey:@"content_type"] && [[arguments objectForKey:@"content_type"] isKindOfClass:[NSString class]]){
            
            [args setObject:[NSString stringWithString:[arguments objectForKey:@"content_type"]] forKey:@"content_type"];
        }
        
        // Свойство декларирует формат кодировки содержимого если сообщение закодировано.
        // Фотмат: текстовый UTF8 (например: "gzip").
        if ([arguments objectForKey:@"content_encoding"] && [[arguments objectForKey:@"content_encoding"] isKindOfClass:[NSString class]]){
            
            [args setObject:[NSString stringWithString:[arguments objectForKey:@"content_encoding"]] forKey:@"content_encoding"];
        }
        
        // Свойство декларирует "заголовки" сообщения - пары <ключ, значение> для выпонения
        // маршрутизации сообщения и направления его в связные очерди.
        // "Заголовки" позволяют выполнять маршрутизацию сообщений игнорируя ключи маршрутизации.
        // Собщение будет доставлено в соответствии с выбранными правилами маршрутизации
        // указанными при связывании очередей с обменниками.
        // Для использования заголовков необходимо чобы Exchange имел тип @"headers".
        // Если в аргументах очереди указано <x-match, all> - сообщение будет доставлено в очередь только в
        // случае полного совпадения всех указанных заголовков.
        // Если в аргументах очереди указано <x-match, any> - сообщение будет доставлено в очередь в
        // случае совпадения хотябы одного из указанных заголовков.
        // Фотмат: Dictionary
        if ([arguments objectForKey:@"headers"] && [[arguments objectForKey:@"headers"] isKindOfClass:[NSDictionary class]]){
            
            NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
            
            for(id key in [arguments objectForKey:@"headers"]){
                if([key isKindOfClass:[NSString class]]){
                    if ([[arguments objectForKey:@"headers"] objectForKey:key] && [[[arguments objectForKey:@"headers"] objectForKey:key] isKindOfClass:[NSString class]]){
                        [headers setObject:[NSString stringWithString:[[arguments objectForKey:@"headers"] objectForKey:key]] forKey:key];
                    }
                }
            }
            
            if([headers count] >0){
                [args setObject:[NSDictionary dictionaryWithDictionary:headers] forKey:@"headers"];
            }
            headers = nil;
        }
        
        // Свойство декларирует способ доставки сообщения - следует ли сохранить сообщение на диске
        // Фотмат: unsigned int
        // 1 - не сохранять на диске; 2 - сохранить.
        if ([arguments objectForKey:@"delivery_mode"] && [[arguments objectForKey:@"delivery_mode"] isKindOfClass:[NSNumber class]]){
            
            uint16_t delivery_mode = ([[arguments objectForKey:@"delivery_mode"] unsignedIntValue] > 1) ? 2 : 1 ;
            
            [args setObject:[NSNumber numberWithUnsignedInt: delivery_mode] forKey:@"delivery_mode"];
        }

        
        // Свойство декларирует приоритет сообщения.
        // Фотмат: unsigned int
        // Значение 0 до 9.
        if ([arguments objectForKey:@"priority"] && [[arguments objectForKey:@"priority"] isKindOfClass:[NSNumber class]]){
            
            uint16_t priority = ([[arguments objectForKey:@"priority"] unsignedIntValue] > 9) ? 9 : [[arguments objectForKey:@"priority"] unsignedIntValue] ;
            
            [args setObject:[NSNumber numberWithUnsignedInt: priority] forKey:@"priority"];
        }
        
        // Свойство декларирует идентификатор корреляции сообщения - например, на какой запрос это
        // сообщение является ответом.
        // Фотмат: текстовый UTF8.
        if ([arguments objectForKey:@"correlation_id"] && [[arguments objectForKey:@"correlation_id"] isKindOfClass:[NSString class]]){
            
            [args setObject:[NSString stringWithString:[arguments objectForKey:@"correlation_id"]] forKey:@"correlation_id"];
        }
        
        // Свойство декларирует имя очереди в которой другие приложения должны размещать ответ.
        // Фотмат: текстовый UTF8.
        
        if ([arguments objectForKey:@"reply_to"] && [[arguments objectForKey:@"reply_to"] isKindOfClass:[NSString class]]){
            
            [args setObject:[NSString stringWithString:[arguments objectForKey:@"reply_to"]] forKey:@"reply_to"];
        }
        
        // Свойство декларирует время, по истечении которого сообщение будет удалено.
        // Фотмат: текстовый UTF8 !!!! Именно ТЕКСТОВЫЙ! Т.е. должно быть написано, например:
        // expiration : "10000" , что означает период TTL == 10 секунд и тд.
        // Значение поля описывает период TTL в миллисекундах.
        if ([arguments objectForKey:@"expiration"] && [[arguments objectForKey:@"expiration"] isKindOfClass:[NSString class]]){
            
            [args setObject:[NSString stringWithString:[arguments objectForKey:@"expiration"]] forKey:@"expiration"];
        }
        
        // Свойство декларирует идентификатор сообщения в виде строки.
        // Фотмат: текстовый UTF8.
        if ([arguments objectForKey:@"message_id"] && [[arguments objectForKey:@"message_id"] isKindOfClass:[NSString class]]){
            
            [args setObject:[NSString stringWithString:[arguments objectForKey:@"message_id"]] forKey:@"message_id"];
        }

        // Свойство декларирует метку времени UNIX момента отправки сообщения.
        // Фотмат: unsigned word
        if ([arguments objectForKey:@"timestamp"] && [[arguments objectForKey:@"timestamp"] isKindOfClass:[NSNumber class]]){
            
            // Если пользователь указал, что необходимо поставить метку времени
            if ([[arguments objectForKey:@"timestamp"] boolValue]){
                
                NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
                [args setObject:[NSNumber numberWithDouble:timeStamp] forKey:@"timestamp"];
            }
        }

        
        // Свойство декларирует тип сообщения, например, какой тип события или команды представляет это
        // сообщение.
        // Фотмат: текстовый UTF8.
        if ([arguments objectForKey:@"type"] && [[arguments objectForKey:@"type"] isKindOfClass:[NSString class]]){
            
            [args setObject:[NSString stringWithString:[arguments objectForKey:@"type"]] forKey:@"type"];
        }
        
        // Свойство декларирует идентификатор пользователя отправляющего сообщение.
        // Указанный id должен в точности совпадать с данными пользователя указанными при
        // аутентификации, иначе сервер вернет ошибку 406 PRECONDITION_FAILED.
        // Фотмат: текстовый UTF8.
        if ([arguments objectForKey:@"user_id"] && [[arguments objectForKey:@"user_id"] isKindOfClass:[NSString class]]){
            
            [args setObject:[NSString stringWithString:[arguments objectForKey:@"user_id"]] forKey:@"user_id"];
        }
        
        // Свойство декларирует идентификатор приложения, создавшего сообщение.
        // Фотмат: текстовый UTF8.
        if ([arguments objectForKey:@"app_id"] && [[arguments objectForKey:@"app_id"] isKindOfClass:[NSString class]]){
            
            [args setObject:[NSString stringWithString:[arguments objectForKey:@"app_id"]] forKey:@"app_id"];
        }
        
        // Свойство декларирует идентификатор маршрутизации внутри кластера для использования
        // кластерными приложениями и не должен использоваться клиентскими приложениями.
        // Устарел в AMQP 0.9.1 - т. е. не используется.
        // Фотмат: текстовый UTF8.
        if ([arguments objectForKey:@"cluster_id"] && [[arguments objectForKey:@"cluster_id"] isKindOfClass:[NSString class]]){
            
            [args setObject:[NSString stringWithString:[arguments objectForKey:@"cluster_id"]] forKey:@"cluster_id"];
        }

        if ([args count] > 0){
            funcParam.arguments = [NSDictionary dictionaryWithDictionary:args];
        }
        args = nil;
    }
    
    NSDictionary *rpc_reply;
    
    rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"basicPublish:" andArgumets:funcParam];
    
    if([rpc_reply objectForKey:@"success"]){
        NSLog(@"%@", [rpc_reply objectForKey:@"success"]);
    }
    
    else if([rpc_reply objectForKey:@"error"]){
        NSLog(@"Queue bind error: %@", [rpc_reply objectForKey:@"error"]);
        NSLog(@"Error code: %@", [rpc_reply objectForKey:@"error_code"]);
    }
    
    rpc_reply = nil;
    funcParam = nil;
}

// Метод посылает запрос серверу запустить "потребителя", который является временным запросом
// на получение сообщений из определенной очереди.
// Пользователи сохраняются до тех пор, пока они были объявлены на канале, или пока клиент не отменит их.
RCT_EXPORT_METHOD(basicConsume:(NSString *_Nonnull) queue_name parameters: (NSDictionary *) config arguments: (NSDictionary *_Nullable) arguments successCallback:(RCTResponseSenderBlock)successCallback errorCallback: (RCTResponseSenderBlock)errorCallback){
    
    AmqpQueue *queue = [self getQueue:queue_name];
    if (queue != nil){
        
        AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
        
        NSMutableDictionary *param = [[NSMutableDictionary alloc] init];
        
        [param setObject:[NSNumber numberWithUnsignedInt:1] forKey:@"channel"];
        [param setObject:[NSString stringWithString:queue_name] forKey:@"queue"];
        
        if ([config objectForKey:@"no_local"] && [[config objectForKey:@"no_local"] isKindOfClass:[NSNumber class]]){
            [param setObject:[NSNumber numberWithBool:[[config objectForKey:@"no_local"] boolValue]] forKey:@"no_local"];
        }
        
        if ([config objectForKey:@"no_ack"] && [[config objectForKey:@"no_ack"] isKindOfClass:[NSNumber class]]){
            [param setObject:[NSNumber numberWithBool:[[config objectForKey:@"no_ack"]boolValue]] forKey:@"no_ack"];
        }
        
        if ([config objectForKey:@"exclusive"] && [[config objectForKey:@"exclusive"] isKindOfClass:[NSNumber class]]){
            [param setObject:[NSNumber numberWithBool:[[config objectForKey:@"exclusive"] boolValue]] forKey:@"exclusive"];
        }
        
        if ([config objectForKey:@"consummer_tag"] && [[config objectForKey:@"consummer_tag"] isKindOfClass:[NSString class]]){
            [param setObject:[NSString stringWithString:[config objectForKey:@"consummer_tag"]] forKey:@"consummer_tag"];
        }
        
        funcParam.parameters = [NSDictionary dictionaryWithDictionary:param];
        param = nil;
        
        if (arguments != nil && [arguments count]>0){
            
            NSMutableDictionary *args = [[NSMutableDictionary alloc] init];
            
            for(id key in arguments){
                if([key isKindOfClass:[NSString class]]){
                    if ([arguments objectForKey:key] && [[arguments objectForKey:key] isKindOfClass:[NSString class]]){
                        [args setObject:[NSString stringWithString:[arguments objectForKey:key]] forKey:key];
                    }
                }
            }
            
            funcParam.arguments = [NSDictionary dictionaryWithDictionary:args];
            args = nil;
        }
        
        NSDictionary *rpc_reply;
        
        rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"basicConsume:" andArgumets:funcParam];
        
        if([rpc_reply objectForKey:@"success"]){
            
            NSString *success_str;
            
            if ( [rpc_reply objectForKey:@"success"] && [[rpc_reply objectForKey:@"success"] isKindOfClass:[NSString class]]){
                success_str = [NSString stringWithString:[rpc_reply objectForKey:@"success"]];
            }else{
                success_str = @"success";
            }
            
            NSString *consumer_tag;
            
            if ([rpc_reply objectForKey:@"consumer_tag"] && [[rpc_reply objectForKey:@"consumer_tag"] isKindOfClass:[NSString class]]){
                
                consumer_tag = [NSString stringWithString:[rpc_reply objectForKey:@"consumer_tag"]];
            }else{
                consumer_tag = @"";
            }
            
            NSDictionary *success = [NSDictionary dictionaryWithObjectsAndKeys:
                                     success_str, @"success",
                                     consumer_tag, @"consumer_tag",
                                     nil];
            
            successCallback(@[success]);
            consumer_tag = nil;
            success_str = nil;
            
        }
        
        else if([rpc_reply objectForKey:@"error"]){
            
            NSMutableString *error_str = [NSMutableString stringWithString:@"Queue consume error: "];
            
            if ( [rpc_reply objectForKey:@"error"] && [[rpc_reply objectForKey:@"error"] isKindOfClass:[NSString class]]){
                
                [error_str appendString:[rpc_reply objectForKey:@"error"]];
            }
            
            if ([rpc_reply objectForKey:@"error_code"] && [[rpc_reply objectForKey:@"error_code"] isKindOfClass:[NSNumber class]]){
                
                [error_str appendString:[NSString stringWithFormat:@". Error code: %u.", [[rpc_reply objectForKey:@"error_code"] unsignedIntValue]]];
            }
            
            errorCallback(@[error_str]);
            error_str = nil;
        }
        
        rpc_reply = nil;
        funcParam = nil;
    }else{
        errorCallback(@[@"There is no queue with the specified name."]);
    }
 
}

// Метод завершает работу с потребителем очереди и отписывается от получения сообщений.
RCT_EXPORT_METHOD(basicCancel:(NSString *_Nullable)consummer_tag successCallback:(RCTResponseSenderBlock)successCallback errorCallback: (RCTResponseSenderBlock)errorCallback) {

    AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
    
    NSMutableDictionary *param = [[NSMutableDictionary alloc] init];
    
    [param setObject:[NSNumber numberWithUnsignedInt:1] forKey:@"channel"];
    
    if (consummer_tag != nil && [consummer_tag length] > 0){
        [param setObject:[NSString stringWithString:consummer_tag] forKey:@"consummer_tag"];
    }

    funcParam.parameters = [NSDictionary dictionaryWithDictionary:param];
    param = nil;
 
    NSDictionary *rpc_reply;
    
    rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"basicCancel:" andArgumets:funcParam];
    
    if([rpc_reply objectForKey:@"success"]){
        
        NSString *success_str;
        
        if ( [rpc_reply objectForKey:@"success"] && [[rpc_reply objectForKey:@"success"] isKindOfClass:[NSString class]]){
            success_str = [NSString stringWithString:[rpc_reply objectForKey:@"success"]];
        }else{
            success_str = @"success";
        }
        
        successCallback(@[success_str]);
        success_str = nil;
        
    }
    
    else if([rpc_reply objectForKey:@"error"]){
        
        NSMutableString *error_str = [NSMutableString stringWithString:@"Queue consume error: "];
        
        if ( [rpc_reply objectForKey:@"error"] && [[rpc_reply objectForKey:@"error"] isKindOfClass:[NSString class]]){
            
            [error_str appendString:[rpc_reply objectForKey:@"error"]];
        }
        
        if ([rpc_reply objectForKey:@"error_code"] && [[rpc_reply objectForKey:@"error_code"] isKindOfClass:[NSNumber class]]){
            
            [error_str appendString:[NSString stringWithFormat:@". Error code: %u.", [[rpc_reply objectForKey:@"error_code"] unsignedIntValue]]];
        }
        
        errorCallback(@[error_str]);
        error_str = nil;
    }
    
    rpc_reply = nil;
    funcParam = nil;
}

// Метод отправляет запрос на сервер о повторной доставке всех неподтвержденных сообщений
// по указанному каналу.
RCT_EXPORT_METHOD(basicRecover:(BOOL) requeue){
    
    AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
    
    funcParam.parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithUnsignedInt:1], @"channel",
                            [NSNumber numberWithBool:requeue], @"requeue",
                            nil];
       
    NSDictionary *rpc_reply;
    
    rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"basicRecover:" andArgumets:funcParam];
    
      if([rpc_reply objectForKey:@"success"]){
          NSLog(@"Basic reject: %@", [rpc_reply objectForKey:@"success"]);
      }
    
    else if([rpc_reply objectForKey:@"error"]){
        NSLog(@"Basic reject error: %@", [rpc_reply objectForKey:@"error"]);
        NSLog(@"Error code %@", [rpc_reply objectForKey:@"error_code"]);
    }
    
    rpc_reply = nil;
    funcParam = nil;
}

// Метод обеспечивает прямой доступ к сообщениям в очереди с использованием синхронного диалога
// AMQP_BASIC_GET_EMPTY_METHOD - будет получен если в указанной очереди нет сообщений
// Если сообщения в очереди есть сервер вернет одно сообщение и количество оставшихся в очереди сообщений
RCT_EXPORT_METHOD(basicGet:(NSString *_Nonnull) queue_name consummerTag:(NSString *_Nullable)consummer_tag noAsk: (BOOL) no_ack){
    
    AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
    
    NSMutableDictionary *param = [[NSMutableDictionary alloc] init];
    
    [param setObject:[NSNumber numberWithUnsignedInt:1] forKey:@"channel"];
    [param setObject:[NSString stringWithString:queue_name] forKey:@"queue"];
    [param setObject:[NSNumber numberWithBool:no_ack] forKey:@"no_ack"];
    
    if (consummer_tag != nil && [consummer_tag length] > 0){
        [param setObject:[NSString stringWithString:consummer_tag] forKey:@"consummer_tag"];
    }

    funcParam.parameters = [NSDictionary dictionaryWithDictionary:param];
    param = nil;
       
    NSDictionary *rpc_reply;
    
    rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"basicGet:" andArgumets:funcParam];
    
      if([rpc_reply objectForKey:@"success"]){
          NSLog(@"Basic get: %@", [rpc_reply objectForKey:@"success"]);
          
          // AMQP_BASIC_GET_EMPTY_METHOD - будет получен если в указанной очереди нет сообщений
          // при этом, если есть кластер, сервер вернет cluster_id
          if ([rpc_reply objectForKey:@"cluster_id"]){
              NSLog(@"Cluster id: %@", [rpc_reply objectForKey:@"cluster_id"]);
          }
          
          // Если сообщения в очереди есть сервер вернет одно сообщение и количество оставшихся
          // в очереди сообщений
          if ([rpc_reply objectForKey:@"message"]){
              
              AmqpMessage *incoming_message = (AmqpMessage *) [rpc_reply objectForKey:@"message"];
              
              NSLog(@"Delivery tag: %llu\n", incoming_message.delivery_tag);
              NSLog(@"Redelivered: %u\n", incoming_message.redelivered);
              NSLog(@"Exchange: %@\n", incoming_message.exchange);
              NSLog(@"Routing key: %@\n", incoming_message.routing_key);
              
              // Количество не прочитанных сообщений
              NSLog(@"Message count: %u\n", incoming_message.message_count);
              
              NSLog(@"Incoming message: %@", [[NSString alloc] initWithData:incoming_message.body encoding:NSUTF8StringEncoding]);
              NSLog(@"%@",incoming_message.property);
              
              incoming_message = nil;
              
          }
      }
    
    else if([rpc_reply objectForKey:@"error"]){
        NSLog(@"Basic get error: %@", [rpc_reply objectForKey:@"error"]);
        NSLog(@"Error code %@", [rpc_reply objectForKey:@"error_code"]);
    }
    
    rpc_reply = nil;
    funcParam = nil;
}


// Метод позволяет клиенту отклонить сообщение.
RCT_EXPORT_METHOD(basicReject:(NSNumber *_Nonnull)delivery_tag requeue: (BOOL) requeue){
    
    AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
    
    funcParam.parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithUnsignedInt:1], @"channel",
                            [NSNumber numberWithUnsignedInt:[delivery_tag unsignedIntValue]], @"delivery_tag",
                            [NSNumber numberWithBool:requeue], @"requeue",
                            nil];
       
    NSDictionary *rpc_reply;
    
    rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"basicReject:" andArgumets:funcParam];
    
      if([rpc_reply objectForKey:@"success"]){
          NSLog(@"Basic reject: %@", [rpc_reply objectForKey:@"success"]);
      }
    
    else if([rpc_reply objectForKey:@"error"]){
        NSLog(@"Basic reject error: %@", [rpc_reply objectForKey:@"error"]);
        NSLog(@"Error code %@", [rpc_reply objectForKey:@"error_code"]);
    }
    
    rpc_reply = nil;
    funcParam = nil;
}

// Метод подтверждает одно или несколько сообщений, полученных с помощью методов BASIC_CONSUME или
// BASIC_GET.
RCT_EXPORT_METHOD(basicAck:(NSNumber *_Nonnull)delivery_tag multiple: (BOOL) multiple){
    
    AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
    
    funcParam.parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithUnsignedInt:1], @"channel",
                            [NSNumber numberWithUnsignedInt:[delivery_tag unsignedIntValue]], @"delivery_tag",
                            [NSNumber numberWithBool:multiple], @"multiple",
                            nil];
       
    NSDictionary *rpc_reply;
    
    rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"basicAck:" andArgumets:funcParam];
    
      if([rpc_reply objectForKey:@"success"]){
          NSLog(@"Basic ack: %@", [rpc_reply objectForKey:@"success"]);
      }
    
    else if([rpc_reply objectForKey:@"error"]){
        NSLog(@"Basic ack error: %@", [rpc_reply objectForKey:@"error"]);
        NSLog(@"Error code %@", [rpc_reply objectForKey:@"error_code"]);
    }
    
    rpc_reply = nil;
    funcParam = nil;
}

// Метод позволяет клиенту отклонять одно или несколько входящих сообщений. 
RCT_EXPORT_METHOD(basicNack:(NSNumber *_Nonnull)delivery_tag multiple: (BOOL) multiple requeue: (BOOL) requeue){
    
    AmqpRpcParameters *funcParam = [[AmqpRpcParameters alloc] init];
    
    funcParam.parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithUnsignedInt:1], @"channel",
                            [NSNumber numberWithUnsignedInt:[delivery_tag unsignedIntValue]], @"delivery_tag",
                            [NSNumber numberWithBool:multiple], @"multiple",
                            [NSNumber numberWithBool:requeue], @"requeue",
                            nil];
       
    NSDictionary *rpc_reply;
    
    rpc_reply =  [self.amqp_conn ScheduleTaskFromString:@"basicNack:" andArgumets:funcParam];
    
      if([rpc_reply objectForKey:@"success"]){
          NSLog(@"Basic nack: %@", [rpc_reply objectForKey:@"success"]);
      }
    
    else if([rpc_reply objectForKey:@"error"]){
        NSLog(@"Basic nack error: %@", [rpc_reply objectForKey:@"error"]);
        NSLog(@"Error code %@", [rpc_reply objectForKey:@"error_code"]);
    }
    
    rpc_reply = nil;
    funcParam = nil;
}


@end
