package nl.kega.reactnativerabbitmq;

import android.util.Log;

import java.io.IOException;

import java.util.Date;
import java.text.SimpleDateFormat;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;

import com.rabbitmq.client.Channel;
import com.rabbitmq.client.DefaultConsumer;
import com.rabbitmq.client.Envelope;
import com.rabbitmq.client.AMQP;


public class RabbitMqConsumer extends DefaultConsumer {

    private RabbitMqQueue connection;
    private Channel channel;
    
    public RabbitMqConsumer(Channel channel, RabbitMqQueue connection){
        super(channel);

        this.channel = channel;
        this.connection = connection;
    }

    @Override
    public void handleDelivery(String consumerTag, Envelope envelope, AMQP.BasicProperties properties, byte[] body) throws IOException{
          
	   // String routing_key = envelope.getRoutingKey();
       // String exchange = envelope.getExchange();
        String content_type = properties.getContentType();
		String reply_to = properties.getReplyTo();
		String correlation_id = properties.getCorrelationId();

        Boolean is_redeliver = envelope.isRedeliver(); // флаг повторной доставки
		
		// Метка времени 
		StringBuilder sb = new StringBuilder();
        SimpleDateFormat data_format = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        Date date = new Date();
		
		//long time_stamp = 0; // От использования time stamp UNIX пришлось отказаться т.к 
		                       // Преобразование типа long в doble это сужающее преобразование
							   // и при этом теряются 3 последних разряда, а у WritableMap нет метода putLong
							   // Поэтому будем отправлять строку, а затем в коде JavaScript преобразовывать ей в time_stamp UNIX
				
		date = properties.getTimestamp();
		if (date != null){
		   sb.append(data_format.format(date)); // форматированный вариант не удобен, если есть необходимость в сравнении даты
		}else{
			sb.append("no data available");
		}
		
		

        String message = new String(body, "UTF-8");

        WritableMap message_params = Arguments.createMap();
        message_params.putString("name", "message");
        message_params.putString("consumer_tag", consumerTag);
        message_params.putString("message", message);
        message_params.putString("content_type", content_type);
		message_params.putString("reply_to", reply_to);
		message_params.putString("correlation_id", correlation_id);
		message_params.putString("time_stamp", sb.toString());
		
        message_params.putDouble("delivery_tag", envelope.getDeliveryTag());
        message_params.putBoolean("is_redeliver", is_redeliver);
		
		
		
		
		// message_params.putString("routing_key", routing_key);
        // message_params.putString("exchange", exchange);

        this.connection.onMessage(message_params);
    }



}