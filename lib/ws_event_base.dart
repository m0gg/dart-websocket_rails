part of websocket_rails;

abstract class WsEventBase {
  Map _attr;
  String connection_id;

  static const String DATA_IDX = 'data';
  static const String SUCCESS_IDX = 'success';
  static const String TOKEN_IDX = 'token';
  static const String CHANNEL_IDX = 'channel';
  static const String ID_IDX = 'id';

  static const NAME = 'INVALID';

  WsEventBase([this._attr, this.connection_id]);

  factory WsEventBase.fromJson(List jsonData) {
    if(jsonData is List && jsonData.length > 0) {
      Iterator argIt = jsonData.iterator
        ..moveNext();
      return _switchByType(argIt.current,
      (argIt.moveNext() ? argIt.current : null),
      (argIt.moveNext() ? argIt.current : null));
    } else throw new Exception('Malformed call of factory WsEventBase.fromJSON! Expected List with length > 0 jsonDATA: $jsonData');
  }

  static _switchByType(String name, [Map _attr, String connection_id]) {
    switch(name) {
      case WsPing.NAME:
        return new WsPing();
      case WsPong.NAME:
        return new WsPong();
      case WsConnectionEstablished.NAME:
        return new WsConnectionEstablished();
      case WsConnectionClosed.NAME:
        return new WsConnectionClosed();
      case WsConnectionError.NAME:
        return new WsConnectionError();
      default:
        return new WsGEvent.switchByType(name, _attr, connection_id);
    }
    return null;
  }

  String get name {
    return NAME;
  }

  String toJson() {
    return JSON.encode([name, _attr, connection_id]);
  }
}

class WsGEvent extends WsEventBase {
  String _name;

  WsGEvent(this._name, Map attr, [String connection_id])
  : super(attr, connection_id);

  factory WsGEvent.switchByType(String name, Map attr, [String connection_id]) {
    if(attr[WsEventBase.SUCCESS_IDX] != null)
      return new WsResult(name, attr, connection_id);
  }

  dynamic get data {
    return _attr[WsEventBase.DATA_IDX];
  }

  String get name {
    return this.name;
  }

  int get id {
    return (_attr[WsEventBase.ID_IDX] != null ? _attr[WsEventBase.ID_IDX] : random);
  }

  static Random _RND = new Random();
  static get random {
    return (((1+_RND.nextInt(99999))*0x10000)|0);
  }
}

class WsResult extends WsGEvent {
  WsResult(String name, Map attr, [String connection_id])
  : super(name, attr, connection_id);

  bool get success {
    return _attr[WsEventBase.SUCCESS_IDX];
  }
}

class WsToken extends WsGEvent {
  WsToken(String name, Map attr, [String connection_id])
  : super(name, attr, connection_id);

  bool get token {
    return _attr[WsEventBase.TOKEN_IDX];
  }

  bool get channel {
    return _attr[WsEventBase.CHANNEL_IDX];
  }
}


class WsPing extends WsEventBase {
  static const NAME = 'websocket_rails.ping';

  WsPing([Map attr, String connection_id])
  : super(attr, connection_id);
}

class WsPong extends WsEventBase {
  static const NAME = 'websocket_rails.pong';

  WsPong([Map attr, String connection_id])
  : super(attr, connection_id);
}

class WsConnectionEstablished extends WsEventBase {
  static const NAME = 'client_connected';

  WsConnectionEstablished([Map attr, String connection_id])
  : super(attr, connection_id);
}

class WsConnectionClosed extends WsEventBase {
  static const String NAME = 'connection_closed';

  WsConnectionClosed([Map attr, String connection_id])
  : super(attr, connection_id);
}

class WsConnectionError extends WsEventBase {
  static const String NAME = 'connection_error';

  WsConnectionError([Map attr, String connection_id])
  : super(attr, connection_id);
}