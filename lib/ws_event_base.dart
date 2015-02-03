part of websocket_rails;

abstract class WsEvent {
  Map attr;
  String connectionId;

  static const String DATA_IDX = 'data';
  static const String SUCCESS_IDX = 'success';
  static const String TOKEN_IDX = 'token';
  static const String S_TOKEN_IDX = 'server_token';
  static const String CHANNEL_IDX = 'channel';
  static const String ID_IDX = 'id';
  static const String DATA_CID_IDX = 'connection_id';

  WsEvent([this.attr, this.connectionId]);

  factory WsEvent.fromJson(List jsonData) {
    if(jsonData is List && jsonData.length > 0) {
      Iterator argIt = jsonData.iterator
        ..moveNext();
      return _switchByType(argIt.current,
      (argIt.moveNext() ? argIt.current : null),
      (argIt.moveNext() ? argIt.current : null));
    } else throw new Exception('Malformed call of factory WsEventBase.fromJSON! Expected List with length > 0 jsonDATA: $jsonData');
  }

  static WsEvent _switchByType(String name, [Map attr, String connectionId]) {
    switch(name) {
      case WsPing.NAME:
        return new WsPing();
      case WsPong.NAME:
        return new WsPong(connectionId);
      case WsConnectionEstablished.NAME:
        return new WsConnectionEstablished(attr);
      case WsConnectionClosed.NAME:
        return new WsConnectionClosed();
      case WsConnectionError.NAME:
        return new WsConnectionError();
      default:
        return new WsData.switchByType(name, attr, connectionId);
    }
  }

  String get name;
  String toJson() => JSON.encode([name, attr, connectionId]);
}

class WsData extends WsEvent {
  static Random _RND = new Random();
  static get random => (((1+_RND.nextInt(99999))*0x10000)|0);

  String _name;

  WsData(this._name, Map attr, [String _connectionId])
  : super(attr, _connectionId);

  factory WsData.switchByType(String name, Map attr, [String connectionId]) {

    if(attr[WsEvent.SUCCESS_IDX] != null)
      return new WsResult(name, attr, connectionId);

    if(attr[WsEvent.CHANNEL_IDX] != null) {
      switch(name) {
        case WsSubscribe.NAME:
          return new WsSubscribe.fromAttr(attr, connectionId);
        case WsToken.NAME:
          return new WsToken(attr, connectionId);
        default:
          return new WsChannelEvent(name, attr, connectionId);
      }
    }
  }

  dynamic get data => attr[WsEvent.DATA_IDX];
  String get name => this._name;
  int get id => (attr[WsEvent.ID_IDX] != null ? attr[WsEvent.ID_IDX] : attr[WsEvent.ID_IDX] = random);
}

class WsChannelEvent extends WsData {
  WsChannelEvent(String name, Map attr, [String connectionId])
  : super(name, attr, connectionId);

  String get channel => attr[WsEvent.CHANNEL_IDX];
  String get serverToken => attr[WsEvent.S_TOKEN_IDX];
}

//Data-classes
class WsResult extends WsData {
  WsResult(String name, Map attr, [String connectionId])
  : super(name, attr, connectionId);

  bool get success => attr[WsEvent.SUCCESS_IDX];
}


//Control-classes
class WsToken extends WsChannelEvent {
  static const String NAME = 'websocket_rails.channel_token';

  WsToken(Map attr, [String connectionId])
  : super(NAME, attr, connectionId);

  String get token => attr[WsEvent.TOKEN_IDX];
  String get channel => attr[WsEvent.CHANNEL_IDX];
  String get name => NAME;
}

class WsSubscribe extends WsChannelEvent {
  static const NAME = 'websocket_rails.subscribe';

  WsSubscribe.fromAttr(Map attr, [connectionId])
  : super(NAME, attr, connectionId);

  WsSubscribe(String channelName, [String connectionId])
  : super(NAME, null, connectionId) {
    attr = { 'data': { 'channel': channelName }};
  }

  /*String get channel => attr[WsEvent.DATA_IDX][WsEvent.CHANNEL_IDX];
  void set channel(arg) => attr[WsEvent.DATA_IDX][WsEvent.CHANNEL_IDX] = arg;*/
  String get name => NAME;
}

class WsSubscribePrivate extends WsSubscribe {
  static const NAME = 'websocket_rails.subscribe_private';

  WsSubscribePrivate(String channelName, [String connectionId])
  : super(channelName, connectionId);
}

class WsUnsubscribe extends WsSubscribe {
  static const NAME = 'websocket_rails.unsubscribe';

  WsUnsubscribe(String channelName, [String connectionId])
  : super(channelName, connectionId);
}

class WsPing extends WsEvent {
  static const NAME = 'websocket_rails.ping';

  WsPing()
  : super();

  String get name => NAME;
}

class WsPong extends WsEvent {
  static const NAME = 'websocket_rails.pong';

  WsPong(String connectionId)
  : super({}, connectionId);

  String get name => NAME;
}

class WsConnectionEstablished extends WsEvent {
  static const NAME = 'client_connected';

  WsConnectionEstablished(Map attr)
  : super(attr);

  String get name => NAME;
  String get connectionId => attr[WsEvent.DATA_IDX][WsEvent.DATA_CID_IDX];
}

class WsConnectionClosed extends WsEvent {
  static const String NAME = 'connection_closed';

  WsConnectionClosed()
  : super();

  String get name => NAME;
}

class WsConnectionError extends WsEvent {
  static const String NAME = 'connection_error';

  WsConnectionError()
  : super();

  String get name => NAME;
}