//    Not used currently, but perhaps later.
//   function getGenomicRange(annot) {
//     var chr, start, stop, startString, stopString, genomicRange;
//
//     // Get genomic range
//     chr = annot.chr;
//     start = annot.start;
//     stop = start + annot.length;
//     startString = start.toLocaleString();
//     stopString = stop.toLocaleString();
//     genomicRange = 'chr' + chr + ':' + startString + '-' + stopString;
//
//     return genomicRange;
//   }
//
//   function getEnsemblLink(annot) {
//     var url, link;
//     url = 'https://www.ensembl.org/' + annot.id;
//     link = '<a target="_blank" href="' + url + '">' + annot.name + '</a>';
//     return link;
//   }
//
//   function writeAnnotsTable() {
//
//     var chr, annots, datum, row, header, table, annotsContainer, keys,
//         genomicRange, ensemblLink, key, i, j, k, displayKeys;
//
//     rows = [];
//
//     annotsContainer = ideogram.annots;
//
//     keys = ideogram.rawAnnots.keys;
//
//     for (i = 0; i < annotsContainer.length; i++) {
//       chr = annotsContainer[i].chr;
//       annots = annotsContainer[i].annots;
//       for (j = 0; j < annots.length; j++) {
//         annot = annots[j];
//         row = [];
//
//         genomicRange = getGenomicRange(annot);
//         ensemblLink = getEnsemblLink(annot);
//
//         for (k = 0; k < keys.length; k++) {
//           key = keys[k];
//           if (key === 'name') {
//             datum = ensemblLink;
//           } else if (key === 'start') {
//             datum = genomicRange;
//           } else if (key === 'id') {
//             continue;
//           } else {
//             datum = annot[key];
//           }
//           row.push(datum)
//
//         }
//         row = '<tr><td>' + row.join('</td><td>') + '</td></tr>';
//         rows.push(row);
//       }
//     }
//
//     displayKeys = [];
//     for (i = 0; i < keys.length; i++) {
//       key = keys[i];
//       if (key == 'start') {
//         key = 'Genomic range';
//       } else if (key === 'id') {
//         continue;
//       } else {
//         key = key[0].toUpperCase() + key.slice(1);
//       }
//       displayKeys.push(key)
//     }
//
//     header = '<tr><th>' + displayKeys.join('</th><th>') + '</th></tr>';
//
//     table =
//       '<table class="table table-striped table-sm">' +
//         '<thead>' + header + '</thead>' +
//         '<tbody>' + rows + '</tbody>' +
//       '</table>';
//
//     $('#ideogram-container').append(table);
//   }

// Use colors like inferCNV; see
// https://github.com/broadinstitute/inferCNV/wiki#demo-example-figure
var heatmapThresholds = [
  [-0.1, '#00B'], // If -0.001 < expression value, use blue (loss)
  [0.3, '#DDD'], // If -0.001 >= value 0 > 0.003, use grey
  ['+', '#F00'] // If value >= 0.003, use red (gain)
];

var legend = [{
  name: 'Expression level',
  rows: [
    {name: 'Low', color: '#00B'},
    {name: 'Normal', color: '#DDD'},
    {name: 'High', color: '#F00'}
  ]
}];

function getSelectedTracks() {
  var selectedTracks = [];

  checkboxes.forEach(function(checkbox) {
    var trackIndex = parseInt(checkbox.getAttribute('id').split('_')[1]);
    if (checkbox.checked) {
      selectedTracks.push(trackIndex);
    }
  });

  return selectedTracks;
}

function updateTracks() {
  var selectedTracks = getSelectedTracks();
  ideogram.updateDisplayedTracks(selectedTracks);
}

function createTrackFilters() {
  var i, listItems, trackLabels, content, checked;
  // Only apply this function once
  if (document.querySelector('#filter_1')) return;
  listItems = '';
  trackLabels = ideogram.rawAnnots.keys.slice(6,);
  displayedTracks = ideogram.config.annotationsDisplayedTracks;
  for (i = 0; i < trackLabels.length; i++) {
    checked = (displayedTracks.includes(i + 1)) ? 'checked' : '';
    listItems +=
      '<li>' +
        '<label for="filter_' + (i + 1) + '">' +
          '<input type="checkbox" id="filter_'  + (i + 1) + '" ' + checked + '/>' +
          trackLabels[i] +
        '</label>' +
      '</li>';
  }
  content = 'Tracks ' + listItems;
  document.querySelector('#tracks-to-display').innerHTML = content;


  $('#filters-container').after('<div id="ideogramTitle">Copy number variation inference</div>');

  checkboxes = document.querySelectorAll('input[type=checkbox]');
  checkboxes.forEach(function(checkbox) {
    checkbox.addEventListener('click', function() {
      updateTracks();
    });
  });
}
 
function warnIdeogramOfNumericCluster() {
  var cluster, cellAnnot, warning;

  cluster = $('#cluster option:selected').val();
  cellAnnot = $('#annotation option:selected').val();

  warning =
    '<div id="ideogramWarning" style="height: 400px; margin-left: 20px;">' +
      'Ideogram not available for selected cluster ("' + cluster + '") and ' +
      'cell annotation ("' + cellAnnot + '").' +
    '</div>';

    $('#tracks-to-display, #_ideogramOuterWrap').html('');
    $('#ideogramWarning, #ideogramTitle').remove();
    $('#ideogram-container').append(warning);
}

function initializeIdeogram(url) {

  // Percent-encode all slashes to "%2F" after "/o/" in GCS ?alt=media URL
  var splitUrl = url.split('/o/');
  var objPathPctEncoded = splitUrl[1].replace('/', '%2F');
  var url = splitUrl[0] + '/o/' + objPathPctEncoded;

  if (typeof window.ideogram !== 'undefined') {
    delete window.ideogram;
    $('#tracks-to-display').html('');
    $('#_ideogramOuterWrap').html('');
  }

  $('#ideogramWarning, #ideogramTitle').remove();

  window.ideogram = new Ideogram({
    container: '#ideogram-container',
    organism: ideogramInferCnvSettings.organism.toLowerCase(),
    assembly: ideogramInferCnvSettings.assembly,
    chrHeight: 400,
    dataDir: 'https://unpkg.com/ideogram@1.4.1/dist/data/bands/native/',
    annotationsPath: url,
    annotationsLayout: 'heatmap',
    legend: legend,
    onDrawAnnots: createTrackFilters,
    debug: true,
    rotatable: false,

    chrHeight: 90,
    annotationHeight: 20,
    geometry: 'collinear',
    orientation: 'horizontal',
    heatmapThresholds: heatmapThresholds
  });

    // Log Ideogram.js initialization in Google Analytics
    ga('send', 'event', 'ideogram', 'initialize');
}