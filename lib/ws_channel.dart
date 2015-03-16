part of websocket_rails;

class WsChannel
extends Object
with DefaultBindable
implements Bindable {

  String mName;
  bool mPrivate;
  String mToken;
  Future get onSubscribe => mOnSubscribeCompleter.future;
  Completer mOnSubscribeCompleter = new Completer();
  WsEventDispatcher mGw;

  static Logger mLog = new Logger('WebSocketChannel');

  WsChannel(this.mGw, this.mName, this.mPrivate);

  Future subscribe() {
    WsSubscribe e = (mPrivate ? new WsSubscribePrivate(mName): new WsSubscribe(mName));
    return mGw.eventQueueAddTracked(e)
      ..then((_) {
      mLog.finest('acknowledged channel subscription for: "$mName"');
      mOnSubscribeCompleter.complete(this);
    });
  }

  destroy() {
    mGw.eventQueueAddTracked(new WsUnsubscribe(mName)).then((_) {
      mEventControllers.forEach((k, StreamController v) => v.close());
    });
  }

  trigger(String eName, [dynamic data = const {}]) {
    return mGw.eventQueueAddTracked(new WsData('$mName.$eName', { 'data': data, 'token': mToken }));
  }

  dispatch(WsEvent e) {
    if(e is WsToken) {
      mLog.finest('received token for channel: "${mName}"');
      mToken = e.token;
    } else if(e is WsChannelEvent) {
      _setupController(e.name).add(e.data);
    } else {
      throw new Exception('Unexpected event dispatched to Channel "$mName": $e');
    }
  }
}