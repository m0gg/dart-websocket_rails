part of websocket_rails;

abstract class WsEventDispatcher implements WsChannelManager, WsEventAsyncQueue {
  WsEventRelay mRelay;

  void attachRelay(WsEventRelay);
  void detachRelay();
  void handleEvent(WsEvent);

  String get connectionId;
}

abstract class WsEventRelay implements EventQueue<WsEvent> {
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
