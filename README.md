# Machinus V3

[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://GitHub.com/drekka/Machinus/graphs/commit-activity)
[![GitHub license](https://img.shields.io/github/license/drekka/Machinus.svg)](https://github.com/drekka/Machinus/blob/master/LICENSE)
[![GitHub tag](https://img.shields.io/github/tag/drekka/Machinus.svg)](https://GitHub.com/drekka/Machinus/tags/)

A powerful yet easy to use state machine for iOS/tvOS/MacOS. 

## Quick feature list

* Asynchronous thread safe transitions.
* Transition hooks.
* Transition barriers that can deny, redirect or fail a transition.
* Dynamic transitions.
* iOS/tvOS app background state tracking.
* Combine and async/await friendly code.
* Optional notifications of state changes.

## Index

# What is a state machine?

In some code bases objects can exist in a number of states. For example, a user can be _'Registered'_, _'logged out'_, _'logged in'_,  _'inactive'_,  _'pending'_, _'banned'_, _'timed out'_ and more. It's possible to manage state using booleans, enums, `if-then-else`'s, `switch`'s and all sorts of other code but over time that can become unmanagable, especially in large code bases where there are a lot of developers and complex processing. That complexity sucking large amounts of time and effort to understand, debugg an extend. 

This is where state machines are often a good solution to the complexity problem. They can marshal object state, automatically run code when that state changes, define what is a valid state change and what is not, and provide other attached functionality. 

Done right, state machines can address state based complexity and as a result, dramatically simplify code.

# Machinus?

[Github](https://www.github.com) already has a number of state machine projects so why did I bother writing another? Because I didn't find a single Swift based one that had all the features I wanted. 

Essentially the projects I looked fell into two camps. Either defining an object's state using structs or classes, or defining it using an enum. 

The enum based machines tended to be simpler and easier to work because everything was attached to the enum that defined the object state. But the trade off was limited functionality, often because of the limitations of enums. Struct/class based machines generally had the functionality, but their trade off was the implied complexity on the calling code to track the state objects in order to request state changes.

With Machinus I decided to take a different approach. It defines a state using a simple protocol which can then be applied to anything to make it a state. Although generally, I'd recommend an enum for simplicity. Then when configuring the machine, these states are combined with a struct that defined the attached functionality, thus Machinus get's the benefits of both approaches to building state machines. Add in app background tracking (in iOS) and other unique features and (IMHO) Machinus is the best state machine available. But I might be biased :-)

# Quick guide

So let's look at using Machinus in 4 easy steps.

## 1. Installing

Machinus (V3) is supplied as a Swift Package Manager framework. So just search using the url [https://github.com/drekka/Machinus](https://github.com/drekka/Machinus) in Xcode's SPM package search.

## 2. Declare the states

States are declared by applying the `StateIdentifier` protocol. Generally (and I'd recommend this) it's easiest to use an enum. 

```swift
enum UserState: StateIdentifier {
    case initialising
    case registering
    case loggedIn
    case loggedOut
    case background
}
```

If you are using associated values you will also need to implement `Hashable`. Otherwise Swift will automatically synthesise it.

## 3. Create the states and machine

Now we can setup and configure the machine.  `StateConfig<S>` instances are used to add any functionality you want to execute on a state change as well as to define what is a valid transition. `<S>` being the previously created `StateIdentifier` type.

```swift
let machine = try await StateMachine {

    StateConfig<UserState>(.initialising,
                           didEnter: { _, _, _ in reloadConfiguration() },
                           canTransitionTo: .loggedOut)
                                    
    StateConfig<UserState>(.loggedOut, 
                           didEnter: { _, _, _ in displayLoginScreen() },
                           didExit: { _, _, _ in hideLoginScreen() },
                           canTransitionTo: .loggedIn, registering)

    StateConfig<UserState>(.loggedIn,
                           didEnter: { _, _, _ in displayUsersHomeScreen() },
                           transitionBarrier: {
                               return userIsLoggedIn() ? .allow : .redirect(to: .loggedOut)
                           },
                           canTransitionTo: .loggedOut)

    StateConfig<UserState>(.registering, 
                           didEnter: { _, _, _ in displayRegistrationScreen() },
                           dynamicTransition: {
                               return registered() ? .loggedIn : .loggedOut
                           },
                           canTransitionTo: .loggedOut, .loggedIn)

    StateConfig<UserState>.background(.background,
                                      didEnter: { _, _, _ in displayPrivacyScreen() },
                                      didExit: { _, _, _ in hidePrivacyScreen() })
    }
```

After this the `StateConfig<T>` instances are no longer needed because state change requests are enacted passing the state identifiers. 

Also note that Machinus automatically starts in the first state listed, so …

```swift
await machine.state == .initialising // -> true
```

## 4. Transition

Now the state machine's setup lets ask it to transition to a different state.

```swift
try await machine.transition(to: .loggedOut)
```

This will trigger a sequence of events:

1. The machine will change to the `.loggedOut` state.
1. The `.loggedOut` state's `didEnter` closure will be executed to call `displayLoginScreen()`.

_And … Ta da! We've just used a state machine!_

# States

States are configured using the **`StateCofig<S>`** class. `<S>` being anything that implements the `StateIdentifier` protocol. Most are created using the **`StateConfig<T>.init(…)`** initialiser which takes the **`StateIdentifier`** for the state and a range of optional arguments to define it's behaviour.

## Simple states

The base type of state, a simple state has optional closures to execute when the machine enters or leaves the state, to deny a transition and another that can dynamically decide what the next state to transition to is.   

```swift
// StateConfig with the works!
Let loggedIn = StateConfig<MyState>(.loggedIn,
                                     didEnter: { machine, fromState, toState in … },
                                     didExit: { machine, fromState, toState in … },
                                     dynamicTransition: { machine in … },
                                     transitionBarrier: { machine in … },
                                     canTransitionTo: state1, state2, state3, …) {
```
* The **State identifier**
* **`didEnter`** - Executed when the machine transitions to this state.
* **`didExit`** - Executed when the machine leaves this state. 
* **`dynamicTransition`** - When requested, called to decide what the next state of the machine will be.
* **`transitionBarrier`** - Called before a transition to decide if it's ok to transition to this state. A barrier can return one of 3 responses:
    * **`.allow`** - Allow the requested transition to occur.
    * **`.redirect(to:S)`** - Redirects to another state.
    * **`.fail`** - Fails the transition with a `StateMachineError.transitionDenied` error.
* **`canTransitionTo`** A list of states that can be transitioned to. If a transition to a state not in this list is requested, a `StateMachineError.illegialTransition` error will be thrown.

## Global states

Any state can transition to a global state without it being in their `canTransitionTo` list. The only exception to this are final state's which cannot be left and therefore cannot transition to a global state.

```swift
Let timeout = StateConfig<MyState>.global(.timeout,
                                          didEnter: { machine, fromState, toState in … },
                                          didExit: { machine, fromState, toState in … },
                                          dynamicTransition: { machine in … },
                                          transitionBarrier: { machine in … },
                                          canTransitionTo: state1, state2, state3, …)
```

## Final states

Final states cannot be left once entered. For example you might use a state when the app hits an error that cannot be recovered from. Final state's don't need `canTransitionTo` lists, `dynamicTransition` or `didExit` closures because the machine can never leave them.

```swift
Let configLoadFailure = StateConfig<MyState>.final(.configLoadFailure,
                                                   didEnter: { machine, fromState, toState in … },
                                                   transitionBarrier: { machine in … })
```

## Final global states

Final and global, a combination of both.

```swift
Let unrecoverableError = StateConfig<MyState>.final(.majorError,
                                                    didEnter: { machine, fromState, toState in … },
                                                    transitionBarrier: { machine in … })
```

## The background state (iOS/tvOS only)

If iOS if you add a background state to the machine then the machine will automatically watch the app's foreground/background state. When it goes into the background, a transition to the background state will automatically be made no matter what state it's currently in. Then inversely, when the app comes back to the foreground, the machine will automatically transition back to the state it was prior to being backgrounded. 

Background state processing invokes some unique processing that other states don't do. They don't need `canTransitionTo` lists, `transitionBarriers` or `dynamicTransition` closures as none of these are called during the transition. Nor are other state's `didExit` or `didEnter` closures called. The thought behind this is that background transitions can effectively occur at any time and from any state and should return to that state when the app is foregrounded again. Machinus effectively acting as if the app never left the original state. However the execution of the background state's `didEnter` and `didExit` give you the opportunity to do things like put up privacy screens.

*Also note that trying to register more than one background state will throw an error.*

```swift
Let background = StateConfig<MyState>.background(.background,
                                                 didEnter: { machine, fromState, toState in … },
                                                 didExit: { machine, fromState, toState in … })
```

# The state machine

```swift
let machine = StateMachine(name: "User state machine") { machine, fromState, toState in … }
                           withStates: {
                               StateConfig<MyState>(.initialising, … )
                               StateConfig<MyState>(.registering, … )
                               StateConfig<MyState>(.loggedIn, … )
                               StateConfig<MyState>(.loggedOut, … )
                           }
```

The optional **`name`** argument is used to uniquely identify the state machine in logs and debug sessions. If you don't pass it, a UUID appended with the type of the state identifier is used. This is purely to support debugging when multiple state machines are in play.

The optional **`didTransition`** closure is called after each transition.

After that comes a list of the states for the machine which you can list using a builder style (AKA SwiftUI).

_Note: Machinus requires at least 3 states. This is simple logic. A state machine is useless with only 1 or two states. So the initialiser will fail with anything less than 3._ 

## Properties

The core `StateMachine<S>` class has some additional properties available:

* **`postNotifications: Bool`** - Defaults to false. When true, every time a transition is successful a matching notification is posted. This allows code that is far away from the machine to still see what it's doing. *See [Listening to transition notifications](#listening-to-transition-notifications).*

* **`state: S async`** - Returns the current state of the machine. Because states implement `StateIdentifier` which is an extension of `Hashable` they are easily comparable using standard operators.

```swift
await machine.state == .initialising // = true
```

# Transitions

A '**Transition**' is the process of changing from one state to another. It sounds simple, but it's actually a little more complicated than you might think.

All transitions are queued asynchronously. This is done so that the machine can fully process each transition with any closures it might have before moving on to the next transition. This also allows for the odd situation where a closure on a state might trigger another state change request.

## Manual transitions

Manual transitions are the simplest to understand. You simply request the state you would like the machine to transition to like this: 

```swift
await machine.transition(to: .registering) { machine, result in
    if let Result.failure(let error) = result {
        // Handle the error
        return
    }
    // The transition was successful. Result contains the previous state.
}
```

Where **`machine`** is a reference to the machine and **`result`** is a `Result<(_ from: <S>, _ to: <S>), StateMachineError>` where `S: StateIdentifier`.

Note that the transition is not executed directly, but queued for execution. This is to ensure that a state `didEnter` or `didExit` or even the engines own `didTransition` closure can request another transition without interfering with the transition being executed. 

### Transition execution

When you request a transition the machine follows these steps:

1. The transition is queued for execution.
2. If there is no transition already in flight, the engine picks up the next transition from the queue.
3. The transition is pre-flighted. This can fail the transition for a number of reasons including:
    * The new state is not a known state. Throws `StateMachineError.unknownState(S)`.
    * Unless a global state, the requested state does not exist in the list of allowed transitions of the current state. Throws `StateMachineError.illegalTransition`.
    * The new state's transition barrier denies the transition. Throws a `StateMachineError.transitionDenied`.
    * The new state and the old state are the same. Throws a `StateMachineError.alreadyInState`.
4. Once pre-flight is passed, the machine executes the transition:
    1. The state is changed.
    2. The old state's `didExit` closure is called passing the machine and new state.
    3. The new state's `didEnter` closure is called passing the machine and old state.
    4. The machine's `didTransition` closure is called, passing the machine and old state.
    5. If `postNotifications` is true, a state change notification is sent.
5. The transition request's completion closure is called with the previous state as a result.

## Dynamic transitions

Dynamic transitions are processed exactly the same as a manual transition except for one thing. Prior to running the transition, the current state's `dynamicTransition` closure is executed to obtain the the state to transition too.

For example:

```swift
let machine = StateMachine {
                  StateConfig<MyState>(.registering, 
                                       dynamicTransition: {
                                           return registered() ? .loggedIn : .loggedOut
                                       },
                                       canTransitionTo: .loggedOut, .loggedIn)
                  StateConfig<MyState>(.loggedOut, canTransitionTo: .loggedIn, registering)
                  StateConfig<MyState>(.loggedIn, canTransitionTo: .loggedOut)
              }

machine.transition { machine, result in /* … */ }
```

The call to execute a transition is the same except that there is no `to` state argument. The lack of that argument tells the machine to look for a dynamic closure and obtain the next state from it.

If there's no dynamic closure on the current state, the machine will return a `StateMachineError.noDynamicClosure(S)` error to indicate a dynamic was expected. 

## Background transitions (iOS & tvOS)

Background transitions are special cases because they are not considered part of the normal state map. Sure you can request a transition to a background state just like transitioning to any other state, and it will be run through the same process. However if the transition to background is triggered by the app being sent to the background it runs an entirely different process.

### Going into the background

1. The background transition is queued. 
2. The current state is stored as the state to restore to.
3. The state is changed to the background state.
4. The background state's `didEnter` closure is called.
5. The machine is told to suspend processing until a foreground transition is requested. If any subsequence transition requests are received, they are queued.

### Returning to the foreground

Foreground transitions revert the background process.

1. The foreground transition is queued as the next transition to execute.
2. The machine is told to resume transition processing.
3. If the restore state has a `transitionBarrier` it is executed, and if the result is `.redirect(to:)`, then that state is used as the restore state.
5. The state is changed to the restore state.
6. The background state's `didExit` closure is called.

## Subscribing to transitions with Combine

Machinus is Combine aware with the machine publishing state changes. Here's an example of listening to state changes.

```swift
machine.statePublisher.sink { newState in
    print("Received \(newState)")
    switch newState {
    case .loggedIn:
        displayUsersHomeScreen()
    case .loggedOut:
        displayLoginScreen()
    case .Registering:
        displayRegisterUserScreen()
    }
}
```

Note that on subscription, Machinus will immediately send the current state so your code knows what it is.

## Using `AsyncSequence` to watch transitions

In keeping with Swift's async/await there is an `AynsSequence` property that can be accessed to receive state changes.

```swift
for await state in machine.stateSequence {
    print("Received \(newState)")
    switch newState {
    case .loggedIn:
        displayUsersHomeScreen()
    case .loggedOut:
        displayLoginScreen()
    case .Registering:
         displayRegisterUserScreen()
     }
}
```


# Resetting the engine

Resetting the state machine is quite simple. `.reset()` will hard reset the engine back to the 1st state in the list. It does not execute any actions or rules as it's a hard reset.

```swift
await machine.reset { machine in ... }
```

*Note: `reset()` is the only way to exit a final state. Although that's generally not something that you would want to do and suggests that your final state is not really final.*
