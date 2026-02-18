const esbuild = require('esbuild');

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

esbuild.buildSync({
  entryPoints: [require.resolve('turndown')],
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
    js: 'var TurndownService = TurndownModule;'
  }
});

console.log('Built Resources/turndown-bundle.js');
