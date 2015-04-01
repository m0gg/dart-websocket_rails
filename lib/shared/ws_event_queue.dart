part of websocket_rails;

abstract class EventQueue<T> {
  List<T> get mEventQueue;
  bool get mEventQueueIsBlocked;

  void eventQueueOut(T e);
  void eventQueueAdd(T e);
  void eventQueueFlush();
}
class EventQueueDefaults<T> implements EventQueue<T> {
  List<T> mEventQueue = [];

  void eventQueueAdd(T e) {
    mEventQueueIsBlocked ? mEventQueue.add(e) : eventQueueOut(e);
  }

  void eventQueueFlush() {
    mEventQueue.forEach((_) {
      eventQueueOut(_);
    });
    mEventQueue.clear();
  }
}

abstract class WsEventAsyncQueue implements EventQueue<WsData>  {
  Map<int, Completer> get mEventQueueCompleter;

  Future eventQueueAddTracked(WsData e);
  void eventQueueEmitResponse(WsResult e);
}

class WsEventAsyncQueueDefaults implements WsEventAsyncQueue {
  Map<int, Completer> mEventQueueCompleter = {};

  Future eventQueueAddTracked(WsData e) {
    if(mEventQueueCompleter[e.id] is !Completer) {
      Completer ac = mEventQueueCompleter[e.id] = new Completer();
      eventQueueAdd(e);
      return ac.future;
    } else
      throw new Exception('Double id registered.');
  }

  void eventQueueEmitResponse(WsResult e) {
    if(mEventQueueCompleter[e.id] != null) {
      if(e.success)
        mEventQueueCompleter[e.id].complete(e.data);
      else
        mEventQueueCompleter[e.id].completeError(e.data);
      mEventQueueCompleter.remove(e.id);
    }
  }
}