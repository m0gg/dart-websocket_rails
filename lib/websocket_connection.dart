part of websocket_rails;

class WebSocketConnection {
  String url;
  WebSocketRails dispatcher;
  WebSocket ws;
  List<WsEvent> message_queue;
  String connection_id;
  
  StreamController<CloseEvent> onClose;
  StreamController<WsEvent> onError;
  StreamController<WsEvent> onMessage;
  
  WebSocketConnection(this.url, this.dispatcher) {
    message_queue = new List();
    String protocol;
    if(window.location.protocol == 'https:')
      protocol = 'wss:';
    else
      protocol = 'ws:';
        this.ws = new WebSocket('$protocol//${this.url}');
    this.ws.onClose.listen(_onClose);
    this.ws.onError.listen(_onError);
    this.ws.onMessage.listen(_onMessage);
  }
  
  close() {
    ws.close();
  }
  
  _onClose(CloseEvent e) {
    if(dispatcher == null || dispatcher.connection != this) return;
    WsEvent event = new WsEvent([WsEvent.NAME_CONN_CLOSE, JSON.decode({ 'data': e })]);
    dispatcher.state = WebSocketRails.STATE_DISCONNECTED;
    dispatcher.dispatch(event);
  }
  
  _onError(Event e) {
    if(dispatcher == null || dispatcher.connection != this) return;
    WsEvent event = new WsEvent([WsEvent.NAME_CONN_ERROR, JSON.decode({ 'data': e })]);
    dispatcher.state = WebSocketRails.STATE_DISCONNECTED;
    dispatcher.dispatch(event);
  }
  
  _onMessage(MessageEvent e) {
    if(dispatcher == null || dispatcher.connection != this) return;
    dispatcher.newMessage(JSON.decode(e.data));
  }
  
  trigger(WsEvent e) {
    if(this.dispatcher.state == WebSocketRails.STATE_CONNECTED) {
      sendEvent(e);
    } else {
      this.message_queue.add(e);
    }
  }
  
  sendEvent(WsEvent e) {
    if(this.connection_id != null) e.connection_id = this.connection_id;
    ws.sendString(e.serialize());
  }
  
  flushQueue() {
    for(WsEvent e in message_queue) {
      trigger(e);
    }
    message_queue.clear();
  }
}