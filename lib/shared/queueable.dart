part of websocket_rails;

abstract class Queueable<T> {
  List<T> queue;

  void flushQueue();
  void queueAdd(T e);
  void queueOut(T e);
  bool get queueIsBlocked;
}

class DefaultQueueable<T> implements Queueable<T> {
  List<T> queue = [];

  void queueAdd(T e) {
    if(queueIsBlocked)
      queue.add(e);
    else
      queueOut(e);
  }

  void flushQueue() {
    if(queueIsBlocked) return;
    for(T e in queue) {
      queueOut(e);
    }
    queue.clear();
  }
}