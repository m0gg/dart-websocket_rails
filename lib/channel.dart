part of websocket_rails;

class Channel {
  String name;
  WebSocketRails dispatcher;
  bool private;
  
  List queue;
  String token;
  String connection_id;
  
  Function onSuccess;
  Function onFailure;
  
  Map<String, Stream<dynamic>> cbStreams;
  Map<String, StreamController<dynamic>> cbControllers;
  
  static const String SUBSCRBE_PRIVATE = 'websocket_rails.subscribe_private';
  static const String SUBSCRBE = 'websocket_rails.subscribe';
  static const String UNSUBSCRIBE = 'websocket_rails.unsubscribe';
  static const String RAILS_TOKEN = 'websocket_rails.channel_token';
  
  Channel(this.name, this.dispatcher, this.private, { this.onSuccess: null, this.onFailure: null }) {
    String e_name = (private ? SUBSCRBE_PRIVATE : SUBSCRBE);
    connection_id = dispatcher.connection.connection_id;
    WsData e = new WsData(e_name, { 'data': { 'channel': name }}, connection_id);
    cbControllers = {};
    cbStreams = {};
    queue = [];
    dispatcher.triggerEvent(e);
  }
  
  destroy() {
    if(connection_id == dispatcher.connection.connection_id) {
      WsData e = new WsData(UNSUBSCRIBE, { 'data': { 'channel': name }}, connection_id);
      dispatcher.triggerEvent(e);
    }
    //@_callbacks = {}
  }
  
  
  bind(String name, Function cb) {
    if(cbStreams[name] == null) {
      cbControllers[name] = new StreamController.broadcast();
      cbStreams[name] = cbControllers[name].stream;
    }
    cbStreams[name].listen(cb);
  }
  
  /*
  unbind: (event_name) ->
    delete @_callbacks[event_name]
  */
  
  trigger(String eName, String message) {
    WsData e = new WsData(eName, { 'channel': name, 'data': message, 'token': token }, connection_id);
    if(token == null) {
      queue.add(e);
    } else {
      dispatcher.triggerEvent(e);
    }
  }
  
  dispatch(dynamic e) {
    if(e is WsToken) {
      connection_id = dispatcher.connection.connection_id;
      token = e.token;
      flushQueue();
    } else if(e is WsChannel) {
      cbControllers[e.name].add(e);
    }
  }
  
  flushQueue() {
    for(WsEvent e in queue) {
      dispatcher.triggerEvent(e);
    }
    queue.clear();
  }
}