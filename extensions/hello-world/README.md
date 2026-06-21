# Hello World

The first-party **dogfood** extension for Whetstone — the smallest thing that
proves the whole extension pipeline works end to end.

## What it does

It contributes a single command, **Say Hello**, bound to `Mod-Alt-H`. Running it
pops a toast back in the editor:

> 👋 Hello from a sandboxed extension!

## How it works

The logic in `main.js` runs inside an isolated **Web Worker** — no DOM, no Node,
no access to the editor's internals. The only thing in scope is the `whetstone`
host API:

```js
whetstone.commands.register("hello.greet", () => {
  whetstone.ui.notify("👋 Hello from a sandboxed extension!", "success");
});
```

That round-trip — manifest → command registry → keybinding → sandbox RPC → host
UI — is the contract every extension builds on.

## Try editing it

Change the message in `main.js`, then hit **Reload from source** in the
Extensions manager to see it update live.
