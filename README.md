dart-websocket_rails
====================

pub package to communicate with a websocket managed by [websocket-rails/websocket-rails](https://github.com/websocket-rails/websocket-rails/tree/master/lib/assets/javascripts/websocket_rails) gem.

Usage
=====

Quite similar to javascript-origin.
See [m0gg/dart-websocket_rails-sample](https://github.com/m0gg/dart-websocket_rails-sample).

Open a connection
-----------------

```ruby
WebSocketRails railsWs = new WebSocketRails('${window.location.host}/websocket')
  ..connect();
```

Subscribe to channel
----------------------

```ruby
Channel wsCh = railsWs.subscribe('foo');
```

Trigger an Event
----------------

```ruby
// Future trigger(String name, [Map<String, String> data])
railsWs.trigger('poke');
railsWs.trigger('poke', { 'id': 1 });
```

Trigger returns a `Future` which will be resolved when the websocket receives a result event (WsResult).
Internally it will send a WsData Event with `data` argument encoded as JSON. If you wish to Send a specific Event type
or modify other attributes as data you'll need to create the Event yourself and pass it to `WebSocketRails.triggerEvent()`.

Trigger an Event on Channel
---------------------------

```ruby
Channel wsCh = railsWs.subscribe('foo');
wsCh.trigger('poke', { 'id': 1 })
```

or

```ruby
railsWs.trigger('ch1.poke', { 'id': 1 })
```

Bind to event
-----------------

`WebSocketRails` and `Channel` implement the internal `Binable` interface and thus can be bound the same ways. Currently there are two ways to bind to an event. But if you want to unbind a single event later, you'll need to choose the "dart-way".

"Old"-fashioned way
```ruby
wsCh.bind('bar', (data) {
  dyynamic m = JSON.decode(data);
  print(m);
});
```

"dart"-way
```ruby
StreamSubscription sc = wsCh.getEventStream('bar').listen((data) {
  dyynamic m = JSON.decode(data);
  print(m);
});
```
The `StreamSubscription` instance can later be `sc.cancel()`-ed to unbind a single event.
The returned `Stream` of `WsChannel.getEventStream()` can be listened to multiple times.

CHANGELOG
=========

26. Mar. 2015 - 0.2.0:

##### [6a92d1b](https://github.com/m0gg/dart-websocket_rails/commit/6a92d1b0f80b9691791cdc7b5a727b521cd3aa17) rework internals #####
Reworked internal structure. Usage mostly keeps the same.
- Stable reconnecting
- trigger Channel messages

29. Jan. 2015 - 0.1.0:

##### [b193e37](https://github.com/m0gg/dart-websocket_rails/commit/349d796e38bf1ed6b3dc34594a58d3004b51ca99) Implement correct handling of reconnect #####
Reconnect will now be called automaically on connection loss, but not if the initial connect() was unsuccessful. The Periodic call of reconnect() can be configured by the optional parameter reconnectTimeout on initialization ob the WebsocketRails instance.


WIP
===

It's not finished yet, but it works.
