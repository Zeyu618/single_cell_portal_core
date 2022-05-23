import React from 'react'
// import Modal from 'react-bootstrap/lib/Modal'

import Select from '~/lib/InstrumentedSelect'
import { clusterSelectStyle } from '~/lib/cluster-utils'
import { newlineRegex } from '~/lib/validation/io'
import { fetchBucketFile } from '~/lib/scp-api'
import PlotUtils from '~/lib/plot'
const { getLegendSortedLabels } = PlotUtils

// Value to show in menu if user has not selected a group for DE
const noneSelected = 'Select group'

/** Takes array of strings, converts it to list options suitable for react-select */
function getSimpleOptions(stringArray) {
  const assignLabelsAndValues = name => ({ label: name, value: name })
  return stringArray.map(assignLabelsAndValues)
}

const nonAlphaNumericRegex = /\W/g

/**
 * Transform raw TSV text into array of differential expression gene objects
 */
function parseDeFile(tsvText) {
  const deGenes = []
  const tsvLines = tsvText.split(newlineRegex)
  for (let i = 1; i < tsvLines.length; i++) {
    // Each element in this array is DE data for the gene in this row
    const [
      index, // eslint-disable-line
      name, score, log2FoldChange, pval, pvalAdj, pctNzGroup, pctNzReference
    ] = tsvLines[i].split('\t')
    const deGene = {
      score, log2FoldChange, pval, pvalAdj, pctNzGroup, pctNzReference
    }
    Object.entries(deGene).forEach(([k, v]) => {
      // Cast numeric string values as floats
      deGene[k] = parseFloat(v)
    })
    deGene.name = name
    deGenes.push(deGene)
  }

  return deGenes
}

/**
 * Fetch array of differential expression gene objects
 *
 * @param {String} bucketId Identifier for study's Google bucket
 * @param {String} deFilePath File path of differential expression file in Google bucket
 * @param {Integer} numGenes Number of genes to include in returned deGenes array
 *
 * @return {Array} deGenes Array of DE gene objects, each with properties:
 *   name: Gene name
 *   score: Differential expression score assigned by Scanpy.
 *   log2FoldChange: Log-2 fold change.  How many times more expression (1 = 2, 2 = 4, 3 = 8).
 *   pval: p-value.  Statistical significance of the `score` value.
 *   pvalAdj: Adjusted p-value.  p-value adjusted with Benjamini-Hochberg FDR correction
 *   pctNzGroup: Percent non-zero, group.  % of cells with non-zero expression in selected group.
 *   pctNzReference: Percent non-zero, reference.  % of cells with non-zero expression in non-selected groups.
 **/
async function fetchDeGenes(bucketId, deFilePath, numGenes=15) {
  const data = await fetchBucketFile(bucketId, deFilePath)
  const tsvText = await data.text()
  const deGenes = parseDeFile(tsvText)
  return deGenes.slice(0, numGenes)
}

/** Pick groups of cells for differential expression (DE) */
export default function DeGroupPicker({
  bucketId, clusterName, annotation, deGenes, deGroup, setDeGroup, setDeGenes, setDeFileUrl,
  countsByLabel
}) {
  const groups = getLegendSortedLabels(countsByLabel)

  /** Update group in differential expression picker */
  async function updateDeGroup(newGroup) {
    setDeGroup(newGroup)

    const deFileName = `${[
      clusterName,
      annotation.name,
      newGroup,
      annotation.scope,
      'wilcoxon'
    ]
      .map(s => s.replaceAll(nonAlphaNumericRegex, '_'))
      .join('--') }.tsv`

    const basePath = '_scp_internal/differential_expression/'
    const deFilePath = `${basePath}${deFileName}`.replaceAll('/', '%2F')

    const deGenes = await fetchDeGenes(bucketId, deFilePath)

    setDeGroup(newGroup)
    setDeGenes(deGenes)

    const baseUrl = 'https://storage.googleapis.com/download/storage/v1/'
    const deFileUrl = `${baseUrl}/${bucketId}/o/${deFilePath}?alt=media`
    setDeFileUrl(deFileUrl)
  }

  return (
    <>
      {!deGenes &&
        <div className="flexbox-align-center flexbox-column">
          <span>Compare one group to all others</span>
          <Select
            defaultMenuIsOpen
            options={getSimpleOptions(groups)}
            data-analytics-name="de-group-select"
            value={{
              label: deGroup === null ? noneSelected : deGroup,
              value: deGroup
            }}
            onChange={newGroup => updateDeGroup(newGroup.value)}
            styles={clusterSelectStyle}
          />
        </div>
      }
      {deGenes &&
      <>
        <Select
          options={getSimpleOptions(groups)}
          data-analytics-name="de-group-select"
          value={{
            label: deGroup === null ? noneSelected : deGroup,
            value: deGroup
          }}
          onChange={newGroup => updateDeGroup(newGroup.value)}
          styles={clusterSelectStyle}
        />
        <span>vs. all other groups</span>
        <br/>
        <br/>
      </>
      }
    </>
  )
}
