library websocket_rails;

import 'dart:convert';
import 'dart:html';
import 'dart:async';
import 'dart:math';

part 'ws_event.dart';
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
    this.onOpenController = new StreamController.broadcast();
    this.cbControllers = {};
    this.cbStreams = {};
    this.queue = {};
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
        if(e.connection_id == ocid && !e.isResult()) triggerEvent(e);
      });
    }
  }
  
  newMessage(List message) {
    for(List data in message) {
      print(data);
      WsEvent e = new WsEvent(data);
      if(e.isResult()) {
        queue[e.id].emitResponse(e);
        queue[e.id] = null;
      } else if(e.isChannel()) {
        dispatchChannel(e);
      } else if(e.isPing()) {
        pong();
      } else {
        dispatch(e);
      }
      
      if(state == STATE_CONNECTING && e.name == WsEvent.NAME_CONN_EST) {
        connectionEstablished(e.data);
      }
    }
  }
  
  connectionEstablished(Map<String, String> e) {
    state = STATE_CONNECTED;
    connection.connection_id = e['connection_id'];
    connection.flushQueue();
    onOpenController.add(e);
  }
  
  bind(String name, Function cb) {
    cbStreams[name].listen(cb);
  }

  /*
  unbind: (event_name) =>
    delete @callbacks[event_name]
  */
  
  trigger(String name, Map<String, String> data, { Function onSuccess: null, Function onFailure: null }) {
    WsEvent e = new WsEvent([name, data, connection.connection_id], onSuccess: onSuccess, onFailure: onFailure);
    triggerEvent(e);
  }
  
  WsEvent triggerEvent(WsEvent e) {
    if(queue[e.id] == null) {
      queue[e.id] = e;
    }
    if(connection != null) connection.trigger(e);
    return e;
  }
  
  dispatch(WsEvent e) {
    if(cbControllers.containsKey(e.name)) cbControllers[e.name].add(e.data);
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
        onSuccess(e);
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
  
  dispatchChannel(WsEvent e) {
    if(channels[e.channel] != null) {
      channels[e.channel].dispatch(e.name, e.data);
    }
  }
  
  pong() {
    WsEvent e = new WsEvent([WsEvent.NAME_RAILS_PONG, {}, connection.connection_id]);
    connection.trigger(e);
  }
  
  connectionStale() {
    state != STATE_CONNECTED;
  }
  
  reconnectChannels() {
    channels.forEach((String name, Channel c) {
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
