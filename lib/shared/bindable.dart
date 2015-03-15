part of websocket_rails;

abstract class Bindable {
  Map eventControllers;

  //compat
  StreamSubscription bind(String eName, Function cb);
  StreamController _setupController(String eName);
  Stream getEventStream(String eName);
  StreamController getEventController(String eName);

  // unbind via StreamSubscription.cancel()
}

class DefaultBindable implements Bindable {
  Map<String, StreamController<dynamic>> eventControllers = {};

  @deprecated
  StreamSubscription bind(String eName, Function cb) => getEventStream(eName).listen(cb);

  StreamController _setupController(String eName) {
    StreamController sC = eventControllers[eName];
    if(sC == null) {
      sC = new StreamController.broadcast();
      eventControllers[eName] = sC;
    }
    return sC;
  }

  StreamController getEventController(String eName) => eventControllers[eName];
  Stream getEventStream(String eName) => _setupController(eName).stream;
}