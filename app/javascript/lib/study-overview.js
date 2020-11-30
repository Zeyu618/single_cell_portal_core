/**
* @fileoverview Study Overview user interface
*
* The Explore tab in Study Overview has three main views:
*   - Default: Shows "Clusters" and sometimes "Genomes", etc.
*   - Single-gene: Shows distribution (violin or box) plot and others
*   - Multiple-gene: Shows dot plot and heatmap
*/

import { fetchExplore } from 'lib/scp-api'
import { drawScatterPlots, resizePlots, setColorScales } from 'lib/scatter-plot'

const baseCamera = {
  'up': { 'x': 0, 'y': 0, 'z': 1 },
  'center': { 'x': 0, 'y': 0, 'z': 0 },
  'eye': { 'x': 1.25, 'y': 1.25, 'z': 1.25 }
}

/** Listen for events, and update view accordingly */
function attachEventHandlers(study) {
  // For inferCNV ideogram
  $('#ideogram_annotation').on('change', function() {
    const ideogramFiles = window.SCP.study.inferCNVIdeogramFiles
    const fileId = $(this).val() // eslint-disable-line
    if (fileId !== '') {
      const ideogramAnnot = ideogramFiles[fileId]
      window.ideogramInferCnvSettings = ideogramAnnot.ideogram_settings
      window.initializeIdeogram(ideogramAnnot.ideogram_settings.annotationsPath)
    } else {
      $('#tracks-to-display, #_ideogramOuterWrap').html('')
      $('#ideogramTitle').remove()
    }
  })

  // resize listener
  $(window).on('resizeEnd', () => {resizePlots()})

  // listener for cluster nav, specific to study page
  $('#annotation').change(function() {
    const an = $(this).val() // eslint-disable-line
    // keep track for search purposes
    $('#search_annotation').val(an)
    $('#gene_set_annotation').val(an)
    drawScatterPlots(study)
  })

  $('#subsample').change(function() {
    const subsample = $(this).val() // eslint-disable-line
    $('#search_subsample').val(subsample)
    $('#gene_set_subsample').val(subsample)
    drawScatterPlots(study)
  })

  $('#cluster').change(function() {
    const newCluster = $(this).val() // eslint-disable-line
    // keep track for search purposes
    $('#search_cluster').val(newCluster)
    $('#gene_set_cluster').val(newCluster)
    drawScatterPlots(study)
  })

  $(document).on('change', '#spatial-group', function() {
    const newSpatial = $(this).val() // eslint-disable-line
    // keep track for search purposes
    $('#search_spatial-group').val(newSpatial)
    $('#gene_set_spatial-group').val(newSpatial)
    drawScatterPlots(study)
  })

  // listener to redraw expression scatter with new color profile
  $('#colorscale').change(function() {
    const theme = $(this).val() // eslint-disable-line
    // $('#search_colorscale').val(theme)
    setColorScales(theme)
  })
}

/** Get HTML for dropdown menu for spatial files */
function getSpatialDropdown(study) {
  const options = study.spatialGroupNames.map(name => {
    return `<option value="${name}">${name}</option>`
  })
  const domId = 'spatial-group'
  const select =
    `<select name="${domId}" id="${domId}" class="form-control">${
      options
    }</select>`
  return (
    `<div class="form-group col-sm-4">` +
    `<label for=${domId}>Spatial group</label><br/>${select}` +
    `</div>`
  )
}

/** Add dropdown menu for spatial files */
function addSpatialDropdown(study) {
  if (study.spatialGroupNames.length > 0) {
    const dropdown = getSpatialDropdown(study)
    $('#view-options #precomputed-panel #precomputed .row').append(dropdown)
  }
}

/** Initialize the "Explore" tab in Study Overview */
export default async function initializeExplore() {
  window.SCP.study = {}
  window.SCP.plots = []
  window.SCP.plotRects = []

  window.SCP.startPendingEvent('user-action:page:view:site-study',
    { speciesList: window.SCP.taxons },
    'plot:',
    true)

  // if tab position was specified in url, show the current tab
  if (window.location.href.split('#')[1] !== '') {
    const tab = window.location.href.split('#')[1]
    $(`#study-tabs a[href="#${tab}"]`).tab('show')
  }
  $('#cluster-plot').data('camera', baseCamera)

  const accession = window.SCP.studyAccession
  const study = await fetchExplore(accession)

  window.SCP.study = study
  window.SCP.study.accession = accession
  window.SCP.taxons = window.SCP.study.taxonNames

  attachEventHandlers(study)

  if (study.cluster) {
    // set default subsample option of 10K (if subsampled) or all cells
    if (study.cluster.numPoints > 10000 && study.cluster.isSubsampled) {
      $('#subsample').val(10000)
      $('#search_subsample').val(10000)
    }

    addSpatialDropdown(study)

    drawScatterPlots(study)
  }

  if (study.inferCNVIdeogramFiles) {
    // user has no clusters, but does have ideogram annotations

    const ideogramSelect = $('#ideogram_annotation')
    const firstIdeogram = $('#ideogram_annotation option')[1].value

    // manually trigger change to cause ideogram to render
    ideogramSelect.val(firstIdeogram).trigger('change')
  }
}
