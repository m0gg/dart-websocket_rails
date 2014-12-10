library websocket_rails;

import 'dart:convert';
import 'dart:html';
import 'dart:async';
import 'dart:math';

part 'ws_event.dart';
part 'ws_event_base.dart';
part 'channel.dart';
part 'websocket_connection.dart';

class WebSocketRails {
  String url;
  int state;
  WebSocketConnection connection;
  Map<int, WsEvent> queue;
  Map<String, Channel> channels;

  Map<String, StreamController<dynamic>> cbControllers;
  Map<String, Stream<dynamic>> cbStreams;

  static const int STATE_DISCONNECTED = 0;
  static const int STATE_CONNECTING = 1;
  static const int STATE_CONNECTED = 2;

  StreamController<WsEvent> onOpenController;
  Stream<WsEvent> get onOpen => onOpenController.stream;

  WebSocketRails(this.url) {
    this.onOpenController = new StreamController.broadcast()
      ..stream.listen((e) => connection.flushQueue);
    this.cbControllers = {};
    this.cbStreams = {};
    this.queue = {};
    this.channels = {};
  }

  connect() {
    state = STATE_CONNECTING;
    connection = new WebSocketConnection(this.url, this);
  }

  disconnect() {
    if(connection != null) {
      connection.close();
      this.connection = null;
    }
    state = STATE_DISCONNECTED;
  }

  reconnect() {
    if(connection != null) {
      String ocid = connection.connection_id;
      disconnect();
      connect();
      queue.forEach((int i, WsEvent e) {
        if(e != null && e._connectionId == ocid && e is ! WsResult) triggerEvent(e);
      });
    }
  }

  newMessage(List message) {
    for(List data in message) {
      WsEvent e = new WsEvent.fromJson(data);
      if(e is WsResult) {
        //queue[e.id].emitResponse(e);
        queue[e.id] = null;
      } else if(e is WsChannel || e is WsToken) {
        dispatchChannel(e);
      } else if(e is WsPing) {
        pong();
      } else if(state == STATE_CONNECTING && e is WsConnectionEstablished) {
        connectionEstablished(e);
      }
    }
  }

  connectionEstablished(WsConnectionEstablished e) {
    state = STATE_CONNECTED;
    connection.connection_id = e.connectionId;
    onOpenController.add(e);
  }

  bind(String name, Function cb) {
    cbStreams[name].listen(cb);
  }

/*
  unbind: (event_name) =>
    delete @callbacks[event_name]
  */

  Future trigger(String name, [Map<String, String> data = const { }]) {
    Completer ac = new Completer();
    WsEvent e = new WsData(name, data, connection.connection_id);
    triggerEvent(e);
    return ac.future;
  }

  WsEvent triggerEvent(WsData e) {
    if(queue[e.id] == null) {
      queue[e.id] = e;
    }
    if(connection != null) connection.trigger(e);
    return e;
  }

  dispatch(WsEvent e) {
    if(cbControllers.containsKey(e.name)) cbControllers[e.name].add(e);
  }

  Channel subscribe(String name, { Function onSuccess: null, Function onFailure: null }) {
    return _subscribe(name, false, onSuccess: onSuccess, onFailure: onFailure);
  }

  Channel subscribe_private(String name, { Function onSuccess: null, Function onFailure: null }) {
    return _subscribe(name, true, onSuccess: onSuccess, onFailure: onFailure);
  }

  Channel _subscribe(String name, bool private, { Function onSuccess: null, Function onFailure: null }) {
    if(channels[name] == null) {
      Channel c = new Channel(name, this, private, onSuccess: (WsEvent e) {
        cbControllers[name] = new StreamController<WsEvent>.broadcast();
        cbStreams[name] = cbControllers[name].stream;
        if(onSuccess != null) onSuccess(e);
      }, onFailure: onFailure);
      channels[name] = c;
      return c;
    } else {
      return channels[name];
    }
  }

  unsubscribe(String name) {
    if(channels[name] != null) {
      channels[name].destroy();
      channels.remove(name);
    }
  }

  dispatchChannel(WsChannel e) {
    if(channels[e.channel] != null) {
      channels[e.channel].dispatch(e);
    } else {
      //TODO:
    }
  }

  pong() {
    connection.trigger(new WsPong(connection.connection_id));
  }

  connectionStale() {
    state != STATE_CONNECTED;
  }

  reconnectChannels() {
    channels.forEach((String name, Channel c) {
      //TODO:
      /*
            callbacks = channel._callbacks
            channel.destroy()
            delete @channels[name]
            channel = if channel.is_private
              @subscribe_private name
            else
              @subscribe name
            channel._callbacks = callbacks
            channel
             */
    });
  }
}
