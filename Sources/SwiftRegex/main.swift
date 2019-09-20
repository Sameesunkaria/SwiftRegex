//
//  Created and submitted by:
//  Samar Sunkaria
//  Student ID: 101503191
//
//  Compiler Construction (UCS802) Assignment 1
//  Parsing regular expressions into NFA and DFA
//

//
//  NOTE: Scroll to the bottom of the file to input your own regex, and test strings.
//
//  The code is broken down into four sections. Locate the corresponding MARK comments.
//  - Data Structures
//  - Parsing regex into NFA
//  - Convert NFA into DFA
//  - Recognizing if string belongs to language defined by the regex
//

import Foundation

struct RegexParser {
    let regex: String
    private var expression: Node

    init(regex: String, reduceIntoDFA: Bool = false) {
        self.regex = regex
        self.expression = Node()

        let expression = parseExpression(regex)

        if reduceIntoDFA {
            self.expression = generateReducedExpression(expression: expression, regex: regex)
        } else {
            self.expression = expression
        }
    }

    // MARK: - Data Structures
    private struct Transition: Equatable {
        let state: Substring
        let node: Node
    }

    private class Node: Hashable, Equatable {
        static func == (lhs: Node, rhs: Node) -> Bool {
            return lhs === rhs
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(self).hashValue)
        }

        var isFinal = false
        var transitions = [Transition]()
    }

    private typealias ParsedExpression = (initial: Node, final: Node)

    private enum ExpressionElement {
        case expression(ParsedExpression)
        case operation(Character)
    }


    // MARK: - Parsing regex into NFA
    private func generateTokens(expression: Substring) -> [Substring] {
        var parenthesisCount = 0
        var subExpressionStart: Int?

        var tokens = [Substring]()

        for character in expression.enumerated() {
            switch character.element {
            case "(":
                parenthesisCount += 1
                if subExpressionStart == nil {
                    subExpressionStart = character.offset
                }
            case ")":
                parenthesisCount -= 1
                if parenthesisCount == 0, subExpressionStart != nil {
                    let startIndex = expression.index(expression.startIndex, offsetBy: subExpressionStart! + 1)
                    let endIndex = expression.index(expression.startIndex, offsetBy: character.offset - 1)
                    let subExpression = expression[startIndex...endIndex]

                    tokens.append(subExpression)

                    subExpressionStart = nil
                }

            default:
                if subExpressionStart == nil {
                    let startIndex = expression.index(expression.startIndex, offsetBy: character.offset)
                    let endIndex = expression.index(startIndex, offsetBy: 1)
                    let subExpression = expression[startIndex..<endIndex]
                    tokens.append(subExpression)
                }
            }
        }

        return tokens
    }

    private func generateUnion(from leftParsedExpression: ParsedExpression, and rightParsedExpression: ParsedExpression) -> ParsedExpression {
        let rootNode = Node()
        let finalNode = Node()

        rootNode.transitions.append(Transition(state: "", node: leftParsedExpression.initial))
        rootNode.transitions.append(Transition(state: "", node: rightParsedExpression.initial))

        leftParsedExpression.final.transitions.append(Transition(state: "", node: finalNode))
        rightParsedExpression.final.transitions.append(Transition(state: "", node: finalNode))

        return (rootNode, finalNode)
    }

    private func generateKleeneClosure(from parsedExpression: ParsedExpression) -> ParsedExpression {
        let rootNode = Node()
        let finalNode = Node()

        rootNode.transitions.append(Transition(state: "", node: parsedExpression.initial))
        rootNode.transitions.append(Transition(state: "", node: finalNode))

        parsedExpression.final.transitions.append(Transition(state: "", node: finalNode))
        parsedExpression.final.transitions.append(Transition(state: "", node: parsedExpression.initial))

        return (rootNode, finalNode)
    }

    private func evaluateKleenClosures(on expressionElements: [ExpressionElement]) -> [ExpressionElement] {
        var evaluatedExpressionElements = [ExpressionElement]()
        for element in expressionElements.enumerated() {
            if case .operation("*") = element.element {
                let previousElement = evaluatedExpressionElements.popLast()!
                guard case let .expression(expression) = previousElement else { fatalError("Invalid regex") }
                evaluatedExpressionElements.append(.expression(generateKleeneClosure(from: expression)))
            } else {
                evaluatedExpressionElements.append(element.element)
            }
        }

        return evaluatedExpressionElements
    }

    private func evaluateUnionOperations(on expressionElements: [ExpressionElement]) -> [ExpressionElement] {
        var evaluatedExpressionElements = [ExpressionElement]()

        var skipNext = false

        for element in expressionElements.enumerated() {
            if case .operation("|") = element.element {
                let previousElement = evaluatedExpressionElements.popLast()!

                let nextIndex = element.offset + 1
                guard nextIndex < expressionElements.count else { fatalError("Invalid regex") }
                let nextElement = expressionElements[element.offset + 1]

                guard
                    case let .expression(leftExpression) = previousElement,
                    case let .expression(rightExpression) = nextElement
                    else { fatalError("Invalid regex") }

                evaluatedExpressionElements.append(.expression(generateUnion(from: leftExpression, and: rightExpression)))
                skipNext = true
            } else if skipNext {
                skipNext = false
                continue
            } else {
                evaluatedExpressionElements.append(element.element)
            }
        }

        return evaluatedExpressionElements
    }

    private func reduceExpressionIntoConcatenation(_ expressionElements: [ExpressionElement]) -> [ParsedExpression] {
        let expressionWithUnionAndConcatenationOperations = evaluateKleenClosures(on: expressionElements)
        let expressionWithOnlyConcatenationOperations = evaluateUnionOperations(on: expressionWithUnionAndConcatenationOperations)

        return expressionWithOnlyConcatenationOperations.map {
            guard case let .expression(expression) = $0 else { fatalError("Invalid regex") }
            return expression
        }
    }

    private func evaluateConcatenation(on expression: [ParsedExpression]) -> ParsedExpression {
        let rootNode = Node()
        var finalNode = rootNode

        for element in expression {
            finalNode.transitions = element.initial.transitions
            finalNode = element.final
        }

        return (rootNode, finalNode)
    }

    private func parseToken(expression: Substring) -> ParsedExpression {

        if expression.count == 1 {
            let rootNode = Node()
            let transition = Transition(state: expression, node: Node())
            rootNode.transitions.append(transition)
            return (rootNode, transition.node)
        }

        let tokens = generateTokens(expression: expression)

        var expressionElements = [ExpressionElement]()

        for token in tokens {
            switch token {
            case "*", "|": expressionElements.append(.operation(token.first!))
            default: expressionElements.append(.expression(parseToken(expression: token)))
            }
        }

        return evaluateConcatenation(on: reduceExpressionIntoConcatenation(expressionElements))
    }

    private func parseExpression(_ regex: String) -> Node {
        let parsedExpression = parseToken(expression: Substring(regex))
        parsedExpression.final.isFinal = true
        return parsedExpression.initial
    }

    // MARK: - Convert NFA into DFA
    private func getAllNodes(from expression: Node, into set: Set<Node> = Set<Node>()) -> Set<Node> {
        var nodes = set
        nodes.insert(expression)
        for transition in expression.transitions {
            if nodes.contains(transition.node) { continue }
            nodes = getAllNodes(from: transition.node, into: nodes)
        }

        return nodes
    }

    private func generateEpsilonClosure(for node: Node, into set: Set<Node> = Set<Node>()) -> Set<Node> {
        var epsilonAcessibleNodes = set
        epsilonAcessibleNodes.insert(node)

        for transition in node.transitions {
            guard transition.state == "" else { continue }
            if epsilonAcessibleNodes.contains(transition.node) { continue }
            epsilonAcessibleNodes = generateEpsilonClosure(for: transition.node, into: epsilonAcessibleNodes)
        }

        return epsilonAcessibleNodes
    }

    private func getInputSymbols(for regex: String) -> Set<Substring> {
        var symbols = Set<Substring>()
        for character in regex {
            switch character {
            case "|", "*", "(", ")": continue
            default: symbols.insert(Substring(String(character)))
            }
        }

        return symbols
    }

    private func generateDFA(from state: Set<Node>, symbols: Set<Substring>, into automaton: [Set<Node> : Node] = [Set<Node> : Node]()) -> [Set<Node> : Node] {

        var dfa = automaton

        let node = Node()
        dfa[state] = node

        let allTransitions = state.flatMap { $0.transitions }

        for symbol in symbols {
            let transitionsForSymbol = allTransitions.filter { $0.state == symbol }
            if transitionsForSymbol.isEmpty { continue }

            let nextState = transitionsForSymbol
                .map{ generateEpsilonClosure(for: $0.node) }
                .reduce(Set<Node>()) { $0.union($1) }

            if dfa[nextState] == nil {
                dfa = generateDFA(from: nextState, symbols: symbols, into: dfa)
            }

            node.transitions.append(Transition(state: symbol, node: dfa[nextState]!))
        }

        return dfa
    }

    private func generateReducedExpression(expression: Node, regex: String) -> Node {
        let initialSet = generateEpsilonClosure(for: expression)
        let dfa = generateDFA(from: initialSet, symbols: getInputSymbols(for: regex))
        let initialNode = dfa[initialSet]!

        for set in dfa {
            set.value.isFinal = set.key.map { $0.isFinal }.contains(true)
        }

        return initialNode
    }

    // MARK: - Recognizing if string belongs to language defined by the regex
    private func recognize(string: Substring, in expression: Node) -> Bool {

        if expression.isFinal, string.isEmpty {
            return true
        }

        for transition in expression.transitions {
            if transition.state.isEmpty {
                if recognize(string: string, in: transition.node) {
                    return true
                }
            } else if string.isEmpty {
                continue

            } else if transition.state == string[...string.startIndex] {
                if recognize(string: string.dropFirst(), in: transition.node) {
                    return true
                }
            }
        }

        return false
    }

    func recognize(string: String) -> Bool {
        return recognize(string: Substring(string), in: expression)
    }

    func printBasicAutomatonDescription() {
        let allNodes = getAllNodes(from: expression)
        let nodeNames = Dictionary(uniqueKeysWithValues: allNodes.enumerated().map { ($0.element, $0.offset) })

        print("Description of automation representing: \(regex)")
        print("Each line represents a node.\n")
        print("There are a total of \(allNodes.count) nodes.")
        print("State\tisFinal\t\tTransition states")
        print(allNodes.map {
            "\(nodeNames[$0]!)\t\t\($0.isFinal)\t\t\($0.transitions.map { t in "\(t.state) -> \(nodeNames[t.node]!)" })\n"
        }.reduce("", +))
    }
}


let regex1 = "(a|b)*abb"
let testString1 = "aabb"

// NFA
let nfaParser1 = RegexParser(regex: regex1)
print("String \"\(testString1)\" recognized: \(nfaParser1.recognize(string: testString1))")
nfaParser1.printBasicAutomatonDescription()

// DFA
let dfaParser1 = RegexParser(regex: regex1, reduceIntoDFA: true)
print("String \"\(testString1)\" recognized: \(dfaParser1.recognize(string: testString1))")
dfaParser1.printBasicAutomatonDescription()



let regex2 = "(a(b|c)d)*|ef*"
let testString2 = "acdf"

// NFA
let nfaParser2 = RegexParser(regex: regex2)
print("String \"\(testString2)\" recognized: \(nfaParser2.recognize(string: testString2))")
nfaParser2.printBasicAutomatonDescription()

// DFA
let dfaParser2 = RegexParser(regex: regex2, reduceIntoDFA: true)
print("String \"\(testString2)\" recognized: \(dfaParser2.recognize(string: testString2))")
dfaParser2.printBasicAutomatonDescription()
