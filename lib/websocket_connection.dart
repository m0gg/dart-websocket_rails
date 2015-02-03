part of websocket_rails;

class WebSocketConnection
extends Object
with EventQueueDefaults
implements EventQueue<WsEvent>, WsEventRelay {
  String url;
  WebSocket ws;
  String connectionId;

  StreamController onOpenController = new StreamController.broadcast();
  StreamController<CloseEvent> onCloseController = new StreamController.broadcast();
  StreamController<WsEvent> onEventController = new StreamController.broadcast();

  Stream get onOpen => onOpenController.stream;
  Stream get onClose => onCloseController.stream;
  Stream get onEvent => onEventController.stream;

  List<WsEvent> _eventQueue = [];
  List get eventQueue => _eventQueue;

  bool get isOpened => ws.readyState == WebSocket.OPEN;

  WebSocketConnection(this.url) {
    onOpen.listen(connectionEstablished);
    onEvent.listen(handleEvent);
    String protocol = (window.location.protocol == 'https:') ? 'wss:': 'ws:';
    this.ws = new WebSocket('$protocol//${this.url}');
    this.ws.onClose.listen(_onClose);
    this.ws.onError.listen(_onError);
    this.ws.onMessage.listen(_onMessage);
  }

  close() {
    ws.close();
    onEventController.add(new WsConnectionClosed());
    onEventController.done.then((_)=> onEventController.close);
    onOpenController.done.then((_)=> onOpenController.close);
    onCloseController.done.then((_) => onCloseController.close());
  }

  _onClose(CloseEvent e) {
    log.fine("disconnected from ${url}");
    if(!e.wasClean) {
      log.fine("websocket connection was shut down unexpectedly with code: ${e.code} reason: \"${e.reason}\"");
    }
    close();
  }

  _onError(Event e) {
    log.fine("websocket generated an error: ${e}");
    close();
  }

  _onMessage(MessageEvent event) {
    List<WsEvent> messages = JSON.decode(event.data).map((_) => new WsEvent.fromJson(_));
    for(WsEvent e in messages) {
      handleEvent(e);
      onEventController.add(e);
    }
  }

  connectionEstablished(WsConnectionEstablished e) {
    connectionId = e.connectionId;
    eventQueueFlush();
  }

  handleEvent(WsEvent e) {
    if(e is WsPing)
      pong();
    else if(e is WsConnectionEstablished)
      onOpenController.add(e);
  }

  sendEvent(WsEvent e) {
    // old version, is this really correct?
    //if(this.connectionId != null) e.connectionId = this.connectionId;
    if(this.connectionId == null) {
      log.fine("Updated connectionId of Event");
      e.connectionId = this.connectionId;
    }
    ws.sendString(e.toJson());
  }

  pong() {
    eventQueueAdd(new WsPong(connectionId));
  }

  bool get eventQueueIsBlocked => ws.readyState != WebSocket.OPEN;
  bool eventQueueOut(WsEvent e) {
    // Send and pray!
    sendEvent(e);
    return true;
  }

  @deprecated
  trigger(WsEvent e) => eventQueueAdd(e);
}