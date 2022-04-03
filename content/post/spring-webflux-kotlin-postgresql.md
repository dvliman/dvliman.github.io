---
title: "Building a reactive web service with Spring Webflux, Kotlin, and PostgreSQL"
date: 2019-03-24T09:00:00Z
draft: false
---

This post shows how to create a reactive web service with Spring Webflux, Kotlin, PostgreSQL

> For the context,[Spring Framework 5](https://spring.io/) introduced the so-called **Reactive Stack**. The keyword `reactive` refers to the [Reactive Manifesto](https://www.reactivemanifesto.org/), which is a [specification](https://github.com/reactive-streams/reactive-streams-jvm/blob/master/README.md) for asynchronous stream processing with non-blocking back-pressure. 
> This specification is a joint collaboration between engineers from Netflix, Pivotal, Red Hat, Twitter and many others. It has been implemented in many languages such as: Java, Javascript, Swift, NET, etc.
 
> In short, Spring Webflux is a non-blocking web framework that uses [Reactor](https://projectreactor.io/) library, which implements the Reactive Streams Specifications, to asynchronously manage HTTP requests.

Requirements
============

Say we want to build an HTTP service that can do the following:

*   `curl -XPOST /api/users/create -d '{"name": "some-name", "email": "some-email"}'`
*   `curl -XPOST /api/users/fetch -d '{"userid": 123}'`
*   `curl -XPOST /api/users/all`

Note: the final code repo is [here](https://github.com/dvliman/spring-webflux-kotlin-postgresql/)

Let’s start the journey by going to [Spring Initializr](https://start.spring.io/). It is a very handy tool to generate the skeleton project.

*   **Project:** Gradle Project
*   **Language:** Kotlin
*   **Spring Boot:** 2.2.0 (SNAPSHOT)
*   **Group:** com.dvliman
*   **Artifact:** demo
*   **Dependencies:** Reactive Web
*   **Generate Project — ⌘ + ⏎**

At this point, if you run `./gradlew bootRun`, you should see something like this:
{{< gist dvliman 118a912acf0c61016e1d8ca7b79d865e >}}

Good! Now we just need to add additional dependencies:
{{< gist dvliman af1f260b9a7236bb67d3cb458923165f >}}

Note: At the time of writing, there is no “official” reactive JDBC drivers. JDBC is inherently a blocking API. However, there are some third-party libraries that we can use. I picked David Moten’s rxjava2-jdbc library because it has a great [documentation](https://github.com/davidmoten/rxjava2-jdbc/blob/master/README.adoc) and it implements the Reactive Streams specifications

Design
======

Before we jump into coding, let’s think about what we need to build. At the minimum, we will need to:

*   read a configuration file such as database connection string
*   be able to read and write some data into our database
*   process HTTP requests

Coding
======

It is a good idea to start thinking about the data. So let’s define the schema
{{< gist dvliman a23b16a492eee4bf75a84f4f95bb1aea >}}

And write some queries to get a feel for how it works and what not
{{< gist dvliman ee7a6c929ba6183fa3edc01adb0ce03d >}}

Next, let’s write a code to read the config file:
{{< gist dvliman 12646919ee99201aa542c5a47228b8dd >}}

The `@Value` annotation takes a SPEL-expression to evaluate config values in the `application.properties` which contains the database connection string
{{< gist dvliman fededaad0b1edc4d26030c190473c68c >}}

Okay, now we can add a `@Configuration` for all our `beans`
{{< gist dvliman cb4b250151757fcf8abd69fecf847e5a >}}

With database connection bean setup, we can start wiring up the model and repository. So let’s work on that:
{{< gist dvliman 007f400e82f28ab65d2696fd473e118f >}}
{{< gist dvliman 1e4a4d5d9a36e64a63727ba4636fbd8a >}}

Notice how the return type signature is `Mono<User>` or `Flux<User>`? They are both implementations of Reactive Streams [Publisher](http://www.reactive-streams.org/reactive-streams-1.0.0-javadoc/org/reactivestreams/Publisher.html) interface. I am not going to go into too much details about Reactive Streams but in essence:
*   Mono is a stream of 0..1 elements
*   Flux is a stream of 0..N elements
*   a `Publisher<T>` is responsible for publishing elements of type `T` and provides a `subscribe` method for subscribers to connect to it
*   a `Subscriber<T>` connects to a `Publisher`, receives a confirmation via `onSubscribe`, then receive data via the `onNext` callbacks and additional signals via `onError` and `onComplete`
*   a `Subscription` represents a link between a `Publisher` and a `Subscriber`, and allows for backpressuring the publisher with `request` or terminating the link with `cancel`
*   a `Processor` combines the capabilities of a `Publisher` and a `Subscriber`in a single interface

The next class to take a look is the class that handles the HTTP requests
{{< gist dvliman db12cf21d3289e1eb12946d5c6730cc3 >}}

In Spring Webflux, HTTP handler is essentially a function that takes HTTP request and return HTTP response. `(ServerRequest) -> Mono<ServerResponse>`

Finally, let’s add a router that routes incoming HTTP requests to the HTTP handler based on URL, HTTP method, and Content-Type header
{{< gist dvliman 55861ba7e557704ab31d2a1ddd6a3198 >}}

That is it! Now you can test with curl:
