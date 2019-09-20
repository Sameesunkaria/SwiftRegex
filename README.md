# SwiftRegex

```
Compiler Construction (UCS802) Assignment 1
Parsing regular expressions into NFA and DFA
```

### Created and submitted by:
```
Samar Sunkaria
Student ID: 101503191
```

## Introduction 

SwiftRegex is a regular expression parser, written in Swift 5.0. 

SwiftRegex has a type called `RegexParser`, which is responsible for taking in a regular expression in the form of a string, and converting it into an NFA or further into a DFA. 

The regular expression can have all unicode symbols as part of the alphabet, except `|`, `*`, `(` and `)`. The first two represent the "or" operation (`|`) and the "Kleene Closure" operation (`*`). The parenthesis are used to define the precedence of operations. All other characters are treated as a part of the alphabet.

SwiftRegex supports three operations, "Kleene Closure", "or" and "concatenation". If no operation is defined between two characters, a "concatenation" is inferred.

## Running the code

There is a single Swift file, titled `main.swift`. If you have the Swift compiler installed on your system, you can just run this code by running the command `swift main.swift`.

If you do not have the Swift compiler installed, there are several online compilers (or playgrounds) for Swift. I have sucessfully tested this project on [https://repl.it/languages/swift](https://repl.it/languages/swift).

## Usage

The struct `RegexParser` can be initialized with a regular expression in the form of a string. By default `RegexParser` will generate an NFA for the regular expression it was initialized with. 

```swift
let parser = RegexParser(regex: "(a|b)*abb")
```

At the time of initialization, we can pass in `true` for `reduceIntoDFA`, if we want the automaton to be converted from an NFA into a DFA. 

```swift
let parser = RegexParser(regex: "(a|b)*abb", reduceIntoDFA: true)
```

To evaluate if a string belongs to the language defined by the regular expression passed into the `RegexParser`, we can use the `recognize(string:)` method on `RegexParser`. This method returns a `Bool`, specifying if the test string was recognized to be a part of the language.

```swift
parser.recognize(string: "aabb")
```

You can also get a basic description of the automaton created by using the `printBasicAutomatonDescription` method on `RegexParser`. This prints out the number of nodes in the graph, reprsenting the underlying structure of the automaton. It also displays if a node is set to be the final node, and all of its transition states. 

```swift
parser.printBasicAutomatonDescription()
```

The output should look similar to this:

```
Description of automation representing: (a|b)*abb
Each line represents a node.

There are a total of 5 nodes.
State    isFinal        Transition states
0        false         ["b -> 4", "a -> 0"]
1        true          ["b -> 3", "a -> 0"]
2        false         ["b -> 3", "a -> 0"]
3        false         ["b -> 3", "a -> 0"]
4        false         ["b -> 1", "a -> 0"]
```

## Implementation

### Data structure representing the automaton

The automation has been represented using a series of nodes, that hold the transitions information as well as a flag which states if it is a final node.

```swift
class Node {
    var isFinal = false
    var transitions = [Transition]()
}
```

A `Transition` holds the transition state, and a pointer to the next `Node`.

```swift
struct Transition {
    let state: Substring
    let node: Node
}
```

**NOTE:** An epsilon/empty transtion, is denoted by an empty `state` string (`""`).

### Parsing the regular expression into NFA

The regular expression string is parsed recursively, in two steps. 

The first step is tokenizing the string into set of single expressions and operations. And the second step is to convert the expressions into their graph representation and apply the operations.

Tokenizing the regular expression string is handeled by the `generateTokens(expression:)` method. So, for our regular expression `(a|b)*abb`, the generated tokens are

```
["a|b", "*", "a", "b", "b"]
```

Now, all expressions are converted into their graph representation. Single character expressions are replaced, with two nodes and a transition from the first node to the second one, with the transition state being the character itself.

Here, `a|b` is also a single expression, but since it is not represented by a single character, it has to be evaluated seperately before we can evaluate our complete expression. Hence, the recursive nature of this alogrithm.

Once the tokens are generated, and all the single expressions are evaluated, now the operations are applied. 

The operations of the single expressions are applied in a sequential order based on the precedence of the operator.

- Kleene Closure: `evaluateKleenClosures(on:)`
- OR: `evaluateUnionOperations(on:)`
- Concatenation: `evaluateConcatenation(on:)`

After evaluating all the operations on the single expressions represented with a graph, a complete graph is generated. And the final node has its `isFinal` flag set to `true`. 

This is done in the method `parseExpression`.

This expression is used to evaluate our test strings.

### Converting the NFA into a DFA

To convert the NFA into a DFA, we need to have a set of all the nodes, in our graph. To find that, a depth first search algorithm is used.

All the nodes conform to the swift protocol `Hashable`, and hence, can be stored in a Swift `Set`.

Now we create an epsilon closure for each of the nodes. This closure is stored as a `Set<Node>`. This is crutial, since we would need to perform set operations on the epsilon closures.

We also need to know all of the symbols in the alphabet of the language, which is done by the method `getInputSymbols(for:)`.

Finally, the `generateDFA(from:symbols:)` method, takes in the NFA expression, and converts it into a DFA.

### Recognizing strings

To recognize if a test string belongs in the language represented by a regular expression, the `recognize(string:)` method is used. This method recursively checks if the string belongs to the language.

The transition states of the parsed expression, are compared against the first letter of the test string, and if the state matches, a substring from the second letter onwards is checked against the expression starting from the next node after transition.

In the case of an epsilon transition (transition state: `""`), the complete string is compared against the expression starting from the next node after transition.

