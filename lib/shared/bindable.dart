part of websocket_rails;

abstract class Bindable {
  Map mEventControllers;

  //compat
  StreamSubscription bind(String eName, Function cb);
  StreamController _setupController(String eName);
  Stream getEventStream(String eName);
  StreamController getEventController(String eName);
}

class DefaultBindable implements Bindable {
  Map<String, StreamController<dynamic>> mEventControllers = {};

  @deprecated('Only kept for compat. Use getEventStream(String event_name) for the dart-way.')
  StreamSubscription bind(String eName, Function cb) => getEventStream(eName).listen(cb);

  StreamController _setupController(String eName) {
    StreamController sC = mEventControllers[eName];
    if(sC == null) {
      sC = new StreamController.broadcast();
      mEventControllers[eName] = sC;
    }
    return sC;
  }

  StreamController getEventController(String eName) => mEventControllers[eName];
  Stream getEventStream(String eName) => _setupController(eName).stream;
}