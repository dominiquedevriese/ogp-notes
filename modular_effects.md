# Effects

A common characteristic of the code examples we have seen so far is that they do not interact with the outside world.
The presented code performs computations and modifies the internal state of data abstractions, but it does not, for example, directly produce output, interact with the network, hard drive or display of the computer on which it is running.
The absence of such external effects differentiates our examples so far from the code of many software applications, where interactions with the outside world are an important part, if not the whole point, of the software's intended behavior.
For example, an interactive 3D computer games is designed to continuously receive user input, compute the updated state of the game and render it on the user's display.
Similarly, a network server is designed to continuously respond to incoming network requests according to its configuration.
In doing so, it may read data from the hard drive or send outgoing network requests to a database or other server, and wait for and use the responses to these requests.

Generally, when a program interacts with components outside its own private memory, we refer to this as "external effects".
This type of effects should not be confused with "internal effects": interactions with the program's own mutable state (such as mutable fields of objects) or the use of exceptions or other control flow primitives (e.g. continuations) which are not observable outside the program.
Both internal and external effects of a program, component or method are sometimes called "side effects" or (preferably) "effects".
The term "side effects" suggests that executing a piece of software always produces certain direct results (e.g., an exit status), while interactions with the outside world are indirect or side results.
This is usually incorrect since effects are very often the main or only reason for executing certain code and can hardly be considered a side result.
For this reason, we prefer to use the term "effects".

The boundary between internal and external effects is not 100% clear-cut.
For example, in some contexts, the allocation of internal memory might be considered as a purely internal effect, but in other contexts, it may be regarded as an external effect, because it can be observable to outside code (since memory usage by one program affects the memory available to other programs), or because we may be trying to limit the memory used by a program.

## How external effects are (not) different from internal effects

Before we look at concrete examples, we want to take a step back and mention two points about how external effects are different from internal effects and how they are similar.
We will explain that (1) contrary to internal effects, external effects affect the correctness of software directly rather than indirectly, but (2) similar to internal effects, it is useful to keep external effects abstract in other components.

### External effects are of direct importance.

[AVM: I don't fully understand the difference.
"breaking a representation invariant will only indirectly affect the correctness of the software as a whole"
If a private method unexpectedly crashes on some range of inputs, it can directly affect clients of the class. I think I don't understand the way you use "indirectly" in this subsection.]

Some of the techniques that we have already seen in previous chapters enforce some kind of restriction on internal effects.
For instance, representation invariants enforce that the effect of mutating the internal state of an object in a method never results in a new inconsistent state.
When we use a representation invariant to constrain the internal effects of methods, this is not of direct importance in the sense that human users of the software or other systems it communicates with will never directly observe this internal state.
Instead, we only use representation invariants to make it easier to satisfy contracts, i.e. validate postconditions, preserve class invariants etc.
[AVM: I don't understand the following sentence ("indirectly affect").]
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
It also allowed us to easily [change representations](lecture2part1.md#encapsulating-the-fields-of-class-interval): properly encapsulated classes can switch to a different representation without breaking their clients' expectations.
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
It does not apply the main principle of this course ([modular programming](lecture2part1.md)) when it comes to effects.
Essentially, the responsibility for interacting with the application's log output was distributed over all the code in the application, rather than centralized in a single place.
Because the responsibility is shared, changing requirements about logging require modifying all the code that is jointly responsible for it.
Another way to say this is that the logging effect was not properly encapsulated.

This situation is very similar to what happens if we do not encapsulate the internal state of a class.
Imagine that all components in a system would have direct access to implementation details of a class like `Interval` (see [before](lecture2part1.md#the-problem)), i.e. the class `Interval`'s fields are public and other code reads and writes the fields directly.
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
In this scenario, the `System.out.println(...)` statements that we had before correspond to direct updates of the `System.out` global variable.
Implementing the application features 1-2-3 listed above would require modifying the internal representation of this variable and imposing invariants on it.
This is hard to implement because the state is not encapsulated, but accessed directly by all other components.
Instead, it would have been better to use a [data abstraction](complexity_modularity_abstraction.md#data-abstractions), for example like this:
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

A first way to do this is in the form of a [procedural abstraction](complexity_modularity_abstraction.md#procedural-abstractions), by defining a class Log with  a public static procedure `logMessage`, which implements logging once and for all:
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

But what if we want to enforce properties about effects that may mutate memory ("stateful effects"), for example:

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

