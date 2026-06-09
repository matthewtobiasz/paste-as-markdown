var TurndownService = require('turndown');
var gfm = require('turndown-plugin-gfm');

var TURNDOWN_OPTIONS = {
  headingStyle: 'atx',
  hr: '---',
  bulletListMarker: '-',
  codeBlockStyle: 'fenced',
  fence: '```',
  emDelimiter: '*',
  strongDelimiter: '**',
  linkStyle: 'inlined'
};

var service = new TurndownService(TURNDOWN_OPTIONS);
service.use(gfm.gfm);
service.remove(['script', 'style', 'noscript']);

// Dedicated service for converting table cell contents. The confluenceTable
// rule below needs to convert cell innerHTML to markdown, but calling
// service.turndown() re-entrantly from inside one of its own replacement
// functions is undocumented behavior in turndown and risks corrupting
// in-flight conversion state. A separate instance makes cell conversion a
// clean, independent call. It intentionally does NOT carry the
// confluenceTable rule, so a (degenerate) nested table inside a cell can't
// recurse.
var cellService = new TurndownService(TURNDOWN_OPTIONS);
cellService.use(gfm.gfm);
cellService.remove(['script', 'style', 'noscript']);

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

    function convertCell(td) {
      // Convert the cell's innerHTML so that inline elements (strong, em, a)
      // become markdown rather than being left as HTML. Uses cellService —
      // never the outer service — see comment above.
      return cellService.turndown(td.innerHTML).trim().replace(/\|/g, '\\|');
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
  var md = service.turndown(html);
  // Normalize non-breaking spaces to regular spaces. Apple's NSAttributedString
  // HTML export (the RTF fallback path) and many web editors emit U+00A0 for
  // ordinary spaces, which leaks invisible characters into the markdown.
  return md.replace(/\u00A0/g, ' ');
}

module.exports = { convert: convert };
