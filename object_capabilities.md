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

In some sense, the method `getLog()` in the `Database` class constitutes a form of [representation exposure](representation_objects.md).
Roughly, the idea is that we can interpret the log output produced through `Database`'s `log` object as part of its internal representation, so that it is an error to return a reference to the object in `getLog()`.

In some languages like [Pony](https://www.ponylang.io/), the use of effect abstractions is enforced more strictly, by offering a feature known as *capability safety*.
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
        Database db = new Database (new StandardLog(stdout));
        BusinessLogic bl = new BusinessLogic(new BlackHoleLog());
        //...
    }
}
```
The above code gives the `Database` object access to `stdout` through a `StandardLog` object, but not `BusinessLogic`.
In a capability-safe language, the `BusinessLogic` object has no alternative way to access stdout and is in fact guaranteed not to be able to access it.

In such languages, objects implementing effect interfaces do not just represent *a* way to perform certain effects, but they represent the only way to perform certain effects.
For this reason, references to such objects are called *capabilities*, since they represent the capability or authority of some code to perform certain effects.

Capability safety has many advantages:
- Code Audit. It becomes very easy to verify whether properties about effects are guaranteed in an application.
  For example, in the above `MyApplication` class, it is syntactically clear that the application will never access the standard input channel, and that its behavior does not depend on it.
  Verifying the same property in a Java application would require auditing the entire code base of an application.

- Security. The approach of enforcing a property by only giving components access to capabilities that are guaranteed to respect the property, even works when we invoke untrusted code, i.e. code that is potentially under the control of a malicious adversary.
  This creates an effective way to restrict the authority of untrusted plugins, potentially buggy libraries etc. and can thus be a very effective way to increase the security of software.
