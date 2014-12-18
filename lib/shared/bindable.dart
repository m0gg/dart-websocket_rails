part of websocket_rails;

abstract class Bindable {
  Map eventControllers;

  //compat
  StreamSubscription bind(String eName, Function cb);
  StreamController _setupController(String eName);
  Stream getEventStream(String eName);

  // unbind via StreamSubscription.cancel()
}

class DefaultBindable implements Bindable {
  Map<String, StreamController<dynamic>> eventControllers = {};

  StreamSubscription bind(String eName, Function cb) {
    return getEventStream(eName).listen(cb);
  }

  StreamController _setupController(String eName) {
    StreamController sC = eventControllers[eName];
    if(sC == null) {
      sC = new StreamController.broadcast();
      eventControllers[eName] = sC;
    }
    return sC;
  }

  Stream getEventStream(String eName) {
    return _setupController(eName).stream;
  }
}