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

// Confluence and other rich editors produce tables with no <thead> or <th> —
// every row uses <td>, even the header row. The GFM plugin only converts tables
// that have a heading row (first row all <th>, or wrapped in <thead>), so these
// tables pass through as raw HTML. Fix: promote the first <tr> of a tbody-only
// table to a header row by replacing its <td> cells with <th>.
service.addRule('confluenceTable', {
  filter: function (node) {
    return (
      node.nodeName === 'TABLE' &&
      !node.querySelector('thead') &&
      !node.querySelector('th') &&
      !!node.querySelector('tbody tr')
    );
  },
  replacement: function (content, node) {
    var rowsNL = node.querySelectorAll('tr');
    if (!rowsNL || rowsNL.length === 0) return content;
    var rows = rowsNL;

    function cellText(td) {
      // Strip block-level wrappers (<p>, <div>) that wrap cell content so that
      // inline markdown (bold, links) survives but the surrounding paragraph
      // tags don't leak into the cell text.
      return td.textContent.trim();
    }

    function convertCell(td) {
      // Re-run the turndown converter on the cell's innerHTML so that inline
      // elements (strong, em, a) are converted to markdown rather than left as HTML.
      return service.turndown(td.innerHTML).trim().replace(/\|/g, '\\|');
    }

    function nodeListToArray(nl) {
      var a = [];
      for (var i = 0; i < nl.length; i++) a.push(nl[i]);
      return a;
    }

    var headerCells = nodeListToArray(rows[0].querySelectorAll('td'));
    var header = '| ' + headerCells.map(convertCell).join(' | ') + ' |';
    var separator = '| ' + headerCells.map(function () { return '---'; }).join(' | ') + ' |';

    var rowsArr = nodeListToArray(rows);
    var bodyRows = rowsArr.slice(1).map(function (row) {
      var cells = nodeListToArray(row.querySelectorAll('td'));
      return '| ' + cells.map(convertCell).join(' | ') + ' |';
    });

    return '\n\n' + [header, separator].concat(bodyRows).join('\n') + '\n\n';
  }
});

function convert(html) {
  return service.turndown(html);
}

module.exports = { convert: convert };
