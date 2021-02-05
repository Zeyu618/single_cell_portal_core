import React, { useState, useEffect } from 'react'
import _uniqueId from 'lodash/uniqueId'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faDna } from '@fortawesome/free-solid-svg-icons'

import { log, startPendingEvent } from 'lib/metrics-api'
import { getColorBrewerColor } from 'lib/plot'
import DotPlotLegend from './DotPlotLegend'
import { getAnnotationCellValuesURL, getExpressionHeatmapURL } from 'lib/scp-api'

export const dotPlotColorScheme = {
  // Blue, purple, red.  These red and blue hues are accessible, per WCAG.
  colors: ['#0000BB', '#CC0088', '#FF0000'],

  // TODO: Incorporate expression units, once such metadata is available.
  values: [0, 0.5, 1]
}

/** renders a morpheus powered dotPlot for the given URL paths and annotation
  * Note that this has a lot in common with Heatmap.js.  they are separate for now
  * as their display capabilities may diverge (esp. since DotPlot is used in global gene search)*/
export default function DotPlot({ studyAccession, genes, renderParams, annotationValues }) {
  const [graphId] = useState(_uniqueId('dotplot-'))
  const expressionValuesURL = getExpressionHeatmapURL(studyAccession, genes, renderParams.cluster)
  const annotationCellValuesURL = getAnnotationCellValuesURL(studyAccession,
                                                             renderParams.cluster,
                                                             renderParams.annotation.name,
                                                             renderParams.annotation.scope,
                                                             renderParams.annotation.type,
                                                             renderParams.subsample)
  useEffect(() => {
    if (renderParams.annotation.name) {
      const plotEvent = startPendingEvent('plot:dot', window.SCP.getLogPlotProps())
      log('dot-plot:initialize')
      renderDotPlot({
        target: `#${graphId}`,
        expressionValuesURL: expressionValuesURL,
        annotationCellValuesURL: annotationCellValuesURL,
        annotationName: renderParams.annotation.name,
        annotationValues: annotationValues
      })
      plotEvent.complete()
    }
  }, [expressionValuesURL, annotationCellValuesURL, renderParams.annotation.name, renderParams.annotation.scope])
  return (
    <div>
    { renderParams.cluster &&
      <>
        <div id={graphId} className="dotplot-graph"></div>
        <DotPlotLegend/>
      </> }
    { !renderParams.cluster && <FontAwesomeIcon icon={faDna} className="gene-load-spinner"/> }
    </div>
  )
}

/** Render Morpheus dot plot */
function renderDotPlot({target, expressionValuesURL, annotationCellValuesURL, annotationName, annotationValues}) {
  const $target = $(target)
  $target.empty()

  // Collapse by mean
  const tools = [{
    name: 'Collapse',
    params: {
      collapse_method: 'Mean',
      shape: 'circle',
      collapse: ['Columns'],
      collapse_to_fields: [annotationName],
      pass_expression: '>',
      pass_value: '0',
      percentile: '100',
      compute_percent: true
    }
  }]

  const config = {
    shape: 'circle',
    dataset: expressionValuesURL,
    el: $target,
    menu: null,
    colorScheme: {
      scalingMode: 'relative'
    },
    focus: null,
    // We implement our own trivial tab manager as it seems to be the only way
    // (after 2+ hours of digging) to prevent morpheus auto-scrolling
    // to the heatmap once it's rendered
    tabManager: {
      add: options => {
        $target.empty()
        $target.append(options.$el)
        return { id: $target.attr('id'), $panel: $target }
      },
      setTabTitle: () => {},
      setActiveTab: () => {},
      getWidth: () => $target.width(),
      getHeight: () => $target.height(),
      getTabCount: () => 1
    },
    tools
  }

  // Load annotations if specified
  if (annotationCellValuesURL !== '') {
    config.columnAnnotations = [{
      file: annotationCellValuesURL,
      datasetField: 'id',
      fileField: 'NAME',
      include: [annotationName]
    }]
    config.columnSortBy = [
      { field: annotationName, order: 0 }
    ]
    config.columns = [
      { field: annotationName, display: 'text' }
    ]
    config.rows = [
      { field: 'id', display: 'text' }
    ]

    // Create mapping of selected annotations to colorBrewer colors
    const annotColorModel = {}
    annotColorModel[annotationName] = {}
    const sortedAnnots = annotationValues.sort()

    // Calling % 27 will always return to the beginning of colorBrewerSet
    // once we use all 27 values
    $(sortedAnnots).each((index, annot) => {
      annotColorModel[annotationName][annot] = getColorBrewerColor(index)
    })
    config.columnColorModel = annotColorModel
  }

  config.colorScheme = dotPlotColorScheme

  // Instantiate dot plot and embed in DOM element
  new window.morpheus.HeatMap(config)
}
