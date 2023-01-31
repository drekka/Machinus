# Machinus V3 (beta)

[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://GitHub.com/drekka/Machinus/graphs/commit-activity)
[![GitHub license](https://img.shields.io/github/license/drekka/Machinus.svg)](https://github.com/drekka/Machinus/blob/master/LICENSE)
[![GitHub tag](https://img.shields.io/github/tag/drekka/Machinus.svg)](https://GitHub.com/drekka/Machinus/tags/)

A powerful yet easy to use state machine for iOS/tvOS/MacOS and SwiftUI. 

## Quick feature list

* SwiftUI friendly as an `ObservableObject` with `@Published` state changes and errors.
 
* Fixed and dynamic transitions.

* State change closures to attach functionality to.

* App wide state change notifications.

* Transition barriers for allowing, denying, redirecting or failing a transition request.

* iOS/tvOS app background state tracking.

* Local state data stores for attaching data.
 
## Index

- [What is a state machine and why would I need one?](#what-is-a-state-machine-and-why-would-i-need-one)
- [Machinus?](#machinus)
- [Quick guide](#quick-guide)
  - [1. Installing](#1-installing)
  - [2. Declare the states](#2-declare-the-states)
  - [3. Configure the machine](#3-configure-the-machine)
  - [4. Transition](#4-transition)
- [States](#states)
  - [State config parameters](#state-config-parameters)
  - [Standard states](#standard-states)
  - [Global states](#global-states)
  - [Final states](#final-states)
  - [Final global states](#final-global-states)
  - [Background state (iOS/tvOS only)](#background-state-iostvos-only)
- [The state machine](#the-state-machine)
  - [Alternate form](#alternate-form)
  - [Properties & Functions](#properties-functions)
- [Transitions](#transitions)
  - [The transition process](#the-transition-process)
    - [Phase 1: Preflight](#phase-1-preflight)
    - [Phase 2: Transition](#phase-2-transition)
  - [Manual transitions](#manual-transitions)
  - [Dynamic transitions](#dynamic-transitions)
  - [Background transitions (iOS & tvOS)](#background-transitions-ios--tvos)
    - [Going into the background](#going-into-the-background)
    - [Returning to the foreground](#returning-to-the-foreground)
- [Storing state data](#storing-state-data)
- [Watching transitions](#watching-transitions)
  - [Machine closure](#machine-closure)
  - [Combine & SwiftUI](#combine--swiftui)
  - [Listening to transition notifications](#listening-to-transition-notifications)
- [Resetting the engine](#resetting-the-engine)


# What is a state machine and why would I need one?

Sometimes an app needs to track the state of something. For example, a user might have a _'Registered'_, _'logged out'_, _'logged in'_,  _'inactive'_,  _'pending'_, _'banned'_, or _'timed out'_ state. Whilst it's possible to track state using booleans or  enums with `if-then-else`, `switch` and other language features, it can often become unmanageable. Especially with large and complex code bases where state tracking might be spread across many files which are not necessarily well understood (or sometimes written) by the developers. So whilst quite possible, rolling your own state tracking and behaviour can absorb large amounts of time. 

State machines can help solve state complexity and manage it. Apart from centralising state, they can automatically run code when states change, define a map of valid state changes, and provide other related functionality.

Used right, a state machine can manage complexity and simplify your code.

# Machinus?

[Github](https://www.github.com) already hosts a number of state machines implementations. Most of which fall into one of two architectural designs. Using either structs/classes or enums to represent state. 

Enum based machines tend to be easy to use because everything is driven by the enum. But sometimes they're too simple because of the limitations of what you can do with an enum. Struct/class machines usually have the functionality, but then place the onus on the app to keep references to the states.

Machinus uses a different approach. It has a two part approach. A protocol which can turn anything into a state. Generally an enum because it's the simplest to use. Then a separate type to define it's configuration. This gives Machinus the benefit of both approaches. 

Add to that built in app background tracking (iOS and tvOS), plus some other unique features and (IMHO) Machinus is the best state machine available. 

But I might be biased :-)

# Quick guide

So let's look at using Machinus in 4 easy steps. In this example we are going to use it in a SwiftUI app. 

## 1. Installing

Machinus (V3) is supplied as a Swift Package Manager framework. So just search using the url [https://github.com/drekka/Machinus](https://github.com/drekka/Machinus) in Xcode's SPM package search.

## 2. Declare the states

States are declared by applying the `StateIdentifier` protocol. Generally I'd recommend applying it to an enum to make life easy. 

```swift
enum UserState: StateIdentifier {
    case initialising
    case registering
    case loggedIn
    case loggedOut
    case background
}
```

> Whilst enums are the easiest to use, it's not possible to use an enum with associated values as a state. The reason is that to register the state with the machine you have to pass the enum and that would require the associated values up front. If you need to store data with a state, make use of the [state data store](#state-data-store) mentioned below.

## 3. Configure the machine

With the states defined, we can configure the machine. This is done using instances of **`StateConfig<S>`** (where `S: StateIdentifier`). These configs are where you define what transitions are allowed and attach functionality to be executed when the machine changes state. For example:

```swift
let machine = try await StateMachine {

    StateConfig<UserState>(.initialising,
                           didEnter: { _ in reloadConfiguration() },
                           allowedTransitions: .loggedOut)
                                    
    StateConfig<UserState>(.loggedOut, 
                           didEnter: { _ in displayLoginScreen() },
                           allowedTransitions: .loggedIn, .registering,
                           didExit: { _ in hideLoginScreen() })

    StateConfig<UserState>(.loggedIn,
                           entryBarrier: {
                               return userIsLoggedIn() ? .allow : .redirect(to: .loggedOut)
                           },
                           didEnter: { _ in displayUsersHomeScreen() },
                           allowedTransitions: .loggedOut)

    StateConfig<UserState>(.registering, 
                           didEnter: { _ in displayRegistrationScreen() },
                           dynamicTransition: {
                               return registered() ? .loggedIn : .loggedOut
                           },
                           allowedTransitions: .loggedOut, .loggedIn)

    StateConfig<UserState>.background(.background,
                                      didEnter: { _ in displayPrivacyScreen() },
                                      didExit: { _ in hidePrivacyScreen() })
    }
```

Once the machine is configured, we generally don't need these instances of the state configs because we use the state identifiers to request state changes.

> Machinus automatically starts in the first state listed, so …
>```swift
> machine.state == .initialising // -> true
> ```

## 4. Transition

Now the machine is ready we can ask it to transition.

```swift
machine.transition(to: .loggedOut)
```

And given the states we defined above, this will:

1. Change to the `.loggedOut` state.
1. Run the `.loggedOut` state's `didEnter` closure which calls `displayLoginScreen()`.

_And … Ta da! We've just used a state machine!_

# States

As the [Quick guide](#quick-guide) shows, states are configured using the **`StateConfig<S>`** type (where `S:StateIdentifier`). Mostly these state configs are fairly generic, but Machinus also has some special configs you can use for greater control.

## State config parameters

Configuring a state can involve as little as one or two parameters, or quite a few. The following are all the parameters that can be specified. It follows the order in which they are used during a transition.

<details><summary><strong>State identifier</strong> (required)</summary>

The unique identifier of the state. `.loggedIn` in the above example.

</details>

<details><summary><code>entryBarrier</code> (optional)</summary>

If defined, is called before a transition _**to**_ this state to determine if it should be allowed. It is passed the state that the machine is about to transition from and can return:

* **`.allow`** - Allow the transition to occur.

* **`.deny`** - Deny the transition, stopping it from occurring with a `StateMachineError.transitionDenied` error.
* **`.redirect(to:S)`** - Redirect to another state.
* **`.fail(StateMachineError)`** - Fail the transition with the specified error.

</details>

<details><summary><code>didEnter</code> (optional)</summary>

Executed when the machine transitions to this state. Is passed the state transitioned from.

</details>

<details><summary><code>dynamicTransition</code> (optional)</summary>

Can be executed to programmatically decide which state to transition to. It should return the desired state.

</details>

<details><summary><code>exitBarrier</code> (required)</summary>

An `exitBarrier` is called before a transition _**from**_ this state to determine if it should be allowed. It is passed the state to be transitioned to and can return:

* **`.allow`** - Allow the transition to occur.

* **`.deny`** - Deny the transition, stopping it from occurring with a `StateMachineError.transitionDenied` error. 
      >Note that if the state being transitioned to is a [global state](#global-states) then this will be ignored and the transition allowed.

* **`.redirect(to:S)`** - Redirect to another state.

* **`.fail(StateMachineError)`** - Fail the transition with the specified error.

</details>

<details><summary>... or <code>allowedTransitions</code> (optional)</summary>

A list of states that this state can transition to. If a transition is requested to a state not in this list, a `StateMachineError.illegalTransition` error will be thrown. 

`allowedTransitions` lists are actually converted into an `exitBarrier` behind the scenes. If neither a `exitBarrier` or a `allowedTransitions` list is specified, then a simple barrier is built that denies all transitions.

</details>

<details><summary><code>didExit</code> (optional)</summary>

Executed when the machine leaves this state. Is passed the state the machine has transitioned to.

</details>

_Warning: Whilst it's possible to request a transition change in one of the callbacks, you should be careful about doing so. Any nested transition request will be run immediately and change the state  of the machine immediately. Further closures for the current change will still be run and passed the correct states, however the actual state of the machine will have moved on. So the recommendation is that if you do need to do this, you queue the new transition so the current transition gets to finish before the new one is executed._

## Standard states

These are the most common type of state you will use and are created using one of **`StateConfig<S>`**'s two initialisers:

```swift
// With an optional exitBarrier.
Let loggedIn = StateConfig<MyState>(.loggedIn,
                                     entryBarrier: { fromState in … },
                                     didEnter: { fromState in … },
                                     dynamicTransition: { … },
                                     exitBarrier: { toState in … },                                                                 
                                     didExit: { toState in … })

// With the allowedTransition var arg.
Let loggedIn = StateConfig<MyState>(.loggedIn,
                                     entryBarrier: { fromState in … },
                                     didEnter: { fromState in … },
                                     dynamicTransition: { … },
                                     allowedTransitions: .loggedOut, .registering,
                                     didExit: { toState in … })
```

The difference between these two is subtle. One has a required `exitBarrier`, the other has an optional `allowedTransitions` list.

The `exitBarrier` is required on the first initialiser and decides if the machine should be allowed to transition from this state to another. In the second initialiser it is swapped with an optional `allowedTransitions` list which is the list of state identifier's this state can transition to.


## Global states

Global states are states that can be transitioned to from any other state (except [final states](#final-states) without having to be listed in the `allowedTransitions` list or allowed by an `exitBarrier`. This makes them particularly useful for states that are available globally across your app.

```swift
Let timeout = StateConfig<MyState>.global(.timeout,
                                          entryBarrier: { state in … },
                                          didEnter: { fromState in … },
                                          dynamicTransition: { … },
                                          allowedtransitions: .loggedOut, …,
                                          didExit: { toState in … })

// Or ...

Let timeout = StateConfig<MyState>.global(.timeout,
                                          entryBarrier: { state in … },
                                          didEnter: { fromState in … },
                                          dynamicTransition: { … },
                                          exitBarrier: { toState in … },
                                          didExit: { toState in … })
```

> *The only states that cannot transition to a global state are final states.*

## Final states

Final states are "dead end" states. ie. once the machine transitions to them it cannot leave. For example, a final state could be used when the app hits an error that cannot be recovered from. Because they cannot be left, final state's don't need `allowedTransitions` lists, `dynamicTransition`, `exitBarrier` or `didExit` closures.

```swift
Let configLoadFailure = StateConfig<MyState>.final(.configLoadFailure,
                                                   entryBarrier: { fromState in … },
                                                   didEnter: { fromState in … })
```

> *Technically you can "recover" from a final state by resetting the machine. See [Resetting the engine](#resetting-the-engine). Otherwise the only way to recover is to restart the app.*

## Final global states

Finally there are final global states which quite obviously are  both final and global.

```swift
Let unrecoverableError = StateConfig<MyState>.finalGlobal(.majorError,
                                                          entryBarrier: { fromState in … },
                                                          didEnter: { fromState in … })
```

## Background state (iOS/tvOS only)

If you are using Machinus in an iOS or tvOS app, there is an additional state that can be added specifically to represent the app being pushed into the background. A common example of this is to use it for overlaying a privacy screen when the app is pushed into the background and removing it when it comes back to the foreground.

When you configure a background state Machinus will automatically start watching the app's foreground and background notifications. When it detects the app being pushed into the background it automatically transitions to the background state without having to be asked. Inversely, it will also automatically transition back to the current state when the app is returned to the foreground. 

The Background state involves some unique processing. It don't have `allowedTransitions` lists, `entryBarrier`, `exitBarrier` or `dynamicTransition` closures as the transitions to and from the background by pass such processing. Nor are the current state's `didExit` or `didEnter` closures called when the transitions occur. 

The reasoning is that background transitions are considered ["out of band"](https://en.wikipedia.org/wiki/Out-of-band_data). Effectively parallel to the machine's normal state changes and their execution reflects that by keeping the other states unaware of the jump in and out of the background state. 

> *You can only register one background state.*

> *See [background transitions](#background-transitions-ios-tvos) for details on what is called and when.*


```swift
Let background = StateConfig<MyState>.background(.background,
                                                 didEnter: { fromState in … },
                                                 didExit: { toState in … })
```

# The state machine

There are several ways you can go about initialising the state machine itself depending on your needs.

Firstly you can use a builder style like this:

```swift
let machine = StateMachine(name: "User state machine") {
                               StateConfig<MyState>(.initialising, … )
                               StateConfig<MyState>(.registering, … )
                               StateConfig<MyState>(.loggedIn, … )
                               StateConfig<MyState>(.loggedOut, … )
                           }
                           didTransition: { fromState, toState in … }
```

The optional **`name`** argument is used to uniquely identify the state machine in logs and debug sessions. If you don't pass it, a UUID appended with the type of the state identifier is used. This is purely for debugging when multiple state machines are being used.

Next there is a list of states to be registered. You cannot request a transition to a state not in this list.

Finally there is an optional **`didTransition`** closure which is called after each transition.

> _Machinus requires a minimum of 3 states. This is simply because state machine's are pretty useless with only one or two states. So the initialiser will fail with anything less than 3._ 

As well as the builder style shown above, there are also initialisers that take `StateConfig<S>` var arg and `Array[StateConfig<S>]` arguments as alternatives. So you can choose whichever suites your needs.  

## Alternate form

Sometimes you may want to create the state machine as a constant or in an initialiser. The issue that can arise from this is that you cannot declare any closures because they will capture `self` and Swift will throw a compilation error indicating you cannot capture before an instance is fully created.  

To support this situation Machinus allows you to setup the machine's states, then add the closures later. For example:

```swift
struct MyApp {

    let state = StateMachine {
        StateConfig<AppStarte>(.initialising, allowedTransitions: .unregistered, .loggedIn, .loggedOut)
        StateConfig<AppStarte>(.unregistered, allowedTransitions: .loggedIn)
        StateConfig<AppStarte>(.loggedIn, allowedTransitions: .loggedOut)
        StateConfig<AppStarte>(.loggedOut, allowedTransitions: .unregistered, .loggedIn)
    }
    
    init() {
        state[.unregistered].didEnter = { _ in showRegistration() }
        state[.loggedIn].didEnter = { _ in showHomeScreen() }
        state[.loggedIn].didExit = { _ in clearCache() }
    }
}
```

As you can see there in a subscript on the machine that provides access to the state configs where you can attached functionality.

## Properties & Functions

`StateMachine<S>` has these properties and functions:

<details><summary><code>@Published var state: S</code></summary>

Returns the current state of the machine. Because states implement `StateIdentifier` which is an extension of `Hashable` they are easily comparable using standard operators.

```swift
await machine.state == .initialising // = true
```

</details>

<details><summary><code>@Published var error: StateMachineError&lt;S&gt;</code></summary>

A second publisher that produces errors. You will need to listen to this publisher to receive any errors that occur.   

</details>

<details><summary><code>var postTransitionNotifications: Bool</code></summary>

When set to true, every time a transition is successful a matching notification is posted. This allows code that is far away from the machine to still receive transition events. *See [Listening to transition notifications](#listening-to-transition-notifications).*

</details>

<details><summary><code>func reset()</code></summary>

Resets the machine back to it's initial state. *See [Resetting the engine](#resetting-the-engine).*

</details>

<details><summary><code>func transition()</code></summary>

Performs a [Dynamic transition](#dynamic-transitions).

</details>

<details><summary><code>func transition(to state: S)</code></summary>

Performs a [manual transition](#manual-transitions).

</details>

<details><summary><code>subscript(state: S) -&gt; StateConfig&lt;S&gt;</code></summary>

Provides access to a state's config to allow changes to be made after it has been registered. Mostly for adding closures after swift has set all of a classes properties during initialisation.

</details>

# Transitions

## The transition process

The idea of '**transitioning**' a machine from one state to another sounds like a simple thing, but there's actually a little more to it than a simple change of one value to another. 

### Phase 1: Preflight

Preflight is where the transition request is checked to ensure it is valid from the machine's point of view. It can fail the transition for any of the following reasons:

* The requested state is not a known registered state. Throws `StateMachineError.unknownState(S)`.

* Unless a global state, the requested state has failed to pass the `exitBarrier` or does not exist in the list of `allowedTransitions` states. Throws `StateMachineError.illegalTransition`.

* The requested state's `entryBarrier` has denied the transition with a `.deny` response or some other error. Throws a `StateMachineError.transitionDenied` or `StateMachineError.unexpectedError(Error)`.

* The new state and the old state are the same. Throws a `StateMachineError.alreadyInState`.

> Either the current state's `exitBarrier` or requested state's `entryBarrier` may redirect the request to a new state. This triggers a recursive call to preflight with the redirected state.* 

### Phase 2: Transition

Providing the preflight passes, the machine then performs the transition like this:

1. The internal state is changed to the new state.

2. The previous state's `didExit` closure is called.

3. The new state's `didEnter` closure is called.

4. The machine's `didTransition` closure is called.

5. If `postNotifications` is true, a state change notification is sent.

## Manual transitions

Manual transitions are probably the most common form of transition request. The desired new state is passed as an argument like this: 

```swift
machine.transition(to: .registering)
```

## Dynamic transitions

Dynamic transitions where the `dynamicTransition` closure of the current state is used to determine the state to transition to. They are triggered by simply not specifying a `to:` state argument like this:

```swift
machine.transition()
```

> _If there is no dynamic closure set on the current state the machine will throw a `StateMachineError.noDynamicClosure(S)` error._ 

## Background transitions (iOS & tvOS)

Background transitions are a special case because they are not considered part of the normal state map. Automatically triggered by the app being backgrounded or restored, they involve a unique and simplified transition process. In both cases skipping pre-flight and only running some of the closures. 

### Going into the background

1. The current state is stored so it can be returned to.

1. The state is changed to the background state.

1. The background state's `didEnter` closure is called.

1. The machine is told to suspend processing until a foreground transition is requested. If any subsequent transition requests are received they will fail with a `StateMachineError.suspended` error.

### Returning to the foreground

Foreground transitions revert the machine back to the state it was in when backgrounded.

1. The machine is told to resume transition processing.

2. The state is changed to the restore state.

3. The background state's `didExit` closure is called.

# Storing state data

Sometimes you want the ability to store some data with a state. For example, you might want to store the current user with a logged in state. As associated values on enums being used as state identifiers is not possible, Machinus provides a storage area in each config that can be used. As a bonus, these storage areas are automatically emptied whenever the machine exits that particular state. 

Here's an example of storing some data:

```swift
stateMachine[.loggedIn].user = user
stateMachine[.loggedIn].securityLevel = .high

// And later ...
if stateMachine[.loggedIn].securityLevel == .high { ...
```

It's also possible to tell the machine not to clear the data when the state is exited. That syntax looks like this:

```swift
stateMachine[.registering]["termsViewed", true] = true
```

The `, true` telling Machinus to preserve the data regards of the machine state.

# Watching transitions

Apart from the individual closures on the states, there are multiple ways to observe a state transition.

## Machine closure

This is the closure that is passed to the machine when you create it like this:

```swift
let machine = StateMachine(name: "User state machine") {
                               // State configs.
                           }
                           didTransition: { fromState, toState in
                               // Called on every state change.
                           }
```

## Combine & SwiftUI

Machinus provides two `@Published` properties which output the state and any errors from failed transitions as well as the machine itself conforming to `ObservableObject`.

In a lot of cases you will probably be using the state machine to control the UI generated by SwiftUI. Typically you might start by declaring the state machine in the app like this:

```swift
enum AppState: StateIdentifier {
    case initialising
    case signedIn
    case signedOut
    case backgrounded
}

@main
final class MyApp: App {

    private let logonManager = LogonManager()

    private let appState = StateMachine(name: "My App") {
        StateConfig<AppState>(.initialising, allowedTransitions: .signedIn, .signedOut)
        StateConfig<AppState>(.signedOut, allowedTransitions: .signedIn)
        StateConfig<AppState>(.signedIn, allowedTransitions: .signedOut)
        #if os(iOS)
            StateConfig<AppState>.background(.backgrounded)
        #endif
    }

    init() {
        // Set closures in init.
        appState[.initialising].dynamicTransition = { [weak self] in
            guard let self else { return .signedOut }
            return self.logonManager.currentUser == nil ? .signedOut : .signedIn
        }
    }

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(appState)
                .environmentObject(logonManager)
        }
    }
}
``` 

With `MainWindow` looking like this:

```swift
struct MainWindow: View {

    @EnvironmentObject private var appState: StateMachine<AppState>
    @EnvironmentObject private var logonManager: logonManager

    var body: some View {
        switch appState.state {

        case .initialising:
            Text("Initialising app")

        case .signedOut:
            Text("Please sign in")

        default:
            Text(verbatim: "Hello \(logonManager.currentUser.name)")
        }
    }
}
```

This is a pretty simple example but in it you can see how we can used the state machine to drive the UI.

## Listening to transition notifications

Sometimes a piece of code far away from the machine needs to be notified of a state change and it may code consuming or too difficult to pass a reference to the machine. Machinus supports this by providing a property which enables a  notification each time the state changes. 

```swift
machine.setPostNotifications = true

// Then somewhere else ...
machine.transition(to: .loggedIn) 
```

And far far away...

```swift
let observer = NotificationCenter.default.addStateChangeObserver { [weak self] (stateMachine: any StateMachine<MyState>, from: MyState, to: MyState) in
    // Do something here.
}
```

> *It's important to define the state types in the closure as the observer will only be called for state machines of that type.*



# Resetting the engine

Resetting the state machine hard resets the engine back to the 1st state in the list. It does not execute any state closures.

```swift
try await machine.reset { ... }
```

> *`reset()` is the only way to exit a final state. Although that's generally not something that you would want to do and suggests that your final state is not really a final.*
