library websocket_rails;

import 'dart:convert';
import 'dart:html';
import 'dart:async';
import 'dart:math';

part 'shared/bindable.dart';
part 'shared/queueable.dart';
part 'ws_event.dart';
part 'ws_event_base.dart';
part 'channel.dart';
part 'websocket_connection.dart';

class WebSocketRails
extends Object
with DefaultBindable
implements Bindable {

  String url;
  int state;
  WebSocketConnection connection;
  Map<String, Channel> _channels = {};
  Map<int, WsEvent> _eventQueue = {};
  Map<int, Completer> _eventQueueCompleter = {};


  static const int STATE_DISCONNECTED = 0;
  static const int STATE_CONNECTING = 1;
  static const int STATE_CONNECTED = 2;

  WebSocketRails(this.url);

  //TODO: implement own streams
  Stream get onOpen => connection.onOpen.stream;
  Stream get onClose => connection.onClose.stream;

  connect() {
    if(connection == null) {
      state = STATE_CONNECTING;
      connection = new WebSocketConnection(this.url)
        ..onOpen.stream.listen((_) => _connectionEstablished(_))
        ..onEvent.stream.listen((_) => _newMessage(_));
    }
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
      String oCid = connection.connectionId;
      disconnect();
      connect();
      _eventQueue.forEach((int i, WsEvent e) {
        if(e != null && e.connectionId == oCid && e is ! WsResult) triggerEvent(e);
      });
    }
  }

  _newMessage(WsEvent e) {
    if(e is WsResult) {
      _emitResponse(e);
    } else if(e is WsChannel || e is WsToken) {
      _dispatchChannel(e);
    } else {
      _dispatch(e);
    }
  }

  _emitResponse(WsData e) {
    if(e.id != null && _eventQueue[e.id] != null && _eventQueueCompleter[e.id] != null) {
      _eventQueueCompleter[e.id].complete(e.data);
      _eventQueue[e.id] = null;
      _eventQueueCompleter[e.id] = null;
    }
  }

  _connectionEstablished(WsConnectionEstablished e) {
    state = STATE_CONNECTED;
    reconnectChannels();
  }

  Future trigger(String name, [Map<String, String> data = const {}]) {
    Completer ac = new Completer();
    WsData e = new WsData(name, data, connection.connectionId);
    _eventQueueCompleter[e.id] = ac;
    triggerEvent(e);
    return ac.future;
  }

  WsEvent triggerEvent(WsData e) {
    if(connection == null) throw new Exception('Could not trigger Event. No existing connection!');
    if(_eventQueue[e.id] == null)
      _eventQueue[e.id] = e;
    else
      throw new Exception('Could not queue Event, id already used');
    connection.trigger(e);
    return e;
  }

  _dispatch(WsData e) {
    if(eventControllers[e.name] != null) eventControllers[e.name].add(e.data);
  }

  //Channel related
  Channel subscribe(String name) => _subscribe(name, false);
  Channel subscribePrivate(String name) => _subscribe(name, true);
  Channel _subscribe(String name, bool private) {
    if(_channels[name] == null)
      return _channels[name] = new Channel(name, private)
        ..channelEventDispatchStream.listen(triggerEvent);
    return _channels[name];
  }

  _unsubscribe(String name) {
    if(_channels[name] != null) {
      _channels[name].destroy();
      _channels.remove(name);
    }
  }

  _dispatchChannel(WsChannel e) {
    if(_channels[e.channel] != null)
      _channels[e.channel].dispatch(e);
  }
  //End Channel related

  get connectionStale => state != STATE_CONNECTED;

  reconnectChannels() {
    _channels.forEach((String name, Channel c) {
      connection.trigger(c._getSubscriptionEvent());
    });
  }
}
