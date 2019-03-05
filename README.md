# Machinus
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Build Status](https://travis-ci.com/drekka/Machinus.svg?branch=master)](https://travis-ci.com/drekka/Machinus)
 
# What's a state machine?

Often there are things in your app that have a number of unique *'states'*. For example - a user's states include being registered, logged out or logged in. You represent these states with booleans or enums, then add code which looks at these values to decide what to do. Displaying a home screen when the user logs in for example. 

It usually starts this with some simple `if` or `switch` statements, but as the app grows it's not uncommon to end up adding more variables with the code starting to get complicated, difficult to manage, debug and develop.

This is where a state machine can help. Basically a state machine provides a simple interface for creating states, defining which state changes are allowed and which aren't, and attaching code to execute when a state change occurs, without you having to add all the logic to decide what to do.

# Machinus?

If you look around [Github](https://www.github.com) you'll find plenty of state machine implementations so why write another? 

Simply put - Because none of them worked the way I wanted and... because I could. 

Generally speaking I found two different types of state machines implementations on Github - Those that defined states using enums and those that defined states using classes. 

Enum based machines tend to have limited functionality because of the limitations of enums, but be easy to setup and work with. Machines where state's were defined by creating classes tended to require more code and not be as easy to work with as enum based ones. 

With Machinus I decided to take a different approach. I use a protocol to provide the unique identities of the states, and then a single class to setup the functionality of those states. I found this gives me the best of both styles of machines.

## Machinus features

* The flexibility of a class based state machine with the ease of an enum design.
* Allowed transitions lists to define what are legal transitions.
* Optional global states which any state can transition to. Great for error states or similar.
* Multiple points where you can attach code (actions) to be executed when a state change occurs:
    * Before and after leaving a state.
    * Before and after entering a state.
    * Before and after a transition.
* Optional barrier closures which can allow or deny transitions to new state.
* 2 transition styles:
    * Manual where calling code passes the next state to transition to.
    * Automatic where a pre-defined closure returns the next state.
* Transition notifications.
* Custom dispatch queue for transition execution.

# Quick guide

## 1. Install

Currently Machinus is [Carthage](https://github.com/Carthage/Carthage) friendly. Just add this to your `Cartfile`:

```
github "drekka/Machinus"
```

And update your dependencies.

## 1. Declare your state identifiers

The simplest way to start is to define the state identifiers using an enum. You can use other things, but an enum is the easiest. Whatever we use, we have to implement the `StateIdentifer` protocol so that Machinus knows they identify the states.

```swift
enum UserState: StateIdentifier {
    case initialising
    case registering
    case loggedIn
    case loggedOut
}
```

## 2. Create the states and the machine

Now we can create a set of states instances and a machine.

```swift
let initialising = State<UserState>(withIdentifier: .initialising, allowedTransitions: .registering, .loggedOut)
let registering = State<UserState>(withIdentifier: .registering, allowedTransitions: .loggedIn)
let loggedIn = State<UserState>(withIdentifier: .loggedIn, allowedTransitions: .loggedOut)
let loggedOut = State<UserState>(withIdentifier: .loggedOut, allowedTransitions: .loggedIn)

let machine = Machinus(withStates: initialising, registering, loggedIn, loggedOut)
```

By default Machinus starts in the first state, so...

```swift
machine.state == .initialising // = true
```

Notice we compare with the state identifier. The `State` class is only used during setup. All Machinus functions that need a state argument use `StateIdentifer` instances.

## 3. Add functionality

Now let's add some function to execute when a state changes.

```swift
let registering = State<UserState>(withIdentifier: .registering, allowedTransitions: .loggedIn)
    .afterEntering { _ in
        registerUser()
}
```

## 4. Transition

Now we can request a transition.

```swift
machine.transition(toState: .registering) { previousState, error in
    // Do stuff after the transition.
}
```

Ta da!

# States

As per above, creating a state is just a matter of defining its identifier and creating an instance of `State<I>` with the `withIdentifier` and `allowedTransitions` arguments.

```swift
let initialising = State<UserState>(withIdentifier: .initialising, allowedTransitions: .registering, .loggedOut)
```

`withIdentifier` is required. `allowedTransitions` is optional. 

## Adding actions to states

As previously stated, state machines provide the ability to attach functionality (which we call 'Actions') to transitions from one state to another. 

There are four actions you can attach to each state and you can define more than one at a time. The four actions are: 

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

As you can see these are all chaining methods and can be entered in any order that suites you. They're also passed the relevant 'other' state. For the state being left, it's the state the machine is going to, and for the state being changed too, it's the previous state. 

## Global states

You can also specify that a state is 'global' in nature. Global states do not need to specified in other state's allowed transitions lists because any state in the machine can transition to them. Hence the global nature of them.

```swift
let initialising = State<UserState>(withIdentifier: .appError)
    .makeGlobal()
```

## Transition barriers

Transition barriers are simple closures that can cancel a transition. They are most useful where you have some criteria for allowing a change to a state, but don't want to repeat that criteria on all the other states that can transition to it. 

A state's barrier closure is called before a transition is started. If the closure returns false then the transition is cancelled and the completion called with a `MachinusError.transitionDenied` error.

You can setup a barrier like this.

```swift
let loggedIn = State<UserState>(withIdentifier: .loggedIn, allowedTransitions: .loggedOut)
    .withTransitionBarrier {
        Return self.user != nil
}
```

Just return false to deny the transition.

# The state machine

Creating a state machine looks like this.

```swift
let machine = Machinus(
    name: "User state machine", 
    withStates: initialising, registering, loggedIn, loggedOut)
```

The `name` argument is option and is used to uniquely identify the state machine in logs and debug sessions. If you don't set it, a UUID is generated appended with the type of the state identifier.

You cannot create a state machine without the `withStates` argument having at least 3 state arguments. This is simple logic. A state machine is a waste of time if it only has 1 or two states. So the initialiser won't compile with anything less than 3. 

## Options

* `sameStateAsError: Bool` (property)  - Default false. If true and you request a transition to a state when the machine is already in that state then the `MachinusError.alreadyInState` is passed to the completion closure. \
When false (the default) the machine simply calls the transition completion with a `nil` previous state and a `nil` error. No transition or transition closures are executed.

* `postNotifications: Bool` (property)  - Default false. If true, every time a transition is done, a matching state change notification will be sent. This allows objects which cannot directly access the machine to still know about state changes.

* `transitionQueue: DispatchQueue` (property) - Default `DispatchQueue.main`. The dispatch queue that transition will be queued on.

## Checking the engine's state

Machinus has a `state` variable which allows you to see the current state of the machine and because states are defined using the `StateIdentifier`, which is an extension of `Hashable` and `Equatable`, you can easy compare states using stadnard operators.

```swift
machine.state == .initialising // = true
```

## Transitions

A 'Transition' is the process of a state machine changing from one state to another. Machinus provides two types of transitions and you can use one or the other, or both in any combination you want.

### Transition execution

The execution of the actions for a transition follow a specific order. Here's an outline of what happens.

* The transition is requested and queued on the transition queue.
    1. The transition is pre-flighted and errors returned if any of these conditions fail:
	    * The new state has not been registered.
	    * The new state is not global or in the list of allowed transitions of the current  state.
	    * The new state's transition barrier denies the transition.
	    * The new state and the old state are the same. Error optionsl.
    1. The transition is executed:
        1. The machines `beforeTransition` closure is called.
        1. The old state's `beforeLeaving` closure is called.
        1. The new state's `beforeEntering` closure is called.
        1. The state is changed.
        1. The old state's `AfterLeaving` closure is called.
        1. The new state's `afterEntering` closure is called.
        1. The machines `afterTransition` closure is called.
        1. The state change notification is sent.
    1. The transition completion is called with the old state.

#### Dispatch queues

All transitions are queued on a dispatch queue. This is to ensure that they execute smoothly and that if one of their actions triggers another state change, the first transitions gets a chance to execute before the second transition is started.

The default dispatch queue is the main dispatch queue, but you can change it to another if you like.

### Manual transitions

Manual transitions are the simplest to follow. They are where you pass the state you want the machine to transition to as an argument. 

```swift
machine.transition(toState: .registering) { previousState, error in
    if let error = error {
        // Handle the error
        return
    }
    // The transition was successful.
}
```

If the transition was successful the completion closure is passed the previous state of the machine. If there was a problem, an error is passed instead. 

### Dynamic transitions

Dynamic transitions are a different thing. They are most useful when you have some logic that defines the next state and you want to set it on the engine rather than the code calling it. Here's an example:

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

Notice how we trigger the dynamic transition by not specifying the new state.

### Transition errors

Transitions can return the following `MachinusError` errors:

* **.alreadyInState** - Returned if a state change is requested, the requested state is the same as the current state and the `sameStateAsError`` flag is set.

* **.unregisteredState** - Returned when a transition is requested to a state that was not registered on the state machine's intialiser.

* **.transitionDenied** - Returned when a transition barrier rejects a transition.

* **.illegalTransition** - Returned when the target state is not in the current state's allowed transition list.

* **.dynamicTransitionNotDefined** - Returned when a dynamic transition is requested and there is no dynamic transition defined on the current state.
 
### Transition actions

In addition to actions which are attached to states, you can add the following actions to the state machine itself.

* **`.beforeTransition { fromState, toState in ...}`** - Executed just before the machine changes state. It's passed both the from and to states as arguments.

* **`.afterTransition { fromState, toState in ... }`** - Executed just before the machine changes state. It's passed both the from and to states as arguments.

### Listening to transition notifications

Sometimes you want to be notified of a state change but it's in a state machines that's somewhere else in the code base. Machinus supports this by providing a property which enables the sending a notification once a transition has executed. Here's how to use it.

```swift
self.machine!.postNotifications = true
self.machine!.transition(toState: .loggedIn) { _, _ in } 
```

And somewhere else in you code:

```swift
let o = NotificationCenter.default.addStateChangeObserver { (machine: Machinus<MyState>, fromState: MyState, toState: MyState) in
    // Do something here.
}
```



## Resetting the engine

Resetting the state machine to it's initial state is quite simple. This is a hard reset which does not execute any actions.

```swift
machine.reset()
```
 
