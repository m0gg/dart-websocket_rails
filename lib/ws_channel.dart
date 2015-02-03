part of websocket_rails;

class WsChannel
extends Object
with DefaultBindable, DefaultQueueable<WsEvent>
implements Bindable, Queueable<WsEvent> {

  String name;
  bool private;
  String token;

  WsEventGateway gw;
  bool _subscriptionAcknowledged = false;

  WsChannel(this.gw, this.name, this.private) {
    gw.onClose.listen((_) => this._subscriptionAcknowledged = false);
    gw.onOpen.listen((_) {
      if(!this._subscriptionAcknowledged) _subscribe();
    });
    if(gw.isOpened) _subscribe();
  }

  Future _subscribe() {
    WsSubscribe e = (private ? new WsSubscribePrivate(name): new WsSubscribe(name));
    return gw.trackEvent(e)
      ..then((_) {
      log.finest("acknowledged channel subscription for: '$name'");
      this._subscriptionAcknowledged = true;
    });
  }

  destroy() {
    gw.trackEvent(new WsUnsubscribe(name)).then((_) {
      eventControllers.forEach((k, StreamController v) => v.close());
    });
  }

  trigger(String eName, dynamic data) {
    queueAdd(new WsData(eName, { 'channel': name, 'data': data, 'token': token }));
  }

  dispatch(WsEvent e) {
    if(e is WsToken) {
      log.finest("received token for channel: '${name}'");
      token = e.token;
      flushQueue();
    } else if(e is WsChannelEvent) {
      _setupController(e.name).add(e.data);
    } else {
      throw new Exception('Unexpected event dispatched to Channel "$name": $e');
    }
  }

  bool get queueIsBlocked => !gw.isOpened || token == null;
  queueOut(WsEvent e) {
    gw.triggerEvent(e);
  }
}