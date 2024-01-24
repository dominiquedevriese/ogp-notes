# Effects

A common characteristic of the code examples we have seen so far is that they do not interact with the outside world.
The code presented performs computations and modifies the internal state of data abstractions, but it does not, for example, directly produce output, interact with the network, hard drive or display of the computer on which it is running.
The absence of such external effects differentiates our examples so far from the code of many software applications, where interactions with the outside world are an important part, if not the whole point, of the software's intended behavior.
For example, an interactive 3D computer games is designed to continuously receive user input, compute the updated state of the game and render it on the user's display.
Similarly, a network server is designed to continuously respond to incoming network requests according to its configuration.
In doing so, it may read data from the hard drive or send outgoing network requests to a database or other server, and wait for and use the responses to these requests.

Generally, when a program interacts with components outside its own private memory, we refer to this as "external effects".
This type of effects should not be confused with "internal effects": interactions with the program's own mutable state (such as mutable fields of objects) or the use of exceptions or other control flow primitives (e.g. continuations) which are not observable outside the program.
Both internal and external effects of a program, component or method are sometimes called "side effects" or (preferably) "effects".
The term "side effects" suggests the perspective that executing a piece of software produces certain direct results in the form of computation results, while interactions with the outside world are indirect or side results.
This is usually incorrect since effects are very often the main or only reason for executing certain code and can hardly be considered a side result.
For this reason, we prefer to use the term "effects".

The boundary between internal and external effects is not 100% clear-cut.
For example, in some contexts, the allocation of internal memory might be considered as a purely internal effect, but in other contexts, it may be regarded as an external effect, because it can be observable to outside code (since memory usage by one program affects the memory available to other programs), or because we may be trying to limit the memory used by a program.

## How external effects are (not) different from internal effects

Before we look at concrete examples, we want to take a step back and mention two points about how external effects are different from internal effects and how they are similar.
We will explain that (1) contrary to internal effects, external effects affect the correctness of software directly rather than indirectly, but (2) similar to internal effects, it is useful to keep external effects abstract in other components.

### External effects are of direct importance
Some of the techniques that we have already seen in previous chapters enforce some kind of restriction on internal effects.
Particularly, representation invariants enforce that internal state of an object is never modified in such a way that it breaks the representation invariant.
When we use a representation invariant to constrain the internal effects of methods, this is not of direct importance in the sense that human users of the software or other systems it communicates with will never directly observe this internal state.
Instead, we only use representation invariants to make it easier to satisfy contracts, i.e. validate postconditions, preserve class invariants etc.
In this sense, representation invariants are only indirectly important: breaking a representation invariant will only indirectly affect the correctness of the software as a whole.
Ultimately, internal effects are only ever a means to an end, an implementation detail that is unobservable to outside systems and humans and only used internally to implement methods.

As mentioned above, the situation is different for external effects: these are often the ultimate purpose of an application and directly observable to outside systems or humans.
In othere words, external effects are not just important indirectly but their correctness directly affects the correctness of software applications.
For example, if we are implementing a network server application, then ensuring the application's correctness means ensuring various properties of the external effects of the application:
* The server should continuously listen on network sockets for incoming requests.
* When a packet comes in, the server should produce a corresponding response.
* Outgoing responses should be formatted according to the protocol implemented.
* Outgoing responses should contain the information that corresponds to the incoming request according to their configuration.
* Outgoing responses should not contain confidential information unless the request has been succesfully authenticated and authorized.
* ...

### Abstract effects

Despite this difference, there is also a way that external effects are similar to internal effects.

Enforcing representation invariants was only possible when classes' internal state was properly encapsulated by making all class variables private and by avoiding representation exposure.
However, this was not the only reason for encapsulating internal state.
It also allowed us to easily change representations: properly encapsulated classes can switch to a different representation without breaking their clients' expectations.
TODO: where is this explained in the course?
In other words, when an API is properly encapsulated, clients can be left unaware of internal used to implement it.

Similar situations arise when dealing with external effects.
For example, when a webserver invokes a database, it is often desirable to keep the server code unaware of how this database is accessed: as an in-memory database (requiring only internal effects to access), a database on the local disk (requiring disk access) or a remote database accross the internet (accessed over the network).
Similarly, when the webserver needs to log messages, it is best to keep it unaware of how log messages are stored (e.g. on the local disk, on a developer console, on a remote log server etc.), the format in which log messages are stored, whether filtering is applied before logging (e.g. to anonymize clients' private information) etc.
By keeping the web server unaware of such details, it will not need to be updated when logging requirements change.

# Basic Console Effects in Java #

For ease of discussion, we will use console output as a recurring example in this chapter.
However, all of our discussion applies equally to other types of external effects.
Before we explain how to encapsulate effects, let us first explore the basic APIs for interacting with the console in Java.

A very simple example involving external effects is the prototypical "Hello World!" application:
```java
class HelloWorld {
    public static void main(String[] args) {
        System.out.println("Hello World!");
    }
}
```
When this application is run, it will print the string "Hello World!" to its standard output channel.
When using Eclipse, this output will be displayed in the "Console" view.
The code uses the method `println(String)` on the public static member variable `out : PrintStream` of Java's built-in class `System`.

Similarly, we can invoke methods on the public static member `in : InputStream` of the class `System` to read input from a program's standard input channel.
However, the interface of the `InputStream` class is a bit inconvenient to use and it is easier to use a `Scanner` for this purpose:
```java
class HelloSomeone {
  	public static void main(String[] args) {
		System.out.println("What's your name?");
		Scanner scanner = new Scanner(System.in);
		String name = scanner.next();
		System.out.println("Hello, " + name + "!");
	}
}
```

TODO: do we ever use `InputStream`?

# A non-modular treatment of effects #

Now imagine that an application uses console output for logging purposes.
Concretely, different components in an application output messages on the console to keep track of the internal steps they have performed and errors they encounter as part of responding to a user request.
Keeping such a log is common practice in software development as a way to facilitate debugging or analyzing the system's behavior.

Concretely, the code might look as follows:
```java
package parsing;

class InputParser {
    Request parseInput(String userInput) {
        //...
        System.out.println("Finished parsing: input was '" + userInput +
                           "', parsed request is '" + result.toString() + "'.")
        return result;
    }
}

package businesslogic;

class BusinessLogic {
    void handleRequest(Request req) {
        System.out.println("Started handling request: '" + request.toString() + "'.");
        //...
        System.out.println("Handling request step 2...");
        //...
        System.out.println("Finished handling request: '" + request.getId() + "'.");
    }
}

package database;

class DatabaseAccess {
    void modifyUserRecord(int entryId, User newData) {
        System.out.println("Started modifying user record in database: '" +
                           entryId + "', '" + newData.toString() + "'.");
        //...
        System.out.println("Finished modifying user record in database: '" +
                           entryId + "'.");
    }
}
```
The code suggests classes `InputParser`, `BusinessLogic` and `DatabaseAccess`: classes representing different components of the application; a parser for user input, the business logic and a class responsible for accessing the database.
All three components log technical details of their operation to `System.out`.
We are only showing a few instances where this happens, but one should imagine that similar logging operations are scattered accross the entire application source code.

Now imagine that for a next version of the application, the development team is asked to make one of the following changes:
1. Log messages should be shorter than a fixed maximum length.
1. All log messages should contain a timestamp in addition to their current content, so that developers can investigate which operations are taking an unnecessarily long time.
1. Log messages should be logged to different output channels, according to a user configuration.
   Log messages may be logged, for example, to standard output (through `System.out` as before), sent over the network to a dedicated server or be ignored completely.

It should be clear that none of these requirements will be easy to implement.
Essentially, developers will have to manually inspect and modify the entire application source code, and:
* track down all places where something is printed to `System.out`.
* determine whether a log message is being printed or something else.
* modify the print statement to implement the new requirement from the list above.
When another new requirement needs to be implemented, the same procedure will have to be followed again, resulting in a lot of manual effort and a lot of opportunity for error.

The reason that these requirements are hard to implement is that the original code was not implemented well.
It does not apply the main principle of this course ([modular programming](#first-steps-in-modular-programming-part-i)) when it comes to effects.
Essentially, the responsibility for interacting with the application's log output was distributed over all the code in the application, rather than centralized in a single place.
Because the responsibility is shared, changing requirements about logging require modifying all the code that is jointly responsible for it.
Another way to say this is that the logging effect was not properly encapsulated.

This situation is very similar to what happens if we do not encapsulate the internal state of a class.
Imagine that all components in a system would have direct access to implementation details of a class like `Interval` (see [before](#first-steps-in-modular-programming-part-i)), i.e. the class `Interval`'s fields are public and other code reads and writes the fields directly.
That would make it impossible to enforce invariants on the internal state of the class and it would also make it impossible to change to a different internal representation.
The problem in our logging example is no different: internal implementation details of the logging effect are not properly encapsulated and because of this, it is impossible to enforce properties on what is logged or change to a different implementation of the logging effect.

# Procedural Effect Abstractions #

An interesting perspective to understand the problem and how to solve it, is to imagine that `System.out` does not represent output to an output channel outside the application, but instead logs all messages to an in-memory buffer, something like this:
```java
class System {
    public static String out;
}
class BusinessLogic {
    void handleRequest(Request req) {
        System.out += "Started handling request: '" + request.toString() + "'.\n";
        //...
        System.out += "Handling request step 2...\n";
        //...
        System.out += "Finished handling request: '" + request.getId() + "'.\n";
    }
}
//...
```
In this scenario, the `System.out.println(...)` statements that we had before correspond to direct updats of the `System.out` global variable.
The new requirements listed above requiring modifying the internal representation of this variable and imposing invariants on it.
This is hard to implement because the state is not encapsulated, but accessed directly by all other components.
Instead, it would have been better to use a [data abstraction](#managing-complexity-through-modularity-and-abstraction), for example like this:
```java
class System {
    private String out;
    public void appendOutput(String msg) {
        out += msg;
    }
}
class BusinessLogic {
    System system;

    public BusinessLogic(System system) {
        this.system = system;
    }
    void handleRequest(Request req) {
        system.appendOut("Started handling request: '" + request.toString() + "'.\n");
        //...
        system.appendOut("Handling request step 2...\n");
        //...
        system.appendOut("Finished handling request: '" + request.getId() + "'.\n");
    }
}
//...
```
With such a design, many of the requirements above could be implemented simply by modifying the implementation of `System` and leaving its clients untouched, saving us a big amount of work.

Of course, we do not actually want to replace the application's standard with an in-memory buffer, but we can still get inspiration from the analogy.
Similarly to how we might place a data abstraction around a piece of internal state, we can place an effect abstraction around `System.out`.
The effect abstraction will be responsible for implementing the effect (for example, log to standard output or to an in-memory buffer or to the network) and enforcing properties of the external effects.

A first way to do this is in the form of a procedural abstraction, by defining a class Log with  a public static procedure `logMessage`, which implements logging once and for all:
```java
public class Log {
	public static void logMessage(String msg) {
		System.out.println(msg);
	}
}
```
All other components in the application can then invoke the static method `Log.logMessage()` rather than `System.out.println()`, for example:
```java
package businesslogic;

class BusinessLogic {
    void handleRequest(Request req) {
        Log.logMessage("Started handling request: '" + request.toString() + "'.");
        //...
        Log.logMessage("Handling request step 2...");
        //...
        Log.logMessage("Finished handling request: '" + request.getId() + "'.");
    }
}
```

If we ensure that all log messages in the entire application are printed using `Log.logMessage` rather than directly through `System.out.println`, then it becomes significantly easier to implement some of the changing requirements mentioned above.

For example, one of the requirements stated

    Log messages should be shorter than a fixed maximum length.

This is now easy to implement and requires modifying only the effect abstraction `Log`, and none of its clients:
```java
public class Log {
    public static final int MAXIMUM_LENGTH = 100;
	public static void logMessage(String msg) {
		System.out.println(msg.substring(0,MAXIMUM_LENGTH));
	}
}
```
Note that here, we are manually truncating log messages that are longer than the maximum length.
We could also implement the requirement in two alternative ways: either using defensive programming:
```java
public class Log {
    public static final int MAXIMUM_LENGTH = 100;
	public static void logMessage(String msg) {
        if(msg.length > MAXIMUM_LENGTH) throw new IllegalArgumentException("message too long: '" + msg + "'");
		System.out.println(msg);
	}
}
```
or by imposing a contract:
```java
public class Log {
    public static final int MAXIMUM_LENGTH = 100;
    /**
     * Log the given message.
     * @pre msg.length <= MAXIMUM_LENGTH
     * @post true
     */
	public static void logMessage(String msg) {
		System.out.println(msg);
	}
}
```
All three of these solutions are easy to implement because there is a single central effect abstraction for logging.
The different styles have the same advantages and disadvantages as when we've used them for enforcing invariants on abstract state or representation invariants on internal state.

Two other requirements, namely

    All log messages should contain a timestamp in addition to their current content,
    so that developers can investigate which operations are taking an unnecessarily long
    time.

and

    All log messages should be logged to a different output channel, depending on a
    user configuration

similarly become easy to implement, but we leave them as an exercise for the reader.

# Single-Object Effect Abstractions #

But what if we want to enforce properties about effects that are a bit more stateful, for example:

    All log messages should contain a sequence number in addition to their current content.

Enforcing this in an effect abstraction requires a form of mutable state: we need to keep a counter in order to determine the sequence number to be printed for every next message.
It is possible to implement this by introducing global state in our effect implementation class `Log`:
```java
public class Log {
    private static int counter = 0;
	public static void logMessage(String msg) {
		System.out.println(String.format("%d: %s", ++counter, msg));
	}
}
```
In this code, `String.format` will produce a string that contains the integer `counter + 1` in decimal notation, followed by a colon and the specified log message.
The counter will be kept in a static variable of the `Log` class.
The variable is global and since it is not final, can be incremented in every invocation of the `logMessage` function.

Unfortunately, there are many downsides to the use of global mutable state like this `counter` variable.
One important problem is that global mutable state makes code very difficult to test.
For example, unit tests cannot be kept independent from each other, since their behavior will depend on the state of global variables in methods that they invoke.
Another problem with global mutable state is that in the presence of concurrency, it requires synchronization variables or other mechanisms to avoid data races (other courses explain this in more detail).

For that reason, it is better to implement stateful effect abstractions in an object and store the state in a field of the object:
```java
public class Log {
    private int counter;

    public Log() {
        counter = 0;
    }

	public void logMessage(String msg) {
		System.out.println(String.format("%d: %s", ++counter, msg));
	}
}
```
The Log object can then be constructed during initialization of an application and a reference can be passed to code that needs it:
```java
class MyApplication {
    public static void main() {
        Log log = new Log();
        BusinessLogic bl = new BusinessLogic(log);
        //...
    }
}

class BusinessLogic {
    private Log log;
    public BusinessLogic(Log log) {
        this.log = log;
    }

    public void doSomething() {
        log.logMessage("Doing something...")
    }
}
```

We leave it as an exercise to the reader to verify that this approach lends itself much better to unit testing, i.e. that every unit test can be given a private implementation of logging whose behavior is independent from that of other tests.

# Effect Interfaces #

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
        if(msg.length > MAXIMUM_LENGTH) throw new IllegalArgumentException("message too long: '" + msg + "'");
		System.out.println(msg);
	}

    public void logMessageWithoutRestriction(String msg) {}
		System.out.println(msg);
	}
}
```
However, even this requires us to decide upfront for every component which type of logging to use and changing a component to a different kind of logging requires changing all places where log messages are generated.
In other words, our use of (stateful) procedural effect abstractions already allows us to impose constraints on the logs or change the implementation of logging in a central place, but it does not yet offer abstract effects, in the sense that components cannot be entirely agnostic about which type of logging they require.

Fortunately, we have already seen the solution for this problem: [polymorphism](#polymorphism).
Applying the techniques we've already sene, we can change our `Log` class to an interface so that we can provide several different implementations of it:
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
        if(msg.length > MAXIMUM_LENGTH) throw new IllegalArgumentException("message too long: '" + msg + "'");
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

By programming against the effect interface `Log`, clients remain fully agnostic of which type of logging they use:
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

In what follows, we will refer to interfaces representing abstract effects as "effect interfaces" and to objects implementing them as "effect instances".

# Implementing Effect Interfaces #
Representing abstract effects as effect interfaces and implementing them using effect instances has many advantages.

## Parameterized Effekkkkjjcts ##
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

## Effect Wrappers ##

Very often, it is useful to implement effect interfaces in such a way that they wrap other effect interfaces.
For example, we've previously seen the `LengthRestrictedLog` class, which implements a log instance that enforces a maximum length of log messages:
```java
public class LengthRestrictedLog implements Log {
    public static final int MAXIMUM_LENGTH = 100;
	public void logMessage(String msg) {
        if(msg.length > MAXIMUM_LENGTH) throw new IllegalArgumentException("message too long: '" + msg + "'");
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
An alternative is to implement `LengthRestrictedLog` as a wrapper around an underlying log effect instance:
```java
public class LengthRestrictedLog implements Log {
    public static final int MAXIMUM_LENGTH = 100;
    public Log log;
    public LengthRestrictedLog(Log log) {
        this.log = log;
    }
	public static void logMessage(String msg) {
        if(msg.length > MAXIMUM_LENGTH) throw new IllegalArgumentException("message too long: '" + msg + "'");
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

## Layers of Abstract Effects ##

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
There are implementations of the interface as an in-memory database and an SQL database.
Both have access to a `Log` effect instance, and the SQL database additionally has access to a hypothetical `SqlServerConnection` effect instance.
In other words, the effect instances in this code form layers, can each be implemented in several different ways and are implemented in terms of each other.
Such layers often provide increasingly more abstract interfaces to external effects in the application.

Although we will not elaborate on this here, implementing software by identifying layers of effect abstractions is in fact a very general way to modularly design software.
Conversely, many interfaces and classes in object-oriented software can be understood as effect interfaces and instances to the application's effects (even if they weren't explicitly intended as such).

## Unit Testing and Effect Stubbing ##

One important scenario where the possibility of easily switching to alternative effect implementations is important is during testing.
Unit testing framework often produce their own console output, in order to show the progress and intermediate results of unit tests.
It is a pity if this output is polluted by log messages from the components under test.
We can easily avoid this by instantiating those components, for example, using a `BlackHoleLog` that will throw away log messages during the tests:
```java
class BusinessLogicTest {
    @Test
    public void testDoSomething() {
        BusinessLogic bl = new BusinessLogic(new BlackHoleLog());
        bl.doSomething()
        assertTrue(bl.hasSomethingBeenDone());
    }
}
```
Note that this is very easy here because we are only using the effect of console output.
Testing becomes more difficult if the code also uses effects that produce input, e.g. console input.
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
        if(cursor < MAXLOGS) {
            buffer[cursor++] = msg;
        } else throw new IllegalStateException("Buffer is full");
    }
    public String[] getBuffer() {
        return buffer.clone();
    }
}

class BusinessLogicTest {
    @Test
    public void testDoSomething() {
        BufferLog log = new BufferLog();
        BusinessLogic bl = new BusinessLogic(log);
        bl.doSomething()
        String[] logs = log.getBuffer()
        assertEquals("log message 1", buf[0]);
        assertEquals("log message 2", buf[1]);
        assertNull(buf[2]);
    }
}
```
Using the stored buffer of effects, the above code tests whether the right effects have happened.

## Effect Interfaces in Java ##

Many interfaces and classes in Java are really effect interfaces.
A good example is the `java.io.OutputStream` abstract class in the Java standard library that we show a snippet of here:
```java
public abstract class OutputStream {
    public void write(byte[] b) throws IOException;
}
```
For our purposes, we can construct an abstract class as the same as an interface.
The class offers a `void write(byte[])` method, making it not very different from our `Log` effect interface and its `void logMessage(String)` (if we imagine that a `String` is just a sequence of bytes).
Additionally, the Java standard library offers a number of useful effect instances of `OutputStream` that are sometimes similar to the ones we've sketched here:
* `ByteArrayOutputStream`: similar to our `BufferLog`.
* `FileOutputStream`: writes to a file, similar to the hypothetical `FileLog` which we've mentioned somewhere.
* `CipherOutputStream`: an output stream that applies a cryptographic cipher to the data being written and then writes the resulting bytes to an underlying OutputStream.

Additionally, the `java.io.PrintStream` class extends `OutputStream` with some convenient methods like `void println(String)` and writes data to an underlying OutputStream.
In fact, the object `System.out` which we have been using in our examples is an instance of the `PrintStream`.
As such, our examples have essentially been building a `Log` abstract effect layer on top of an abstract output stream effect layer, although we hadn't initially noticed.

Note that this means we could have implemented `StandardLog` as a wrapper around an output stream to obtain a `Log` effect instance that can write to an arbitrary underlying output stream, whether it streams into a buffer, file or encrypted network connection:
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

# Capabilities and capability-safety #

Let us take another look at a code snippet we have seen above:
```java
public class Application {
    public static void main() {
        BusinessLogic bl = new BusinessLogic( new LogWithPrefix("BusinessLogic says: "));
        Database db = new Database(new LogWithPrefix("Database says: "));
        // ...
    }
}
```
It seems like this approach of using effect abstractions very effectively ensures the intended property:

   Every log message should be prepended with the name of the component that generated it.

Unfortunately, this is only guaranteed under certain assumptions about classes like `BusinessLogic`, namely that:
* `BusinessLogic` only ever logs messages through the `Log` object it receives in its constructor
* The same is true for all methods invoked by the methods of `BusinessLogic`, the methods invoked by those methods etc.
There are many ways that `BusinessLogic` could violate those assumptions, for example:
```java
class Database {
    private Log log;
    // ...
    public Log getLog() {
        return log;
    }
}
class BusinessLogic {
    private Log log;
    private Database db;
    public BusinessLogic(Log log) {
        this.log = log;
    }
    public void problem1() {
        System.out.println("Bypassing the effect abstraction entirely...");
    }
    public void problem2() {
        Log log2 = new StandardLogger();
        log2.logMessage("Constructing a new logger myself...");
    }
    public void problem3() {
        db.getLog().logMessage("Borrowing someone else's logger...")
    }
}
```

This code shows that in Java, the use of effect abstractions is not enforced.
We can easily bypass an abstraction like `Log` by accessing `System.out` directly, by constructing an alternative logger ourselves (which indirectly will access `System.out`) or by using an effect abstraction that the code wasn't supposed to have access to (like `db.getLog()` which should probably not be publicly accessible).
Essentially, the problem in the first two examples is that Java makes primitive effects available to all code in an application, for example by making `System.out` available as a public global variable (and similarly for other effects).
The third example shows that programmers should make sure to properly encapsulate effect abstractions that classes have access to, similar to what they should do for encapsulating internal mutable state of objects.

In some sense, the method `getLog()` in the `Database` class constitutes a form of [representation exposure](#representation-objects-and-representation-exposure).
Roughly, the idea is that we can interpret the log output produced through `Database`'s `log` object as part of its internal representation, so that it is an error to return a reference to the object in `getLog()`.

In some languages like [Pony](https://www.ponylang.io/), the use of effect abstractions is enforced more strictly, by offering a feature known as /capability safety/.
In those languages, primitive effects are never made available through globally accessible APIs like `System.out`.
Rather, they are made available through effect interfaces that are provided as arguments to the main method.
An application can then choose who gets access to those primitive effects by giving them (indirect) access to the effect interfaces or not.
In Java syntax, you may imagine something like this:
```java
class StandardLog implements Log {
    OutputStream out;
    public StandardLog(OutputStream out) {
        this.out = out;
    }
    public void logMessage(String msg) {
        out.println(msg);
    }
}
class MyApplication {
    public static void main(OutputStream stdout, InputStream stdin) {
        Database db = new Database (new StandardLogger(stdout));
        BusinessLogic bl = new BusinessLogic(new BlackHoleLog());
        //...
    }
}
```
The above code gives the `Database` object access to `stdout` through a `StandardLog` object, but not `BusinessLogic`.
In a capability-safe language, the `BusinessLogic` object has no alternative way to access stdout and is in fact guaranteed not to be able to access it.

In such languages, objects implementing effect interfaces do not just represent /a/ way to perform certain effects, but they represent the only way to perform certain effects.
For this reason, references to such objects are called /capabilities/, since they represent the capability or authority of some code to perform certain effects.

Capability safety has many advantages:
- Code Audit. It becomes very easy to verify whether properties about effects are guaranteed in an application.
  For example, in the above `MyApplication` class, it is syntactically clear that the application will never access the standard input channel, and that its behavior does not depend on it.
  Verifying the same property in a Java application would require auditing the entire code base of an application.

- Security. The approach of enforcing a property by only giving components access to capabilities that are guaranteed to respect the property, even works when we invoke untrusted code, i.e. code that is potentially under the control of a malicious adversary.
  This creates an effective way to restrict the authority of untrusted plugins, potentially buggy libraries etc. and can thus be a very effective way to increase the security of software.

