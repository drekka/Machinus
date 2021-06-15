# Machinus
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Build Status](https://travis-ci.com/drekka/Machinus.svg?branch=master)](https://travis-ci.com/drekka/Machinus)

## Quick feature list

* Asynchronous transitions with optional notifications.
* Ability to specify valid transitions.
* App background tracking with a custom state.
* Combine publishing.
* Multiple transition closures where code can be attached for execution during transitions.
* Transition barriers that can deny the transition or dynamically or redirect to another state.
* Manual, or closure based dynamic transitions.
* Custom transition queues.
* Builder style syntax.

## Index

* [Quick guide](#quick-guide)
* [Configuring states](#configuring-states)
    * [Allowed transitions](#allowed-tansitions)
    * [didEnter](#didenter)
    * [didExit](#didexit)
    * [Dynamic transitions](#dynamic-transitions)
    * [Transition barriers](#transition-barriers)
* [The state machine](#the-state-machine)
    * [Options](#options)
    * [Checking the engine's state](#checking-the-engines-state)
    * [Transitions](#transitions)
        * [Transition execution](#transition-execution)
        * [Manual transitions](#manual-transitions)
        * [Dynamic transitions](#dynamic-transitions)
        * [Transition errors](#transition-errors)
        * [Listening to transition notifications](#listening-to-transition-notifications)
        * [Subscribing to transitions with Combine](#subscribing-to-transitions-with-combine)
    * [Resetting the engine](#resetting-the-engine)
    * [FAQ](#faq)
        * [Why does Machinus execute transitions asynchronously?](#why-does-machinus-execute-transitions-asynchronously)

# What is a state machine?

State machines are a solution to the problem of managing complex states in your app. For example you might have multiple user states. _'Registered'_, _'logged out'_, _'logged in'_,  _'inactive'_,  _'pending'_ and _'banned'_. You could manage these and the logic they drive with booleans or an enum, and implement lots of _if-then-else_ and _switch_ statements through out your code, but as your app grows they're likely to become an unmaintainable mess that's almost impossible to understand, debug and develop. A state machine solves this by centralising the management of these states, the logic they drive and the rules of what state changes are allowed. Done right, it can dramatically simplify your code.

# Machinus?

If you look around [Github](https://www.github.com) you'll find plenty of state machine implementations. So why did I bother writing another? 

Simply put - Because I didn't find a single one that had all the features I wanted, and ... because I could. 

When I was looking around all the machines I found fell into designs that followed one of two styles, either managing states as classes, or managing them as enums. Enum machines tended to be simpler to use because of the nature of enums but were also limited by them as well. Class based machines generally had more functionality but were not as easy to use because you had to preserve the original state references and use them when talking to the machine.

So with Machinus I decided on a different approach. Machinus uses a protocol to drive what defines the identifier of a state. This makes it easy to talk to the machine through any sort of types you want, including an enum which is perhaps the easiest way to do it. The state identifiers are then linked with configurations that provide an extensive range of functionality. Thus Machinus gets the usability of the enum based machines and the flexibility of the class based machines. Add in app background tracking and several other unique features and (IMHO) Machinus is the best state machine out there.

# Quick guide

So enough of the chit chat, let's go through implementing Machinus in 4 easy steps.

## 1. Installing

### Carthage 

Machinus can be added to a [Carthage](https://github.com/Carthage/Carthage) driven project by adding this to your `Cartfile`:

```
github "drekka/Machinus"
```

### Swift package manager

Machinus can be included using Swift's package manager by searching with the url [https://github.com/drekka/Machinus]() in package search.

### CocoaPods

I know it's controversial, but don't use CocoaPods. It was never a good idea and I don't support it.

## 2. Declare the states

The states that Machinus manages are declared using the `StateIdentifier` protocol. Generally (and I'd recommend this) the easiest way to declare them is by using an enum: 

```swift
enum UserState: StateIdentifier {
    case initialising
    case registering
    case loggedIn
    case loggedOut
}
```

## 3. Create the states and machine

Now we can create the configuration for the state machine and start it. This involves creating state configurations using the  `StateConfig<T>`, `BackgroundStateConfig<T>`, `GlobalStateConfig<T>` and  `FinalStateConfig<T>` classes. `StateConfig<T>` being the most commonly used and the `<T>` type is the identifier type. In our case, `UserState`.

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

After this we no longer need to refer to the `StateConfig<T>` instances as we can use the enum to request state changes. 

Also Machinus by default starts in the first state listed, so …

```swift
machine.state == .initialising // = true
```


## 4. Transition

So now that that machine's configured, let's execute a transition from one state to enother.

```swift
machine.transition(to: .loggedOut)
```

This will caused the following to occur:

* The state of the machine to become `.loggedOut`.
* The `.loggedOut` state's `didEnter` closure to be executed which calls `displayLoginScreen()`.

_So - Ta da! We've just used a state machine!_

# Configuring states

The simplest setup for a state is an identifier. Nothing else is required. However such a state is generally not that useful so the configuration can contain a whole lot more.

Firstly there's several types of state configurations to choose from:

* **`StateConfig<T>`** - The most commonly used type of config and the parent of the other state types. Using this type you can define:
	* The **State identifier**
	* The **`didEnter`** closure called when the machine transitions to this state.
	* The **`didExit`** closure called when the machine exits the state.
	* A **Dynamic transition** closure which can be executed to dynamically select the next state. This is executed if the machine is asked to transition from this state without specifying which state to transition to.
	* A **Transition barrier** closure that's called before a transition to this state occurs. This closure can allow the transition, deny it or redirect the machine to different state.
	* A list of **Allowed transitions** which are states that the machine is allowed to transition to.

* **`GlobalStateConfig<T>`** - Global state configurations are the same as `StateConfig<T>` configurations except that any state can transition to a global state with it having to appear in the other states allowed transition list. In other words any state (except for those configured using `FinalStateConfig<T>`) can transition to them.

* **`FinalStateConfig<T>`** - Final states, once transitioned to, cannot be left. A good example where you might use one would be some sort of app error state which the app cannot recover from and therefore there is no ability to transition from it. `FinalStateConfig<T>`'s therefore, do not have allowed transition lists and `didExit` closures. Note that a machine reset will exit a final state.

* **`BackgroundStateConfig<T>`** - You can only declare one background state and it's presence tells the machine to start watching the app's state. When the app goes into the background the machine will then automatically transition to the background state and automatically transition back to the prior state when the app comes to the foreground again.<br /><br />
The transition process for a background state transition is also different to that for other states in that only the background state's `didEnter` and `didExit` closures are called. However the transition barrier of the state being returned to is called and if it returns a `.redirect(T)` reresponse the machine will then transition to the state specified instead of the original state it was going to restore.<br /><br />
Apart from that, all closures on other states and the machine are ignored during a transition to and from the background state. The logic for this is that background transitions are not considered part of the normal transition map. They can only be configured with `didEnter` and `didExit` closures. Allowed transition lists, barriers and dynamic closures make no sense for a background state.  

Now let's take a look at the various arguments to a config in detail.

## Allowed transitions

Except for global and background states, if you want to be able to transition from one state to another, you have to specify the states you want to transition to in the `canTransitionTo` list of a config.

```swift
StateConfig<MyState>(.loggedOut, canTransitionTo: .loggedIn, registering)
```

Simply says that the machine will allow transitions from `.loggedOut` to `.loggedIn` or `.registering`.

## didEnter

These closures are executed after the machine has successfully transitioned to a new state. They are passed the previous state of the machine so it can be referenced if necessary in the closure.

```swift
BackgroundStateConfig<MyState>(.background, didEnter: { previousState in
                                                          displayPrivacyScreen() 
                                                      })
```

This is executed after the `didExit` closure on the previous state.

## didExit

These closures are executed on a state after the machine has successfully transition from it to another state. It is passed the new state of the machine.

```swift
BackgroundStateConfig<MyState>(.background, didExit: { nextState in
                                                         removePrivacyScreen() 
                                                     })
```

This is executed before the `didEnter` closure on the next state.

## Dynamic transitions

Dynamic transitions allow you to specify a closure that determines the state to transition to at run time. For example, during the registration process a user might decide to cancel or otherwise not continue to register. So the next state could be one of several states based on logic that executes at that time.

One way to do this is to add a dynamic transition closure to the state config like this:

```swift
StateConfig<MyState>(.registering, 
                     dynamicTransition: {
                         return registered() ? .loggedIn : .loggedOut
                     },
                     canTransitionTo: .loggedOut, .loggedIn)
```

Then ask the machine to transition without specifying a state to transition to. When it receives a call like that, it looks for a  `dynamicTransition` closure and executes it to receive the state it should transition to.

Note: you can still [reset the machine](#resetting-the-engine) if you need to.

## Transition barriers

Sometimes you need to have some logic that decides whether a transition to a state should be allowed. This is what we call a transition barrier. Basically if a state has a transition barrier, any time the machine is asked to transition to it, the barrier is executed to decide whether to allow the transition. 

```swift
Let StateConfig<MyState>(.loggedIn, 
                     transitionBarrier {
                         return userIsLoggedIn() ? .allow : .redirect(to: .loggedOut)
                     },
                     canTransitionTo: .loggedOut)
```

In this case, if a request to transition to `.loggedIn` is received and the user is logged in then the transition will be allowed, if not then the machine will redirect to the `.loggedOut` state.

A transition barrier closure can return one of 3 responses:

* **`.allow`** - Allows the transition to occur as requested.
* **`.redirect(to:T)`** - Redirects to a different state. Useful for things like the above example where returning to the `.loggedIn` state should redirect to `.loggedOut` when the user has timed out.
* **`.fail`** - Fails the transition with a `StateMachineError.transitionDenied` error.

# The state machine

Declaring the machine can be coded in a number of different ways.

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

The optional `name` argument can be used to uniquely identify the state machine in logs and debug sessions. If you don't set it, a UUID appended with the type of the state identifier is used.

The `didTransition` closure is called after each transition.

_Note: Machinus requires at least 3 states. This is simple logic. A state machine is useless with only 1 or two states. So the initialiser will fail with anything less than 3._ 

## Options

* `postNotifications: Bool` (property)  - Default false. When true, every time a transition is done a matching state change notification will be sent. This allows objects which cannot directly access the machine to still know about state changes. See [Listening to transition notifications](#listening-to-transition-notifications)

* `transitionQueue: DispatchQueue` (property) - Default `DispatchQueue.main`. The dispatch queue that transition will be queued on.

## Checking the engine's state

Machinus has a `state` variable which allows you to see the current state of the machine. Because states are defined using the `StateIdentifier`, which is an extension of `Hashable` and `Equatable`, you can easy compare states using standard operators.

```swift
machine.state == .initialising // = true
```

## Transitions

A 'Transition' is the process of a state machine changing from one state to another. It sounds simple, but the process is actually a little more complicated than you might think.

### Transition execution

The execution of a transition follows a specific formula. Here's an outline of what happens:

1. The transition is queued on the transition queue.
1. Pre-flighting is done and errors returned if any of these conditions fail:
    * The new state has not been registered.
    * The new state is not global or in the list of allowed transitions of the current state.
    * The new state's transition barrier denies the transition.
    * The new state and the old state are the same.
1. The transition is executed:
    1. The state is changed.
    1. The old state's `didExit` closure is called.
    1. The new state's `didEnter` closure is called.
    1. The machine's `didTransition` closure is called, passing the old and new states.
    1. The state change notification is sent if `postNotifications` is true.
1. The transition request completion closure is called.

#### Dispatch queues

The default dispatch queue is the main dispatch queue, but you can change it to another if you like. The transition actions will also be executed on this queue.

All transitions are queued asynchronously on a dispatch queue. This ensures that if one of the executed closures triggers another state change, then the current transition has a chance to finish before the new transition is started.

### Manual transitions

Manual transitions are the simplest to execute. 

```swift
machine.transition(to: .registering) { result in
    if let Result.failure(let error) = result {
        // Handle the error
        return
    }
    // The transition was successful. Result contains the previous state.
}
```

If the transition is successful the completion closure is passed the previous state of the machine. If there is a problem, an error is passed.

### Dynamic transitions

Dynamic transitions look the same, but work quite differently. Dynamic transitions are useful when you need to transition to different states depending on some dynamic logic. 

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

The call to execute a transition is the same, except for the lack of the `to:` argument. This tells Machinus that a dynamic transition is expected so it looks for a dynamic transition closure. If not found, a `fatalError(…)` is generated. 

If found, it's executed and the returned state is transitioned to.

### Transition errors

Transitions can return the following `MachinusError` errors:

* **.alreadyInState** - Returned if a state change is requested, the requested state is the same as the current state and the `enableSameStateError` flag is set.

* **.transitionDenied** - Returned when a transition barrier rejects a transition.

* **.illegalTransition** - Returned when the target state is not in the current state's allowed transition list.

* **finalState** - Returned if the machine is currently in a final state.

### Subscribing to transitions with Combine

Machinus is Combine aware with the engine being a Combine `Publisher`. Here's an example of listening to state changes.

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

Note thar on subscription, Machinus will immediately send the current state value so your code knows what it is.

## Resetting the engine

Resetting the state machine is quite simple. `.reset()` will hard reset the engine back to the 1st state in the list. It does not any actions or rules.

```swift
machine.reset()
```
 
# FAQ

## Why does Machinus execute transitions asynchronously?

Originally I wanted Machinus to be synchronous, then I realised that driving things asynchronously was easier to write. Especially when you consider the flow of a `did…` closure requesting another state changes. In that nested state change scenario, synchronous execution becomes very difficult to manage.