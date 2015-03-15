part of websocket_rails;

class WebSocketConnection
extends Object
with EventQueueDefaults<WsEvent>
implements WsEventRelay {
  String url;
  WebSocket ws;
  String connectionId;

  StreamController onOpenController              = new StreamController.broadcast();
  StreamController<CloseEvent> onCloseController = new StreamController.broadcast();
  StreamController<WsEvent> onEventController    = new StreamController.broadcast();

  Stream get onOpen  => onOpenController.stream;
  Stream get onClose => onCloseController.stream;
  Stream get onEvent => onEventController.stream;

  List<WsEvent> _eventQueue = [];
  List get eventQueue => _eventQueue;

  bool get isOpened => ws.readyState == WebSocket.OPEN;

  static Logger log = new Logger('WebSocketConnection');

  WebSocketConnection(this.url) {
    onOpen.listen(connectionEstablished);
    String protocol = (window.location.protocol == 'https:') ? 'wss:': 'ws:';
    this.ws = new WebSocket('$protocol//${this.url}');
    this.ws.onClose.listen(_onClose);
    this.ws.onError.listen(_onError);
    this.ws.onMessage.listen(_onMessage);
  }

  close() {
    if(isOpened) ws.close();
  }

  _onClose(CloseEvent e) {
    log.fine('Disconnected from ${url}');
    if(!e.wasClean) {
      log.fine('Websocket connection was shut down unexpectedly with code: ${e.code} reason: "${e.reason}"');
    }
    onCloseController.add(e);
    onOpenController.addError(e);
    onEventController.done.then(close());
    onOpenController.done.then(close());
    onCloseController.done.then(close());
  }

  _onError(Event e) {
    log.fine('Websocket generated an error: ${e.path}');
  }

  _onMessage(MessageEvent event) {
    List<WsEvent> messages = JSON.decode(event.data).map((_) => new WsEvent.fromJson(_));
    for(WsEvent e in messages) {
      if(e == null)
        log.fine('Null Event: ${event.data}');
      else handleEvent(e);
    }
  }

  connectionEstablished(WsConnectionEstablished e) {
    connectionId = e.connectionId;
    eventQueueFlush();
  }

  handleEvent(WsEvent e) {
    if(e is WsPing)
      pong();
    else if(e is WsConnectionEstablished) {
      onOpenController.add(e);
    } else {
      onEventController.add(e);
    }
  }

  sendEvent(WsEvent e) {
    if(this.connectionId != null) e.connectionId = this.connectionId;
    log.finest('Send Event: ${e.toJson()}');
    ws.sendString(e.toJson());
  }

  pong() {
    eventQueueAdd(new WsPong(connectionId));
  }

  bool get eventQueueIsBlocked => ws.readyState != WebSocket.OPEN;
  bool eventQueueOut(WsEvent e) {
    sendEvent(e);
    return true;
  }

  @deprecated
  trigger(WsEvent e) => eventQueueAdd(e);
}