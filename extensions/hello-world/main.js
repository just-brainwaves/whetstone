// Hello World — the first-party dogfood extension that proves the §C API.
//
// It runs inside a sandboxed Web Worker. The only thing in scope is the global
// `whetstone` host API (no DOM, no Node, no editor internals). It registers a
// command; running it (palette → "Hello World: Say Hello", or Mod-Alt-H) shows a
// toast built from this extension's own settings — edit them on its page in the
// Extensions manager and run the command again to see them take effect live.

whetstone.commands.register("hello.greet", () => {
  const greeting = whetstone.config.get("greeting") || "Hello!";
  const excited = whetstone.config.get("excited");
  whetstone.ui.notify(excited ? `${greeting} 🎉` : greeting, "success");
});

whetstone.log("hello-world activated");
