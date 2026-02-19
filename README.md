# Paste as Markdown

A lightweight macOS menu bar utility that converts rich text on your clipboard to Markdown. Copy formatted text from any app, click the menu bar icon, and paste clean Markdown. Everything runs locally with no network access.

## How it works

1. Copy formatted text from a browser, Google Docs, email, etc.
2. Click the clipboard icon in the menu bar → **Convert Clipboard to Markdown**
3. The icon flashes a checkmark (✓) on success
4. Paste into your editor — you now have Markdown

The app reads HTML from the macOS clipboard (with an RTF fallback), converts it using [turndown.js](https://github.com/mixmark-io/turndown) running inside Apple's JavaScriptCore framework, and writes the result back as plain text. No data leaves your machine.

## Supported conversions

- Headings (`# h1` through `###### h6`)
- Bold, italic, strikethrough
- Links and images
- Ordered and unordered lists
- GFM tables (via [turndown-plugin-gfm](https://github.com/mixmark-io/turndown-plugin-gfm))
- Fenced code blocks and inline code
- Blockquotes and horizontal rules
- Script/style tags are stripped automatically

## Installation

### Download (recommended)

1. Download the latest `PasteAsMarkdown-vX.X.X.zip` from [Releases](https://github.com/matthewtobiasz/paste-as-markdown/releases)
2. Unzip and drag **Paste as Markdown.app** to `/Applications`
3. Double-click to launch — the clipboard icon appears in your menu bar

> **Note:** On first launch, macOS may say the app is from an unidentified developer. Go to **System Settings → Privacy & Security** and click **Open Anyway**.

### Build from source

Requires macOS 11+, Xcode command line tools, and Node.js (for bundling turndown.js at build time).

```
make        # install npm deps, bundle JS, compile Obj-C, assemble .app
make run    # build and launch
make test   # build and run unit tests
make dist   # build and create PasteAsMarkdown.zip
make clean  # remove build artifacts
```

The built app is at `Paste as Markdown.app` — drag it to `/Applications` or run it from here.

## Project structure

```
src/
  main.m                App entry point, menu bar setup, conversion action
  MarkdownConverter.h/m JSContext bridge to turndown.js
  ClipboardHelper.h/m   NSPasteboard read (HTML/RTF) and write (plain text)
  Info.plist            App metadata (LSUIElement=YES hides dock icon)
test/
  tests.m               Unit tests
js/
  package.json          npm dependencies (turndown, turndown-plugin-gfm, esbuild)
  entry.js              Bundle entry point for esbuild
  build.js              esbuild config — produces Resources/turndown-bundle.js
Makefile                Build system
```

The JS bundle (~590KB) is generated at build time and embedded in the app. At runtime there are no external dependencies — the app is fully self-contained.

## How it's built

- **Objective-C** with AppKit for the menu bar UI
- **JavaScriptCore** (macOS system framework) to run turndown.js natively
- **turndown.js** + **domino** (pure-JS DOM) for HTML→Markdown conversion
- **esbuild** bundles everything into a single IIFE with polyfills for JavaScriptCore's minimal environment
- No Xcode project — just a Makefile

## License

MIT
