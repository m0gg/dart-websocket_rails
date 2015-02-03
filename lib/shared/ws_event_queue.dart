part of websocket_rails;

abstract class EventQueue<T> {
  List get eventQueue;

  bool get eventQueueIsBlocked;

  bool eventQueueOut(T e);
  void eventQueueAdd(T e) {
    eventQueueIsBlocked ? eventQueue.add(e) : eventQueueOut(e);
  }

  bool eventQueueFlush() {
    eventQueue.forEach((_) {
      bool result = eventQueueOut(_);
      if(result) eventQueue.remove(_);
      else return false;
    });
    eventQueue.clear();
    return true;
  }
}
class EventQueueDefaults implements EventQueue<T> {
  void eventQueueAdd(T e) {
    eventQueueIsBlocked ? eventQueue.add(e) : eventQueueOut(e);
  }

  bool eventQueueFlush() {
    eventQueue.forEach((_) {
      bool result = eventQueueOut(_);
      if(result) eventQueue.remove(_);
      else return false;
    });
    eventQueue.clear();
    return true;
  }
}

abstract class WsEventAsyncQueue implements EventQueue<WsData> {
  Map<int, Completer> get eventQueueCompleter;

  Future eventQueueAddTracked(int i, WsData e);
  void eventQueueEmitResponse(WsResult e);
}

class WsEventAsyncQueueDefaults implements WsEventAsyncQueue {
  Future eventQueueAddTracked(int i, WsData e) {
    Completer ac = eventQueueCompleter[e.id] = new Completer();
    eventQueueAdd(e);
    return ac.future;
  }

  void eventQueueEmitResponse(WsResult e) {
    eventQueueCompleter[e.id].complete(e.data);
  }
}