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

Very useful to capture any data that goes beyond primitive values. Deref the state. Rinse and repeat.

**IDE debuggers**

I have my fair share of trying out different debugger tools: cider debugger, enlighten, cursive debuggers, etc. They are handy for tracing codebases. They automatically follow the call chains, often leading you to code branches that you did not expect.

But in practice, I don't use them as much - mainly because I feel like they can be a bit distracting due to how we generally instrument the breakpoints, hitting next / up/down the call stack.

They are definitely useful as a starting point in big and unfamiliar codebases

**Clojure libraries such as [spyscope](https://github.com/dgrnbrg/spyscope), [hashp](https://github.com/weavejester/hashp), [scope-capture](https://github.com/vvvvalvalval/scope-capture), etc**

There are plenty of excellent functions and macros that help with debugging. Some printout recursive calls nicely. I tend to fall back to something simple like a hashp. It gets the job done nicely. Saves some typing

Then one day, when I was pairing with my colleague Craig Ludington; he used a combination of println, atom, and reader macro - all at once; which I thought was pretty cool. I ended up modifying and extending his debug code but I want to give credit back to him - Thank you, Craig!

Let's say we have this (hypothetical) code:
```
(defn between [from target to]
  (and (<= from target) (<= target to)))

(defn calculate-loan-size
  [loan-amount]
  (cond
    (between 1 loan-amount 10000) :small
    (between 10001 loan-amount 50000) :modest
    (between 50001 loan-amount 150000) :large
    (>= loan-amount 150001) :jumbo))
```

And the ask is to modify such that if the `loan-amount` input was 10000.50, the output should be `:modest`, not `:small`

We can add a reader tag that looks like this

```
(defn calculate-loan-size
  [loan-amount]
  (cond
    #d (between 1 loan-amount 10000) :small
    #d (between 10001 loan-amount 50000) :modest
    #d (between 50001 loan-amount 150000) :large
    #d (>= loan-amount 150001) :jumbo))
```

Then run the code `(calculate-loan-size 10000.01)`

We can call `(user/tags)` to print out the debug tags. On emacs, I set the shortcut command+6 and command+5 to clear out the tags

```
[{0 [[1 :same-values (between 1 loan-amount 10000)] false]}
 {1 [[1 :same-values (between 10001 loan-amount 50000)] false]}
 {2 [[1 :same-values (between 50001 loan-amount 150000)] false]}
 {3 [[1 :same-values (>= loan-amount 150001)] false]}]
```

1.  0, 1, 2, and 3 corresponds to 4 forms that are being the debugged
2.  1 and `:same-values` indicates there we only 1 call and all of them have the same values. It is useful to know when we have multiple calls (intentional or not) and if the values are the same
3.  `(between 1 loan-amount 10000)` is self explanatory
4.  `false` is the return value

We can pull the value out with the index `(user/logs 0)` or the form `(user/logs '(between 1 loan-amount 10000))`

user/logs takes variadic function. For example, if we capture an HTTP request map, we can do `(user/logs 0 last :header #(get "Content-Type"))`

This is how it is implemented in my `~/.clojure/user.clj`

```
(def log-store (atom {}))

(defn debug [tag val]
  (swap! log-store update-in [tag] #(conj (or % []) val))
  val)

(defn logs
  [tag & functions]
  (let [tag (if (number? tag)
              (nth (keys @log-store) tag)
              tag)]
    (loop [values    (@log-store tag)
           functions functions]
      (if (seq functions)
        (recur ((first functions) values)
               (rest functions))
        values))))

(defn same-values? [x]
  (if (= 1 (count (set x)))
    :same-values
    :different-values))

(defn tags []
  (->> @log-store
       (reduce-kv #(assoc %1 [(count %3) (same-values? %3) %2] (last %3)) {})
       (map-indexed hash-map)
       (into [])))

(defn debug-data-reader [form]
  `(debug (quote ~form) ~form))
```

And `~/.clojure/data_readers.clj` 
```
{d user/debug-data-reader}
```

I can load this code in any project i.e in the `deps.edn`
```
{:aliases {:dev {:extra-paths ["/Users/dliman/.clojure"]}}}
```

On emacs, I have set the keybindings to:
```
(use-package! smartparens
  :init
  (map! :map smartparens-mode-map
        ...
        "s-5" #'user-reset-log-store
        "s-6" #'user-tags
        "s-7" #'user-logs))

;; or

(global-set-key (kbd "s-5") 'user-reset-log-store)
(global-set-key (kbd "s-6") 'user-tags)
(global-set-key (kbd "s-7") 'user-logs)

```

and the definitions:
```
(defun user-reset-log-store ()
  (interactive)
  (cider-interactive-eval
    (format "
(require 'user)
(reset! user/log-store {})"
            (cider-last-sexp))))

(defun user-tags ()
  (interactive)
  (cider--pprint-eval-form "(user/tags)"))

(defun user-logs (&optional index-or-name)
  (interactive)
  (let* ((form (read-from-minibuffer "index-or-name: " index-or-name))
         (command (if (string-match form "")
                      "(user/tags)"
                    (format "(user/logs %s first)" form))))
    (cider--pprint-eval-form command)))
```

With combination of keyboard shortcut, emacs buffer, running the code in REPL, this makes debugging a lot faster (for me)

I hope this is useful for someone. I would love hear your thoughts on how you debug your clojure code!

