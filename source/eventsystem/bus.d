module eventsystem.bus;

import core.thread;
import std.parallelism;
import core.sync.mutex;
import core.sync.semaphore;
import std.range;
import std.array;
import std.algorithm;

alias EventBus = EventBusSingleton.instance;
class EventBusSingleton
{
    private
    {
        static EventBusSingleton _instance;
        static Mutex _busMutex;
        SafeQueue!string _eventQueue;
        shared void delegate(string)[] _listeners;
        static size_t _numThreads;
    }

    private this()
    {
        _busMutex = new Mutex;
        auto semaphore = new Semaphore(0);
        _eventQueue = new SafeQueue!string(semaphore);
        _numThreads = defaultPoolThreads();
        _listeners = [];
    }

    public static EventBusSingleton instance()
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

    public void subscribe(shared void delegate(string) listener)
    {
        synchronized (_busMutex)
        {
            _listeners ~= listener;
        }
    }

    public void unsubscribe(shared void delegate(string) listener)
    {
        synchronized (_busMutex)
        {
            _listeners = _listeners.remove!(a => a == listener);
        }
    }

    public void publish(string event)
    {
        _eventQueue.push(event);

        void delegate(string)[] listeners;
        synchronized (_busMutex)
        {
            listeners = cast(void delegate(string)[]) _listeners.dup;
        }

        foreach (listener; listeners.parallel)
        {
            listener(event);
        }
    }

    public void startDispatching()
    {
        foreach (i; 0 .. _numThreads)
        {
            auto thread = new Thread(() {
                while (true)
                {
                    auto event = _eventQueue.pop;
                    if (event == "")
                        continue;

                    void delegate(string)[] listeners;
                    synchronized (_busMutex)
                    {
                        listeners = cast(void delegate(string)[]) _listeners.dup;
                    }

                    foreach (listener; listeners.parallel)
                    {
                        listener(event);
                    }
                }
            });
            thread.isDaemon(true);
            thread.start();
        }
    }
}

class SafeQueue(T)
{
    private
    {
        T[] _elements;
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
            _elements ~= value;
            _semaphore.notify;
        }
    }

    T pop()
    {
        _semaphore.wait;
        synchronized
        {
            T value = _elements.front;
            _elements = _elements[1 .. $];
            return value;
        }
    }
}
