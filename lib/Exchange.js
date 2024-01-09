import { DeviceEventEmitter } from 'react-native';

export class Exchange {

    constructor(connection, exchange_config) {

        this.callbacks = {};
        this.rabbitmqconnection = connection.rabbitmqconnection;

        this.name = exchange_config.name;
        this.exchange_config = exchange_config;

        this.rabbitmqconnection.addExchange(exchange_config);
    }

    on(event, callback){
        this.callbacks[event] = callback;
    }

    removeon(event){
        delete this.callbacks[event];
    }
	
    exchangeDeclare(){
        this.rabbitmqconnection.declareExchange(this.name);
    }
	
    exchangeDeclarePassive(){
        this.rabbitmqconnection.declareExchangePassive(this.name);
    }	

    publish(message, routing_key = '', mandatory, properties = {}){
        this.rabbitmqconnection.basicPublish(message, this.name, routing_key, mandatory, properties);
    }

    delete(){
        this.rabbitmqconnection.deleteExchange(this.name);
    }

}

export default Exchange;
