var TurndownService = require('turndown');
var gfm = require('turndown-plugin-gfm');

var service = new TurndownService({
  headingStyle: 'atx',
  hr: '---',
  bulletListMarker: '-',
  codeBlockStyle: 'fenced',
  fence: '```',
  emDelimiter: '*',
  strongDelimiter: '**',
  linkStyle: 'inlined'
});

service.use(gfm.gfm);
service.remove(['script', 'style', 'noscript']);

function convert(html) {
  return service.turndown(html);
}

module.exports = { convert: convert };
