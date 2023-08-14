module eventsystem.bus;

import core.sync.mutex;
import core.sync.semaphore;
import core.thread;
import std.container.dlist;
import std.parallelism;

/++ 
 * import eventsystem;

   // Define a simple TestEvent derived from Event
   class TestEvent : Event {}
   
   // Define a KeyPressEvent derived from Event which captures a keyCode
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
       // Register an event handler for the TestEvent
       EventBus.subscribe!TestEvent((event) {
            writeln("Test event has occurred");
       });
   
       // Register an event handler for the KeyPressEvent
       EventBus.subscribe!KeyPressEvent((event) {
            writeln("Key with code ", event.keyCode, " has been pressed!");
       });
       
       // Start multiple threads to handle the events
       EventBus.startDispatching();
   
       // Publish events to the event bus
       EventBus.publish(new TestEvent); // Trigger the TestEvent
       EventBus.publish(new KeyPressEvent(42)); // Example of a key code
   
       // Ensure that dispatching stops when exiting the scope
       scope (exit)
       {
           EventBus.stopDispatching;
       }
   }
 +/

abstract class Event
{
}

alias EventBus = EventBusSingleton.instance;
class EventBusSingleton
{
    private
    {
        static EventBusSingleton _instance;
        Mutex _busMutex;
        SafeQueue!Event _eventQueue;
        Semaphore _terminationSemaphore;
        void delegate(Event)[][string] _listenersByType;
        size_t _numThreads;
    }

    private this()
    {
        _busMutex = new Mutex;
        auto semaphore = new Semaphore(0);
        _terminationSemaphore = new Semaphore(0);
        _eventQueue = new SafeQueue!Event(semaphore);
        _numThreads = defaultPoolThreads();
    }

    static EventBusSingleton instance()
    {
        if (!_instance)
        {
            synchronized (EventBusSingleton.classinfo)
            {
                if (!_instance)
                    _instance = new EventBusSingleton;
            }
        }
        return _instance;
    }

    void numThreads(size_t value) @property
    {
        _numThreads = value;
    }

    void subscribe(T : Event)(void delegate(T) listener)
    {
        synchronized (_busMutex)
        {
            auto key = typeid(T).toString();
            if (key in _listenersByType)
            {
                _listenersByType[key] ~= cast(void delegate(Event)) listener;
            }
            else
            {
                _listenersByType[key] = [cast(void delegate(Event)) listener];
            }
        }
    }

    void publish(T : Event)(T event)
    {
        _eventQueue.push(event);

        void delegate(Event)[] listeners;
        synchronized (_busMutex)
        {
            auto key = event.classinfo.toString();
            listeners = key in _listenersByType ? _listenersByType[key] : null;
            if (listeners is null)
                listeners = [];
        }
    }

    void startDispatching()
    {
        foreach (i; 0 .. _numThreads)
        {
            auto thread = new Thread(() {
                while (true)
                {
                    auto event = _eventQueue.pop;
                    if (event is null)
                        break; // thread stopping

                    void delegate(Event)[] listeners;
                    synchronized (_busMutex)
                    {
                        auto key = event.classinfo.toString();
                        listeners = key in _listenersByType ? _listenersByType[key] : null;
                    }

                    if (listeners !is null)
                    {
                        foreach (listener; listeners)
                        {
                            listener(event);
                        }
                    }
                }
                _terminationSemaphore.notify();
            });
            thread.isDaemon(false);
            thread.start();
        }
    }

    void stopDispatching()
    {
        foreach (_; 0 .. _numThreads)
        {
            _eventQueue.push(null);
        }

        foreach (_; 0 .. _numThreads)
        {
            _terminationSemaphore.wait();
        }
    }
}

class SafeQueue(T)
{
    private
    {
        DList!T _elements;
        Semaphore _semaphore;
    }

    this(Semaphore semaphore)
    {
        _semaphore = semaphore;
    }

    void push(T value)
    {
        synchronized
        {
            _elements.insertBack(value);
            _semaphore.notify;
        }
    }

    T pop()
    {
        _semaphore.wait;
        synchronized
        {
            auto value = _elements.front;
            _elements.removeFront();
            return value;
        }
    }
}