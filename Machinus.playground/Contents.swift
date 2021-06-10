
import PlaygroundSupport
import Machinus_Sources

PlaygroundPage.current.needsIndefiniteExecution = true

enum UserState: StateIdentifier {
    case initialising
    case registering
    case loggedIn
    case loggedOut
}

let initialising = StateConfig<UserState>(identifier: .initialising, allowedTransitions: .registering, .loggedOut)

let registering = StateConfig<UserState>(identifier: .registering, allowedTransitions: .loggedIn)
    .afterEntering { _ in
        registerUser()
}

let loggedIn = StateConfig<UserState>(identifier: .loggedIn, allowedTransitions: .loggedOut)
    .afterEntering { _ in
        displayUserHome()
}

let loggedOut = StateConfig<UserState>(identifier: .loggedOut, allowedTransitions: .loggedIn)
    .afterEntering { _ in
        displayEnterPassword()
}

print("Creating the machine")
let machine = StateMachine(withStates: initialising, registering, loggedIn, loggedOut)

// Confirm we are in the first state.
machine.state == .initialising

print("\nQueuing transition to registering a user")
machine.transition(to: .registering) { _, error in
    if let error = error { print("    Error! \(error)") }
}

wait()

// Do another
print("\nQueuing transition to logged in")
machine.transition(to: .loggedIn) { _, error in
    if let error = error { print("    Error! \(error)") }
}

wait()

print("\nQueuing transition to logged out")
machine.transition(to: .loggedOut) { _, error in
    if let error = error { print("    Error! \(error)") }
}

wait()

print("End")

