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
with DefaultBindable, EventQueueDefaults<WsData>, WsEventAsyncQueueDefaults
implements Bindable, WsEventDispatcher {

  String url;
  int state;
  Duration reconnectTimeout;
  StreamSubscription relayOnEventSubscription;
  WsEventRelay mRelay;

  // TODO: fix usage
  Map<String, WsChannel> _channels = {};
  Map<String, WsChannel> get channels =>_channels;

  List<WsEvent> _eventQueue = [];
  List get eventQueue => _eventQueue;

  Map<int, Completer> _eventQueueCompleter = {};
  Map<int, Completer> get eventQueueCompleter => _eventQueueCompleter;

  bool closed = false;

  static const int STATE_DISCONNECTED = 0;
  static const int STATE_CONNECTING = 1;
  static const int STATE_CONNECTED = 2;

  WebSocketRails(this.url, { this.reconnectTimeout }) {
    if(this.reconnectTimeout == null) this.reconnectTimeout = new Duration(seconds: 1);
  }

  Future connect() {
    Completer ac = new Completer();
    if(mRelay == null || state == STATE_DISCONNECTED) {
      state = STATE_CONNECTING;
      WsEventRelay nRelay = new WebSocketConnection(this.url);
      nRelay.onOpen.single
        ..then((_) {
        attachRelay(nRelay);
        _connectionEstablished(_);
        ac.complete();
      })
        ..catchError((_) => ac.completeError(_));

      /*connection = new WebSocketConnection(this.url)
        ..onErrorController.stream.listen((_) => ac.completeError(_))
        ..onEventController.stream.listen((_) => _newMessage(_))
        ..onOpenController.stream.listen((_) {*/

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

  String get connectionId {
    if(mRelay != null) {
      return mRelay.connectionId;
    } else return null;
  }

  void attachRelay(WsEventRelay nRelay) {
    if(mRelay != null && mRelay.isOpened) {
      Exception e = new Exception('''
          Already having an active relay attached...
          This point is either reached because of a bug
          or invalid handling of the library!
      ''');
      log.fine(e);
      return;
    }
    log.fine("Attaching WsEventRelay");
    mRelay = nRelay;
    nRelay.onClose.single.then((_) => handleDisconnect());
    relayOnEventSubscription = nRelay.onEvent.listen(handleEvent);
  }

  void detachRelay() {
    if(relayOnEventSubscription != null)
      relayOnEventSubscription.cancel();
    if(mRelay != null)
      mRelay = null;
  }

  disconnect() {
    closed = true;
    disconnectRelay();
    detachRelay();
  }

  disconnectRelay() {
    if(mRelay != null && mRelay.isOpened)
      mRelay.close();
  }

  reconnect() {
    String oCid = mRelay.connectionId;
    disconnect();

    connect()
      ..then((_) {
      eventQueue.forEach((WsEvent e) {
        if(e.connectionId == oCid && e is !WsResult) triggerEvent(e);
      });
    })
      ..catchError((_) => new Future.delayed(this.reconnectTimeout, reconnect));
  }


  // TODO: Continue working here!
  handleEvent(WsEvent e) {
    if(e is WsResult) {
      eventQueueEmitResponse(e);
    } else if(e is WsChannelEvent || e is WsToken) {
      _dispatchChannel(e);
    } else if(e is WsConnectionClosed) {
      if(state != STATE_CONNECTING) reconnect();
    } else {
      _dispatch(e);
    }
  }

  void handleDisconnect() {
    state = STATE_DISCONNECTED;
    if(!closed) reconnect();
  }

  @deprecated
  _emitResponse(WsData e) {
    throw new Exception("Do not use!");
    /*if(e.id != null && _eventQueue[e.id] != null && _eventQueueCompleter[e.id] != null) {
      _eventQueueCompleter[e.id].complete(e.data);
      _eventQueue[e.id] = null;
      _eventQueueCompleter[e.id] = null;
    }*/
  }

  _connectionEstablished(WsConnectionEstablished e) {
    log.fine("connected to ${url}");
    closed = false;
    state = STATE_CONNECTED;
  }

  @deprecated
  Future trigger(String name, [Map<String, String> data = const {}]) {
    WsData e = new WsData(name, data, connectionId);
    return trackEvent(e);
  }

  Future trackEvent(WsData e) {
    Completer ac = new Completer();
    _eventQueueCompleter[e.id] = ac;
    triggerEvent(e);
    return ac.future;
  }

  bool eventQueueOut(WsData e) => triggerEvent(e) != null;
  WsEvent triggerEvent(WsData e) {
    if(mRelay == null) throw new Exception('Could not trigger Event. No existing connection!');
    if(_eventQueue[e.id] == null)
      _eventQueue[e.id] = e;
    else {
      Exception ex = new Exception('Could not queue Event, id already used: ${e.toJson()}');
      log.fine(ex);
      throw ex;
    }
    mRelay.sendEvent(e);
    return e;
  }

  _dispatch(WsData e) {
    if(eventControllers[e.name] != null) eventControllers[e.name].add(e.data);
  }

//Channel related
  WsChannel subscribe(String name, [bool private]) => _subscribe(name, private);
  WsChannel subscribePrivate(String name) => _subscribe(name, true);
  WsChannel _subscribe(String name, bool private) {
    if(_channels[name] != null) return _channels[name];

    log.finest("subscribing to channel: '$name', private: $private");
    return _channels[name] = new WsChannel(this, name, private);
  }

  unsubscribe({ WsChannel channel, String name }) {
    if(channel != null && name != null) throw new Exception('Specify either name or channel for unsubscription.');
    WsChannel chan;
    if(name != null) {
      chan = _channels[name];
      _channels.remove(name);
    } else if(channel != null) {
      chan = channel;
      // TODO: find a better solution
      if(_channels.containsValue(chan)) _channels.forEach((k, v) {
        if(v == chan) _channels.remove(k);
      });
    }
    chan.destroy();
  }

  // TODO: fix usage
  void dispatchChannelEvent(WsChannelEvent e) => _dispatchChannel(e);
  _dispatchChannel(WsChannelEvent e) {
    if(_channels[e.channel] != null) {
      log.finest("dispatch event to channel '${e.channel}': ${e.name}");
      _channels[e.channel].dispatch(e);
    }
  }
//End Channel related

  // TODO: fix usage
  bool get isOpened => state == STATE_CONNECTED;
  bool get eventQueueIsBlocked => state != STATE_CONNECTED;

  @deprecated
  bool get connectionStale => isOpened;

  @deprecated
  reconnectChannels() {
    throw new Exception("Do not use this function! Channels react on reconnection themselves!");
  }
}
