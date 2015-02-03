library websocket_rails;

import 'dart:convert';
import 'dart:html';
import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';

part 'shared/bindable.dart';
part 'shared/queueable.dart';
part 'shared/ws_event_gateway.dart';
part 'shared/ws_event_queue.dart';
part 'ws_event.dart';
part 'ws_event_base.dart';
part 'ws_channel.dart';
part 'websocket_connection.dart';

final Logger log = new Logger("WesocketRails");

class WebSocketRails
extends Object
with DefaultBindable
implements Bindable, WsEventDispatcher {

  String url;
  int state;
  Duration reconnectTimeout;
  WebSocketConnection connection;
  Map<String, WsChannel> _channels = {};
  Map<int, WsEvent> _eventQueue = {};
  Map<int, Completer> _eventQueueCompleter = {};


  static const int STATE_DISCONNECTED = 0;
  static const int STATE_CONNECTING = 1;
  static const int STATE_CONNECTED = 2;

  WebSocketRails(this.url, { this.reconnectTimeout }) {
    if(this.reconnectTimeout == null) this.reconnectTimeout = new Duration(seconds: 1);
    log.finest("initialized");
  }

  //TODO: implement own streams
  Stream get onOpen => connection.onOpenController.stream;
  Stream get onClose => connection.onCloseController.stream;

  Future connect() {
    log.finest("called connect()");
    Completer ac = new Completer();
    if(connection == null) {
      state = STATE_CONNECTING;
      connection = new WebSocketConnection(this.url)
        ..onErrorController.stream.listen((_) => ac.completeError(_))
        ..onEventController.stream.listen((_) => _newMessage(_))
        ..onOpenController.stream.listen((_) {
        ac.complete();
        _connectionEstablished(_);
      });
    } else {
      Exception e = new Exception('''
          Already having a connection...
          This point is either reached because of a bug
          or invalid handling of the library!
      ''');
      log.fine(e);
      ac.completeError(e);
    }
    return ac.future;
  }

  disconnect() {
    log.finest("called disconnect()");
    if(connection != null) {
      connection.close();
      this.connection = null;
    }
    state = STATE_DISCONNECTED;
  }

  reconnect() {
    log.finest("called reconnect()");
    if(connection != null) {
      String oCid = connection.connectionId;
      disconnect();
      connect()
        ..then((_) {
        _eventQueue.forEach((int i, WsEvent e) {
          if(e != null && e.connectionId == oCid && e is ! WsResult) triggerEvent(e);
        });
      })
        ..catchError((_) {
        new Future.delayed(this.reconnectTimeout, reconnect);
      });
    }
  }

  _newMessage(WsEvent e) {
    if(e is WsResult) {
      _emitResponse(e);
    } else if(e is WsChannelEvent || e is WsToken) {
      _dispatchChannel(e);
    } else if(e is WsConnectionClosed) {
      log.fine("Connection lost! trying to reestablish...");
      if(state != STATE_CONNECTING) reconnect();
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
    log.fine("connected to ${url}");
    state = STATE_CONNECTED;
  }

  @deprecated
  Future trigger(String name, [Map<String, String> data = const {}]) {
    WsData e = new WsData(name, data, connection.connectionId);
    return trackEvent(e);
  }

  Future trackEvent(WsData e) {
    Completer ac = new Completer();
    _eventQueueCompleter[e.id] = ac;
    triggerEvent(e);
    return ac.future;
  }

  WsEvent triggerEvent(WsData e) {
    if(connection == null) throw new Exception('Could not trigger Event. No existing connection!');
    if(_eventQueue[e.id] == null)
      _eventQueue[e.id] = e;
    else {
      Exception ex = new Exception('Could not queue Event, id already used: ${e.toJson()}');
      log.fine(ex);
      throw ex;
    }
    connection.trigger(e);
    return e;
  }

  _dispatch(WsData e) {
    if(eventControllers[e.name] != null) eventControllers[e.name].add(e.data);
  }

//Channel related
  WsChannel subscribe(String name) => _subscribe(name, false);
  WsChannel subscribePrivate(String name) => _subscribe(name, true);
  WsChannel _subscribe(String name, bool private) {
    if(_channels[name] != null) return _channels[name];

    log.finest("subscribing to channel: '$name', private: $private");
    return _channels[name] = new WsChannel(this, name, private);
  }

  unsubscribe(String name) {
    if(_channels[name] != null) {
      log.finest("unsubscribing channel: '$name'");
      _channels[name].destroy();
      _channels.remove(name);
    }
  }

  _dispatchChannel(WsChannelEvent e) {
    if(_channels[e.channel] != null) {
      log.finest("dispatch event to channel '${e.channel}': ${e.name}");
      _channels[e.channel].dispatch(e);
    }
  }
//End Channel related

  bool get isOpened => state != STATE_CONNECTED;

  @deprecated
  bool get connectionStale => isOpened;

  @deprecated
  reconnectChannels() {
    throw new Exception("Do not use this function! Channels react on reconnection themselves!");
  }
}
