import React, { useState, useEffect } from 'react'
import _clone from 'lodash/clone'

import Study, { getByline } from 'components/search/results/Study'
import DotPlot from 'components/visualization/DotPlot'
import StudyViolinPlot from 'components/visualization/StudyViolinPlot'
import ClusterControls, { emptyDataParams, getAnnotationValues } from 'components/visualization/ClusterControls'
import { fetchClusterOptions } from 'lib/scp-api'
import { getDefaultClusterParams } from 'lib/cluster-utils'



/** Renders expression data for a study.  This assumes that the study has a 'gene_matches' property
    to inform which genes to show data for
  */
export default function StudyGeneExpressions({ study }) {
  const [dataParams, setDataParams] = useState(_clone(emptyDataParams))
  const [annotationList, setAnnotationList] = useState(null)
  let controlDataParams = _clone(dataParams)

  if (annotationList && !dataParams.cluster) {
    // if the user hasn't specified anything yet, but we have the study defaults, use those
    controlDataParams = Object.assign(controlDataParams, getDefaultClusterParams(annotationList))
  }

  let studyRenderComponent
  if (!study.gene_matches) {
    return <Study study={study}/>
  }

  const showDotPlot = study.gene_matches.length > 1 && !dataParams.consensus

  if (!study.can_visualize_clusters) {
    studyRenderComponent = (
      <div className="text-center">
        This study contains {study.gene_matches.join(', ')} in expression data.<br/>
          This study does not have cluster data to support visualization in the portal
      </div>
    )
  } else if (showDotPlot) {
    // render dotPlot for multigene searches that are not collapsed
    const annotationValues = getAnnotationValues(controlDataParams.annotation, annotationList)
    studyRenderComponent = <DotPlot studyAccession={study.accession}
      genes={study.gene_matches}
      dataParams={controlDataParams}
      annotationValues={annotationValues}/>
  } else {
    // render violin for single genes or collapsed
    studyRenderComponent = <StudyViolinPlot studyAccession={study.accession} genes={study.gene_matches} dataParams={dataParams} setAnnotationList={setAnnotationList}/>
  }

  return (
    <div className="study-gene-result">
      <label htmlFor={study.name} id= 'result-title'>
        <a href={study.study_url} >{ study.name }</a>
      </label>
      <div ><em>{ getByline(study.description) }</em></div>
      <div>
        <span className='badge badge-secondary cell-count'>
          {study.cell_count} Cells
        </span>
        {
          study.gene_matches.map(geneName => {
            return (<span key={geneName} className='badge gene-match'>
              { geneName }
            </span>)
          })
        }
      </div>
      <div className="row graph-container">
        <div className="col-md-10">
          { studyRenderComponent }
        </div>
        <div className="col-md-2 graph-controls">
          <ClusterControls
            studyAccession={study.accession}
            setDataParams={setDataParams}
            dataParams={controlDataParams}
            fetchAnnotationList={false}
            showConsensus={study.gene_matches.length > 1}
            preloadedAnnotationList={annotationList}/>
        </div>
      </div>

    </div>
  )
}
