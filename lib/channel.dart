part of websocket_rails;

class Channel
extends Object
with DefaultBindable, DefaultQueueable<WsEvent>
implements Bindable, Queueable<WsEvent> {

  String name;
  bool private;
  String token;

  Channel(this.name, this.private);

  WsSubscribe getSubscriptionEvent() {
    return (private ? new WsSubscribePrivate(name): new WsSubscribe(name));
  }

  destroy() {
    /*if(connectionId == dispatcher.connection.connectionId) {
      WsUnsubscribe e = new WsUnsubscribe(name, connectionId);
      dispatcher.triggerEvent(e);
    }*/
    //TODO: callbacks on destroying channel
    //@_callbacks = {}
  }

  trigger(String eName, String message) {
    queueAdd(new WsData(eName, { 'channel': name, 'data': message, 'token': token }));
  }

  dispatch(WsEvent e) {
    if(e is WsToken) {
      token = e.token;
      flushQueue();
    } else if(e is WsChannel) {
      _setupController(e.name).add(e.data);
    } else {
      print('Unexpected event dispatched to Channel "$name": $e');
    }
  }

  bool get queueIsBlocked => token == null;
  queueOut(WsEvent e) {
    //TODO: implement triggering
    //dispatcher.triggerEvent(e);
  }
}