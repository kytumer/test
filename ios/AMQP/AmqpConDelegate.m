//
//  AMQPConDelegate.m
//  AMQ
//
//  Created by Mac on 24.05.2023.
//

#import "AmqpConDelegate.h"

typedef enum _message_metod{
    RETURN  = 0x003C0032,
    DELIVER = 0x003C003C,
}message_metod;

@implementation AmqpConDelegate

- (void) errorWhenAMQPConnection: (AMQPConnectoin *) connection faildWithErrorCode: (unsigned int) errorCode errorString: (NSString *) errorString{
    
    [self sendString:[NSString stringWithFormat:@" RabbitMQ server connection error %uh, message: %@\n", errorCode, errorString]];
    
}

- (void) libraryErrorWhenAMQPConnection: (AMQPConnectoin *) connection faildWithErrorCode: (unsigned int) errorCode errorString: (NSString *) errorString{
    
    [self sendString:[NSString stringWithFormat:@" AMQP library error %uh, message: %@\n", errorCode, errorString]];
    
}

- (void) channelErrorWhenAMQPConnection: (AMQPConnectoin *) connection channel: (unsigned int) channelNum faildWithErrorCode: (unsigned int) errorCode errorString: (NSString *) errorString{
    
    [self sendString:[NSString stringWithFormat:@"Channel nuber %u error code: %u, message: %@\n", channelNum, errorCode, errorString]];
}

- (void) receivedFromAMQPConnection: (AMQPConnectoin *) connection message: (AmqpMessage *) incoming_message{

    [EventEmitter emitEventWithName:@"RabbitMqQueueEvent" body:[self parsingMessage:incoming_message withMetod:DELIVER]];
}
- (void) returnFromAMQPConnection: (AMQPConnectoin *) connection message: (AmqpMessage *) return_message{
    
    [EventEmitter emitEventWithName:@"RabbitMqQueueEvent" body:[self parsingMessage:return_message withMetod:RETURN]];
}


-(void)sendString: (NSString *) message{

    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"This string in main thread: %@", message);
    });
    
}

-(NSDictionary *) parsingMessage: (AmqpMessage *) message withMetod: (message_metod) metod{
    
    NSMutableDictionary *disassembled_message = [[NSMutableDictionary alloc] init];
    
    NSString *message_body = [[NSString alloc] initWithData:message.body encoding:NSUTF8StringEncoding];
    
    [disassembled_message setObject:@"message" forKey:@"name"];
    [disassembled_message setObject:message_body forKey:@"message"];
    
    if (metod == RETURN){
        [disassembled_message setObject:[NSNumber numberWithUnsignedInt:message.reply_code] forKey:@"reply_code"];
        if (message.reply_text != nil){
            [disassembled_message setObject:message.reply_text forKey:@"reply_text"];
        }
    }
    
    if (metod == DELIVER){
        
        if (message.consumer_tag != nil){
            [disassembled_message setObject:message.consumer_tag forKey:@"consumer_tag"];
        }
        [disassembled_message setObject:[NSNumber numberWithUnsignedLong:message.delivery_tag] forKey:@"delivery_tag"];
        [disassembled_message setObject:[NSNumber numberWithBool:message.redelivered] forKey:@"redelivered"];
    }
    
    if (message.exchange != nil){
        [disassembled_message setObject:message.exchange forKey:@"exchange"];
    }
    
    if (message.routing_key != nil){
        [disassembled_message setObject:message.routing_key forKey:@"routing_key"];
    }
    
    
    if (message.property != nil){
        
        // Свойство декларирует тип контента сообщения.
        // Фотмат: текстовый UTF8 (например: "text/plain" или charset="utf-8" или "application/json").
        if ([message.property objectForKey:@"content_type"]){
            
            [disassembled_message setObject:[NSString stringWithString:[message.property objectForKey:@"content_type"]] forKey:@"content_type"];
        }
        
        // Свойство декларирует формат кодировки содержимого если сообщение закодировано.
        // Фотмат: текстовый UTF8 (например: "gzip").
        if ([message.property objectForKey:@"content_encoding"] ){
            
            [disassembled_message setObject:[NSString stringWithString:[message.property objectForKey:@"content_encoding"]] forKey:@"content_encoding"];
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
        if ([message.property objectForKey:@"headers"]){
            
            if([[message.property objectForKey:@"headers"] count] >0){
                [disassembled_message setObject:[NSDictionary dictionaryWithDictionary:[message.property objectForKey:@"headers"]] forKey:@"headers"];
            }
        }
        
        // Свойство декларирует способ доставки сообщения - следует ли сохранить сообщение на диске
        // Фотмат: unsigned int
        // 1 - не сохранять на диске; 2 - сохранить.
        if ([message.property objectForKey:@"delivery_mode"]){
        
            [disassembled_message setObject:[NSNumber numberWithUnsignedInt: [[message.property objectForKey:@"delivery_mode"] unsignedIntValue] ] forKey:@"delivery_mode"];
        }

        
        // Свойство декларирует приоритет сообщения.
        // Фотмат: unsigned int
        // Значение 0 до 9.
        if ([message.property objectForKey:@"priority"] && [[message.property objectForKey:@"priority"] isKindOfClass:[NSNumber class]]){
            
            [disassembled_message setObject:[NSNumber numberWithUnsignedInt: [[message.property objectForKey:@"priority"] unsignedIntValue]] forKey:@"priority"];
        }
        
        // Свойство декларирует идентификатор корреляции сообщения - например, на какой запрос это
        // сообщение является ответом.
        // Фотмат: текстовый UTF8.
        if ([message.property objectForKey:@"correlation_id"]){
            
            [disassembled_message setObject:[NSString stringWithString:[message.property objectForKey:@"correlation_id"]] forKey:@"correlation_id"];
        }
        
        // Свойство декларирует имя очереди в которой другие приложения должны размещать ответ.
        // Фотмат: текстовый UTF8.
        
        if ([message.property objectForKey:@"reply_to"]){
            
            [disassembled_message setObject:[NSString stringWithString:[message.property objectForKey:@"reply_to"]] forKey:@"reply_to"];
        }
        
        // Свойство декларирует время, по истечении которого сообщение будет удалено.
        // Фотмат: текстовый UTF8 !!!! Именно ТЕКСТОВЫЙ! Т.е. должно быть написано, например:
        // expiration : "10000" , что означает период TTL == 10 секунд и тд.
        // Значение поля описывает период TTL в миллисекундах.
        if ([message.property objectForKey:@"expiration"]){
            
            [disassembled_message setObject:[NSString stringWithString:[message.property objectForKey:@"expiration"]] forKey:@"expiration"];
        }
        
        // Свойство декларирует идентификатор сообщения в виде строки.
        // Фотмат: текстовый UTF8.
        if ([message.property objectForKey:@"message_id"]){
            
            [disassembled_message setObject:[NSString stringWithString:[message.property objectForKey:@"message_id"]] forKey:@"message_id"];
        }

        // Свойство декларирует метку времени UNIX момента отправки сообщения.
        // Фотмат: unsigned word
        if ([message.property objectForKey:@"timestamp"]){
            
            // От использования UNIX timestamp пришлось отказаться т.к.
            // в преобразование типа long в doble это сужающее преобразование
            // и при этом теряются 3 последних разряда, а в язаке JAVA в классе WritableMap
            // нет метода putLong.
            // Поэтому было принято решение преобразовать timestamp в строку содержащую дату,
            // а затем, в коде JavaScript, по мере необходимости, преобразовать её обратно в timestamp.
            
            NSDateFormatter *dateFormater = [[NSDateFormatter alloc] init];
            [dateFormater setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            
            NSDate *date_from_timestamp = [NSDate dateWithTimeIntervalSince1970: [[message.property objectForKey:@"timestamp"] unsignedLongValue]];
            
            [disassembled_message setObject:[NSString stringWithString:[dateFormater stringFromDate: date_from_timestamp]] forKey:@"timestamp"];
        }else{
            [disassembled_message setObject:@"no data available" forKey:@"timestamp"];
        }

        
        // Свойство декларирует тип сообщения, например, какой тип события или команды представляет это
        // сообщение.
        // Фотмат: текстовый UTF8.
        if ([message.property objectForKey:@"type"]){
            
            [disassembled_message setObject:[NSString stringWithString:[message.property objectForKey:@"type"]] forKey:@"type"];
        }
        
        // Свойство декларирует идентификатор пользователя отправляющего сообщение.
        // Указанный id должен в точности совпадать с данными пользователя указанными при
        // аутентификации, иначе сервер вернет ошибку 406 PRECONDITION_FAILED.
        // Фотмат: текстовый UTF8.
        if ([message.property objectForKey:@"user_id"]){
            
            [disassembled_message setObject:[NSString stringWithString:[message.property objectForKey:@"user_id"]] forKey:@"user_id"];
        }
        
        // Свойство декларирует идентификатор приложения, создавшего сообщение.
        // Фотмат: текстовый UTF8.
        if ([message.property objectForKey:@"app_id"]){
            
            [disassembled_message setObject:[NSString stringWithString:[message.property objectForKey:@"app_id"]] forKey:@"app_id"];
        }
        
        // Свойство декларирует идентификатор маршрутизации внутри кластера для использования
        // кластерными приложениями и не должен использоваться клиентскими приложениями.
        // Устарел в AMQP 0.9.1 - т. е. не используется.
        // Фотмат: текстовый UTF8.
        if ([message.property objectForKey:@"cluster_id"]){
            
            [disassembled_message setObject:[NSString stringWithString:[message.property objectForKey:@"cluster_id"]] forKey:@"cluster_id"];
        }
    }

    return [NSDictionary dictionaryWithDictionary:disassembled_message];
}

@end

