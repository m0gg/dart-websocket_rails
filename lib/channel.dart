part of websocket_rails;

class Channel
extends Object
with DefaultBindable, DefaultQueueable<WsEvent>
implements Bindable, Queueable<WsEvent> {

  String name;
  bool private;
  String token;
  StreamController<WsEvent> channelEventOutController = new StreamController();

  Channel(this.name, this.private) {
    channelEventOutController.add(_getSubscriptionEvent());
  }

  Stream<WsEvent> get channelEventDispatchStream => channelEventOutController.stream;

  WsSubscribe _getSubscriptionEvent() {
    return (private ? new WsSubscribePrivate(name): new WsSubscribe(name));
  }

  destroy() {
    channelEventOutController.add(new WsUnsubscribe(name));
    eventControllers.forEach((k, StreamController v) => v.close());
    channelEventOutController.done.then((e) => channelEventOutController.close());
  }

  trigger(String eName, dynamic data) {
    queueAdd(new WsData(eName, { 'channel': name, 'data': data, 'token': token }));
  }

  dispatch(WsEvent e) {
    if(e is WsToken) {
      token = e.token;
      flushQueue();
    } else if(e is WsChannel) {
      _setupController(e.name).add(e.data);
    } else {
      throw new Exception('Unexpected event dispatched to Channel "$name": $e');
    }
  }

  bool get queueIsBlocked => token == null;
  queueOut(WsEvent e) {
    channelEventOutController.add(e);
  }
}