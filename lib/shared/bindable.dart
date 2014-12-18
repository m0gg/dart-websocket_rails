part of websocket_rails;

abstract class Bindable {
  Map eventControllers;

  //compat
  void bind(String eName, Function cb);
  StreamController _setupController(String eName);
  Stream getEventStream(String eName);

  /*TODO: unbind callbacks
  unbind: (event_name) ->
    delete @_callbacks[event_name]
  */
}

class DefaultBindable implements Bindable {
  Map<String, StreamController<dynamic>> eventControllers = {};

  bind(String eName, Function cb) {
    getEventStream(eName).listen(cb);
  }

  /*TODO: unbind callbacks
  unbind: (event_name) ->
    delete @_callbacks[event_name]
  */

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