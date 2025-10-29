module seb;

import core.sync.mutex;
import core.sync.semaphore;
import core.thread;
import std.container.dlist;
import std.parallelism;

/++ 
 * import seb;

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
    private bool _isCancelled = false;

    void cancel()
    {
        _isCancelled = true;
    }

    auto isCancelled() @property const
    {
        return _isCancelled;
    }
}

alias EventBus = SEBSingleton.instance;
class SEBSingleton
{
    private
    {
        static SEBSingleton _instance;
        Mutex _busMutex;
        SafeQueue!Event _eventQueue;
        Semaphore _terminationSemaphore;
        void delegate(Event)[][string] _listeners;

        size_t _numThreads;
        size_t _runningThreads = 0;
        Thread[] _threads;
        bool _isRunning = false;
    }

    alias start = startDispatching;
    alias stop = stopDispatching;

    private this()
    {
        _busMutex = new Mutex;
        auto semaphore = new Semaphore(0);
        _terminationSemaphore = new Semaphore(0);
        _eventQueue = new SafeQueue!Event(semaphore);
        _numThreads = defaultPoolThreads();
    }

    static SEBSingleton instance()
    {
        if (!_instance)
        {
            synchronized (SEBSingleton.classinfo)
            {
                if (!_instance)
                    _instance = new SEBSingleton;
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
            auto typeId = typeid(T).toString();
            if (typeId in _listeners)
                _listeners[typeId] ~= cast(void delegate(Event)) listener;
            else
                _listeners[typeId] = [cast(void delegate(Event)) listener];
        }
    }

    void publish(T : Event)(T event)
    {
        if (!event.isCancelled)
            _eventQueue.push(event);
    }

    void startDispatching()
    {
        synchronized (_busMutex)
        {
            if (_isRunning)
                return;

            _threads.length = 0;
            _runningThreads = 0;

            foreach (i; 0 .. _numThreads)
            {
                auto thread = new Thread(() {
                    while (true)
                    {
                        auto event = _eventQueue.pop;
                        if (event is null)
                            break; // thread stopping

                        if (event.isCancelled)
                            continue;

                        void delegate(Event)[] listeners;
                        synchronized (_busMutex)
                        {
                            auto typeId = event.classinfo.toString();
                            listeners = typeId in _listeners ? _listeners[typeId] : null;
                        }

                        if (listeners !is null)
                        {
                            foreach (listener; listeners)
                            {
                                listener(event);
                                if (event.isCancelled)
                                    break;
                            }
                        }
                    }
                    _terminationSemaphore.notify();
                });
                thread.isDaemon(false);
                thread.start();

                _threads ~= thread;
                ++_runningThreads;
            }

            _isRunning = true;
        }
    }

    void stopDispatching()
    {
        size_t toStop;

        synchronized (_busMutex)
        {
            if (!_isRunning || _runningThreads == 0)
                return;

            toStop = _runningThreads;

            foreach (_; 0 .. toStop)
                _eventQueue.push(null);
        }

        foreach (_; 0 .. toStop)
            _terminationSemaphore.wait();

        foreach (t; _threads)
            t.join();

        synchronized (_busMutex)
        {
            _threads.length = 0;
            _runningThreads = 0;
            _isRunning = false;
        }
    }
}

private class SafeQueue(T)
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
