part of websocket_rails;

abstract class WsEventDispatcher implements WsChannelManager, WsEventAsyncQueue {
  void attachRelay(WsEventRelay);
  void detachRelay(WsEventRelay);
  void handleEvent(WsEvent);
}

abstract class WsEventRelay implements EventQueue {
  Stream get onEvent;
  Stream get onOpen;
  Stream get onClose;

  bool get isOpened;
  String get connectionId;

  void close();

  sendEvent(WsEvent e);
}

abstract class WsChannelManager {
  Map<String, WsChannel> get channels;

  WsChannel subscribe(String name, [bool private]);
  WsChannel subscribePrivate(String name);
  void unsubscribe({ WsChannel channel, String name });
  void dispatchChannelEvent(WsChannelEvent e);
}
