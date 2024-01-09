import {NativeModules, NativeEventEmitter} from 'react-native';

const { EventEmitter } = NativeModules;


const RabbitMqConnection = NativeModules.RabbitMqConnection;


export class Connection {
    
   // constructor(config) {
	constructor() {   
        this.rabbitmqconnection = RabbitMqConnection;
		
		// Создаём объект callbacks
        this.callbacks = {};
        
        this.connected = false;
        const RabbitMqEmitter = new NativeEventEmitter(EventEmitter);
  
        this.subscription = RabbitMqEmitter.addListener('RabbitMqConnectionEvent', this.handleEvent);

       // this.rabbitmqconnection.initialize(config);
    }
    

    // Метод cоздаёт новый канал, используя внутренний выделенный номер канала. 
    createChannel(getsuccessCallback, geterrorCallback){
		this.rabbitmqconnection.createChannel(getsuccessCallback, geterrorCallback);	
	}

    // Метод cоздаёт новый канал, используя внутренний выделенный номер канала. 
    closeChannel(getsuccessCallback, geterrorCallback){
        this.rabbitmqconnection.closeChannel(getsuccessCallback, geterrorCallback);	
    }
	
	
	// Метод осуществляет проверку открыт ли в данный момент канал, и возвращает 
	// Success (1) если канал открыт, Exception error message - если канал закрыт
	isChannelOpen(getsuccessCallback, geterrorCallback){
        this.rabbitmqconnection.isChannelOpen(getsuccessCallback, geterrorCallback);		
    }

	sendHeard(getsuccessCallback){
        this.rabbitmqconnection.sendHard(getsuccessCallback);		
    }
	
	// Метод позволяет получить объект причины завершения работы канала
    // Метод возвращает объект типа ShutdownSignalException	
	getChannelCloseReason(getsuccessCallback){
		this.rabbitmqconnection.getChannelCloseReason(getsuccessCallback);
	}

	
	initializeConnection(config) {
        this.rabbitmqconnection.initialize(config);
    } 
	
    connect() {
        this.rabbitmqconnection.connect();
    }    
    
    close() {
        this.rabbitmqconnection.close();
    }

    clear() {
        this.subscription.remove();
    }

    handleEvent = (event) => {

        if (event.name == 'connected'){ this.connected = true; }
		
        if (event.name == 'closed'){ this.connected = false; }
		
		// Проверяем, содержит ли объект callbacks свойство с именем указанным в event
        if (this.callbacks.hasOwnProperty(event.name)){
			// Если содержит, то выполнием callback с указаным свойством
            this.callbacks[event.name](event)
        }

    }
    
    on(event, callback) {
        this.callbacks[event] = callback;
    } 

    removeon(event) {
        delete this.callbacks[event];
    }
}

export default Connection;