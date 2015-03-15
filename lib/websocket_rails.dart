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

final Logger log = new Logger('WebSocketRails');

class WebSocketRails
extends Object
with DefaultBindable, EventQueueDefaults<WsData>, WsEventAsyncQueueDefaults
implements Bindable, WsEventDispatcher {

  String url;
  int state;
  Duration reconnectTimeout;
  StreamSubscription relayOnEventSubscription;
  WsEventRelay mRelay;

  Map<String, WsChannel> channels = {};
  List<WsData> eventQueue = [];
  Map<int, Completer> eventQueueCompleter = {};

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
      nRelay.onOpen.first
        ..then((_) {
        log.finest('connect() success');
        attachRelay(nRelay);
        _connectionEstablished(_);
        ac.complete();
      })
        ..catchError((_) {
        log.finest('connect() failed');
        ac.completeError(_);
      });

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
    log.fine('Attaching WsEventRelay');
    mRelay = nRelay;
    nRelay.onClose.first.then((_) => handleDisconnect());
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
    log.finest('Attempt reconnect...');
    String oCid = connectionId;
    disconnectRelay();
    detachRelay();

    connect()
      ..then((_) {
      eventQueue.forEach((WsEvent e) {
        if(e.connectionId == oCid && e is !WsResult) triggerEvent(e);
      });
    })
      ..catchError((_) => new Future.delayed(this.reconnectTimeout, reconnect));
  }

  handleEvent(WsEvent e) {
    if(e is WsResult) {
      log.finest('Received result: ${e.toJson()}}');
      eventQueueEmitResponse(e);
    } else if(e is WsChannelEvent) {
      dispatchChannelEvent(e);
    } else {
      StreamController target = getEventController(e.name);
      if(target != null)
        target.add(e);
      else
        log.fine('Received unhandled event: ${e.toJson()}}');
    }
  }

  void handleDisconnect() {
    state = STATE_DISCONNECTED;
    detachRelay();
    if(!closed) reconnect();
  }

  _connectionEstablished(WsConnectionEstablished e) {
    log.finest('Connected to ${url}');
    closed = false;
    state = STATE_CONNECTED;
    eventQueueFlush();
  }

  Future trigger(String name, [Map<String, String> data]) {
    WsData e = new WsData(name, data, connectionId);
    return trackEvent(e);
  }

  @deprecated
  Future trackEvent(WsData e) => eventQueueAddTracked(e);

  @deprecated
  WsEvent triggerEvent(WsData e) {
    eventQueueAdd(e);
    return e;
  }

  eventQueueOut(WsData e) {
    if(mRelay == null) throw new Exception('Could not trigger Event. No existing connection!');
    mRelay.sendEvent(e);
  }

//Channel related
  WsChannel subscribe(String name, [bool private]) => _subscribe(name, private);
  WsChannel subscribePrivate(String name) => _subscribe(name, true);
  WsChannel _subscribe(String name, bool private) {
    if(channels[name] != null) return channels[name];

    log.finest('Subscribing to channel: "$name", private: $private');
    channels[name] = new WsChannel(this, name, private);
    channels[name].subscribe();
    return channels[name];
  }

  unsubscribe({ WsChannel channel, String name }) {
    if(channel != null && name != null) throw new Exception('Specify either name or channel for unsubscription.');
    WsChannel chan;
    if(name != null) {
      chan = channels[name];
      channels.remove(name);
    } else if(channel != null) {
      chan = channel;
      // TODO: find a better solution
      if(channels.containsValue(chan)) channels.forEach((k, v) {
        if(v == chan) channels.remove(k);
      });
    }
    chan.destroy();
  }

  // TODO: fix usage
  @deprecated
  _dispatchChannel(WsChannelEvent e) => dispatchChannelEvent(e);

  void dispatchChannelEvent(WsChannelEvent e) {
    if(channels[e.channel] != null) {
      log.finest('dispatch event to channel "${e.channel}": ${e.name}');
      channels[e.channel].dispatch(e);
    }
  }
//End Channel related

  // TODO: fix usage
  bool get eventQueueIsBlocked => state != STATE_CONNECTED;


  @deprecated
  bool get isOpened => state == STATE_CONNECTED;

  @deprecated
  bool get connectionStale => isOpened;

  @deprecated
  reconnectChannels() {
    throw new Exception('Do not use this function! Channels react on reconnection themselves!');
  }
}
