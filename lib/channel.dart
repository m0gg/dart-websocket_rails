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
    WsEvent e = new WsEvent([e_name, { 'data': { 'channel': name }}, connection_id], onSuccess: onSuccess, onFailure: onFailure);
    dispatcher.triggerEvent(e);
  }
  
  destroy() {
    if(connection_id == dispatcher.connection.connection_id) {
      WsEvent e = new WsEvent([UNSUBSCRIBE, { 'data': { 'channel': name }}, connection_id]);
      dispatcher.triggerEvent(e);
    }
    //@_callbacks = {}
  }
  
  
  bind(String name, Function cb) {
    cbStreams[name].listen(cb);
  }
  
  /*
  unbind: (event_name) ->
    delete @_callbacks[event_name]
  */
  
  trigger(String e_name, String message) {
    WsEvent e = new WsEvent([e_name, { 'channel': name, 'data': message, 'token': token }, connection_id]);
    if(token == null) {
      queue.add(e);
    } else {
      dispatcher.triggerEvent(e);
    }
  }
  
  dispatch(String e_name, dynamic e) {
    if(e_name == RAILS_TOKEN) {
      connection_id = dispatcher.connection.connection_id;
      token = e.data['token'];
      flushQueue();
    } else {
      cbControllers[e_name].add(e);
    }
  }
  
  flushQueue() {
    for(WsEvent e in queue) {
      dispatcher.triggerEvent(e);
    }
    queue.clear();
  }
}