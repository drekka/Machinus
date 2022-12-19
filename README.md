# Machinus V3

[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://GitHub.com/drekka/Machinus/graphs/commit-activity)
[![GitHub license](https://img.shields.io/github/license/drekka/Machinus.svg)](https://github.com/drekka/Machinus/blob/master/LICENSE)
[![GitHub tag](https://img.shields.io/github/tag/drekka/Machinus.svg)](https://GitHub.com/drekka/Machinus/tags/)

A powerful yet easy to use state machine for iOS/tvOS/MacOS. 

## Quick feature list

* Async/await driven.

* Dynamic transitions.

* State change closures.

* Combine `Publisher` and async/await `AsyncSequence` state change consumers.

* State change notifications.

* Transition barriers to deny, redirect or fail a transition.

* iOS/tvOS app background state tracking.
 
## Index

- [Machinus V3](#machinus-v3)
  - [Quick feature list](#quick-feature-list)
  - [Index](#index)
- [What is a state machine and why would I need one?](#what-is-a-state-machine-and-why-would-i-need-one)
- [Machinus?](#machinus)
- [Quick guide](#quick-guide)
  - [1. Installing](#1-installing)
  - [2. Declare the states](#2-declare-the-states)
  - [3. Create the states and machine](#3-create-the-states-and-machine)
  - [4. Transition](#4-transition)
- [States](#states)
  - [Default states](#default-states)
  - [Global states](#global-states)
  - [Final states](#final-states)
  - [Final global states](#final-global-states)
  - [The background state (iOS/tvOS only)](#the-background-state-iostvos-only)
- [The state machine](#the-state-machine)
  - [Properties & Functions](#properties-functions)
- [Transitions](#transitions)
  - [The transition process](#the-transition-process)
    - [Phase 1: Preflight](#phase-1-preflight)
    - [Phase 2: Transition](#phase-2-transition)
  - [Manual transitions](#manual-transitions)
  - [Dynamic transitions](#dynamic-transitions)
  - [Background transitions (iOS & tvOS)](#background-transitions-ios-tvos)
    - [Going into the background](#going-into-the-background)
    - [Returning to the foreground](#returning-to-the-foreground)
- [Watching transitions](#watching-transitions)
  - [Machine closure](#machine-closure)
  - [Combine](#combine)
  - [Awaiting AsyncSequence](#awaiting-asyncsequence)
- [Resetting the engine](#resetting-the-engine)

# What is a state machine and why would I need one?

Sometimes an app needs to know about the state of something. For example, a user can be _'Registered'_, _'logged out'_, _'logged in'_,  _'inactive'_,  _'pending'_, _'banned'_, and _'timed out'_. It's possible to track this using booleans or  enums with `if-then-else`, `switch` and other language features, but as your app grows it can often become unmanageable. Especially with larger code bases where the tracking of state gets spread across many files and there have been a number of developers with different ideas on how to do it. The result being a code base that absorbs large amounts of time and effort to understand, debug and extend. 

Addressing state based complexity and non-centralised management is where state machines can come into their own. Apart from centralising the management of state, they can run code when that state changes, define what's a valid or invalid change, and often provide other related functionality as well.

Used right, a state machine can manage complexity and simplify code.

# Machinus?

If you look around [Github](https://www.github.com) you will find quite a number of state machine projects. Most of which fall into one of two designs. Those that use structs or classes to define their state, and those that used enums. 

The enum based machines tend to be pretty easy to use because everything is driven by the enum that defines the states. But they're often simple, limited by what you can do with an enum. Struct and class based machines usually have more functionality, but then place the onus on the developer to keep references to the struct or class for talking to the machine.

Machinus uses a different approach. It uses a simple protocol which you can use to turn anything into a state. Although generally you'd use an enum because they're easy to use when talking to a state machine. But to provide maximum flexibility, it uses structs to configure the machine. This gives it the benefits of both approaches. Add to that built in app background tracking (iOS and tvOS), plus some other unique features and (IMHO) Machinus is the best state machine available. 

But I might be biased :-)

# Quick guide

So let's look at using Machinus in 4 easy steps.

## 1. Installing

Machinus (V3) is supplied as a Swift Package Manager framework. So just search using the url [https://github.com/drekka/Machinus](https://github.com/drekka/Machinus) in Xcode's SPM package search.

## 2. Declare the states

States are declared by applying the `StateIdentifier` protocol. You can use anything, but generally I'd recommend applying it to an enum as they're the easiest thing to use as a state. 

```swift
enum UserState: StateIdentifier {
    case initialising
    case registering
    case loggedIn
    case loggedOut
    case background
}
```

`StateIdentifier` is `Hashable` and Swift will automatically synthesise the required functions unless you are using associated values. In that case you will need to fill out the functions required to implement `Hashable`.

## 3. Create the states and machine

With a `StateIdentifier` done we can setup and configure the machine. This is done with instances of **`StateConfig<S>`** (where `<S>` is any `StateIdentifier` type) which are instantiated with the state change functionality you want to execute, plus what are considered valid transitions for each state and other functionality. For example:

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

Once this is done the `StateConfig<T>` instances are no longer needed because the rest of the public interface to the state machine uses the state identifiers setup in step 2. 

_Also note that Machinus automatically starts in the first state listed, so …_

```swift
await machine.state == .initialising // -> true
```

## 4. Transition

Now the state machine is ready we can ask it to transition.

```swift
let result = try await machine.transition(to: .loggedOut)
// result.from <- The state the machine was in.
// result.to <- The state the machine is in now.
```

And given the states we have defined, this will:

1. Change to the `.loggedOut` state.
1. Run the `.loggedOut` state's `didEnter` closure which calls `displayLoginScreen()`.

_And … Ta da! We've just used a state machine!_

# States

As the [Quick guide](#quick-guide) shows, states are configured using the **`StateConfig<S>`** class with `<S>` being anything that implements the `StateIdentifier` protocol. Mostly these states will be fairly generic, but Machinus also has some special states you can use for greater control.

## Default states

These are the most common type of state you will use and are created using **`StateConfig<S>`**'s default initialiser. This takes the **`StateIdentifier`** which identifies the state, plus  some optional closures and a list of other states that this one can transition to:

```swift
// StateConfig with the works!
Let loggedIn = StateConfig<MyState>(.loggedIn,
                                     didEnter: { fromState, toState in … },
                                     didExit: { fromState, toState in … },
                                     dynamicTransition: { … },
                                     transitionBarrier: { state in … },
                                     canTransitionTo: state1, state2, state3, …) {
```
* **State identifier** (required) - The unique identifier of the state. `.loggedIn` in the above example.

* **`didEnter`** (optional) - Executed when the machine transitions to this state.

* **`didExit`** (optional) - Executed when the machine leaves this state. 

* **`dynamicTransition`** (optional) - Can be executed to decide what state to transition to.

* **`transitionBarrier`** (optional) - If defined, is called before another state can transition to this one. It's job is to decide if the transition to this state should be allowed and can return:
    * **`.allow`** - Allow the transition to occur.
    * **`.redirect(to:S)`** - Redirect to another state.
    * **`.fail`** - Fail the transition with `StateMachineError.transitionDenied`.

    Barriers are also passed the current state of the machine in case they need to check which state is requesting to transition to this one.

* **`canTransitionTo`** (optional) - A list of states that can be transitioned to. If you request a transition to a state that's not in this list, a `StateMachineError.illegialTransition` error will be thrown. *Note - there are exceptions to this such as global and background states.*

> **A note on nested transitions**
> Whilst it's possible to request a transition change in one of the callbacks, you should be careful about doing it. Any nested transition request will be run immediately and change the state again. So for example, if you request a new state change in a `didExit` it will run within that closure and before any subsequent `didEnter` or `didTransition` closures are run. Those closures will still be passed the correct states representing the change, but the actual state of the machine will have moved on. So I'd suggest that if you do need to do this, you queue the new request on the main thread or something similar so the current transition gets to finish before the new one is executed. 

## Global states

Normally you cannot transition to a state that's not in the `canTrasitionTo` list of the current state. However **Global states** ignore this list and can be transitioned to from any other state. This makes them particularly useful for more global types of scenarios.

```swift
Let timeout = StateConfig<MyState>.global(.timeout,
                                          didEnter: { fromState, toState in … },
                                          didExit: { fromState, toState in … },
                                          dynamicTransition: { … },
                                          transitionBarrier: { state in … },
                                          canTransitionTo: state1, state2, state3, …)
```

> *The only states that cannot transition to a global state are final states.*

## Final states

Final states are "dead end" states. ie. once the machine transitions to them it cannot leave. For example, a final state could be used when the app hits an error that cannot be recovered from. Because they cannot be left, final state's don't need `canTransitionTo` lists, `dynamicTransition` or `didExit` closures.

```swift
Let configLoadFailure = StateConfig<MyState>.final(.configLoadFailure,
                                                   didEnter: { fromState, toState in … },
                                                   transitionBarrier: { state in … })
```

> *Technically you can "recover" from a final state by resetting the machine. See [Resetting the engine](#resetting-the-engine).*

## Final global states

Then there are final global states which are quite simply both final and global.

```swift
Let unrecoverableError = StateConfig<MyState>.final(.majorError,
                                                    didEnter: { fromState, toState in … },
                                                    transitionBarrier: { state in … })
```

## The background state (iOS/tvOS only)

If you are using Machinus in an iOS or tvOS app, here is a very specialised state available which has been specifically designed to support the app being pushed to and from the background. A common example of this is the feature of  overlaying a privacy screen when the app is pushed into the background and removing it when it comes back to the foreground.

When you configure a background state Machinus will automatically start watching `UIApplication`'s foreground and background notifications for you. When the app is then pushed into the background, Machinus will automatically transition to your background state and inversely, transition back to the current state when the app is returned to the foreground. 

The Background state involves some unique processing. It don't have `canTransitionTo` lists, `transitionBarriers` or `dynamicTransition` closures as the transitions to and from the background don't call them as they do for other states. Nor are the current state's `didExit` or `didEnter` closures called. 

The reason is that background transitions are considered ["out of band"](https://en.wikipedia.org/wiki/Out-of-band_data). Effectively parallel to the machine's normal state changes and their execution reflects that by keeping the other states unaware of the jump in and out of background. 

> *You can only register one background state.*

> *See [background transitions](#background-transitions-ios-tvos) for details on what is called and when.*


```swift
Let background = StateConfig<MyState>.background(.background,
                                                 didEnter: { fromState, toState in … },
                                                 didExit: { fromState, toState in … })
```

# The state machine

Here is the full initialiser for the state machine:

```swift
let machine = StateMachine(name: "User state machine") { fromState, toState in … }
                           withStates: {
                               StateConfig<MyState>(.initialising, … )
                               StateConfig<MyState>(.registering, … )
                               StateConfig<MyState>(.loggedIn, … )
                               StateConfig<MyState>(.loggedOut, … )
                           }
```

The optional **`name`** argument is used to uniquely identify the state machine in logs and debug sessions. If you don't pass it, a UUID appended with the type of the state identifier is used. This is purely for debugging when multiple state machines are in play and logging is on.

The optional **`didTransition`** closure is called after each transition and is passed the from and to state of the machine.

After that is the list of the states used to define the machine's behaviour. Note these are listed using a builder style (AKA SwiftUI).

> _Machinus requires a minimum of 3 states. This is simply because state machine's are pretty useless with only one or two states. So the initialiser will fail with anything less than 3._ 

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

## The transition process

The idea of a '**Transition**' changing the state of the machine sounds simple, but it's actually a little more complicated than you might think. 

### Phase 1: Preflight

Preflight is where the request is checked to ensure it is a valid. Preflight can fail the transition for any of the following reasons:

* The new state is not a known registered state. Throws `StateMachineError.unknownState(S)`.

* Unless a global state, the requested state does not exist in the list of allowed transitions for the current state. Throws `StateMachineError.illegalTransition`.

* The new state's transition barrier denies the transition. Throws a `StateMachineError.transitionDenied`.

* The new state and the old state are the same. Throws a `StateMachineError.alreadyInState`.

### Phase 2: Transition

Providing the preflight has allowed the transition, these steps are followed:

1. The internal state is updated, triggering the `statePublisher` and `stateSequence` properties.

1. The previous state's `didExit` closure is called.

1. The new state's `didEnter` closure is called.

1. The machine's `didTransition` closure is called.

1. If `postNotifications` is true, a state change notification is sent.

1. Finally The old and new state of the machine are returned to the calling code as a tuple.

## Manual transitions

Manual transitions are where you specify the desired new state as an argument. For example: 

```swift
let result: TransitionResult<MyState> = try await machine.transition(to: .registering)
// result.from <- Previous state
// result.to <- new state
```

**`TransitionResult`** is simply a type alias for the tuple `(_ from: <S>, _ to:<S>) where S: StateIdentifier`.


## Dynamic transitions

Dynamic transitions are processed exactly the same as a manual transition except for one thing. you don't pass any state argument. Instead the machine runs the current state's `dynamicTransition` closure, expecting ti to return the state to transition to. For example:

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

> _If there was no dynamic closure specified for current state, the machine will throw a `StateMachineError.noDynamicClosure(S)` error._ 

## Background transitions (iOS & tvOS)

Background transitions are special cases because they are not considered part of the normal state map. Automatically triggered by the app being backgrounded or restored, they involve a unique and simplified transition process. In both cases skipping pre-flight and only running some of the closures. 

### Going into the background

1. The current state is stored.

1. The state is changed to the background state.

1. The background state's `didEnter` closure is called.

1. The machine is told to suspend processing until a foreground transition is requested. If any transition requests are then received a `StateMachineError.suspended` error will be thrown.

### Returning to the foreground

Foreground transitions revert the machine back to the state it was in when backgrounded.

1. The machine is told to resume transition processing.

1. If the stored previous state has a `transitionBarrier` it is executed and if the result is `.redirect(to:)`, then the redirect state is set as the  state to restore. `.fail` is ignored.

1. The state is changed to the restore state.

1. The background state's `didExit` closure is called.

# Watching transitions

Apart from the individual closures on the states, there are multiple ways to observe a state transition.

## Machine closure

This is the closure that is passed to the machine when you create it like this:

```swift
let machine = StateMachine(name: "User state machine") { fromState, toState in
                               // Called on every state change.
                           }
                           withStates: {
                               ...
                           }
```

## Combine

Machinus also has a Combine publisher which emits states as they change:

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

> *Note that on subscription, Machinus will immediately send the current state so your code knows what it is.*

## Awaiting AsyncSequence

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

## Listening to transition notifications

Sometimes a piece of code far away from the machine needs to be notified of a state change and it may code consuming or too difficult to pass a reference to the machine. Machinus supports this by providing a property which enables a  notification each time the state changes. 

```swift
await machine.setPostNotifications(true)

// Then somewhere else ...
try await machine.transition(to: .loggedIn) { _, _ in } 
```

And far far away...

```swift
let observer = NotificationCenter.default.addStateChangeObserver { [weak self] (stateMachine: any Machine<MyState>, fromState: MyState, toState: MyState) in
    // Do something here.
}
```

> *It's important to define the state types in the closure as the observer will only be called for state machines of that type.*



# Resetting the engine

Resetting the state machine hard resets the engine back to the 1st state in the list. It does not execute any state closures.

```swift
try await machine.reset { ... }
```

> *`reset()` is the only way to exit a final state. Although that's generally not something that you would want to do and suggests that your final state is not really final.*
