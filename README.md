# Machinus
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Build Status](https://travis-ci.com/drekka/Machinus.svg?branch=master)](https://travis-ci.com/drekka/Machinus)

## Quick feature list

* App background aware
* State change notifications
* Combine Publishing of transitions
* Pre and post transition closures
* Transition barriers
* Dynamic transitions
* Transition queues

## Index

* [Quick guide](#quick-guide)
* [States](#states)
    * [Adding actions to states](#adding-actions-to-states)
    * [Global states](#global-states)
    * [Final states](#final-states)
    * [Transition barriers](#transition-barriers)
    * [The background state](#the-background-state)
* [The state machine](#the-state-machine)
    * [Options](#options)
    * [Checking the engine's state](#checking-the-engines-state)
    * [Transitions](#transitions)
        * [Transition execution](#transition-execution)
        * [Manual transitions](#manual-transitions)
        * [Dynamic transitions](#dynamic-transitions)
        * [Transition errors](#transition-errors)
        * [Transition actions](#transition-actions)
        * [Listening to transition notifications](#listening-to-transition-notifications)
        * [Subscribing to transitions with Combine](#subscribing-to-transitions-with-combine)
    * [Resetting the engine](#resetting-the-engine)

# What is a state machine?

Often there is something in your app that has a number of unique *'states'*. For example - the states of a user: registered, logged out or logged in. You can represent these states using booleans or enums, and add code using `if` or `switch` statements. But as the app grows it's not uncommon for it to get complicated, becoming difficult to manage, debug and develop.

This is where a state machine can help. Basically a state machine can simplify your code and reduce bugs by wrapping up all the functionality around maintaining state and executing code when it changes.

# Machinus?

If you look around [Github](https://www.github.com) you'll find plenty of state machine implementations, so why did I bother writing another? Simply put - Because I thought they all had limitations and... because I could. 

Generally speaking I found two different types of state machines implementations - Those that defined states using enums and those that defined states using classes. Enum based machines tend to be simple, but have limited functionality because of their enum base. Class based machines on the other hand had more functionality, but required more code and were not be as easy to work with. 

With Machinus I settled on a different approach. It uses a protocol to uniquely identify states and a single class to associate functionality. This gives it the best of both styles of machines.

# Quick guide

So enough talk, lets see how to use Machinus in 5 easy steps.

## 1. Installing

Machinus is [Carthage](https://github.com/Carthage/Carthage) friendly. Just add this to your `Cartfile`:

```
github "drekka/Machinus"
```

Then update your dependencies.

## 2. Declare your state identifiers

The simplest way to define states is to use an enum. You can use anything you can apply protocols to, but enums are the simplest. All you need to do is ensure it implements the `StateIdentifer` protocol.

```swift
enum UserState: StateIdentifier {
    case initialising
    case registering
    case loggedIn
    case loggedOut
}
```

## 3. Create the states and machine

Next create a series of`StateConfig<T>` instances which are used to configure the states. Then we add a machine instance to manage them.

```swift
let initialising = StateConfig<UserState>(withIdentifier: .initialising, allowedTransitions: .registering, .loggedOut)
let registering = StateConfig<UserState>(withIdentifier: .registering, allowedTransitions: .loggedIn)
let loggedIn = StateConfig<UserState>(withIdentifier: .loggedIn, allowedTransitions: .loggedOut)
let loggedOut = StateConfig<UserState>(withIdentifier: .loggedOut, allowedTransitions: .loggedIn)

let machine = Machinus(withStates: initialising, registering, loggedIn, loggedOut)
```

By default Machinus starts in the first state, so...

```swift
machine.state == .initialising // = true
```

Notice we only need the `StateConfig<T>` instances to configure the machine. Thereafter, we use the `StateIdentifier`s to talk to it. This is how we get the simplicity of enums with the power of classes.

## 4. Add functionality

Now let's do something when a state changes by adding an 'action' to it.

```swift
let registering = StateConfig<UserState>(withIdentifier: .registering, allowedTransitions: .loggedIn)
    .afterEntering { _ in
        registerUser()
}
```

## 5. Transition

And finally let's tell the machine to change state.

```swift
machine.transition(toState: .registering) { previousState, error in
    // Do stuff after the transition.
}
```

Ta da! We've just used a state machine.

# States

Creating a state is a matter of defining two things: its identifier and an instance of `StateConfig<I>` to configure it. Creating the `StateConfig<I>` instance requires the identifier of the state, and optionally adding a list of other states that the new state can transition to.

```swift
let initialising = State<UserState>(identifier: .initialising, allowedTransitions: .registering, .loggedOut)
```

If you try and transition to a state not in the `allowedTransition` list then an error will be thrown. If no list is supplied, then the machine will be unable to leave this state once it transitions to it. Except for some special cases we'll get to later.

## Adding actions to states

As previously stated, state machines provide the ability to attach functionality (which we call 'Actions') to states. These actions are executed in a specific order when the machine transition from one state to another. See [Transition execution](#transition-execution) for details. 

There are four actions you can attach to each state: 

* **`.beforeEntering { previousState in ... }`** - Executed just before the machine changes to the state you defined it on. It's passed the state that the machine is changing from as an argument.

* **`.afterEntering { previousState in ... }`** - Executed just after the machine changes to the state you defined it on.  It's passed the state that the machine is changing from as an argument.

* **`.beforeLeaving { nextState in ... }`** - Executed just before the machine changes from the state you defined it on. It's passed the state that the machine is changing to as an argument.

* **`.afterLeaving { nextState in ... }`** - Executed just after the machine changes from the state you defined it on. It's passed the state that the machine is changing to as an argument.

Here's how you would define all of these actions on a state.

```swift
let registering = State<UserState>(withIdentifier: .registering, allowedTransitions: .loggedIn)
    .beforeEntering { previousState in
        setupForRegistering()
    }
    .afterEntering { previousState in
        startRegistering()
    }
    .beforeLeaving { nextState in
        saveRegisteringData()
    }
    .afterLeaving { nextState in
        registationIsDone()
}
```

As you can see these are all chainable methods. The closures sole argument is the relevant 'other' state depending on whether the state is the new or old state of the machine. For the old state, it's the state the machine is going to, and for the new state, it's the previous state. 

## Global states

You can also specify that a state is 'global' in nature. Global states do not need to be listed in a state's allowed transitions list because it can always be transitioned to from any state. Hence the 'global' nature of them.

```swift
let initialising = State<UserState>(withIdentifier: .appError)
    .makeGlobal()
```

## Final states

When you have a state with no allowed transitions it's an end state in that once entered, the machine cannot leave it. However [global states](#global-states) and the [background state](#the-background-state) can still be accessed.

Setting a state as final lets Machinus know that it cannot be exited at all. 

```swift
let applicationError = State<UserState>(withIdentifier: .appError)
    .makeFinal()
```

If you try and transition to another state (including global states) from a final state then a `nil` error will be returned unless a flag is set on the machine to return `MachinusError.finalState` errors. The transition to the [background state](#the-background-state) also fails when the current state is final, however it always returns a `nil` error.

Note: you can still [reset the machine](#resetting-the-engine) if you need to.

## Transition barriers

Transition barriers can cancel a transition before it happens. They are useful where you have a number of places that can transition to a state and that state needs to have some rules that define if the transition is ok. Placing a barrier on the state provides this functionality.

```swift
let loggedIn = State<UserState>(withIdentifier: .loggedIn, allowedTransitions: .loggedOut)
    .withTransitionBarrier {
        Return self.user != nil
}
```

The barrier closure is called before the transition executes. If the closure returns `false` then the transition is cancelled and it's completion will be called with a `MachinusError.transitionDenied` error.

## The background state

Something you need a machine to track whether the application is in the foreground or background. For example, so it can mask sensitive data with a privacy screen. Machinus supports this by allowing you to set a background state. 

Setting a background state tells Machinus to start tracking the application's state. When the application goes into the background, Machinus will transition to it's state. When the application returns to the foreground, Machinus then returns to the state it left. 

```swift
self.backgroundState = StateConfig(identifier: .background)
    .beforeEntering { previousState in
        addPrivacyScreen()
    }
    .afterLeaving { nextState in
        removePrivacyScreen()
}

self.machine = Machinus(withStates: initialising, registering, loggedIn, loggedOut, backgroundState)
self.machine.backgroundState = .background
```

That's all you have to do. Note:

* The background state by passes `allowedTransition`, transition barriers and other such checks.
* Machinus remembers the current state before transitioning to the background state. It then automatically returns to that state when the application enters the foreground again.
* Only the background state's `beforeEntering` and `afterLeaving` actions are called. None of the other states actions or the machines `beforeTransition` or `afterTransition` actions are called. This is because the transition to a background state is not viewed as a normal transition and also avoids all the other configured actions having to account for a background transition. 

# The state machine

```swift
let machine = Machinus(
    name: "User state machine", 
    withStates: initialising, registering, loggedIn, loggedOut)
```

The optional `name` argument can be used to uniquely identify the state machine in logs and debug sessions. If you don't set it specifically, a UUID appended with the type of the state identifier is used.

The Machinus initialiser requires at least 3 states. This is simple logic. A state machine is useless with only 1 or two states. So the initialiser won't compile with anything less than 3. 

## Options

* `enableSameStateError: Bool` (property)  - Default false. When true a transition when the machine is already in the requested state cancels the transition and returns the `MachinusError.alreadyInState` error. When false (the default) the transition is cancelled and both a `nil` previous state and a `nil` error.

* `enableFinalStateTransitionError: Bool` (property)  - Default false. When true, an attempt to transition from a final state will generate a `MachinusError.finalState` error. When false, a `nil` will be returned. 

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

The execution of the actions for a transition follow a specific order. Here's an outline of what happens when you request a transition.

1. The transition is requested and queued on the transition queue.
1. Pre-flighting is done and errors returned if any of these conditions fail:
    * The new state has not been registered.
    * The new state is not global or in the list of allowed transitions of the current  state.
    * The new state's transition barrier denies the transition.
    * The new state and the old state are the same. Error optional.
1. The transition is executed:
    1. The machine's `beforeTransition` closure is called.
    1. The old state's `beforeLeaving` closure is called.
    1. The new state's `beforeEntering` closure is called.
    1. The state is changed.
    1. The old state's `AfterLeaving` closure is called.
    1. The new state's `afterEntering` closure is called.
    1. The machine's `afterTransition` closure is called.
    1. The state change notification is sent if requested.
1. The transition completion is called with the old state.

#### Dispatch queues

All transitions are queued asynchronously on a dispatch queue. This is to ensure that if an action triggers another state change, the first transitions finishes before the new transition is started.

The default dispatch queue is the main dispatch queue, but you can change it to another if you like. The transition actions will also be executed on this queue.

### Manual transitions

Manual transitions are the simplest to use. They're where you pass the desired state to transition via an argument. 

```swift
machine.transition(toState: .registering) { previousState, error in
    if let error = error {
        // Handle the error
        return
    }
    // The transition was successful.
}
```

If the transition is successful the completion closure is passed the previous state of the machine. If there is a problem, an error is passed. Depending on the setup of the machine it may also be possible for the closure to get both a `nil` previous state and a `nil` error. This can occur if you have told the machine to transition to the state it's already in and not enabled the error for this situation.

### Dynamic transitions

Dynamic transitions work quite differently and are most useful when you need to transition to different states depending on some dynamic logic. 

```swift
let restarting = State<UserState>(withIdentifier: .restarting)
    .withDynamicTransitions {
        return userWasLoggedIn() ? .loggedIn : .loggedOut
}

// And when the machine is in the restarting state. 
machine.transition { previousState, error in
    if let error = error {
        // Handle the error
        return
    }
    // The transition was successful.
}
```

The call to execute a transition is the same, except that it is missing the `toState` argument. This lack of argument tells Machinus that a dynamic transition is to be executed and it will look for a dynamic transition closure to execute. If it doesn't find one, a `fatalError` is generated. 

### Transition errors

Transitions can return the following `MachinusError` errors:

* **.alreadyInState** - Returned if a state change is requested, the requested state is the same as the current state and the `enableSameStateError` flag is set.

* **.transitionDenied** - Returned when a transition barrier rejects a transition.

* **.illegalTransition** - Returned when the target state is not in the current state's allowed transition list.

### Transition actions

In addition to actions which are attached to states, you can add some actions to the state machine itself.

* **`.beforeTransition { fromState, toState in ...}`** - Executed just before the machine changes state. It's passed both the from and to states as arguments.

* **`.afterTransition { fromState, toState in ... }`** - Executed just before the machine changes state. It's passed both the from and to states as arguments.

### Listening to transition notifications

Sometimes a piece of code far away from the machine needs to be notified of a state change. Machinus supports this by providing a property which enables sending a notification once a transition has executed. 

```swift
machine.postNotifications = true
machine.transition(toState: .loggedIn) { _, _ in } 
```

And elsewhere:

```swift
let observer = NotificationCenter.default.addStateChangeObserver { [weak self] (stateMachine: Machinus<MyState>, fromState: MyState, toState: MyState) in
    // Do something here.
}
```

Note: It's important to define the state types in the closure as the observer will only call it for state machines of that type.

### Subscribing to transitions with Combine

Machinus is Combine aware with the engine being a Combine `Publisher`. Here's an example of listen to state changes.

```swift
let state1 = StateConfig<State>(identifier: .first, allowedTransitions: .second)
let state2 = StateConfig<State>(identifier: .second, allowedTransitions: .third)
let state3 = StateConfig<State>(identifier: .third, allowedTransitions: .first)
let machine = Machinus(withStates: state1, state2, state3)

let cancellable = machine.sink { newState in
    switch newState {
    case .first:
        // Sent immediately on subscription.
    case .second:
        // Second transiation has occured.
    case .third:
        // third transiation has occured.
    }
}

machine.transition(toState: .second) { _,_ in }
machine.transition(toState: .third) { _,_ in }
```

Note than on subscription, Machinus will immediately send the current state value so your code knows what it is.

## Resetting the engine

Resetting the state machine to it's initial state is quite simple. This is a hard reset which does not execute any actions or rules.

```swift
machine.reset()
```
 
