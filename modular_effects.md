TODO:
* Clarify terminology a bit more using examples: side-effects per component, "externally observable side-effects" etc.
* Explain that a PrintStream is already the kind of effect abstraction we describe.
* Discuss alternative solution of using `System.setOut()`

# Modular External Effects

A common characteristic of the code examples we have seen so far is that they do not interact with the outside world.
The code presented performs computations and modifies the internal state of data abstractions, but it does not, for example, directly interact with the network, hard drive or display of the computer on which it is running.
The absence of such external effects differentiates our examples so far from the code of many software applications, where interactions with the outside world are an important part of the software's intended behavior.
For example, an interactive 3D computer games is designed to continuously receive user input, compute the updated state of the game and render it on the user's display.
Similarly, a network server is designed to continuously receive network requests and respond to them according to its configuration.
Responding to a network request may involve reading data from the hard drive or sending outgoing network requests to a database or other server.

Generally, when a program interacts with components outside its own memory, we will refer to this as "external effects".
This type of effects should not be confused with interaction with the program's own mutable state (such as mutable static or instance fields of classes or objects) or the use of exceptions or other non-standard control flow primitives (e.g. some languages offer continuations), which we will refer to here as "internal effects" to disambiguate.
Both internal and external effects of a program, component or method are sometimes called its "side effects".
This term suggests the perspective that executing a piece of software produces certain direct results in the form of computation results, while interactions with the outside world are indirect or side results.
Some people use the term "effects" instead, perhaps taking the perspective that interactions with the outside world are often the most important result of running software.

## Console interaction
A very simple example involving external effects is the prototypical "Hello World!" application:
```java
class HelloWorld {
    public static void main(String[] args) {
        System.out.println("Hello World!");
    }
}
```
When this application is run, it will print the string "Hello World!" to its standard output channel.
When using Eclipse, this output will be displayed in the "Console" view when executing the program.
The code uses the method `println(String)` on the public static member `out : PrintStream` of Java's built-in class `System`.
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

In this section, we will discuss how a program can deal modularly with external effects.
For ease of discussion, we will use console output as a recurring example in this chapter.
However, all of our discussion applies equally to other types of external effects.

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
1. Every log message should be prepended with the name of the component that generated it.
1. Finally, we'd like to be sure that some components never log anything.

It should be clear that none of these requirements will be easy to implement.
Essentially, developers will have to do a manuall pass over the entire application source code, and:
* track down all places where something is printed to `System.out`.
* determine whether a log message is being printed or something else.
* modify the print statement to implement the new requirement from the list above.
When another new requirement needs to be implemented, the same procedure will have to be followed again, resulting in a lot of manual effort and a lot of opportunities for making a mistake.

The reason that these requirements are hard to implement is that the original code was not implemented well.
Essentially, the responsibility for interacting with the application's log output was distributed over all the code in the application, rather than centralized in a single place.
Because the responsibility is shared, changing requirements about logging require modifying all the code that is jointly responsible for it.

## Effect abstractions ##

An interesting perspective to understand the problem and how to solve it, is to imagine that `System.out` does not represent output to an output channel outside the application, but instead logs all messages to an in-memory buffer.
From this perspective, our example code above is similar to a situation where a piece of mutable state that is directly accessed from many different places in the application.
The new requirements essentially correspond to modifying the representation of this internal state and imposing invariants on it and they are hard to implement because the state is not properly encapsulated.
If we had used a data abstraction (as introduced in [a previous section](#managing-complexity-through-modularity-and-abstraction)) to encapsulate this internal state, then many of the requirements above could be implemented simply by modifying the data abstraction and leaving its clients untouched.
As such, the data abstraction would save us a big amount of work.

Of course, we do not actually want to replace the application's standard with an in-memory buffer, but we can still get inspiration from the analogy.
Similarly to how we might place a data abstraction around a piece of internal state, we can place an effect abstraction around `System.out`.
Similar to how a data abstraction is responsible for representing the internal state and enforcing invariants on it, the effect abstraction will be responsible for implementing the effect (for example, log to standard output or to the network) and enforcing invariants or protocols on the external effects.

Concretely, such an effect abstraction might be implemented as follows:
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

If we ensure that all log messages in the entire application are printed using `Log.logMessage` rather than directly through `System.out.println`, then it becomes significantly easier to implement the changing requirements mentioned above.

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
The different styles have the same benefits as we've seen before when we've used them for enforcing invariants on abstract state or representation invariants on representation state.

The second requirement

    All log messages should contain a timestamp in addition to their current content, so that developers can investigate which operations are taking an unnecessarily long time.

and the third requirement

    All log messages should be logged to a different output channel, depending on a user configuration

similarly become easy to implement, but we leave them as an exercise for the reader.

Unfortunately, it has not yet become as easy to implement the remaining two requirements, but we will come back to this [later](#TODO):
* Every log message should be prepended with the name of the component that generated it.
* Finally, we'd like to be sure that some components never log anything.
