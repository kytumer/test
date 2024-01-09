package nl.kega.reactnativerabbitmq;

import android.util.Log;
import java.util.HashMap;
import java.util.Map;

import java.io.IOException;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.ReadableType;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.facebook.react.bridge.ReadableMapKeySetIterator;

import com.rabbitmq.client.Channel;
import com.rabbitmq.client.AMQP;
import com.rabbitmq.client.AlreadyClosedException;

public class RabbitMqQueue {

    public String name;
    public String routing_key;
    public String consumer_tag;
    public Boolean passive;
    public Boolean exclusive;
    public Boolean durable;
    public Boolean autodelete;
    public Boolean autoack;
	public Map<String, Object> args;
	public ReadableMap consumer_arguments;
       
    private ReactApplicationContext context;

    private Channel channel;
    private RabbitMqExchange exchange;

    public RabbitMqQueue (ReactApplicationContext context, Channel channel, ReadableMap queue_config, ReadableMap arguments){
       
        this.context = context;
        this.channel = channel;

        this.name = queue_config.getString("name");
		this.passive = (queue_config.hasKey("passive") ? queue_config.getBoolean("passive") : false);
        this.exclusive = (queue_config.hasKey("exclusive") ? queue_config.getBoolean("exclusive") : false);
        this.durable = (queue_config.hasKey("durable") ? queue_config.getBoolean("durable") : true);
        this.autodelete = (queue_config.hasKey("autoDelete") ? queue_config.getBoolean("autoDelete") : false);

        this.consumer_arguments = (queue_config.hasKey("consumer_arguments") ? queue_config.getMap("consumer_arguments") : null);
		
		this.args = toHashMap(arguments);
    }
	
	
    public AMQP.Queue.DeclareOk queueDeclare(){

        AMQP.Queue.DeclareOk declareOk = null;

        try {
			if (!this.passive){
	            declareOk = this.channel.queueDeclare(this.name, this.durable, this.exclusive, this.autodelete, this.args);			
			}else{
				declareOk = this.channel.queueDeclarePassive(this.name);
			}
			
			if (declareOk != null){
				return declareOk;
			}

        } catch (IOException e){
            Log.e("RabbitMqQueue", "Queue error " + e);
            e.printStackTrace();
        }
        return null;
    }
	
	
    public String basicConsume(ReadableMap parameters, ReadableMap arguments){

        Map<String, Object> healthArgs = null;

        boolean no_local = (parameters.hasKey("no_local") ? parameters.getBoolean("no_local") : false);
        boolean no_ack = (parameters.hasKey("no_ack") ? parameters.getBoolean("no_ack") : false);
        boolean exclusive = (parameters.hasKey("exclusive") ? parameters.getBoolean("exclusive") : false);
        String consum_tag = "";
        String consumer_tag = "";

        if (parameters.hasKey("consummer_tag")){
            consum_tag = parameters.getString("consummer_tag");
        }

        if (arguments != null){
            healthArgs = new HashMap<>();

            ReadableMapKeySetIterator iterator = arguments.keySetIterator();
            while (iterator.hasNextKey()) {
                String nextKey = iterator.nextKey();
                healthArgs.put(nextKey, arguments.getString(nextKey));
            }
        }

        try {

          RabbitMqConsumer consumer = new RabbitMqConsumer(this.channel, this);
          consumer_tag = this.channel.basicConsume(this.name, no_ack, consum_tag, no_local, exclusive, healthArgs, consumer);

        } catch (IOException e){
            Log.e("RabbitMqQueue", "Queue error " + e);
            e.printStackTrace();
        }
      return consumer_tag;
    }
	
    public void onMessage(WritableMap message){
        Log.e("RabbitMqQueue", message.getString("message"));

        message.putString("queue_name", this.name);

        this.context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit("RabbitMqQueueEvent", message);
    }

    public void bind(String exchange_name, String routing_key, ReadableMap arguments){
        try {
            this.routing_key = (routing_key == "" ? this.name : routing_key);
            Map<String, Object> healthArgs = null;

            if (arguments != null){
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
                healthArgs = new HashMap<>();

                ReadableMapKeySetIterator iterator = arguments.keySetIterator();
                while (iterator.hasNextKey()) {
                    String nextKey = iterator.nextKey();
                    healthArgs.put(nextKey, arguments.getString(nextKey));
                }
            }
            if ( healthArgs != null && !(healthArgs.isEmpty()) ){
                this.channel.queueBind(this.name, exchange_name, this.routing_key, healthArgs);
            }else{
                this.channel.queueBind(this.name, exchange_name, this.routing_key);
            }
        } catch (Exception e){
            Log.e("RabbitMqQueue", "Queue bind error " + e);
            e.printStackTrace();
        }
    }
	
    public void unbind(String exchange_name, String routing_key, ReadableMap arguments){
        try {
  
            if (!this.exchange.equals(null)){
                this.channel.queueUnbind(this.name, this.exchange.name, routing_key);
                this.exchange = null;
            }
            
        } catch (Exception e){
            Log.e("RabbitMqQueue", "Queue unbind error " + e);
            e.printStackTrace();
        }

        try {
            this.exchange = exchange;
            this.routing_key = (routing_key == "" ? this.name : routing_key);
            Map<String, Object> healthArgs = null;

            if (arguments != null){
                healthArgs = new HashMap<>();

                ReadableMapKeySetIterator iterator = arguments.keySetIterator();
                while (iterator.hasNextKey()) {
                    String nextKey = iterator.nextKey();
                    healthArgs.put(nextKey, arguments.getString(nextKey));
                }
            }
            if ( healthArgs != null && !(healthArgs.isEmpty()) ){
                this.channel.queueUnbind(this.name, exchange_name, this.routing_key, healthArgs);
            }else{
                this.channel.queueUnbind(this.name, this.exchange.name, routing_key);
            }
        } catch (Exception e){
            Log.e("RabbitMqQueue", "Queue unbind error " + e);
            e.printStackTrace();
        }
    }



    public void purge(){ 
        try {
            //this.channel.queuePurge(this.name, true); 
            
            WritableMap event = Arguments.createMap();
            event.putString("name", "purged");
            event.putString("queue_name", this.name);

            this.context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit("RabbitMqQueueEvent", event);
        } catch (Exception e){
            Log.e("RabbitMqQueue", "Queue purge error " + e);
            e.printStackTrace();
        }
    } 

    public void delete(){ 
        try {
            this.channel.queueDelete(this.name); 
            
            WritableMap event = Arguments.createMap();
            event.putString("name", "deleted");
            event.putString("queue_name", this.name);

            this.context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit("RabbitMqQueueEvent", event);
        } catch (Exception e){
            Log.e("RabbitMqQueue", "Queue delete error " + e);
            e.printStackTrace();
        }
    } 


    private Map<String, Object> toHashMap(ReadableMap data){

        Map<String, Object> args = new HashMap<String, Object>();

        if (data == null){
            return args;
        }

        ReadableMapKeySetIterator iterator = data.keySetIterator();

        while (iterator.hasNextKey()) {
            String key = iterator.nextKey();

            ReadableType readableType = data.getType(key);

            switch (readableType) {
                case Null:
                    args.put(key, key);
                    break;
                case Boolean:
                    args.put(key, data.getBoolean(key));
                    break;
                case Number:
                    // Can be int or double.
                    double tmp = data.getDouble(key);
                    if (tmp == (int) tmp) {
                        args.put(key, (int) tmp);
                    } else {
                        args.put(key, tmp);
                    }
                    break;
                case String:
                    Log.e("RabbitMqQueue", data.getString(key));
                    args.put(key, data.getString(key));
                    break;

            }
        }

        return args;
    }



}
