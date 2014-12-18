part of websocket_rails;

class Channel {
  String name;
  WebSocketRails dispatcher;
  bool private;
  
  List queue;
  String token;
  String connectionId;

  Map<String, Stream<dynamic>> cbStreams;
  Map<String, StreamController<dynamic>> cbControllers;
  
  static const String SUBSCRBE_PRIVATE = 'websocket_rails.subscribe_private';
  static const String SUBSCRBE = 'websocket_rails.subscribe';
  static const String UNSUBSCRIBE = 'websocket_rails.unsubscribe';
  static const String RAILS_TOKEN = 'websocket_rails.channel_token';
  
  Channel(this.name, this.dispatcher, this.private, { Function onSuccess: null, Function onFailure: null }) {
    connectionId = dispatcher.connection.connection_id;
    WsSubscribe e = (private ? new WsSubscribePrivate(name, connectionId): new WsSubscribe(name, connectionId));
    cbControllers = {};
    cbStreams = {};
    queue = [];
    dispatcher.triggerEvent(e);
  }
  
  destroy() {
    if(connectionId == dispatcher.connection.connection_id) {
      WsUnsubscribe e = new WsUnsubscribe(name, connectionId);
      dispatcher.triggerEvent(e);
    }
    //TODO: callbacks on destroying channel
    //@_callbacks = {}
  }
  
  
  bind(String eName, Function cb) {
    getStream(eName).listen(cb);
  }
  
  /*TODO: channel unbind callbacks
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
  
  dispatch(WsEvent e) {
    if(e is WsToken) {
      connectionId = dispatcher.connection.connection_id;
      token = e.token;
      flushQueue();
    } else if(e is WsChannel) {
      _setupController(e.name).add(e.data);
    } else {
      print('Unexpected event dispatched to Channel "$name": $e');
    }
  }
  
  flushQueue() {
    for(WsEvent e in queue) {
      dispatcher.triggerEvent(e);
    }
    queue.clear();
  }

  StreamController _setupController(String eName) {
    StreamController sC = cbControllers[eName];
    if(sC == null) {
      sC = new StreamController.broadcast();
      cbControllers[eName] = sC;
    }
    return sC;
  }

  Stream getStream(String eName) {
    return _setupController(eName).stream;
  }
}