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

// Imperative editor feature (§C-C3): the host streams us the document text; we
// compute decoration spans with real logic and post them back. Here we underline
// every occurrence of the word "whetstone" (case-insensitive) — the kind of thing
// the declarative regex slice can't do when the match depends on computed state.
function computeSpans(text) {
  const spans = [];
  const re = /whetstone/gi;
  let m;
  while ((m = re.exec(text))) {
    spans.push({
      from: m.index,
      to: m.index + m[0].length,
      style: { "text-decoration": "underline wavy #38bdf8", "text-underline-offset": "3px" },
    });
  }
  return spans;
}

whetstone.editor.onChange(({ path, text }) => {
  whetstone.editor.setDecorations("brand", path, computeSpans(text));
});

// A sidebar view (§C views): the Worker returns a virtual-DOM tree; the host
// renders it as React. Click handlers are functions — the host echoes the click
// back and we re-render with `whetstone.views.update`. No DOM access here at all.
let clicks = 0;
whetstone.views.register("hello.panel", () => ({
  tag: "div",
  props: { style: { display: "flex", "flex-direction": "column", gap: "10px", "padding-top": "6px" } },
  children: [
    { tag: "p", props: { style: { color: "var(--ws-ink-muted)" } }, children: ["Rendered from a sandboxed Worker."] },
    { tag: "strong", children: [`You clicked ${clicks} time${clicks === 1 ? "" : "s"}.`] },
    {
      tag: "button",
      props: {
        style: {
          "align-self": "flex-start",
          padding: "6px 12px",
          "border-radius": "8px",
          background: "var(--ws-accent)",
          color: "var(--ws-accent-ink)",
          cursor: "pointer",
        },
        onClick: () => {
          clicks++;
          whetstone.views.update("hello.panel");
        },
      },
      children: ["Click me"],
    },
  ],
}));

whetstone.log("hello-world activated");
