# Machinus V3

[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://GitHub.com/drekka/Machinus/graphs/commit-activity)
[![GitHub license](https://img.shields.io/github/license/drekka/Machinus.svg)](https://github.com/drekka/Machinus/blob/master/LICENSE)
[![GitHub tag](https://img.shields.io/github/tag/drekka/Machinus.svg)](https://GitHub.com/drekka/Machinus/tags/)

A powerful yet easy to use state machine for iOS/tvOS/MacOS. 

## Quick feature list

* Async/await transitions.
* Dynamic closure transitions.
* State change closures.
* Combine `Publisher` and async/await `AsyncSequence` state change consumers.
* State change notifications.
* Transition barriers that can deny, redirect or fail a transition.
* iOS/tvOS app background state tracking.
* 
## Index

- [What is a state machine and why would I need one?](#what-is-a-state-machine-and-why-would-i-need-one)
- [Machinus?](#machinus)
- [Quick guide](#quick-guide)
  - [1. Installing](#1-installing)
  - [2. Declare the states](#2-declare-the-states)
  - [3. Create the states and machine](#3-create-the-states-and-machine)
  - [4. Transition](#4-transition)
- [States](#states)
  - [Simple states](#simple-states)
  - [Global states](#global-states)
  - [Final states](#final-states)
  - [Final global states](#final-global-states)
  - [The background state (iOS/tvOS only)](#the-background-state-iostvos-only)
- [The state machine](#the-state-machine)
  - [Properties & Functions](#properties-functions)
- [Transitions](#transitions)
  - [Manual transitions](#manual-transitions)
    - [Transition execution](#transition-execution)
      - [Phase 1: Preflight](#phase-1-preflight)
      - [Phase 2: Transition](#phase-2-transition)
  - [Dynamic transitions](#dynamic-transitions)
  - [Background transitions (iOS & tvOS)](#background-transitions-ios-tvos)
      - [Going into the background](#going-into-the-background)
    - [Returning to the foreground](#returning-to-the-foreground)
  - [Subscribing to transitions with Combine](#subscribing-to-transitions-with-combine)
  - [Using `AsyncSequence` to watch transitions](#using-asyncsequence-to-watch-transitions)
- [Resetting the engine](#resetting-the-engine)


# What is a state machine and why would I need one?

Sometimes an app needs to track the state of something. For example, you might have a user who can be _'Registered'_, _'logged out'_, _'logged in'_,  _'inactive'_,  _'pending'_, _'banned'_, and _'timed out'_. It's possible to manage what happens in your app using booleans, enums, `if-then-else`'s, `switch`'s and other code but as your app grows it can become unmanageable. Especially in larger code bases after a number of developers have been through and the resulting complexity can absorb large amounts of time and effort to understand, debug and extend. 

Addressing this complexity is where state machines come into their own. They can marshal an object's state, run code upon state changes, define valid and invalid state changes as well as other functionality. 

Done right, using a state machine can manage complexity and simplify your code.

# Machinus?

If you look around on [Github](https://www.github.com) you will find a number of state machine projects. So why did I bother writing another? Simply because I didn't find any that had the features I wanted. 

Essentially I found two types of state machines on [Github](https://www.github.com). Ones that used structs or classes to define their state, and others that used enums. 

The enum based machines tended to be easy to use because you can pass enum values to and from the machine. But they were often too simple, or had limited functionality because of the limitations of enums. Struct/class based machines generally had more functionality, but using a struct/class as state means you ahve to managed those states in order to talk to the machine.

Machinus on the other hand uses a third architectural design. It defines state via a simple protocol which generally you would apply to an enum to get the benefits of using an enum to talk to the machine. However when configuring the machine it uses structs to define the machine's functionality. Thus Machinus gets the benefits of both approaches to building state machines. Then there is built in app background tracking (in iOS) and other unique features and (IMHO) Machinus is the best state machine available. 

But I might be biased :-)

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

`StateIdentifier` is `Hashable` and Swift will automatically synthesise the required functions unless you are using associated values. Then you will have to do it yourself.

## 3. Create the states and machine

Now we can setup and configure the machine. It needs instances of **`StateConfig<S>`** (where `<S>` is any `StateIdentifier` type) to attach any state change functionality you desire, define valid transitions and other functionality.

For example

```swift
let machine = try await StateMachine {

    StateConfig<UserState>(.initialising,
                           didEnter: { _, _ in reloadConfiguration() },
                           canTransitionTo: .loggedOut)
                                    
    StateConfig<UserState>(.loggedOut, 
                           didEnter: { _, _ in displayLoginScreen() },
                           didExit: { _, _ in hideLoginScreen() },
                           canTransitionTo: .loggedIn, registering)

    StateConfig<UserState>(.loggedIn,
                           didEnter: { _, _ in displayUsersHomeScreen() },
                           transitionBarrier: {
                               return userIsLoggedIn() ? .allow : .redirect(to: .loggedOut)
                           },
                           canTransitionTo: .loggedOut)

    StateConfig<UserState>(.registering, 
                           didEnter: { _, _ in displayRegistrationScreen() },
                           dynamicTransition: {
                               return registered() ? .loggedIn : .loggedOut
                           },
                           canTransitionTo: .loggedOut, .loggedIn)

    StateConfig<UserState>.background(.background,
                                      didEnter: { _, _ in displayPrivacyScreen() },
                                      didExit: { _, _ in hidePrivacyScreen() })
    }
```

After this the `StateConfig<T>` instances are no longer needed because the state machine public interface is driven using the state identifiers. 

Also note that Machinus automatically starts in the first state listed, so …

```swift
await machine.state == .initialising // -> true
```

## 4. Transition

Now the state machine's setup lets ask it to transition to a different state.

```swift
let result = try await machine.transition(to: .loggedOut)
// result.from <- The state the machine was in.
// result.to <- The state the machine is in now.
```

Which will:

1. Change to the `.loggedOut` state.
1. Run the `.loggedOut` state's `didEnter` closure to call `displayLoginScreen()`.

_And … Ta da! We've just used a state machine!_

# States

As said above states are configured using the **`StateConfig<S>`** class with `<S>` being anything that implements the `StateIdentifier` protocol. 

## Simple states

The most common type of state setup in a machine is the **Simple state**. These are created using **`StateConfig<S>`**'s default initialiser which takes the **`StateIdentifier`** of the state and zero or more closures defining behaviour.

```swift
// StateConfig with the works!
Let loggedIn = StateConfig<MyState>(.loggedIn,
                                     didEnter: { fromState, toState in … },
                                     didExit: { fromState, toState in … },
                                     dynamicTransition: { … },
                                     transitionBarrier: { state in … },
                                     canTransitionTo: state1, state2, state3, …) {
```
* **State identifier** (required) - The unique identifier of the state.

* **`didEnter`** (optional) - Executed when the machine transitions to this state.

* **`didExit`** (optional) - Executed when the machine leaves this state. 

* **`dynamicTransition`** (optional) - Can be executed to decide what state to transition to.

* **`transitionBarrier`** (optional) - Called before a transition executes. It's job is to decide if the transition should be allowed by returning:
    * **`.allow`** - Allow the transition to occur.
    * **`.redirect(to:S)`** - Redirect to another state.
    * **`.fail`** - Fail the transition with `StateMachineError.transitionDenied`.

    Barriers are passed the current state of the machine in case they need to check it.

* **`canTransitionTo`** (optional) - A list of states that can be transitioned to. If you request a transition to a state not in this list, a `StateMachineError.illegialTransition` error is thrown. *Note - there are exceptions to this such as global and background states.*

## Global states

Global states can be transitioned to without having to appear in other state's `canTransitionTo` lists. This makes them particularly useful for global functionality which can be accessed from any state.

```swift
Let timeout = StateConfig<MyState>.global(.timeout,
                                          didEnter: { fromState, toState in … },
                                          didExit: { fromState, toState in … },
                                          dynamicTransition: { … },
                                          transitionBarrier: { state in … },
                                          canTransitionTo: state1, state2, state3, …)
```

*Note: The only states that cannot transition to a global state are final state's because they cannot be left.*

## Final states

Final states are "dead end" states. ie. they cannot be left once entered. For example, you might use a final state when the app hits an error that cannot be recovered from. Because they cannot be left, final state's don't need `canTransitionTo` lists, `dynamicTransition` or `didExit` closures.

```swift
Let configLoadFailure = StateConfig<MyState>.final(.configLoadFailure,
                                                   didEnter: { fromState, toState in … },
                                                   transitionBarrier: { state in … })
```

*Note: you can "recover" from a final state by resetting the machine. See [Resetting the engine](#resetting-the-engine)*

## Final global states

There there are final global states which are quite simply both final and global.

```swift
Let unrecoverableError = StateConfig<MyState>.final(.majorError,
                                                    didEnter: { fromState, toState in … },
                                                    transitionBarrier: { state in … })
```

## The background state (iOS/tvOS only)

If you are using Machinus in an iOS or tvOS app, you have access to an extra type of state specifically added to support the app being pushed into the background. This is primarily to give you a point where you can attach functionality such as overlaying and removing a privacy screen on your UI.

When you add one of these states to the machine, it will automatically triggers the watching of the `UIApplication`'s foreground and background notifications. Then when the app then goes into the background the machine stores a reference to the current state before transitioning into to the background state. When the app then comes back to the foreground, it exits the background state and restores the previously saved state. 

Background states involves some unique processing. They don't have `canTransitionTo` lists, `transitionBarriers` or `dynamicTransition` closures and their processing doesn't call the current state's `didExit` or `didEnter` closures. 

The reason is that background transitions are considered ["out of band"](https://en.wikipedia.org/wiki/Out-of-band_data). Effectively parallel to the machine's normal state changes and their execution reflects that.

*Also note that trying to register more than one background state will throw an error.*

```swift
Let background = StateConfig<MyState>.background(.background,
                                                 didEnter: { fromState, toState in … },
                                                 didExit: { fromState, toState in … })
```

# The state machine

```swift
let machine = StateMachine(name: "User state machine") { fromState, toState in … }
                           withStates: {
                               StateConfig<MyState>(.initialising, … )
                               StateConfig<MyState>(.registering, … )
                               StateConfig<MyState>(.loggedIn, … )
                               StateConfig<MyState>(.loggedOut, … )
                           }
```

The optional **`name`** argument is used to uniquely identify the state machine in logs and debug sessions. If you don't pass it, a UUID appended with the type of the state identifier is used. This is purely for debugging when multiple state machines are in play.

The optional **`didTransition`** closure is called after each transition and is passed the from and to state of the machine.

After that is the list of the states used to define the machine's behaviour. Note these are listed using a builder style (AKA SwiftUI).

_Note: Machinus requires a minimum of 3 states. This is simply because state machine's are pretty useless with only one or two states. So the initialiser will fail with anything less than 3._ 

## Properties & Functions

The core `Machine<S>` protocol has these properties and functions:

* **`var state: S async`** 

   Returns the current state of the machine. Because states implement `StateIdentifier` which is an extension of `Hashable` they are easily comparable using standard operators.

   ```swift
   await machine.state == .initialising // = true
   ```
   
* **`nonisolated var statePublisher: AnyPublisher<S, Never>`**

    A Combine publisher that emits the states as they change.

* **`nonisolated var stateSequence: ErasedAsyncPublisher<S>`**

    An `AsyncSequence` that can be iterated over to receive state changes.

* **`func postNotifications(_ postNotifications: Bool)`**

    When set to true, every time a transition is successful a matching notification is posted. This allows code that is far away from the machine to still see what it's doing. *See [Listening to transition notifications](#listening-to-transition-notifications).*

* **`func reset() async throws -> TransitionResult<S>`**

    Resets the machine back to it's initial state. *See [Resettting the engine](#resetting-the-engine).*

* **`@discardableResult func transition() async throws -> TransitionResult<S>`**

    Performs a [Dynamic transition](#dynamic-transitions).

* **`@discardableResult func transition(to state: S) async throws -> TransitionResult<S>`**

    Performs a [manual transition](#manual-transitions).

# Transitions

A '**Transition**' is the process of changing from one state to another. It sounds simple, but it's actually a little more complicated than you might think. Essentially Machinus supports two types of transitions.

## Manual transitions

Manual transitions are where you pass the desired new state as an argument like this: 

```swift
let result: TransitionResult<MyState> = try await machine.transition(to: .registering)
```

Where **`TransitionResult`** is a type alias for the tuple `(_ from: <S>, _ to:<S>) where S: StateIdentifier`.

### Transition execution

When you request a transition the machine executes it in two phases:

#### Phase 1: Preflight

Preflight is where the request is checked to ensure it is a valid. Preflight can fail the transition for any of the following reasons:

* The new state is not a known state. Throws `StateMachineError.unknownState(S)`.

* Unless a global state, the requested state does not exist in the list of allowed transitions of the current state. Throws `StateMachineError.illegalTransition`.

* The new state's transition barrier denies the transition. Throws a `StateMachineError.transitionDenied`.

* The new state and the old state are the same. Throws a `StateMachineError.alreadyInState`.

#### Phase 2: Transition

Providing the preflight has allowed the transition, these steps are followed:

1. The internal state is updated. As a side effect, the `statePublisher` and `stateSequence` properties will trigger their respective listeners.

1. The old state's `didExit` closure is called passing the old and new states.

1. The new state's `didEnter` closure is called passing the old and new states.

1. The machine's `didTransition` closure is called, passing the old and new states.

1. If `postNotifications` is true, a state change notification is sent.

1. Finally The old and new state of the machine are returned to the calling code as a tuple.

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

let result: TransitionResult<MyState> = try await machine.transition()
```

The call to execute a transition is the same except that there is no `to` state argument. The lack of that argument triggering the execution of the dynamic transition closure to obtain the state to transition to.

_Note: If there's no dynamic closure on the current state, the machine will throw a `StateMachineError.noDynamicClosure(S)` error._ 

## Background transitions (iOS & tvOS)

Background transitions are special cases because they are not considered part of the normal state map. When automatically triggered by the app being sent into the background or restored to the foreground a simplified transition process is run. In both cases by skipping pre-flight and then by only running some of the closures. 

#### Going into the background

1. The current state is stored.

1. The state is changed to the background state.

1. The background state's `didEnter` closure is called.

1. The machine is told to suspend processing until a foreground transition is requested. If any transition requests are received during this time a `StateMachineError.suspended` error will be thrown.

### Returning to the foreground

Foreground transitions revert the machine back to the state it was in when backgrounded.

1. The machine is told to resume transition processing.

1. If the stored previous state has a `transitionBarrier` it is executed and if the result is `.redirect(to:)`, then the redirect state is set as the  state to restore.

1. The state is changed to the restore state.

1. The background state's `didExit` closure is called.

## Subscribing to transitions with Combine

Machinus has a Combine publisher which emits states as it changes to them. Here's an example:

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

*Note that on subscription, Machinus will immediately send the current state so your code knows what it is.*

## Using `AsyncSequence` to watch transitions

In keeping with Swift's async/await there is an `AsyncSequence` property that can be iterated over to receive state changes. It's defined as an `ErasedAsyncPublisher` which is a wrapper for an `AsyncPublisher` that simply erases the internal publisher. Other than that it's exactly the same and can be used like this:

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

Resetting the state machine hard resets the engine back to the 1st state in the list. It does not execute any state closures.

```swift
try await machine.reset { ... }
```

*Note: `reset()` is the only way to exit a final state. Although that's generally not something that you would want to do and suggests that your final state is not really final.*
