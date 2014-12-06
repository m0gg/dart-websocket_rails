part of websocket_rails;

class WsEvent {
  String name;
  int id;
  String channel;
  dynamic data;
  String token;
  String connection_id;
  bool result = false;
  bool success;

  Function onSuccess;
  Function onFailure;

  static Random _rnd = new Random();

  static const int DATA_NAME_IDX = 0;
  static const int DATA_ATTR_IDX = 1;
  static const int DATA_CID_IDX = 2;

  static const String NAME_CONN_EST = 'client_connected';
  static const String NAME_CONN_CLOSE = 'connection_closed';
  static const String NAME_RAILS_PING = 'websocket_rails.ping';
  static const String NAME_RAILS_PONG = 'websocket_rails.pong';
  static const String NAME_CONN_ERROR = 'connection_error';

  WsEvent(List data, { this.onSuccess: null, this.onFailure: null }) {
    this.name = data[DATA_NAME_IDX];
    if(data.length > 1) {
      Map<String, String> attr = data[DATA_ATTR_IDX];
      if(data.length > DATA_CID_IDX && data[DATA_CID_IDX] != null) this.connection_id = data[DATA_CID_IDX];
      this.id = _fetchValue(attr, 'id', int.parse) || (((1+_rnd.nextInt(99999))*0x10000)|0);
      this.channel = _fetchValue(attr, 'channel');
      this.data = _fetchValue(attr, 'data');
      this.token = _fetchValue(attr, 'token');
      String suc = _fetchValue(attr, 'success');
      if(suc != null) {
        this.success = (suc.toLowerCase() == 'true' ? true : false);
        if(this.success) this.result = true;
      }
    }
  }

  dynamic _fetchValue(Map hash, String key, [Function modifier]) {
    if(hash.containsKey(key) && hash[key] != null) {
      if(modifier != null) {
        return modifier(hash[key]);
      } else return hash[key];
    } else return null;
  }

  bool isChannel() {
    return this.channel != null;
  }

  bool isResult() {
    return this.result;
  }

  bool isPing() {
    return this.name == NAME_RAILS_PING;
  }

  List getAttributes() {
    return {
        'id': this.id,
        'channel': this.channel,
        'data': this.data,
        'token': this.token
    };
  }

  String serialize() {
    return JSON.encode([this.name, getAttributes()]);
  }

  emitResponse(WsEvent e) {
    if(e.success)
      onSuccess(e.result);
    else
      onFailure(e.result);
  }
}