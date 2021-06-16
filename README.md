# Machinus
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Build Status](https://travis-ci.com/drekka/Machinus.svg?branch=master)](https://travis-ci.com/drekka/Machinus)

## Quick feature list

* Asynchronous thread safe transitions.
* Closures for attaching functionality to transitions.
* Barrier closures that can deny, redirect or fail a transition.
* Closure based dynamic transitions.
* App background tracking with a custom state.
* Combine publishing of state changes.
* Optional notifications of state changes.
* settable execution dispatch queue.
* Builder syntax.

## Index

* [Quick guide](#quick-guide)
* [State configurations](#state-configurations)
    * [Allowed transitions](#allowed-tansitions)
    * [didEnter](#didenter)
    * [didExit](#didexit)
    * [Dynamic transitions](#dynamic-transitions)
    * [Transition barriers](#transition-barriers)
* [The state machine](#the-state-machine)
    * [Options](#options)
    * [Checking the engine's state](#checking-the-engines-state)
* [Transitions](#transitions)
    * [Manual transitions](#manual-transitions)
    * [Dynamic transitions](#dynamic-transitions)
    * [Background transitions](#background-transitions)
    * [Transition errors](#transition-errors)
    * [Listening to transition notifications](#listening-to-transition-notifications)
    * [Subscribing to transitions with Combine](#subscribing-to-transitions-with-combine)
 * [Resetting the engine](#resetting-the-engine)
 * [FAQ](#faq)
    * [Why does Machinus execute transitions asynchronously?](#why-does-machinus-execute-transitions-asynchronously)

# What is a state machine?

In complex code bases there is often a need to manage a number of states that something can be in. For example a user can have a variety of states - _'Registered'_, _'logged out'_, _'logged in'_,  _'inactive'_,  _'pending'_ and _'banned'_. These could manage with booleans or an enum, but you'd still need a lot of _if-then-else_ and _switch_ statements throughout your code and as we know, that can easily become an unmaintainable mess that's almost impossible to understand, debug or develop. 

State machine can help marshal these situations by managing the states of something and automatically running the correct code when a state changes. In addition they can also define a "map" of valid state changes and provide other useful functionality. Done right, a state machine can dramatically simplify your code.

# Machinus?

Yes it's a state machine and I wrote it. But if you look around [Github](https://www.github.com) you'll find plenty of state machine implementations. So why did I bother writing another? 

Simply put - Because I didn't find a single one that had all the features I wanted, and ... because I could. 

All the state machine implementations I found on Github fell into two broad categories, those that define their states using classes, and those that define them using enums. The enum based machines tended to be simpler to use because performing state changes was just a matter of passing an enum value. However they also tended to have less functionality because everything was attached to the enums. Class based machines generally had more functionality because you can do more with a class, but you had to keep references to the states you'd setup in order to pas them to the machine when you needed a state change.

With Machinus I wanted the best of both worlds so I decided to use a protocol that would define what represented a state. Generally this would be applied to enums but it could be applied to anything. To configure the machine I then use these state identifiers to create a set of state configurations containing the associated functionality for each state. After that all I need is the state identifiers to talk to the machine, thus I've got usability of enums and the flexibility of classes. Add in features like app background tracking and other unique features and (IMHO) Machinus is the best state machine out there.

# Quick guide

Let's look at using Machinus in 4 easy steps.

## 1. Installing

### [Carthage](https://github.com/Carthage/Carthage)

Add this to your `Cartfile`:

```
github "drekka/Machinus"
```

### Swift package manager

Search using the url [https://github.com/drekka/Machinus](https://github.com/drekka/Machinus) in package search.

### CocoaPods

I know it's controversial, but I don't recommend CocoaPods because I don't like how it works and what it does to an Xcode project.

## 2. Declare the states

States are declared by applying the `StateIdentifier` protocol. Generally (and I'd recommend this) the easiest usage is to apply it to an enum. 

```swift
enum UserState: StateIdentifier {
    case initialising
    case registering
    case loggedIn
    case loggedOut
}
```

In the above example Swift will generate the `Hashable` and `Equatable` syntactical sugar needed. 

## 3. Create the states and machine

Now we can create state configurations and setup the machine.  `StateConfig<T>` is the most commonly used configuration type, but there's also `BackgroundStateConfig<T>`, `GlobalStateConfig<T>` and  `FinalStateConfig<T>` for specific cases. `<T>` of course, being the previously created `StateIdentifier` type. In our case, `UserState`.

```swift
let machine = StateMachine {

                  StateConfig<MyState>(.initialising,
                                       didEnter: { _ in reloadConfiguration() },
                                       canTransitionTo: .loggedOut)
                                    
                  StateConfig<MyState>(.loggedOut, 
                                       didEnter: { _ in displayLoginScreen() },
                                       didExit: { _ in hideLoginScreen() },
                                       canTransitionTo: .loggedIn, registering)

                  StateConfig<MyState>(.loggedIn,
                                       didEnter: { _ in displayUsersHomeScreen() },
                                       transitionBarrier {
                                           return userIsLoggedIn() ? .allow : .redirect(to: .loggedOut)
                                       },
                                       canTransitionTo: .loggedOut)

                  StateConfig<MyState>(.registering, 
                                       didEnter: { _ in displayRegistrationScreen() },
                                       dynamicTransition: {
                                           return registered() ? .loggedIn : .loggedOut
                                       },
                                       canTransitionTo: .loggedOut, .loggedIn)

                  BackgroundStateConfig<MyState>(.background,
                                                 didEnter: { _ in displayPrivacyScreen() },
                                                 didExit: { _ in hidePrivacyScreen() })
              }
```

After this piece of code the `StateConfig<T>` instances are no longer needed because from here on we use the `StateIdentifer` enum to talk to the machine. 

Machinus also starts in the first state listed, so …

```swift
machine.state == .initialising // -> true
```

## 4. Transition

Ok, the state machine is setup so let's ask it to transition to a different state.

```swift
machine.transition(to: .loggedOut)
```

This will trigger a sequence of events:

1. The machine will change to the `.loggedOut` state.
1. The `.loggedOut` state's `didEnter` closures to be executed and call `displayLoginScreen()`.

_And … Ta da! We've just used a state machine!_

# State configurations

`StateConfig<T>` is the most commonly used state configuration class. But there are several others that provide additional functionality. So here's the available configuration types and what they provide:

* **`StateConfig<T>`** - The parent class of all state types. It defines:
	* The **State identifier**
	* The state's **`didEnter`** closure that is executed when the machine transitions to this state.
	* The state's **`didExit`** closure that is executed after the machine exits the state.
	* A **`dynamicTransition`** closure which can be executed to generate the next state for the machine.
	* A **`transitionBarrier`** closure that's called when the machine enters the state. A barrier can **allow**, **deny** it or **redirect** the transition to a different state.
	* **`canTransitionTo`** is a list of states that this state is allowed to transition to. If a transition to any other state is requested an error will be returned instead.

* **`GlobalStateConfig<T>`** - Global states are an special extension of `StateConfig<T>` that do not need to appear in other state `canTransitionTo` lists. Essentially any state can transition to a global state. The only exception being final states.

* **`FinalStateConfig<T>`** - Final states are another special extension of `StateConfig<T>` that cannot be left once entered. A situation where you might need such a state would be where the app hits an error that cannot be recovered from. The final state could then be configured to display a final error. `FinalStateConfig<T>`'s don't have allowed transition lists or `didExit` closures.

* **`BackgroundStateConfig<T>`** - You can only pass one background state to a machine and its presence will tell the machine to start watching the app's state. When the app goes into the background, the machine automatically transitions to the background state, and when it comes forward again, the machine automatically transitions back to the prior state. Background states don't need `canTransitionTo` lists, barriers and dynamic transition closures.

## Arguments

The only required parameter to setup a state is it's identifier. However you usually want something to happen when that state is entered and you also usually want to be able to change from that state to another. So there are a variety of arguments that you can pass to a  state configuration.

## Allowed transitions

Except for final and background states, if you want to be able to transition to another state you have need to specify the `canTransitionTo` argument with a list of the valid states that can be transitioned to.

```swift
StateConfig<MyState>(.loggedOut, canTransitionTo: .loggedIn, registering)
```

## didEnter

Executed after the machine has successfully transitioned to a new state, the `didEnter` closure on the new state is passed the previous state of the machine so it can be referenced if necessary.

```swift
BackgroundStateConfig<MyState>(.background, didEnter: { previousState in
                                                          displayPrivacyScreen() 
                                                      })
```

## didExit

Executed after the machine has successfully transitioned to a new state, the `didEnter` closure on the old state is passed the next state of the machine so it can be referenced if necessary.

```swift
BackgroundStateConfig<MyState>(.background, didExit: { nextState in
                                                         removePrivacyScreen() 
                                                     })
```

## Dynamic transitions

`dynamicTransition` closures are executed when a transition is requested without a state argument. When that occurs the current state's `dynamicTransition` closure is executed to get the next state. 

```swift
StateConfig<MyState>(.registering, 
                     dynamicTransition: {
                         return registered() ? .loggedIn : .loggedOut
                     },
                     canTransitionTo: .loggedOut, .loggedIn)
```

When `transition()` is called the `.registering` state's dynamic transition closure is then executed to obtain the state to transition to.

## Transition barriers

Sometimes there is logic that might want to bar a transition to a state. It could be added around the engine, but it would be easier if the engine could take care of this and that is what a transition barrier does. Basically if a state has a transition barrier, any transition to it executes the barrier closure to decide if the transition should be allowed. 

```swift
Let StateConfig<MyState>(.loggedIn, 
                     transitionBarrier {
                         return userIsLoggedIn() ? .allow : .redirect(to: .loggedOut)
                     },
                     canTransitionTo: .loggedOut)
```

In this case, if a request to transition to `.loggedIn` is received, the barrier is executed. If the user is logged in then the transition is allowed, if not then the machine is asked to redirect to the `.loggedOut` state.

Transition barrier's can return one of 3 responses:

* **`.allow`** - Allow the transition to occur.
* **`.redirect(to:T)`** - Redirect to a different state.
* **`.fail`** - Fail the transition with a `StateMachineError.transitionDenied` error.

# The state machine

Declaring the machine can be done in several ways.

```swift
// Old school.
let machine = StateMachine(name: "User state machine", didTransition: { from, to in
                               // didClosure executed after a state has changed.
                           },
                           withStates: 
                               StateConfig<MyState>(.initialising… ),
                               StateConfig<MyState>(.registering… ),
                               StateConfig<MyState>(.loggedIn… ),
                               StateConfig<MyState>(.loggedOut… )
                           )

// Multi-closure Builder style
let machine = StateMachine(name: "User state machine") { from, to in
                               // didClosure executed after a state has changed.
                           }
                           withStates {
                               StateConfig<MyState>(.initialising… )
                               StateConfig<MyState>(.registering… )
                               StateConfig<MyState>(.loggedIn… )
                               StateConfig<MyState>(.loggedOut… )
                           }
```

The optional `name` argument can be used to uniquely identify the state machine in logs and debug sessions. If you don't pass it, a UUID appended with the type of the state identifier is used.

The `didTransition` closure is also optional and if passed,  is called after each transition.

_Note: Machinus requires at least 3 states. This is simple logic. A state machine is useless with only 1 or two states. So the initialiser will fail with anything less than 3._ 

## Options

In addition to the initialiser arguments there are several properties that can be set.

* `postNotifications: Bool` - Defaults to false. When true, every time a transition is successful a matching notification is posted. This allows code that is far away from the machine to still see what it's doing. *See [Listening to transition notifications](#listening-to-transition-notifications).*

* `transitionQueue: DispatchQueue` - Defaults to `DispatchQueue.main`. State transitions are dispatched onto this queue.

## Checking the engine's state

Machinus also has a `state` property which returns the current state of the machine. Because states implement `StateIdentifier` which is an extension of `Hashable` and `Equatable` they are easioly comparable states using standard operators.

```swift
machine.state == .initialising // = true
```

# Transitions

A '**Transition**' is the process of changing from one state to another. It sounds simple, but it's actually a little more complicated than you might think.

All transitions are queued asynchronously on the `transitionQueue`. The reason for this is that by queuing transitions, we allow for the code in one of the executed closures to trigger another transition without trying to nest it inside the current transition.

## Manual transitions

Manual transitions are the simplest to understand. You request the transition passing the desired state as an argument. 

```swift
machine.transition(to: .registering) { result in
    if let Result.failure(let error) = result {
        // Handle the error
        return
    }
    // The transition was successful. Result contains the previous state.
}
```

If the transition is successful the completion closure is called with the previous state of the machine. If an error occurred, a failure is returned with the error that generated it.

### Transition execution

A transition is composed of a number of events. Here's how it works:

1. The transition is queued on the queue referenced by the `transitionQueue` property.
1. Upon execution, pre-flighting is done to check the transition. Pre-flight can fail for any of these reasons:
    * The new state is not a known state. Generates a `fatalError()`.
    * The new state is not global or in the list of allowed transitions of the current state. Returns a `.illegalTransition` error.
    * The new state's transition barrier denies the transition. Returns a `.transitionDenied` error.
    * The new state and the old state are the same. Returns an `.alreadyInState` error.
1. If the pre-flight returned an error, it is returned as the result of the transition.
1. Otherwise the transition is executed:
    1. The state is changed.
    1. The old state's `didExit` closure is called passing the new state.
    1. The new state's `didEnter` closure is called passing the old state.
    1. The machine's `didTransition` closure is called, passing the old and new states.
    1. The state change notification is sent if `postNotifications` is true.
1. The transition request completion closure is called with the previous state as a result.

## Dynamic transitions

Dynamic transitions are exactly the same as a manual transition except that prior to running the core transition above, the `dynamicTransition` closure is executed to obtain the the state to transition too.

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

The call to execute a transition is even the same, except for the lack of the `to:` state argument. The lack of that argument is what tells Machinus to execute the dynamic transition closure. If there's no closure set on the current state, a `fatalError(…)` will be triggered because the developer as obviously miss-configured the machine. 

## Background transitions

Background transitions are special cases because they are not considered part of the normal state map. Sure you can request a transition to a background state just like transitioning to any other state, but when the machine triggers it in response to the apps state charging it runs an entirely different set of transition events.

### Transitioning to the background

1. The background transition is queued on the queue referenced by the `transitionQueue` property.
1. Upon execution, the current state is stored as the state to restore to.
1. The state is changed to the background state.
1. The background state's `didEnter` closure is called passing the restore state as the previous state.

### Transitioning to the foreground

Foreground transitions are also special in that they are not considered part of the normal state map. They run this set of events.

1. The foreground transition is queued on the queue referenced by the `transitionQueue` property.
1. Upon execution, the restore state's configuration is retrieved.
1. If the state has a `transitionBarrier` it's executed, and if the result is `.redirect(to:)`, then the restore state is updated to be the redirect state.
1. The state is then changed to the restore state.
1. The background state's `didExit` closure is called passing the restore state.

## Transition errors

Transitions can return the following `MachinusError` errors:

* **.alreadyInState** - Returned if a state change is requested, the requested state is the same as the current state and the `enableSameStateError` flag is set.

* **.transitionDenied** - Returned when a transition barrier rejects a transition.

* **.illegalTransition** - Returned when the target state is not in the current state's allowed transition list.

* **finalState** - Returned if the machine is currently in a final state.

## Subscribing to transitions with Combine

Machinus is Combine aware with the machine being a Combine `Publisher`. Here's an example of listening to state changes.

```swift
machine.sink { newState in
                print("Received " + String(describing: newState))
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

Note that on subscription, Machinus will immediately send the current state value so your code knows what it is.

# Resetting the engine

Resetting the state machine is quite simple. `.reset()` will hard reset the engine back to the 1st state in the list. It does not execute any actions or rules as it's a hard reset.

```swift
machine.reset()
```

*Note: `reset()` is the only way to exit a final state. Although that's generally not something that you would want to do and suggests that your final state is not really final.*
 
# FAQ
## Is Machinus thread safe?

I believe so although I'm not sure how to definitively say. When Machinus executes a transition it sets a `NSLock` so that only one thread can execute the core transition code at one time. Only upon exiting a transition is the lock unlocked.

## Why does Machinus execute transitions asynchronously?

Originally I wanted Machinus to be synchronous, then I realised that driving things asynchronously was easier to write. Especially when you consider the risk of a `did…` closure triggering another state changes. In that nested state change scenario, synchronous execution becomes very difficult to manage and asynchronous queuing makes things simpler.