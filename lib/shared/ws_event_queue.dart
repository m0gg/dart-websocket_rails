part of websocket_rails;

abstract class EventQueue<T> {
  List<T> get eventQueue;
  bool get eventQueueIsBlocked;

  void eventQueueOut(T e);
  void eventQueueAdd(T e);
  void eventQueueFlush();
}
class EventQueueDefaults<T> implements EventQueue<T> {
  void eventQueueAdd(T e) {
    eventQueueIsBlocked ? eventQueue.add(e) : eventQueueOut(e);
  }

  void eventQueueFlush() {
    eventQueue.forEach((_) {
      eventQueueOut(_);
    });
    eventQueue.clear();
  }
}

abstract class WsEventAsyncQueue implements EventQueue<WsData>  {
  Map<int, Completer> get eventQueueCompleter;

  Future eventQueueAddTracked(WsData e);
  void eventQueueEmitResponse(WsResult e);
}

class WsEventAsyncQueueDefaults implements WsEventAsyncQueue {
  Future eventQueueAddTracked(WsData e) {
    Completer ac = eventQueueCompleter[e.id] = new Completer();
    eventQueueAdd(e);
    return ac.future;
  }

  void eventQueueEmitResponse(WsResult e) {
    eventQueueCompleter[e.id].complete(e.data);
    eventQueueCompleter.remove(e.id);
  }
}