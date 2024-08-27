---
title: "My handy Clojure debugging tools"
date: 2024-08-26T06:00:00Z
draft: false
---

In this blog post, I’d like to share how my debugging tools for Clojure have evolved over the past years. Let's start with each tool

**`(println …)`** 

It is the most versatile technique. There is no learning curve. Focus on tapping at the right places, make the assertions, and move on. The only downside would be there is quite a lot of typing and undo-ing after the fact

**`(defn x [x] (println x) x)`** 

In the next version, I almost always wrap println in a function in the same namespace, slurp, and raise the forms. This helps speed up typing a little bit. We still have to undo changes

**`(def state (atom nil))`**   
**`(defn x [x] (reset! state x))`** 

Very useful to capture any data that goes beyond primitive values. Deref the state. Now you can manipulate the data.

**IDE debuggers**

I have my fair share of trying out different debugger tools: cider debugger, enlighten, cursive debuggers, etc. They are handy for tracing codebases. They automatically follow the callstacks, often leading you to code branches that you did not expect.

But in practice, I don't use them as much - mainly because I feel like they can be a bit distracting due to how we generally instrument the breakpoints, hitting next/up/down the call stack, inspecting values, etc.

They are definitely useful as a starting point in big and unfamiliar codebases

**Clojure libraries such as [spyscope](https://github.com/dgrnbrg/spyscope), [hashp](https://github.com/weavejester/hashp), [scope-capture](https://github.com/vvvvalvalval/scope-capture), [FlowStorm](http://www.flow-storm.org/), etc**

There are plenty of excellent functions and macros that help with debugging. Some printout recursive calls nicely. I tend to fall back to something simple like a hashp. It gets the job done nicely. Saves some typing

Then one day, when I was pairing with my colleague Craig Ludington; he used a combination of println, atom, and reader macro - all at once; which I thought was pretty cool. I ended up modifying and extending his debug code but I want to give credit back to him - Thank you, Craig!

Let's say we have this (hypothetical) code:
{{< gist dvliman d01208f7c48b40c44db89905b14bf0cd >}}

And the ask is to modify such that if the `loan-amount` input was 10000.50, the output should be `:modest`, not `:small`

We can add a reader tag that looks like this
{{< gist dvliman d3e015fb667253c543af3b2318acd8b0 >}}

Then run the code `(calculate-loan-size 10000.50)`

We can call `(user/tags)` to print out the debug tags. On emacs, I set the shortcut command+6 and command+5 to clear out the tags
{{< gist dvliman c387742ef299e175c13dc294893bb104 >}}

1.  0, 1, 2, and 3 corresponds to 4 forms that are being the debugged
2.  1 and `:same-values` indicates there we only 1 call and all of them have the same values. It is useful to know when we have multiple calls (intentional or not) and if the values are the same
3.  `(between 1 loan-amount 10000)` is self explanatory
4.  `false` is the return value

We can pull the value out with the index `(user/logs 0)` or with form `(user/logs '(between 1 loan-amount 10000))`

[user/logs](https://github.com/dvliman/.clojure/blob/cb2153279931f3537140d8a84335a73fbf989147/user.clj#L11) takes variadic function. For example, if we capture an HTTP request map, we can do `(user/logs 0 last :header #(get "Content-Type"))`

This is how it is implemented in my `~/.clojure/user.clj`
{{< gist dvliman 9ae80ebbba797fde22e0f1915ce9f93c >}}

And `~/.clojure/data_readers.clj` 
{{< gist dvliman c70d3e88b88d3d623e2eec2d7fce68b6 >}}

I can load this code in any project i.e in the `deps.edn`
{{< gist dvliman 9172a211270c38c0104d32e0579429f1 >}}


On emacs, I have set the keybindings to:
{{< gist dvliman 65ee959b2d498075bdf5e5d3075b5e8b >}}

and the definitions:
{{< gist dvliman 93c1df9f053565de880392d966ee0572 >}}

With combinations of keyboard shortcuts, emacs buffers, and REPL, this makes debugging a lot faster (for me)

I hope this is useful for someone. I would love hear your thoughts on how you debug your clojure code!

