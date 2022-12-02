# Machinus

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

- [What is a state machine?](#what-is-a-state-machine)
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
  - [Properties](#properties)
- [Transitions](#transitions)
  - [Manual transitions](#manual-transitions)
    - [Transition execution](#transition-execution)
  - [Dynamic transitions](#dynamic-transitions)
  - [Background transitions (iOS & tvOS)](#background-transitions-ios-tvos)
    - [Going into the background](#going-into-the-background)
    - [Returning to the foreground](#returning-to-the-foreground)
  - [Subscribing to transitions with Combine](#subscribing-to-transitions-with-combine)
  - [Using `AsyncSequence` to watch transitions](#using-asyncsequence-to-watch-transitions)
- [Resetting the engine](#resetting-the-engine)


# What is a state machine?

In complex code bases there can be a need to manage complex arrangements of object state. For example a user can be - _'Registered'_, _'logged out'_, _'logged in'_,  _'inactive'_,  _'pending'_, _'banned'_, _'timed out'_ and more. You can manage such states booleans or enums, but you'll end up with a lot of `if-then-else` and `switch` statements to manage things and as we know, that can easily become an unmaintainable mess that will suck large amounts of time and effort understanding, debugging an extending. 

This is where a state machine comes in. It can help marshal an object's state, automatically run code when it changes, define the "map" of valid states and provide other useful functionality. 

Done right, a state machine can address a range of issues and dramatically simplify your code.

# Machinus?

If you look around [Github](https://www.github.com) you'll find plenty of state machine implementations. So why did I bother writing another? 

Simply because none of the implementations I found had the features I wanted. 

Basically all the implementation I looked at either defined a state using structs or classes, or they defined it via an enum. The enum based machines tended to be simpler because a state change was just a matter of passing an enum value. The trade off being functionality limitations that enums imply. The struct/class machines had more functionality, but then as a developer you have keep track of those states in order to request state changes.

Machinus on the other hand defines a state through a protocol which can easily be applied to an enum, and configures functionality using structs to give a wide range of functionality. Add in further functionality such as app background tracking and other unique features and (IMHO) Machinus is the best state machine out there.

# Quick guide

Let's look at using Machinus in 4 easy steps.

## 1. Installing

Machinus (V3) is supplied as a Swift Package Manager based library. Search using the url [https://github.com/drekka/Machinus](https://github.com/drekka/Machinus) in Xcode's package search.

## 2. Declare the states

States are declared by applying the `StateIdentifier` protocol. Generally (and I'd recommend this) the easiest usage is to apply it to an enum. 

```swift
enum UserState: StateIdentifier {
    case initialising
    case registering
    case loggedIn
    case loggedOut
    case background
}
```

Providing you're not adding associated values, Swift will generate the `Hashable` syntactical sugar needed. 

## 3. Create the states and machine

Now we can create the state configurations and setup the machine.  The `StateConfig<S>` class is the key. `<S>` of course, being the previously created `StateIdentifier` type.

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
                           didEnter: { _ in displayUsersHomeScreen() },
                           transitionBarrier: {
                               return userIsLoggedIn() ? .allow : .redirect(to: .loggedOut)
                           },
                           canTransitionTo: .loggedOut)

    StateConfig<UserState>(.registering, 
                           didEnter: { _ in displayRegistrationScreen() },
                           dynamicTransition: {
                               return registered() ? .loggedIn : .loggedOut
                           },
                           canTransitionTo: .loggedOut, .loggedIn)

    StateConfig<UserState>.background(.background,
                                      didEnter: { _ in displayPrivacyScreen() },
                                      didExit: { _ in hidePrivacyScreen() })
    }
```

After this the `StateConfig<T>` instances are no longer needed because from here on the `StateIdentifer` are used to communicate with the machine. 

Also note that Machinus autoamtically starts in the first state listed, so …

```swift
machine.state == .initialising // -> true
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

Generally speaking most states will be fairly standard. But there are also some specialised states with particular functionality attached.

States are configured using the **`StateCofig<S>`** class. `<S>` being anything that implements `StateIdentifier`. Most states are created using the **`StateConfig<T>.init(…)`** initialiser which takes a required **`StateIdentifier`** to identify the state, and a range of optional arguments to define how it behaves.

## Simple states

The most common type of state, a simple state has an identifier, and some optional behaviours. Closures that are executed when the machine enters or leaves the state, a closure that can deny a transition to the state and another than can be used to dynamically decide what state to transition to.   

```swift
// StateConfig with the works!
Let loggedIn = StateConfig<MyState>(.loggedIn,
                                     didEnter: { machine, previous in … },
                                     didExit: { machine, next in … },
                                     dynamicTransition: { … },
                                     transitionBarrier: { … },
                                     canTransitionTo: …) {
```
* The **State identifier**
* The state's **`didEnter`** - Closure that is executed when the machine transitions to this state.
* The state's **`didExit`** - Closure that is executed after the machine exits the state. 
* A **`dynamicTransition`** - Closure which can be executed to generate the next state for the machine.
* A **`transitionBarrier`** - Sometimes it's easier to have logic that bars a transition to a state that to place duplicates of that logic everywhere else. A transition barrier does that by being called before the engine allows a transition. A barrier can return one of 3 responses:
    * **`.allow`** - Allow the transition to occur.
    * **`.redirect(to:S)`** - Redirect to a different state.
    * **`.fail`** - Fail the transition with a `StateMachineError.transitionDenied` error.
* **`canTransitionTo`** Except for final and background states, if you want to be able to transition to another state you have need to specify that state in the `canTransitionTo` list. Otherwise the engine will fail the transition with a `StateMachineError.illegialTransition` error.


## Global states

Global states are special in that any other state can transition to them without having to be present in the other states `canTransitionTo` list. A good example of a global state might be one for re-authenticating a user after a timeout. Using a global means your app can transition to it from any state. The only exception to this are final state's which cannot be left.

```swift
Let timeout = StateConfig<MyState>.global(.timeout,
                                          didEnter: { machine, previous in … },
                                          didExit: { machine, next in … },
                                          dynamicTransition: { … },
                                          transitionBarrier: { … },
                                          canTransitionTo: …)
```

## Final states

Final states cannot be left once entered. For example you might want a state for when the app hits an error that cannot be recovered from. Final state's don't need allowed transition lists, dynamic transition or `didExit` closures because the machine can never leave them.

```swift
Let configLoadFailure = StateConfig<MyState>.final(.configLoadFailure,
                                                   didEnter: { machine, previous in … },
                                                   transitionBarrier: { … })
```

## Final global states

Exactly the same as a final state, except that like a global, they don't need to be  specified in other state's `canTransitionTo` lists.

```swift
Let unrecoverableError = StateConfig<MyState>.final(.majorError,
                                                    didEnter: { machine, previous in … },
                                                    transitionBarrier: { … })
```

## The background state (iOS/tvOS only)

If you add a background state to the machine then it will automatically start watching the app's state. When it goes into the background, the machine will automatically transitions to the background state no matter what state it's currently in and inversely, when the app comes back to the foreground, the machine will transition back to the state prior to being backgrounded. 

Background states don't need `canTransitionTo` lists, `transitionBarriers` or `dynamicTransition` closures as none of these are called during the transition.
Nor will other state's `didExit` or `didEnter` closures be called. The idea being that a background transition can effectively occur at any time and from any state with the intention of returning to that state once the user returns to the app. 

Mostly, background transitions are useful for things like putting up privacy screen.

*Also note that trying to register more than one background state will throw an error.*

```swift
Let background = StateConfig<MyState>.background(.background,
                                          didEnter: { machine, previous in … },
                                          didExit: { machine, next in … })
```

# The state machine

```swift
let machine = StateMachine(name: "User state machine") { machine, previous in … }
                           withStates: {
                               StateConfig<MyState>(.initialising… )
                               StateConfig<MyState>(.registering… )
                               StateConfig<MyState>(.loggedIn… )
                               StateConfig<MyState>(.loggedOut… )
                           }
```

The optional **`name`** argument can be used to uniquely identify the state machine in logs and debug sessions. If you don't pass it, a UUID appended with the type of the state identifier is used. This is purely to support debugging apps which make use of multiple state machines.

The **`didTransition`** closure is also optional and if passed,  is called after each transition.

After that comes a list of the states for the machine expressed in a builder style.

_Note: Machinus requires at least 3 states. This is simple logic. A state machine is useless with only 1 or two states. So the initialiser will fail with anything less than 3._ 

## Properties

The core `StateMachine<S>` class has some additional properties available:

* **`postNotifications: Bool`** - Defaults to false. When true, every time a transition is successful a matching notification is posted. This allows code that is far away from the machine to still see what it's doing. *See [Listening to transition notifications](#listening-to-transition-notifications).*

* **`state: S`** - Returns the current state of the machine. Because states implement `StateIdentifier` which is an extension of `Hashable` they are easily comparable using standard operators.

```swift
machine.state == .initialising // = true
```

# Transitions

A '**Transition**' is the process of changing from one state to another. It sounds simple, but it's actually a little more complicated than you might think.

All transitions are queued asynchronously. This is done so that the machine can fully process all the closures and processes it has to before moving on to the next transition. This also allows for the same closures to queue up new transitions without messing up the one currently being processed.

## Manual transitions

Manual transitions are the simplest to understand. You simply request the state you would like the machine to transition to like this: 

```swift
await machine.transition(to: .registering) { result in
    if let Result.failure(let error) = result {
        // Handle the error
        return
    }
    // The transition was successful. Result contains the previous state.
}
```
Note that the transition is not executed directly, but queued for execution. This is to ensure that a state `didEnter` or `didExit` or even the engines own `didTransition` closure can request another transition without interfering with the current transition in progress. 

If there is a problem with the transition it will be returned in the optional closure. Otherwise the previous state is passed in case you need to check it.

### Transition execution

When you request a transition the machine follows these steps:

1. The transition is queued for execution.
2. If there is no transition already in flight, the engine picks up the next transition from the queue.
3. The transition is pre-flighted. This can fail the transition for any of these reasons, passing the error back in the transitions closure result:
    * The new state is not a known state. Throws `StateMachineError.unknownState(S)`.
    * Unless a global state, the requested state does not exist in the list of allowed transitions of the current state. Throws `StateMachineError.illegalTransition`.
    * The new state's transition barrier denies the transition. Throws a `StateMachineError.transitionDenied`.
    * The new state and the old state are the same. Throws a `StateMachineError.alreadyInState`.
4. The transition is now executed using these steps:
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

machine.transition { result in /* … */ }
```

The call to execute a transition is the same except that there is no `to:S` state argument. The lack of that argument tells the machine to look for a dynamic closure and execute it to obtain the desired state to transition to.

If there's no dynamic closure on the current state, the machine will return a `StateMachineError.noDynamicClosure(S)` error to indicate where a dynamic was expected to be found. 

## Background transitions (iOS & tvOS)

Background transitions are special cases because they are not considered part of the normal state map. In a sense background transitions are considered to be 'outside' the normal state transition map. Sure you can request a transition to a background state just like transitioning to any other state, and it will be run through the same process. However if the transition to background is triggered by the devices state notifications it runs an entirely different set of transition events.

### Going into the background

1. The background transition is queued. 
1. Upon execution, the current state is stored as the state to restore to.
1. The state is changed to the background state.
1. The background state's `didEnter` closure is called passing the restore state as the previous state.

Note that no other closures are called as the machine is assuming that when restored, it will return to the current state. 

### Returning to the foreground

Foreground transitions run this series of events.

1. The foreground transition is queued.
1. Upon execution, the restore state's configuration is retrieved.
1. If the state has a `transitionBarrier` it's executed, and if the result is `.redirect(to:)`, then the restore state is updated to be the redirect state and the transition is requested again.
1. The state is changed to the restore state.
1. The background state's `didExit` closure is called passing the restore state.

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


# Resetting the engine

Resetting the state machine is quite simple. `.reset()` will hard reset the engine back to the 1st state in the list. It does not execute any actions or rules as it's a hard reset.

```swift
await machine.reset()
```

*Note: `reset()` is the only way to exit a final state. Although that's generally not something that you would want to do and suggests that your final state is not really final.*
