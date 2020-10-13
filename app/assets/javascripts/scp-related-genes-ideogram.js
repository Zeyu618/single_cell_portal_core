/**
 * @fileoverview Ideogram for related genes
 *
 * This code enhances single-gene search in the Study Overview page.  It is
 * called upon searching for a gene, invoking functionality in Ideogram.js to
 * retrieve and plot related genes across the genome.  Users can then click a
 * related gene to trigger a search on that gene.  The intent is to improve
 * discoverability for genes of biological interest.
 *
 * More context, a screenshot, and architecture diagram are available at:
 * https://github.com/broadinstitute/single_cell_portal_core/pull/735
 */

/** Handle clicks on Ideogram annotations */
function onClickAnnot(annot) {
  const ideo = this // eslint-disable-line
  document.querySelector('#search_genes').value = annot.name

  // Enable merge of related-genes log props into search log props
  // This helps profile the numerator of click-through-rate
  const namespacedProps = {}
  const props = getRelatedGenesAnalytics(ideo)
  Object.entries(props).forEach(([key, value]) => {
    namespacedProps[`relatedGenes:${key}`] = value
  })

  const event = Object.assign(
    { type: 'click-related-genes' }, namespacedProps
  )
  window.submitGeneSearch(event)
}

/**
 * Reports if current gene has associated taxon (aka species, organism)
 *
 * Enables handling for old SCP studies, where matrices lack taxons
 */
function geneHasTaxon() {
  return window.SCP.taxon !== ''
}

/**
 * Reports if current genome assembly has chromosome length data
 *
 * Enables handling for taxons that cannot be visualized in an ideogram.
 * Example edge case: axolotl study SCP499.
 */
function genomeHasChromosomes() {
  return window.ideogram.chromosomesArray.length > 0
}

/**
* Move Ideogram within expresion plot tabs, per UX recommendation
*/
function putIdeogramInPlotTabs(ideoContainer) {
  const tabContent = document.querySelector('#render-target .tab-content')
  const ideoOuter = document.querySelector('#_ideogramOuterWrap')
  const chrHeight = `${window.ideogram.config.chrHeight}px`

  // Ideogram has `position: absolute`, so manual top offsets are needed
  ideoOuter.style.height = chrHeight

  tabContent.prepend(ideoContainer)
}

/**
 * Displays Ideogram after getting gene search results in Study Overview
 */
function showRelatedGenesIdeogram() { // eslint-disable-line

  if (!geneHasTaxon()) return

  const ideoContainer =
    document.querySelector('#related-genes-ideogram-container')

  if (!genomeHasChromosomes()) {
    ideoContainer.classList = 'hidden-related-genes-ideogram'
    ideoContainer.innerHTML = ''
    return
  }

  putIdeogramInPlotTabs(ideoContainer)

  // Make Ideogram visible
  ideoContainer.classList = 'show-related-genes-ideogram'
}

/**
 * Get summary of related-genes ideogram that was just loaded or clicked
 */
function getRelatedGenesAnalytics(ideo) {
  const props = Object.assign({}, ideo.relatedGenesAnalytics)

  // Use DSP-conventional name
  props['perfTime'] = props.time
  delete props['time']

  props['species'] = window.SCP.taxon
  return Object.assign({}, props)
}

/**
 * Callback to report analytics to Mixpanel.
 * Helps profile denominator of click-through-rate
 */
function onPlotRelatedGenes() {
  const ideo = this // eslint-disable-line
  const props = getRelatedGenesAnalytics(ideo)

  window.SCP.log('plot:related-genes-ideogram', props)
}

/**
 * Initiates Ideogram for related genes
 *
 * This is only done in the context of single-gene search in Study Overview
 */
function createRelatedGenesIdeogram() { // eslint-disable-line

  if (!geneHasTaxon()) return

  // Clear any prior ideogram
  if (typeof window.ideogram !== 'undefined') {
    delete window.ideogram
    document.querySelector('#related-genes-ideogram-container').remove()
  }

  const gene = document.querySelector('#search_genes').value.trim()

  // Create scaffolding for Ideogram for related genes
  const ideoContainer =
    '<div id="related-genes-ideogram-container" class="hidden-related-genes-ideogram"></div>' // eslint-disable-line
  $('body').append(ideoContainer)

  const ideoConfig = {
    container: '#related-genes-ideogram-container',
    organism: window.SCP.taxon,
    chrWidth: 9,
    chrHeight: 100,
    chrLabelSize: 12,
    annotationHeight: 7,
    onClickAnnot,
    onPlotRelatedGenes,
    onLoad() {
      // Handles edge case: when organism lacks chromosome-level assembly
      if (!genomeHasChromosomes()) return
      this.plotRelatedGenes(gene)
    }
  }

  window.ideogram =
    Ideogram.initRelatedGenes(ideoConfig, window.SCP.uniqueGenes)
}
