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

final Logger mLog = new Logger('WebSocketRails');

class WebSocketRails
extends Object
with DefaultBindable, EventQueueDefaults<WsData>, WsEventAsyncQueueDefaults
implements Bindable, WsEventDispatcher {

  String mUrl;
  int mState;
  Duration mReconnectTimeout;
  StreamSubscription mRelayOnEventSubscription;
  WsEventRelay mRelay;

  Map<String, WsChannel> mChannels = {};
  List<WsData> mEventQueue = [];
  Map<int, Completer> mEventQueueCompleter = {};

  bool mClosed = false;

  static const int STATE_DISCONNECTED = 0;
  static const int STATE_CONNECTING = 1;
  static const int STATE_CONNECTED = 2;

  WebSocketRails(this.mUrl, { this.mReconnectTimeout }) {
    if(this.mReconnectTimeout == null) this.mReconnectTimeout = new Duration(seconds: 1);
  }

  Future connect() {
    Completer ac = new Completer();
    if(mRelay == null || mState == STATE_DISCONNECTED) {
      mState = STATE_CONNECTING;
      WsEventRelay nRelay = new WebSocketConnection(this.mUrl);
      nRelay.onOpen.first
        ..then((_) {
        mLog.finest('connect() success');
        attachRelay(nRelay);
        _connectionEstablished(_);
        ac.complete();
      })
        ..catchError((_) {
        mLog.finest('connect() failed');
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
      mLog.fine(e);
      return;
    }
    mLog.fine('Attaching WsEventRelay');
    mRelay = nRelay;
    nRelay.onClose.first.then((_) => handleDisconnect());
    mRelayOnEventSubscription = nRelay.onEvent.listen(handleEvent);
  }

  void detachRelay() {
    if(mRelayOnEventSubscription != null)
      mRelayOnEventSubscription.cancel();
    if(mRelay != null) {
      if(mRelay.isOpened) mRelay.close();
      mRelay = null;
    }
  }

  disconnect() {
    mClosed = true;
    detachRelay();
  }

  reconnect() {
    mLog.finest('Attempt reconnect...');
    detachRelay();

    connect()
      ..then((_) {
      reconnectChannels();
      eventQueueFlush();
    })
      ..catchError((_) => new Future.delayed(this.mReconnectTimeout, reconnect));
  }

  handleEvent(WsEvent e) {
    if(e is WsResult) {
      mLog.finest('Received result: ${e.toJson()}}');
      eventQueueEmitResponse(e);
    } else if(e is WsChannelEvent) {
      dispatchChannelEvent(e);
    } else {
      StreamController target = getEventController(e.name);
      if(target != null)
        target.add(e);
      else
        mLog.fine('Received unhandled event: ${e.toJson()}}');
    }
  }

  void handleDisconnect() {
    mState = STATE_DISCONNECTED;
    detachRelay();
    if(!mClosed) reconnect();
  }

  _connectionEstablished(WsConnectionEstablished e) {
    mLog.finest('Connected to ${mUrl}');
    mClosed = false;
    mState = STATE_CONNECTED;
    eventQueueFlush();
  }

  @Deprecated('Both trigger and triggerEvent are now trackable.')
  Future trackEvent(WsData e) => eventQueueAddTracked(e);

  Future trigger(String name, [Map<String, String> data]) => eventQueueAddTracked(new WsData(name, { 'data': data }, connectionId));
  Future triggerEvent(WsData e) => eventQueueAddTracked(e);

  eventQueueOut(WsData e) {
    if(mRelay == null) throw new Exception('Could not trigger Event. No existing connection!');
    mRelay.sendEvent(e);
  }

  @Deprecated('Use WsChannel subscribe(String name, [bool private = false])')
  WsChannel subscribePrivate(String name) => subscribe(name, true);
  WsChannel subscribe(String name, [bool private = false]) {
    if(mChannels[name] != null) return mChannels[name];

    mLog.finest('Subscribing to channel: "$name", private: $private');
    mChannels[name] = new WsChannel(this, name, private);
    mChannels[name].subscribe();
    return mChannels[name];
  }

  unsubscribe({ WsChannel channel, String name }) {
    if(channel != null && name != null) throw new Exception('Specify either name or channel for unsubscription.');
    if(channel.mGw != this) throw new Exception('Channel not related to this WebsocketRails instance.');
    WsChannel chan;
    if(name != null) {
      chan = mChannels[name];
      mChannels.remove(name);
    } else if(channel != null) {
      chan = channel;
      // TODO: find a better solution
      if(mChannels.containsValue(chan)) mChannels.forEach((k, v) {
        if(v == chan) mChannels.remove(k);
      });
    }
    chan.destroy();
  }

  void dispatchChannelEvent(WsChannelEvent e) {
    if(mChannels[e.channel] != null) {
      mLog.finest('dispatch event to channel "${e.channel}": ${e.toJson()}');
      mChannels[e.channel].dispatch(e);
    }
  }

  bool get mEventQueueIsBlocked => mState != STATE_CONNECTED;

  reconnectChannels() {
    mChannels.forEach((String k, WsChannel v) => v.subscribe());
  }
}
