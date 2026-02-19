const esbuild = require('esbuild');
const path = require('path');

// Polyfills needed for domino to work in JavaScriptCore (no setTimeout/console)
const polyfills = `
if (typeof setTimeout === 'undefined') {
  var setTimeout = function(fn, ms) { fn(); };
}
if (typeof clearTimeout === 'undefined') {
  var clearTimeout = function() {};
}
if (typeof setInterval === 'undefined') {
  var setInterval = function(fn, ms) { return 0; };
}
if (typeof clearInterval === 'undefined') {
  var clearInterval = function() {};
}
if (typeof console === 'undefined') {
  var console = { log: function(){}, warn: function(){}, error: function(){} };
}
`;

// We bundle with platform:"node" so esbuild pulls in domino, which provides
// the DOM APIs (Document, Element, …) that are absent in JavaScriptCore.
// The output still runs inside JSC — esbuild resolves all require() calls at
// build time, so no Node runtime is needed. Don't change this to "browser".
esbuild.buildSync({
  entryPoints: [path.join(__dirname, 'entry.js')],
  bundle: true,
  format: 'iife',
  globalName: 'TurndownModule',
  platform: 'node',
  target: 'es2020',
  outfile: '../Resources/turndown-bundle.js',
  banner: {
    js: polyfills
  },
  footer: {
    js: 'var convert = TurndownModule.convert;'
  }
});

console.log('Built Resources/turndown-bundle.js');
