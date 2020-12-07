/**
* @fileoverview Single-gene view in "Explore" tab of Study Overview page
*
* The Explore tab has three views:
*   - Default: Shows "Clusters" and sometimes "Genomes", etc.
*   - Single-gene: Shows distribution (violin or box) plot and others
*   - Multiple-genes: Shows dot plot and heatmap
*/

import {
  scatterPlots, resizePlots, setColorScales
} from 'lib/scatter-plot'
import { violinPlot } from 'lib/violin-plot'
import {
  addSpatialDropdown, updateCluster
} from 'lib/study-overview/view-options'

/** Render violin and scatter plots for the Explore tab's single-gene view */
async function renderSingleGenePlots(study, gene) {
  $(window).off('resizeEnd')

  violinPlot('box-plot', study, gene)
  scatterPlots(study, gene, true)
  // var target3 = document.getElementById('reference-plot');

  // if error in any of above, show:
  // showMessageModal(null, "An error has occurred loading the data.<br><br>If the error persists after reloading the page, please contact us at <br><a href='mailto:scp-support@broadinstitute.zendesk.com'>scp-support@broadinstitute.zendesk.com</a>");

  // no need to store spinners in data attribute as entire plot div will be re-rendered
  // var spin2 = new Spinner(opts).spin(target2);
  // var spin3 = new Spinner(opts).spin(target3);

  // var urlParams = getRenderUrlParams();

  // var delimiter = "<%= params[:gene] ? "?".html_safe : "&".html_safe %>";
  // url += delimiter + urlParams;
  // $.ajax({
  //     url: url,
  //     method: 'GET',
  //     dataType: 'script'
  // }).fail(function() {
  //     spin2.stop()
  //     spin3.stop()

  // });
}

/** Listen for events, and update view accordingly */
function attachEventHandlers(study, gene) {
  console.log('in attachEventHandlers in explore-single')
  // resize listener
  $(window).off('resizeEnd') // Clear any existing handler
  $(window).on('resizeEnd', () => {resizePlots()})

  $(document).off('change', '#cluster')
  $(document).on('change', '#cluster', function() {
    const cluster = $(this).val() // eslint-disable-line
    const subsample = $('#subsample').val()
    // keep track for search purposes
    $('#search_cluster').val(cluster)
    $('#gene_set_cluster').val(cluster)
    const url =
    `${window.location.pathname}/get_new_annotations` +
    `?cluster=${encodeURIComponent(cluster)}&` +
    `subsample=${encodeURIComponent(subsample)}`
    $.ajax({
      url,
      dataType: 'script',
      success() {
        updateCluster(renderSingleGenePlots, [study, gene])
      }
    })
  })

  const menuSelectors = '#annotation, #subsample, #spatial-group'
  $(document).off('change', menuSelectors)
  $(document).on('change', menuSelectors, function() {
    const menu = $(this) // eslint-disable-line
    const newValue = menu.val()
    // keep track for search purposes
    $(`#search_${menu.id}`).val(newValue)
    $(`#gene_set_${menu.id}`).val(newValue)
    renderSingleGenePlots(study, gene)
  })
}

/** Initialize single-gene view for "Explore" tab in Study Overview */
export default async function exploreSingle() {
  // As set in exploreDefault
  const study = window.SCP.study
  const gene = window.SCP.gene

  attachEventHandlers(study, gene)

  addSpatialDropdown(study)

  renderSingleGenePlots(study, gene)
}
