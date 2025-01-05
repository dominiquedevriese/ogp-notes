### Effect Interfaces ###

Encapsulating effects as procedures or objects is clearly a big improvement already, but our current effect abstractions as procedural abstractions or objects still have certain limitations.
The current solutions assume essentially that the application uses only a single way to log messages.
For example, imagine that some classes in the application need to log to a different destination than others or that the MAXIMUM_LENGTH restriction applies to some classes but not others.

Of course, we could extend our `Log` class with a second method that can be invoked by components that require an alternative form of logging:
```java
public class Log {
    public static final int MAXIMUM_LENGTH = 100;

    public Log() {
    }

    public void logMessageStandard(String msg) {
        if(msg.length > MAXIMUM_LENGTH)
            throw new IllegalArgumentException("message too long: '" + msg + "'");
        System.out.println(msg);
    }

    public void logMessageWithoutRestriction(String msg) {}
        System.out.println(msg);
    }
}
```
However, even this requires us to decide upfront for every component which type of logging to use and changing a component to a different kind of logging requires changing all places where log messages are generated.
In other words, our use of (stateful) procedural effect abstractions already allows us to impose constraints on the logs or change the implementation of logging in a central place, but it does not yet offer abstract effects, in the sense that components cannot be entirely agnostic about which type of logging they require.

Fortunately, we have already seen the solution for this problem: [polymorphism](polymorphism.md).
Changing our `Log` class into an interface allows us to provide several implementations of it:
```java
public interface Log {
    public void logMessage(String msg);
}

public class StandardLog implements Log {
    public void logMessage(String msg) {
        System.out.println(msg);
    }
}

public class LengthRestrictedLog implements Log {
    public static final int MAXIMUM_LENGTH = 100;
    public static void logMessage(String msg) {
        if(msg.length > MAXIMUM_LENGTH)
            throw new IllegalArgumentException("message too long: '" + msg + "'");
        System.out.println(msg);
    }
}

public class BlackHoleLog implements Log {
    public static void logMessage(String msg) {
        // do nothing
    }
}
```
While previously, we had to choose one of the different logging implementations, we can now include all of them.

By programming against the effect interface `Log`, clients now have the ability to remain fully agnostic regarding which type of logging they want to use:
```java
package businesslogic;

class BusinessLogic {
    private Log log;
    public BusinessLogic( Log log ) {
        this.log = log;
    }
    void handleRequest(Request req) {
        log.logMessage("Started handling request: '" + request.toString() + "'.");
        //...
        log.logMessage("Handling request step 2...");
        //...
        log.logMessage("Finished handling request: '" + request.getId() + "'.");
    }
}
```
We can now easily instantiate a client class like `BusinessLogic` with a different implementation of `Log` by providing it to the constructor.
In that sense, the `Log` interface represents an "abstract effect".
Note that several instances of the class `BusinessLogic` can use different implementations of `Log`.

In what follows, we will refer to interfaces representing abstract effects as "effect interfaces", to classes implementing such an interface as "effect interface implementations" and to objects of those classes as "effect instances".

## Working with Effect Interfaces ##
Representing abstract effects as effect interfaces and implementing them in effect instances has many advantages.

### Parameterized Effects ###
Implementations of effect interfaces may also be parameterized.
For example, suppose that we have the following requirement:

   Every log message should be prepended with the name of the component that generated it.

We can now easily accomodate this as follows:
```java
public class LogWithPrefix implements Log {
    private String prefix;
    public LogWithPrefix( String prefix ) {
        this.prefix = prefix;
    }
    public void logMessage( String msg ) {
        System.out.println(prefix + msg);
    }
}
public class Application {
    public static void main() {
        BusinessLogic bl = new BusinessLogic( new LogWithPrefix("BusinessLogic says: "));
        Database db = new Database( new LogWithPrefix("Database says: "));
        // ...
    }
}
```

### Effect Wrappers ###

Very often, it is useful to implement effect interfaces in such a way that they wrap other effect interfaces.
For example, we've previously seen the `LengthRestrictedLog` class, which implements a log instance that enforces a maximum length of log messages:
```java
public class LengthRestrictedLog implements Log {
    public static final int MAXIMUM_LENGTH = 100;
    public void logMessage(String msg) {
        if(msg.length > MAXIMUM_LENGTH)
            throw new IllegalArgumentException("message too long: '" + msg + "'");
        System.out.println(msg);
    }
}

public class MyApplication {
    public static void main() {
        Log log = new LengthRestrictedLog();
    }
}
```
This implementation has the disadvantage that it cannot be combined with other types of loggers.
For example, we cannot combine `LengthRestrictedLog` with `LogWithPrefix` to obtain a length-restricted log that will first add a prefix to all messages, or with a hypothetical `FileLog` to send length-restricted logs to a file on disk.
A solution to this problem is to implement `LengthRestrictedLog` as a wrapper around an underlying log effect instance:
```java
public class LengthRestrictedLog implements Log {
    public static final int MAXIMUM_LENGTH = 100;
    public Log log;
    public LengthRestrictedLog(Log log) {
        this.log = log;
    }
    public static void logMessage(String msg) {
        if(msg.length > MAXIMUM_LENGTH)
            throw new IllegalArgumentException("message too long: '" + msg + "'");
        log.logMessage(msg);
    }
}

public class MyApplication {
    public static void main() {
        Log log0 = new StandardLog();
        Log log = new LengthRestrictedLog(log0);
    }
}
```
By implementing `LengthRestrictedLog` in this way, we can now combine it with an underlying Log effect instance.
Combining effect instances in this way is a very general way to construct effect instances.

### Layers of Abstract Effects ###

Another very common pattern is to construct layers of effect interfaces and implementations.
For example, the `Database` class we've encountered before might itself represent the abstract effect of accessing a database for looking up and modifying data:
```java
public interface Database {
    public String lookupRecord(int id);
    public int pushNewRecord(String newValue);
    public void updateRecord(int id, String newValue);
}
public class InMemoryDatabase implements Database {
    private Log log;
    private String[] records = new String[];
    public InMemoryDatabase(Log log) {
        this.log = log;
    }
    public String lookupRecord(int id) {
        if(0 < id && id < records.length) {
            return records[id];
        } else {
            return null;
        }
    }
    //...
}
public class SqlDatabase implements Database {
    public SqlDatabase(Log log, SqlServerConnection conn) {
      //...
    }
    //...
}
```
This code snippet shows a second effect interface `Database`, which represents a way to access an int-indexed database of records.
There are two implementations of the interface: as an in-memory database and as an SQL database.
Both have access to a `Log` effect instance, and the SQL database additionally has access to a hypothetical `SqlServerConnection` effect instance.
Hence a concrete instance of the `Database` interface will either be a `InMemoryDataBase` or a `SqlDatabase` object and will feature a `Log` instance of a precise type (`LogWithPrefix`, ...).
In other words, the effect instances that this code can account for can be organized into layers. In general such layers often provide increasingly more abstract interfaces to external effects in the application.

Although we will not elaborate on this here, implementing software by identifying layers of effect abstractions is in fact a very general way to modularly design software.
Conversely, many interfaces and classes that you can find in practical object-oriented source code can be understood as effect interfaces and instances to the application's effects (even if they weren't explicitly intended as such).

### Unit Testing and Effect Stubbing ###

One important scenario where the possibility of easily switching to alternative effect implementations is important is during testing.
Unit testing framework often produce their own console output, in order to show the progress and intermediate results of unit tests.
It is a pity if this output is polluted by log messages from the components under test.
We can easily avoid this by instantiating those components, for example, using a `BlackHoleLog` that will throw away log messages during the tests:
```java
class BusinessLogicTest {
    @Test
    public void testDoSomething() {
        BusinessLogic bl = new BusinessLogic(new BlackHoleLog());
        bl.doSomething();
        assertTrue(bl.isSomethingDone());
    }
}
```
Note that this is very easy here because we are only using the effect of console output.
Testing becomes more difficult if the code also uses effects that expect input, e.g. console input.
Such effects are often simulated during unit testing, by implementing the effect abstraction to simulate realistic input.
This practice of simulating effects during unit testing is known as stubbing.

Sometimes, a test is intended to verify whether interaction with an effect instance happens as intended.
This can be achieved as well, for example by constructing a stubbed effect instance that stores the interactions that have happened:
```java
class BufferLog implements Log {
    private static int MAXLOGS = 100;
    private String[] buffer = new String[MAXLOGS];
    private int cursor = 0;
    public void logMessage(String msg) {
        if(cursor >= MAXLOGS) throw new IllegalStateException("Buffer is full");
        buffer[cursor++] = msg;
    }
    public String[] getBuffer() {
        return buffer.clone();
    }
    public int getNbLogs() {
        return cursor;
    }
}

class BusinessLogicTest {
    @Test
    public void testDoSomething() {
        BufferLog log = new BufferLog();
        BusinessLogic bl = new BusinessLogic(log);
        bl.doSomething();
        assertEquals(2, log.getNbLogs());
        String[] logs = log.getBuffer()
        assertEquals("log message 1", buf[0]);
        assertEquals("log message 2", buf[1]);
    }
}
```
Using the stored buffer of effects, the above code tests whether the right effects have happened.

### Effect Interfaces in Java ###

Many interfaces and classes in Java are really effect interfaces.
A good example is the `java.io.OutputStream` abstract class in the Java standard library that we show a snippet of here:
```java
public abstract class OutputStream {
    public void write(byte[] b) throws IOException;
}
```
For our purposes, we can consider an abstract class as the same as an interface.
The class offers a `void write(byte[])` method, making it not very different from our `Log` effect interface and its `void logMessage(String)` (if we imagine that a `String` is just a sequence of bytes).
The Java standard library offers a number of useful effect instances of `OutputStream` that are sometimes similar to the ones we've sketched here:
* `ByteArrayOutputStream`: similar to our `BufferLog`.
* `FileOutputStream`: writes to a file, similar to the hypothetical `FileLog` which we've mentioned somewhere.
* `CipherOutputStream`: an output stream that applies a cryptographic cipher to the data being written and then writes the resulting bytes to an underlying OutputStream.

Additionally, the `java.io.PrintStream` class extends `OutputStream` with some convenient methods like `void println(String)` and writes data to an underlying OutputStream.
In fact, the object `System.out` which we have been using in our examples is an instance of the `PrintStream`.
As such, our examples have essentially been building a `Log` abstract effect layer on top of an abstract output stream effect layer, although we haven't initially noticed.

Note that this means we could have implemented `StandardLog` as a wrapper around an output stream to obtain a `Log` effect instance that can write to an arbitrary underlying output stream, whether it streams into the standard output or standard error channel, a buffer, file or encrypted network connection:
```java
public class StandardLog implements Log {
    private OutputStream out;
    public StandardLog(OutputStream out) {
        this.out = out;
    }
    public void logMessage(String msg) {
        out.println(msg);
    }
}
```
