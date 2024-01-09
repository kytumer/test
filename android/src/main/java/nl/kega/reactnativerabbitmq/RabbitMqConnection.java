package nl.kega.reactnativerabbitmq;

import android.util.Log;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Objects;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeoutException;

import com.facebook.react.modules.core.DeviceEventManagerModule;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.GuardedAsyncTask;

import com.rabbitmq.client.ConnectionFactory;
import com.rabbitmq.client.Connection;
import com.rabbitmq.client.Channel;
import com.rabbitmq.client.Consumer;
import com.rabbitmq.client.ShutdownListener;
import com.rabbitmq.client.ShutdownSignalException;
import com.rabbitmq.client.RecoveryListener;
//import com.rabbitmq.client.Recoverable;
//import com.rabbitmq.client.RecoverableConnection;
import com.rabbitmq.client.ConfirmListener;
import com.rabbitmq.client.AMQP;

class RabbitMqConnection extends ReactContextBaseJavaModule  {

    private ReactApplicationContext context;

    public ReadableMap config;

    private ConnectionFactory factory = null;
	private Connection connection;
    private Channel channel;

    private Callback status;

    private String connectionName = null;

    private ArrayList<RabbitMqQueue> queues = new ArrayList<RabbitMqQueue>();
    private ArrayList<RabbitMqExchange> exchanges = new ArrayList<RabbitMqExchange>();

    public RabbitMqConnection(ReactApplicationContext reactContext) {
        super(reactContext);

        this.context = reactContext;

    }

    @Override
    public String getName() {
        return "RabbitMqConnection";
    }

    @ReactMethod
    public void initialize(ReadableMap config) {
        this.config = config;

        this.factory = new ConnectionFactory();

        if (this.config.hasKey("host")){
            this.factory.setHost(this.config.getString("host"));
        }

        if (this.config.hasKey("port")){
            this.factory.setPort(this.config.getInt("port"));
        }

        if (this.config.hasKey("userName")){
            this.factory.setUsername(this.config.getString("userName"));
        }

        if (this.config.hasKey("password")){
            this.factory.setPassword(this.config.getString("password"));
        }

        if (this.config.hasKey("virtualHost")){
            this.factory.setVirtualHost(this.config.getString("virtualHost"));
        }



         if (this.config.hasKey("heartBeatTimeOut")){
             this.factory.setRequestedHeartbeat(this.config.getInt("heartBeatTimeOut"));
        }

        if (this.config.hasKey("connectTimeOut")){
            this.factory.setConnectionTimeout(this.config.getInt("connectTimeOut"));
        }


        try {
            if (this.config.hasKey("useSSL") && this.config.getBoolean("useSSL")) {
                this.factory.useSslProtocol();
            }
        } catch(Exception e) {
            Log.e("RabbitMqConnection", e.toString());
        }

    }

    @ReactMethod
    public void status(Callback onStatus) {
        this.status = onStatus;
    }

    @ReactMethod
    public void connect() {

        if (this.connection != null && this.connection.isOpen()){
            WritableMap event = Arguments.createMap();
            event.putString("name", "connected");

            this.context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit("RabbitMqConnectionEvent", event);
        }else{

            try {

                if (this.config.hasKey("connectionName")){
                    this.connection = this.factory.newConnection(this.config.getString("connectionName"));
                }else{
                    this.connection = this.factory.newConnection();
                }

            } catch (Exception e){

                WritableMap event = Arguments.createMap();
                event.putString("name", "error");
                event.putString("type", "failedtoconnect");
                event.putString("code", "");
                event.putString("description", e.getMessage());

                this.context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit("RabbitMqConnectionEvent", event);

                this.connection = null;

            }
        }

        if (this.connection != null){

            try {

                this.connection.addShutdownListener(new ShutdownListener() {
                    @Override
                    public void shutdownCompleted(ShutdownSignalException cause) {
                        onClose(cause);
                    }
                });

                WritableMap event = Arguments.createMap();
                event.putString("name", "connected");

                this.context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit("RabbitMqConnectionEvent", event);

            } catch (Exception e){

                Log.e("RabbitMqConnectionChannel", "Create channel error " + e);
                e.printStackTrace();

            }
        }
    }
	
    @ReactMethod
    public void createChannel(Callback successCallback, Callback errorCallback) {
		
		if (this.connection != null){
			
			try { 
			// Создаём канал
            this.channel = this.connection.createChannel();
			// Устанавливаем параметры предварительной выборки (качества обслуживания) для этого канала.
			// Параметры:
			//    prefetchCount (максимальное количество) - максимальное количество сообщений, которые будет доставлять сервер .
			//                                              Принимает значения от 0 до 65535 (AMQP 0-9-1). Если 0, количество 
			//                                              сообщений не ограничено не ограничено.
			//                                              Значение по умолчанию: 0
			// В случае ошибки вернет throws IOException. 
			// Функция имеет перегрузку: void basicQos(int prefetchSize, int prefetchCount, boolean global) throws IOException;
			// Параметры:
			//    prefetchSize (предварительная выборка) -  максимальный объем контента, который будет доставлять сервер (в октетах), 
			//                                              Принимает значения от 0 до 65535 (AMQP 0-9-1).					
			//                                              Если 0, объём  контента не ограничен
            //                                              Значение по умолчанию: 0					
			//    prefetchCount (максимальное количество).
			//    global - true, если настройки должны применяться ко всему каналу, а не к каждому потребителю
            //                                              Значение по умолчанию: true					
            this.channel.basicQos(1);
			
			// Создаём слушателя для сигналов завершения работы канала
			// Если канал будет закрыт, обработчик будет запущен немедленно!
			this.channel.addShutdownListener(new ShutdownListener() {
            @Override
            public void shutdownCompleted(ShutdownSignalException cause) {
                onChannelClose();
                }
            });

            this.channel.addConfirmListener(new ConfirmListener() {

                public void handleNack(long deliveryTag, boolean multiple) throws IOException {
                Log.e("RabbitMqQueue", "Not ack received");
                }

                public void handleAck(long deliveryTag, boolean multiple) throws IOException {
                Log.e("RabbitMqQueue", "Ack received");
                }
            });		
			
			successCallback.invoke("Create channel Ok");
		  
		} catch (IOException error){		
			errorCallback.invoke(error);	
        }	
		}else{
			errorCallback.invoke("The connection does not exist.");
		}
    }

    @ReactMethod
    public void closeChannel(Callback successCallback, Callback errorCallback) {

        if (this.connection != null && this.channel.isOpen()) {

            try {

                this.channel.clearConfirmListeners();
                this.channel.close(200, "success");

                successCallback.invoke("Channel close: ok");

            } catch (IOException | TimeoutException error) {
                errorCallback.invoke(error);
            }
        }

    }

    @ReactMethod
    public void isChannelOpen(Callback successCallback, Callback errorCallback) {
		
		if (this.channel.isOpen()){
			successCallback.invoke(1);
		}else{
			errorCallback.invoke(0);		
		}			
    }
	
	    @ReactMethod
    public void getChannelCloseReason(Callback successCallback) {
		successCallback.invoke(this.channel.getCloseReason().toString());	
    }
	

    @ReactMethod
    public void addQueue(ReadableMap queue_config, ReadableMap arguments) {
        RabbitMqQueue queue = new RabbitMqQueue(this.context, this.channel, queue_config, arguments);
        this.queues.add(queue);
    }
	
    @ReactMethod
    public void declareQueue(String queue_name, Callback successCallback, Callback errorCallback) {
		
		AMQP.Queue.DeclareOk declareOk = null;
		
        RabbitMqQueue found_queue = null;
        for (RabbitMqQueue queue : queues) {
            if (Objects.equals(queue_name, queue.name)){
                found_queue = queue;
            }
        }

        if (!found_queue.equals(null) ){

            try {
					declareOk = found_queue.queueDeclare();

                if (declareOk != null){

				    WritableMap queueInf = Arguments.createMap();
					queueInf.putString("queueName", declareOk.getQueue());
                    queueInf.putInt("messageCount", declareOk.getMessageCount());
				    queueInf.putInt("consumerCount", declareOk.getConsumerCount());

                    successCallback.invoke(queueInf);
				}else{
					errorCallback.invoke("Queue not declared");
				}

            } catch (Exception e){
                // e.printStackTrace();
                errorCallback.invoke(e.getMessage());
            }

        }
    }

    @ReactMethod
    public void bindQueue(String exchange_name, String queue_name, String routing_key, ReadableMap arguments) {

        RabbitMqQueue found_queue = null;
        for (RabbitMqQueue queue : queues) {
            if (Objects.equals(queue_name, queue.name)){
                found_queue = queue;
            }
        }

        if (!found_queue.equals(null)){
            found_queue.bind(exchange_name, routing_key, arguments);
        }
    }

    @ReactMethod
    public void unbindQueue(String exchange_name, String queue_name, String routing_key, ReadableMap arguments) {

        RabbitMqQueue found_queue = null;
        for (RabbitMqQueue queue : queues) {
            if (Objects.equals(queue_name, queue.name)){
                found_queue = queue;
            }
        }

        if (!found_queue.equals(null)){
            found_queue.unbind(exchange_name, routing_key, arguments);
        }
    }

    @ReactMethod
    public void basicConsume(String queue_name, ReadableMap parameters, ReadableMap arguments, Callback successCallback,Callback errorCallback) {

        String consumer_tag = "";
        WritableMap consumerSuccess = Arguments.createMap();

        RabbitMqQueue found_queue = null;
        for (RabbitMqQueue queue : queues) {
            if (Objects.equals(queue_name, queue.name)){
                found_queue = queue;
            }
        }

        if (!found_queue.equals(null) ){

            try {

                consumer_tag = found_queue.basicConsume(parameters, arguments);

                if (consumer_tag.length() != 0){
                    consumerSuccess.putString("success", "basicConsume Ok");
                    consumerSuccess.putString("consumer_tag", consumer_tag);
                }

                successCallback.invoke(consumerSuccess);

            } catch (Exception e){
                errorCallback.invoke(e.getMessage());
            }
        }
    }

    @ReactMethod
    public void removeQueue(String queue_name) {
        RabbitMqQueue found_queue = null;
        for (RabbitMqQueue queue : queues) {
            if (Objects.equals(queue_name, queue.name)){
                found_queue = queue;
            }
        }

        if (!found_queue.equals(null)){
            found_queue.delete();
        }
    }

    @ReactMethod
    public void basicAck(Double delivery_tag, boolean multiple) {

        long long_delivery_tag = Double.valueOf(delivery_tag).longValue();

        try {
            this.channel.basicAck(long_delivery_tag, multiple);
        } catch (IOException e){
            Log.e("RabbitMqQueue", "basicAck " + e);
            e.printStackTrace();
        }
    }

    @ReactMethod
    public void basicNack(Double delivery_tag, boolean multiple, boolean requeue) {

        long long_delivery_tag = Double.valueOf(delivery_tag).longValue();

        try {
            this.channel.basicNack(long_delivery_tag, multiple, requeue);
        } catch (IOException e){
            Log.e("RabbitMqQueue", "basicNack " + e);
            e.printStackTrace();
        }
    }

    @ReactMethod
    public void basicPublish(String message, String exchange_name, String routing_key, boolean mandatory, ReadableMap message_properties) {

        for (RabbitMqExchange exchange : exchanges) {
            if (Objects.equals(exchange_name, exchange.name)){
                Log.e("RabbitMqConnection", "Exchange publish: " + message);
                exchange.publish(message, routing_key, mandatory, message_properties);
                return;
            }
        }

    }


    @ReactMethod
    public void declareExchange(String exchange_name) {

        for (RabbitMqExchange exchange : exchanges) {
            if (Objects.equals(exchange_name, exchange.name)){
                exchange.exchangeDeclare();
                return;
            }
        }
    }

    @ReactMethod
    public void declareExchangePassive(String exchange_name) {

        for (RabbitMqExchange exchange : exchanges) {
            if (Objects.equals(exchange_name, exchange.name)){
                exchange.exchangeDeclarePassive();
                return;
            }
        }
    }

    @ReactMethod
    public void addExchange(ReadableMap exchange_config) {

        RabbitMqExchange exchange = new RabbitMqExchange(this.context, this.channel, exchange_config);
        this.exchanges.add(exchange);
    }

    @ReactMethod
    public void deleteExchange(String exchange_name, Boolean if_unused) {

        for (RabbitMqExchange exchange : exchanges) {
            if (Objects.equals(exchange_name, exchange.name)){
                exchange.delete(if_unused);
                return;
            }
        }

    }

    @ReactMethod
    public void close() {
        try {
			
			this.queues.clear();
			this.exchanges.clear();

     //       this.queues = new ArrayList<RabbitMqQueue>();
      //      this.exchanges = new ArrayList<RabbitMqExchange>();

            this.channel.close();
            this.connection.close();
			
        } catch (Exception e){
            Log.e("RabbitMqConnection", "Connection closing error " + e);
            e.printStackTrace();
        } finally {
            this.connection = null;
            this.factory = null;
            this.channel = null;
        }
    }

    private void onClose(ShutdownSignalException cause) {

		WritableMap event = Arguments.createMap();
		event.putString("name", "Closed");
		event.putString("type", "failedtoconnect");
		event.putString("description", cause.getReason().toString());

        this.context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit("RabbitMqConnectionEvent", event);
    }

    private void onRecovered() {
        Log.e("RabbitMqConnection", "Recovered");

        WritableMap event = Arguments.createMap();
        event.putString("name", "reconnected");

        this.context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit("RabbitMqConnectionEvent", event);
    }

    private void onChannelClose() {

        
		WritableMap event = Arguments.createMap();
		event.putString("name", "channelСlosed");
		event.putString("type", "failedchannel");
		event.putString("description",  this.channel.getCloseReason().toString());
			   
        this.context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit("RabbitMqConnectionEvent", event);
    }
      
    @Override
    public void onCatalystInstanceDestroy() {

        // serialize on the AsyncTask thread, and block
        try {
            new GuardedAsyncTask<Void, Void>(getReactApplicationContext()) {
                @Override
                protected void doInBackgroundGuarded(Void... params) {
                    close();
                }
            }.execute().get();
        } catch (InterruptedException ioe) {
            Log.e("RabbitMqConnection", "onCatalystInstanceDestroy", ioe);
        } catch (ExecutionException ee) {
            Log.e("RabbitMqConnection", "onCatalystInstanceDestroy", ee);
        }
    }

}
