# **Simple event bus —** Thread-Safe Multithreaded Event System

This repository contains a simple implementation of a thread-safe, multithreaded event system in the D programming language.

## Overview

The event system consists of an `SEBSingleton` class that manages event publication and subscription. The event bus can have multiple subscribers that listen for events. When an event is published, all subscribers will receive the event and can react accordingly.

The event bus uses D's `std.parallelism` library to handle events in parallel across multiple threads, ensuring efficient utilization of system resources.

**Please note that the library does not provide a subscription to an event not from the main thread.** **Perhaps we will do this in the future.**

## Usage

### Subscribing to Events

Subscribers can register a delegate function that will be called whenever an event of a particular type is posted:

```d
// register a handler function for the TestEvent
EventBus.subscribe!TestEvent((event) {
	writeln("Test event has occurred");
});
```

### Publishing Events

Event can be published to the bus by calling the `publish` function:

```d
EventBus.publish(new TestEvent);
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

### **Event cancellation**

```D
EventBus.subscribe!KeyPressEvent((event) {
	if(event.keyCode == 42) {
		event.cancel;
	}
});
```

After the event is cancelled, it is lazily removed from the queue.

### Example

Here is a complete example of using the event system:

```d
import seb;
import std.stdio;

class TestEvent : Event {}

class KeyPressEvent : Event
{
    int keyCode;
    this(int code)
    {
        keyCode = code;
    }
}

void main()
{
    // Register event handlers
    EventBus.subscribe!TestEvent((event) {
        writeln("Test event has occurred");
    });
  
    EventBus.subscribe!KeyPressEvent((event) {
        writeln("Key with code ", event.keyCode, " has been pressed!");
    });

    // Start dispatching events
    EventBus.startDispatching();

    // Publish events
    EventBus.publish(new TestEvent);
    EventBus.publish(new KeyPressEvent(42));

    scope (exit)
    {
        EventBus.stopDispatching;
    }
}
```

This will print:

```text
Test event has occurred
Key with code 42 has been pressed!
```

### TO DO

* [X] **Cancelable events**
* [ ] **Subscriber priority**
* [ ] **Subscribe to an event from another thread**
