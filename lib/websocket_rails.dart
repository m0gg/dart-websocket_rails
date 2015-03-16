library websocket_rails;

import 'dart:convert';
import 'dart:html';
import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';

part 'shared/bindable.dart';
part 'shared/ws_event_gateway.dart';
part 'shared/ws_event_queue.dart';
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
    } else {
      Exception e = new Exception('''
          Already having a connection...
          This point is either reached because of a bug
          or invalid handling of the library!
      ''');
      ac.completeError(e);
      throw e;
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
    if(mRelay != null) {
      if(mRelay.isOpened) mRelay.close();
      mRelay = null;
    }
  }

  disconnect() {
    closed = true;
    detachRelay();
  }

  reconnect() {
    log.finest('Attempt reconnect...');
    String oCid = connectionId;
    detachRelay();

    connect()
      ..then((_) {
      reconnectChannels();
      eventQueueFlush(oCid);
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

  void eventQueueFlush([String oCid]) {
    eventQueue.forEach((_) {
      if(_ is !WsResult && (_.connectionId == oCid || _.connectionId == null))
        triggerEvent(_);
      eventQueueOut(_);
    });
    eventQueue.clear();
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
    return eventQueueAddTracked(new WsData(name, data, connectionId));
  }

  @deprecated
  Future trackEvent(WsData e) => eventQueueAddTracked(e);

  Future triggerEvent(WsData e) {
    return eventQueueAddTracked(e);
  }

  eventQueueOut(WsData e) {
    if(mRelay == null) throw new Exception('Could not trigger Event. No existing connection!');
    mRelay.sendEvent(e);
  }

  @deprecated
  WsChannel subscribePrivate(String name) => subscribe(name, true);
  WsChannel subscribe(String name, [bool private = false]) {
    if(channels[name] != null) return channels[name];

    log.finest('Subscribing to channel: "$name", private: $private');
    channels[name] = new WsChannel(this, name, private);
    channels[name].subscribe();
    return channels[name];
  }

  unsubscribe({ WsChannel channel, String name }) {
    if(channel != null && name != null) throw new Exception('Specify either name or channel for unsubscription.');
    if(channel.gw != this) throw new Exception('Channel not related to this WebsocketRails instance.');
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

  void dispatchChannelEvent(WsChannelEvent e) {
    if(channels[e.channel] != null) {
      log.finest('dispatch event to channel "${e.channel}": ${e.name}');
      channels[e.channel].dispatch(e);
    }
  }

  bool get eventQueueIsBlocked => state != STATE_CONNECTED;

  reconnectChannels() {
    channels.forEach((String k, WsChannel v) => v.subscribe());
  }
}
