# Thread-Safe Multithreaded Event System

This repository contains a simple implementation of a thread-safe, multithreaded event system in the D programming language.

## Overview

The event system consists of an `EventBusSingleton` class that manages event publication and subscription. The event bus can have multiple subscribers that listen for events. When an event is published, all subscribers will receive the event and can react accordingly.

The event bus uses D's `std.parallelism` library to handle events in parallel across multiple threads, ensuring efficient utilization of system resources.

## Usage

### Subscribing to Events

Subscribers can register a delegate function that will be invoked whenever an event is published. Here is an example of subscribing to the "foo" and "bar" events:

```d
// register a handler function for the "foo" event
EventBus.subscribe((string event) {
    if (event == "foo")
    {
        synchronized
        {
            writeln("Event 'foo' has been received");
        }
    }
});

// register a handler function for the "bar" event
EventBus.subscribe((string event) {
    if (event == "bar")
    {
        synchronized
        {
            writeln("Event 'bar' has been received");
        }
    }
});
```

### Publishing Events

Events can be published to the bus by calling the `publish` function:

```d
EventBus.publish("foo");
EventBus.publish("bar");
```

### Starting and Stopping Event Dispatching

To start dispatching events, call the `startDispatching` method:

```d
EventBus.startDispatching();
```

To stop dispatching events, call the `stopDispatching` method:

```d
EventBus.stopDispatching();
```

## Example

Here is a complete example of using the event system:

```d
import std.datetime;
import core.thread;
import std.stdio;
import eventsystem.bus;

void main()
{
    // Register event handlers
    EventBus.subscribe((string event) {
        if (event == "foo")
        {
            synchronized
            {
                writeln("Event 'foo' has been received");
            }
        }
    });
    
    EventBus.subscribe((string event) {
        if (event == "bar")
        {
            synchronized
            {
                writeln("Event 'bar' has been received");
            }
        }
    });

    // Start dispatching events
    EventBus.startDispatching();

    // Publish events
    EventBus.publish("foo");
    EventBus.publish("bar");

    // Wait for some time so that the handlers have time to process the events
    Thread.sleep(seconds(1));

    scope (exit)
    {
        EventBus.stopDispatching;
    }
}
```

This will print:

```text
Event 'foo' has been received
Event 'bar' has been received
```
