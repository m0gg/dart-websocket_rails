part of websocket_rails;

class WebSocketConnection
extends Object
with DefaultQueueable<WsEvent>
implements Queueable<WsEvent> {

  String url;
  WebSocket ws;
  String connectionId;

  StreamController<CloseEvent> onCloseController;
  StreamController<Event> onErrorController;
  StreamController<WsEvent> onEventController;
  StreamController onOpenController;

  Stream get onClose => onCloseController.stream;

  WebSocketConnection(this.url) {
    queue = [];
    onCloseController = new StreamController.broadcast();
    onErrorController = new StreamController.broadcast();
    onEventController = new StreamController.broadcast();
    onOpenController = new StreamController.broadcast()
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
    onEventController.close();
    onOpenController.close();
  }

  _onClose(CloseEvent e) {
    log.fine("disconnected from ${url}");
    if(!e.wasClean) {
      log.fine("Websocket connection was shut down unexpectedly with code: ${e.code} reason: \"${e.reason}\"");
    }
    onEventController.add(new WsConnectionClosed());
    onCloseController.add(e);
    onCloseController.done.then((_) => onCloseController.close());
  }

  _onError(Event e) {
    onErrorController.add(e);
  }

  _onMessage(MessageEvent event) {
    List<WsEvent> messages = JSON.decode(event.data).map((_) => new WsEvent.fromJson(_));
    for(WsEvent e in messages) {
      log.finest("received event: '${e.name}'");
      if(e is !WsPing && e is !WsConnectionEstablished)
        onEventController.add(e);
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
      onOpenController.add(e);
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
    log.finest("sending  event: '${e.name}'");
    sendEvent(e);
  }
}