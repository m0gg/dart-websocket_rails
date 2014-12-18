part of websocket_rails;

class WebSocketConnection
extends Object
with DefaultQueueable<WsEvent>
implements Queueable<WsEvent> {

  String url;
  WebSocket ws;
  String connectionId;

  StreamController<CloseEvent> onClose;
  StreamController<WsEvent> onError;
  StreamController<WsEvent> onEvent;
  StreamController onOpen;

  WebSocketConnection(this.url) {
    queue = [];
    onEvent = new StreamController.broadcast();
    onOpen = new StreamController.broadcast()
      ..stream.listen(_connectionEstablished);

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
    //TODO: onClose event
    /*if(dispatcher == null || dispatcher.connection != this) return;
    WsEvent event = new WsEvent([WsEvent.NAME_CONN_CLOSE, JSON.decode({ 'data': e })]);
    dispatcher.state = WebSocketRails.STATE_DISCONNECTED;
    dispatcher.dispatch(event);*/
  }

  _onError(Event e) {
    //TODO: onError event
    /*if(dispatcher == null || dispatcher.connection != this) return;
    WsEvent event = new WsEvent([WsEvent.NAME_CONN_ERROR, JSON.decode({ 'data': e })]);
    dispatcher.state = WebSocketRails.STATE_DISCONNECTED;
    dispatcher.dispatch(event);*/
  }

  _onMessage(MessageEvent event) {
    //TODO: Filter unused connections
    //if(dispatcher == null || dispatcher.connection != this) return;
    List<WsEvent> messages = JSON.decode(event.data).map((_) => new WsEvent.fromJson(_));
    for(WsEvent e in messages) {
      if(e is! WsPing && e is! WsConnectionEstablished)
        onEvent.add(e);
      else
        dispatch(e);
    }
  }

  _connectionEstablished(WsConnectionEstablished e) {
    connectionId = e.connectionId;
    flushQueue();
  }

  dispatch(WsEvent e) {
    if(e is WsPing)
      pong();
    else if(e is WsConnectionEstablished)
      onOpen.add(e);
  }

  sendEvent(WsEvent e) {
    if(this.connectionId != null) e.connectionId = this.connectionId;
    ws.sendString(e.toJson());
  }

  pong() {
    trigger(new WsPong(connectionId));
  }

  //alias Method, compat
  trigger(WsEvent e) => queueAdd(e);

  bool get queueIsBlocked => ws.readyState != WebSocket.OPEN;
  queueOut(WsEvent e) {
    sendEvent(e);
  }
}