# Effects

A common characteristic of the code examples we have seen so far is that they do not interact with the outside world.
The code presented performs computations and modifies the internal state of data abstractions, but it does not, for example, directly interact with the network, hard drive or display of the computer on which it is running.
The absence of such external effects differentiates our examples so far from the code of many software applications, where interactions with the outside world are an important part (if not the whole point) of the software's intended behavior.
For example, an interactive 3D computer games is designed to continuously receive user input, compute the updated state of the game and render it on the user's display.
Similarly, a network server is designed to continuously respond to incoming network requests according to its configuration.
In doing so, it may read data from the hard drive or send outgoing network requests to a database or other server, and wait for and use the responses to these requests.

Generally, when a program interacts with components outside its own private memory, we will refer to this as "external effects".
This type of effects should not be confused with "internal effects": interactions with the program's own mutable state (such as mutable static or instance fields of classes or objects) or the use of exceptions or other control flow primitives (e.g. continuations) which are not observable outside the program at hand.
Both internal and external effects of a program, component or method are sometimes called "side effects" or (preferably) "effects".
The term "side effects" suggests the perspective that executing a piece of software produces certain direct results in the form of computation results, while interactions with the outside world are indirect or side results.
This is often incorrect since effects are very often the main or only reason for executing certain code and can hardly be considered a side result.
For this reason, we prefer to use the term "effects".

Exactly what constitutes an internal or external effect is not always 100% clear-cut.
For example, in some contexts, the allocation of internal memory might be regarded as an external effect, because it can be externally observable to outside code, or because we might care about limiting the amount of memory used by a program, while in other contexts, it might be considered as purely internal computation.

## How external effects are (not) different from internal effects

Before we look at concrete examples, it is useful to take a step back and think about how external effects are related to internal effects: in which aspects they are similar and in which aspects they are different: we will explain here that (1) contrary to internal effects, external effects affect the correctness of software directly rather than indirectly, but (2) similar to internal effects, it is useful to keep external effects abstract in other components.

### External effects are of direct importance
Some of the techniques that we have already seen in previous chapters enforce some kind of restriction on internal effects.
Particularly, representation invariants enforce that internal state of an object is never modified in such a way that it breaks the representation invariant.
When we use a representation invariant to constrain the internal effects of methods, this is not of direct importance in the sense that human users of the software or other systems it communicates with will ever directly observe this internal state.
Instead, we only do it to make it easier to satisfy contracts, i.e. validate postconditions, preserve class invariants etc.
In this sense, representation invariants are only indirectly important: breaking a representation invariant will only indirectly affect the correct behavior of the software as a whole.

Ultimately, internal effects are only ever a means to an end, an implementation detail that is unobservable to outside systems and humans and only used internally to implement methods.
As mentioned above, the situation is different for external effects: these are often the ultimate purpose of an application and directly observable to outside systems or humans.
As such, correctness of external effects is not just important indirectly but their correctness directly affects the correct behavior of software applications.

For example, if we are implementing a network server application, then ensuring the application's correctness means ensuring various properties of the external effects of the application:
* The server should regularly listen on network sockets for incoming requests.
* When a packet comes in, the server should respond by outputting a corresponding response.
* Outgoing responses should always be formatted according to the protocol implemented.
* Outgoing responses should always contain the information that corresponds to the incoming request according to their configuration.
* Outgoing responses should never leak confidential information unless the request has been succesfully authenticated and authorized.
* ...

### Abstract effects

Despite this difference, there is also a way that external effects are similar to internal effects.

Enforcing representation invariants was only possible when classes' internal state was properly encapsulated by making all class variables private and by avoiding representation exposure.
However, this was not the only reason for encapsulating internal state.
It also allowed us to easily change representations: properly encapsulated classes can easily switch to a different representation without breaking their clients' expectations.
TODO: where is this explained in the course?

In other words, when an API is properly encapsulated, clients can be left unaware of which internal effects were used to implement the API.
When dealing with external effects, we often encounter similar situations.
For example, when a webserver invokes a database, it is often desirable to keep the server code unaware of how this database is accessed: as an in-memory database (requiring only internal effects to access), a database on the local disk (requiring access to disk to access) or a remote database accross the internet (accessed by communicating over the network).
Similarly, when the webserver needs to log messages, it is best to keep it unaware of how log messages are stored (e.g. on the local disk, on a developer console, on a remote log server etc.), the format in which log messages are stored, whether some kind of filtering is applied before logging (e.g. to anonymize clients' private information before developers access the logs) etc.
By keeping the web server unaware of such details, it will not need to be changed when something changes about how logs happen.

## Basic Console Effects in Java ##

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

## A non-modular treatment of effects ##

Now imagine that an application uses console output for logging purposes.
Concretely, we will suppose that different components in the codebase output a message on the console output to keep track of the internal steps they have performed and errors they encounter as part of responding to a user request.
Keeping such a log is common practice in many applications as a way to facilitate debugging errors or analyzing the behavior of the application when providing technical support to users.

Concretely, the code might look as follows:
```java
package parsing;

class InputParser {
    Request parseInput(String userInput) {
        //...
        System.out.println("Finished parsing: input was '" + userInput + "', parsed request is '" + result.toString() + "'.")
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
        System.out.println("Started modifying user record in database: '" + entryId + "', '" + newData.toString() + "'.");
        //...
        System.out.println("Finished modifying user record in database: '" + entryId + "'.");
    }
}
```
The code suggests different components of the application (a user input parser, a class responsible for the business logic and a class responsible for accessing the database).
All three components log technical details of their operation to `System.out`.
We are only showing a few instances where this happens, but one should imagine that similar logging operations are scattered accross the entire application source code.

Now imagine that for a next version of the application, the development team is asked to improve the usefulness of the log messages, in one of the following ways:
1. Log messages should be shorter than a fixed maximum length.
1. All log messages should contain a timestamp in addition to their current content, so that developers can investigate which operations are taking an unnecessarily long time.
1. All log messages should be logged to a different output channel, depending on a user configuration.
   Log messages may be logged, for example, to standard output (through `System.out` as before), sent over the network to a dedicated server or be ignored completely.

It should be clear that none of these requirements will be easy to implement.
Essentially, developers will have to do a manual pass over the entire application source code, and:
* track down all places where something is printed to `System.out`.
* determine whether a log message is being printed or something else.
* modify the print statement to implement the new requirement from the list above.
When another new requirement needs to be implemented, the same procedure will have to be followed again, resulting in a lot of manual effort and a lot of opportunities for making a mistake.

The reason that these requirements are hard to implement is that the original code was not implemented well.
Essentially, the responsibility for interacting with the application's log output was distributed over all the code in the application, rather than centralized in a single place.
Because the responsibility is shared, changing requirements about logging require modifying all the code that is jointly responsible for it.

In other words, the logging effect was not properly encapsulated.
Instead, all components in the application directly interact with the underlying console output to log messages.
This is very similar to not encapsulating the internal state of a class.
Imagine that all components in a system would have direct access to implementation details of a class like `Interval` from previous chapters, i.e. its fields are public and components directly read and write to the fields directly.
That would make it impossible to enforce invariants on the internal state of the class and it would also make it impossible to change to a different internal representation.
The problem in our logging example is no different: internal implementation details of the logging effect are not properly encapsulated and because of this, it is impossible to enforce properties on what is logged or change to a different implementation of the logging effect.

# Procedural Effect Abstractions #

An interesting perspective to understand the problem and how to solve it, is to imagine that `System.out` does not represent output to an output channel outside the application, but instead logs all messages to an in-memory buffer.
As explained already, our problematic logging example is similar to a situation where a piece of mutable state that is directly accessed from many different places in the application.
The new requirements essentially correspond to modifying the representation of this internal state and imposing invariants on it and they are hard to implement because the state is not properly encapsulated.
If we had used a data abstraction (as introduced in [a previous section](#managing-complexity-through-modularity-and-abstraction)) to encapsulate this internal state, then many of the requirements above could be implemented simply by modifying the data abstraction and leaving its clients untouched.
As such, the data abstraction would save us a big amount of work.

Of course, we do not actually want to replace the application's standard with an in-memory buffer, but we can still get inspiration from the analogy.
Similarly to how we might place a data abstraction around a piece of internal state, we can place an effect abstraction around `System.out`.
Similar to how a data abstraction is responsible for representing the internal state and enforcing invariants on it, the effect abstraction will be responsible for implementing the effect (for example, log to standard output or to the network) and enforcing invariants or protocols on the external effects.

One way to do this is in the form of a procedural abstraction, by defining a class Log with  a public static procedure `logMessage`, which implements logging once and for all:
```java
public class Log {
	public static void logMessage(String msg) {
		System.out.println(msg);
	}
}
```
All other components in the application would then invoke the static method `Log.logMessage()` rather than `System.out.println()`, for example:
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

For example, the first requirement stated

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
All three of these solutions are only possible because there is a single central effect abstraction for logging.
The different styles have the same benefits as we've seen before when we've used them for enforcing invariants on abstract state or representation invariants on internal state.

The second requirement

    All log messages should contain a timestamp in addition to their current content,
    so that developers can investigate which operations are taking an unnecessarily long
    time.

and the third requirement

    All log messages should be logged to a different output channel, depending on a
    user configuration

similarly become easy to implement, but we leave them as an exercise for the reader.

# Stateful Effect Abstractions #

- stateful effect abstractions die een protocol afdwingen en de link met invarianten, abstracte state en pre- en postcondities
- de afweging tussen static methodes, het singleton patroon en constructor injection

# Effect Interfaces #

Encapsulating effects is clearly a big improvement already, but our current procedural effect abstractions still have certain limitations.
The current solutions assume essentially that the application uses only a single way to log messages.
For example, imagine that some components of the application need to log to a different destination than others (for example, different log files, a server on the network, etc.) or that the MAXIMUM_LENGTH restriction applies to some of the components but not others.

Of course, we could extend our `Log` class with a second static method that can be invoked by components that require an alternative form of logging:
```java
public class Log {
    public static final int MAXIMUM_LENGTH = 100;
	public static void logMessageStandard(String msg) {
        if(msg.length > MAXIMUM_LENGTH) throw new IllegalArgumentException("message too long: '" + msg + "'");
		System.out.println(msg);
	}
    public static void logMessageWithoutRestriction(String msg) {}
		System.out.println(msg);
	}
}
```
However, even this requires us to decide upfront for every component which type of logging to use and changing a component to a different kind of logging is very difficult.
In other words, our use of (stateful) procedural effect abstractions already allows us to impose constraints on the logs or change the implementation of logging in a central place, but it does not yet offer abstract effects, in the sense that components cannot be entirely agnostic about which type of logging they require.

Fortunately, we have already seen the solution for this problem: polymorphism.
We can change our `Log` class to an interface so that we can provide several different implementations of it:
```java
public interface Log {
	public void logMessage(String msg);
}
public class StandardLog implements Log {
    public void logMessage(String msg) {
        System.out.println(msg);
    }
}
public class LengthRestrictedLog {
    public static final int MAXIMUM_LENGTH = 100;
	public static void logMessage(String msg) {
        if(msg.length > MAXIMUM_LENGTH) throw new IllegalArgumentException("message too long: '" + msg + "'");
		System.out.println(msg);
	}
}
```
While previously, we could include only one of the different logging implementations, we can now include all of them.

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
We can easily instantiate a client class like `BusinessLogic` with a different implementation of `Log` by providing it to the constructor.
In fact, several instances of the class can use different implementations of `Log`.

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

One important scenario where the possibility of easily switching to alternative effect implementations is important is during testing.
TODO: stubbing etc.

- het belang van effect interfaces bij testen van effectvolle code, stubs e.d.
- Explain that a PrintStream is already the kind of effect abstraction we describe.
- Discuss alternative solution of using `System.setOut()`

# Capabilities and capability-safety #

- Use of effect abstractions is not enforced...
- Disadvantages: security, code audit
- Alternative: capability-safety
- Then effect abstraction does not just represent a way to perform certain effects, but *the only* way to do so.
  IOW, the authority to perform certain effects
  Discuss capabilities in Pony


TODO:
- meerdere lagen van effect abstracties

1. Finally, we'd like to be sure that some components never log anything.
