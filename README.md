dart-websocket_rails
====================

pub package to communicate with a websocket managed by [websocket-rails/websocket-rails](https://github.com/websocket-rails/websocket-rails/tree/master/lib/assets/javascripts/websocket_rails) gem.

Usage
=====

Quite similar to javascript-origin.

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
railsWs.trigger('music.is_votable');
railsWs.trigger('music.is_votable', { 'data': { 'bar_id': 1 }});
```

Trigger returns a `Future` which will be resolved when the websocket receives a response event.

```ruby
railsWs.trigger('music.is_votable', { 'data': { 'bar_id': 1 }})
  ..then((data) => print(data));
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

CHANGELOG
=========

29. Jan. 2015 - 0.1.0:


##### Implement correct handling of reconnect #####
349d796e38bf1ed6b3dc34594a58d3004b51ca99  
Reconnect will now be called automaically on connection loss, but not if the initial connect() was unsuccessful. The Periodic call of reconnect() can be configured by the optional parameter reconnectTimeout on initialization ob the WebsocketRails instance.


WIP
===

It's not finished yet, but it works.
