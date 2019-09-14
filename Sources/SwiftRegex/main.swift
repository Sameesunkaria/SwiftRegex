import Foundation

struct Transition {
    let state: Substring
    let node: Node
}

class Node {
    var isFinal = false
    var transitions = [Transition]()
}

typealias ParsedExpression = (initial: Node, final: Node)

enum ExpressionElement {
    case expression(ParsedExpression)
    case operation(Character)
}

func generateTokens(expression: Substring) -> [Substring] {
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

func generateUnion(from leftParsedExpression: ParsedExpression, and rightParsedExpression: ParsedExpression) -> ParsedExpression {
    let rootNode = Node()
    let finalNode = Node()

    rootNode.transitions.append(Transition(state: "", node: leftParsedExpression.initial))
    rootNode.transitions.append(Transition(state: "", node: rightParsedExpression.initial))

    leftParsedExpression.final.transitions.append(Transition(state: "", node: finalNode))
    rightParsedExpression.final.transitions.append(Transition(state: "", node: finalNode))

    return (rootNode, finalNode)
}

func generateKleeneClosure(from parsedExpression: ParsedExpression) -> ParsedExpression {
    let rootNode = Node()
    let finalNode = Node()

    rootNode.transitions.append(Transition(state: "", node: parsedExpression.initial))
    rootNode.transitions.append(Transition(state: "", node: finalNode))

    parsedExpression.final.transitions.append(Transition(state: "", node: finalNode))
    parsedExpression.final.transitions.append(Transition(state: "", node: parsedExpression.initial))

    return (rootNode, finalNode)
}

func evaluateKleenClosures(on expressionElements: [ExpressionElement]) -> [ExpressionElement] {
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

func evaluateUnionOperations(on expressionElements: [ExpressionElement]) -> [ExpressionElement] {
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

func reduceExpressionIntoConcatenation(_ expressionElements: [ExpressionElement]) -> [ParsedExpression] {
    let expressionWithUnionAndConcatenationOperations = evaluateKleenClosures(on: expressionElements)
    let expressionWithOnlyConcatenationOperations = evaluateUnionOperations(on: expressionWithUnionAndConcatenationOperations)

    return expressionWithOnlyConcatenationOperations.map {
        guard case let .expression(expression) = $0 else { fatalError("Invalid regex") }
        return expression
    }
}

func evaluateConcatenation(on expression: [ParsedExpression]) -> ParsedExpression {
    let rootNode = Node()
    var finalNode = rootNode

    for element in expression {
        finalNode.transitions = element.initial.transitions
        finalNode = element.final
    }

    return (rootNode, finalNode)
}

func parseToken(expression: Substring) -> ParsedExpression {

    if expression.count == 1 {
        let rootNode = Node()
        let transition = Transition(state: expression, node: Node())
        rootNode.transitions.append(transition)
        return (rootNode, transition.node)
    }

    let tokens = generateTokens(expression: expression)
    print(tokens)

    var expressionElements = [ExpressionElement]()

    for token in tokens {
        switch token {
        case "*", "|": expressionElements.append(.operation(token.first!))
        default: expressionElements.append(.expression(parseToken(expression: token)))
        }
    }

    return evaluateConcatenation(on: reduceExpressionIntoConcatenation(expressionElements))
}

func parseExpression(_ expression: String) -> Node {
    let parsedExpression = parseToken(expression: Substring(expression))
    parsedExpression.final.isFinal = true
    return parsedExpression.initial
}

func createRegex() -> Node {
    let rootNode = Node()

    let transition1 = Transition(state: "a", node: Node())
    let transition2 = Transition(state: "b", node: Node())
    transition2.node.isFinal = true

    transition1.node.transitions.append(transition2)

    rootNode.transitions.append(transition1)
    return rootNode
}

func recognize(string: Substring, in expression: Node) -> Bool {

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

let exp = createRegex()
print(recognize(string: "ab", in: exp))

let regex = "((a|b))*abb"
let exp2 = parseExpression(regex)
print(recognize(string: "aabb", in: exp2))

let regex2 = "(a(b|c)d)|ef*"
let exp3 = parseExpression(regex2)
print(recognize(string: "acdf", in: exp3))