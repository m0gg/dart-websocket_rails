part of websocket_rails;

class WebSocketConnection
extends Object
with EventQueueDefaults<WsEvent>
implements WsEventRelay {
  String mUrl;
  WebSocket mWs;
  String connectionId;

  StreamController mOnOpenController              = new StreamController();
  StreamController<CloseEvent> mOnCloseController = new StreamController.broadcast();
  StreamController<WsEvent> mOnEventController    = new StreamController.broadcast();

  Stream get onOpen  => mOnOpenController.stream;
  Stream get onClose => mOnCloseController.stream;
  Stream get onEvent => mOnEventController.stream;

  List<WsEvent> mEventQueue = [];

  bool get isOpened => mWs.readyState == WebSocket.OPEN;

  static Logger mLog = new Logger('WebSocketConnection');

  WebSocketConnection(this.mUrl) {
    String protocol = (window.location.protocol == 'https:') ? 'wss:': 'ws:';
    this.mWs = new WebSocket('$protocol//${this.mUrl}');
    this.mWs.onClose.listen(_onClose);
    this.mWs.onError.listen(_onError);
    this.mWs.onMessage.listen(_onMessage);
  }

  close() {
    if(isOpened) mWs.close();
  }

  _onClose(CloseEvent e) {
    mLog.fine('Disconnected from ${mUrl}');
    if(!e.wasClean) {
      mLog.fine('Websocket connection was shut down unexpectedly with code: ${e.code} reason: "${e.reason}"');
    }
    mOnCloseController.add(e);
    mOnOpenController.addError(e);
    mOnEventController.done.then(close());
    mOnOpenController.done.then(close());
    mOnCloseController.done.then(close());
  }

  _onError(Event e) {
    mLog.fine('Websocket generated an error: ${e.path}');
  }

  _onMessage(MessageEvent event) {
    List<WsEvent> messages = JSON.decode(event.data).map((_) => new WsEvent.fromJson(_));
    for(WsEvent e in messages) {
      if(e == null)
        mLog.fine('Null Event: ${event.data}');
      else handleEvent(e);
    }
  }

  connectionEstablished(WsConnectionEstablished e) {
    connectionId = e.connectionId;
    eventQueueFlush();
    mOnOpenController.add(e);
  }

  handleEvent(WsEvent e) {
    if(e is WsPing)
      pong();
    else if(e is WsConnectionEstablished) {
      connectionEstablished(e);
    } else {
      mOnEventController.add(e);
    }
  }

  sendEvent(WsEvent e) {
    if(this.connectionId != null) e.connectionId = this.connectionId;
    mLog.finest('Send Event: ${e.toJson()}');
    mWs.sendString(e.toJson());
  }

  pong() {
    eventQueueAdd(new WsPong(connectionId));
  }

  bool get mEventQueueIsBlocked => mWs.readyState != WebSocket.OPEN;
  bool eventQueueOut(WsEvent e) {
    sendEvent(e);
    return true;
  }
}