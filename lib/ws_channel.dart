part of websocket_rails;

class WsChannel
extends Object
with DefaultBindable, EventQueueDefaults<WsData>, WsEventAsyncQueueDefaults
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
    })
    ..catchError((_) {
       mLog.finest('channel subscription for "$mName" received error.');
    });
  }

  destroy() {
    eventQueueAddTracked(new WsUnsubscribe(mName)).then((_) {
      mEventControllers.forEach((k, StreamController v) => v.close());
    });
  }

  Future trigger(String eName, [Map<String, String> data]) => eventQueueAddTracked(new WsData('$mName.$eName', { 'channel': this.mName, 'data': data }));

  dispatch(WsEvent e) {
    if(e is WsToken) {
      mToken = e.token;
      mLog.finest('received token for channel: "${mName}" = "$mToken"');
      eventQueueFlush();
    } else if(e is WsChannelEvent) {
      _setupController(e.name).add(e.data);
    } else {
      throw new Exception('Unexpected event dispatched to Channel "$mName": $e');
    }
  }

  bool get mEventQueueIsBlocked => this.mToken == null;
  Map<int, Completer> get mEventQueueCompleter => mGw.mEventQueueCompleter;
  void eventQueueOut(WsData e) {
    e.attr['token'] = this.mToken;
    mGw.eventQueueAdd(e);
  }
}