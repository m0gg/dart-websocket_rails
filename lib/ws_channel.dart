part of websocket_rails;

class WsChannel
extends Object
with DefaultBindable
implements Bindable {

  String name;
  bool private;
  String token;
  Future get onSubscribe => onSubscribeCompleter.future;
  Completer onSubscribeCompleter = new Completer();
  WsEventDispatcher gw;

  static Logger log = new Logger('WebSocketChannel');

  WsChannel(this.gw, this.name, this.private);

  Future subscribe() {
    WsSubscribe e = (private ? new WsSubscribePrivate(name): new WsSubscribe(name));
    return gw.eventQueueAddTracked(e)
      ..then((_) {
      log.finest('acknowledged channel subscription for: "$name"');
      onSubscribeCompleter.complete();
    });
  }

  destroy() {
    gw.eventQueueAddTracked(new WsUnsubscribe(name)).then((_) {
      eventControllers.forEach((k, StreamController v) => v.close());
    });
  }

  trigger(String eName, [dynamic data = const {}]) {
    return gw.eventQueueAddTracked(new WsData('$name.$eName', { 'data': data, 'token': token }));
  }

  dispatch(WsEvent e) {
    if(e is WsToken) {
      log.finest('received token for channel: "${name}"');
      token = e.token;
    } else if(e is WsChannelEvent) {
      _setupController(e.name).add(e.data);
    } else {
      throw new Exception('Unexpected event dispatched to Channel "$name": $e');
    }
  }
}