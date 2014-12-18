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
  Map<int, WsEvent> eventQueue = {};
  Map<int, Completer> eventQueueCompleter = {};
  Map<String, Channel> channels = {};
  StreamController<WsEvent> onOpenController = new StreamController.broadcast();

  static const int STATE_DISCONNECTED = 0;
  static const int STATE_CONNECTING = 1;
  static const int STATE_CONNECTED = 2;

  WebSocketRails(this.url);

  Stream<WsEvent> get onOpen => onOpenController.stream;

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
      String ocid = connection.connectionId;
      disconnect();
      connect();
      eventQueue.forEach((int i, WsEvent e) {
        if(e != null && e.connectionId == ocid && e is ! WsResult) triggerEvent(e);
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
    if(e.id != null && eventQueue[e.id] != null && eventQueueCompleter[e.id] != null) {
      eventQueueCompleter[e.id].complete(e.data);
      eventQueue[e.id] = null;
      eventQueueCompleter[e.id] = null;
    }
  }

  _connectionEstablished(WsConnectionEstablished e) {
    state = STATE_CONNECTED;
    onOpenController.add(e);
  }

  Future trigger(String name, [Map<String, String> data = const {}]) {
    Completer ac = new Completer();
    WsData e = new WsData(name, data, connection.connectionId);
    eventQueueCompleter[e.id] = ac;
    triggerEvent(e);
    return ac.future;
  }

  WsEvent triggerEvent(WsData e) {
    if(eventQueue[e.id] == null) {
      eventQueue[e.id] = e;
    }
    if(connection != null) {
      connection.trigger(e);
    } else {
      throw new Exception('Could not trigger Event. No existing connection!');
    }
    return e;
  }

  _dispatch(WsData e) {
    if(eventControllers[e.name] != null) eventControllers[e.name].add(e.data);
  }

  Channel subscribe(String name) {
    return _subscribe(name, false);
  }

  Channel subscribe_private(String name) {
    return _subscribe(name, true);
  }

  Channel _subscribe(String name, bool private) {
    if(channels[name] == null) {
      Channel c = channels[name] = new Channel(name, private);
      connection.trigger(c.getSubscriptionEvent());
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

  _dispatchChannel(WsChannel e) {
    if(channels[e.channel] != null)
      channels[e.channel].dispatch(e);
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
