/* eslint-disable require-jsdoc */
import React from 'react'


export const descriptionCharacterLimit = 750
export const summaryWordLimit = 150
import { getDisplayNameForFacet } from 'providers/SearchFacetProvider'


const lengthOfHighlightTag = 21

/* converts description into text snippet */
export function formatDescription(rawDescription, term) {
  const textDescription = stripTags(rawDescription)
  return shortenDescription(textDescription, term)
}

export function highlightText(text, termMatches) {
  let matchedIndices = []
  if (termMatches) {
    matchedIndices = termMatches.map(term => text.indexOf(term))
  }
  if (matchedIndices.length > 0) {
    termMatches.forEach((term, index) => {
      const regex = RegExp(term, 'gi')
      text = text.replace(regex, `<span class='highlight'>${term}</span>`)
    })
  }
  return { styledText: text, matchedIndices }
}

// returns the first 140 characters of the description in plain text
export function getByline(rawDescription) {
  const bylineCharLimit = 140
  const plainText = stripTags(rawDescription).trim()
  let bylineText = plainText.substring(0, bylineCharLimit)
  if (plainText.length > bylineCharLimit) {
    bylineText = `${bylineText}...`
  }
  return bylineText
}

export function shortenDescription(textDescription, term) {
  const { styledText, matchedIndices } = highlightText(textDescription, term)
  const suffixTag = <span className="detail"> ...(continued)</span>

  // Check if there are matches outside of the descriptionCharacterLimit
  if (matchedIndices.some(matchedIndex => matchedIndex >= descriptionCharacterLimit)) {
    // Find matches occur outside descriptionCharacterLimit
    const matchesOutSidedescriptionCharacterLimit = matchedIndices.filter(matchedIndex =>
      matchedIndex > descriptionCharacterLimit
    )

    const firstIndex = matchesOutSidedescriptionCharacterLimit[0]
    // Find matches that fit within the n+descriptionCharacterLimit
    const ranges = matchesOutSidedescriptionCharacterLimit.filter(index => index < descriptionCharacterLimit + firstIndex)
    // Determine where start and end index to ensure matched keywords are included
    const start = ((matchedIndices.length - matchesOutSidedescriptionCharacterLimit.length) *
      (lengthOfHighlightTag + term.length)) + firstIndex
    const end = start + descriptionCharacterLimit + (ranges.length * (lengthOfHighlightTag + term.length))
    const descriptionText = styledText.slice(start - 100, end)
    const displayedStudyDescription = { __html: descriptionText }
    // Determine if there are matches to display in summary paragraph
    const amountOfMatchesInSummaryWordLimit = matchedIndices.filter(matchedIndex =>
      matchedIndex <= summaryWordLimit).length
    if (amountOfMatchesInSummaryWordLimit > 0) {
      //  Need to recaluculate index positions because added html changes size of textDescription
      const beginningTextIndex = (amountOfMatchesInSummaryWordLimit * (lengthOfHighlightTag + term.length))
      const displayedBeginningText = { __html: styledText.slice(0, beginningTextIndex + summaryWordLimit) }
      return <>
        <span className="openingText" dangerouslySetInnerHTML={displayedBeginningText}></span>
        <span className="detail">... </span>
        <span className="studyDescription" dangerouslySetInnerHTML={displayedStudyDescription}></span>{suffixTag}
      </>
    }
    const displayedBeginningText = styledText.slice(0, summaryWordLimit)
    return <>
      <span className="openingText">{displayedBeginningText} </span>
      <span className="detail">... </span>
      <span className="studyDescription" dangerouslySetInnerHTML={displayedStudyDescription}></span>{suffixTag}
    </>
  }
  const displayedStudyDescription = { __html: styledText.slice(0, descriptionCharacterLimit) }
  if (textDescription.length > descriptionCharacterLimit) {
    return <>
      <span className="studyDescription" dangerouslySetInnerHTML={displayedStudyDescription}></span>{suffixTag}
    </>
  } else {
    return <><span className="studyDescription" dangerouslySetInnerHTML={displayedStudyDescription}></span></>
  }
}

/* removes html tags from a string */
export function stripTags(rawString) {
  const tempDiv = document.createElement('div')
  // Set the HTML content with the provided
  tempDiv.innerHTML = rawString
  // Retrieve the text property of the element
  return tempDiv.textContent || ''
}

/* generate a badge for each matched facet, containing the filter names */
function facetMatchBadges(study) {
  const matches = study.facet_matches
  if (!matches) {
    return <></>
  }
  const matchedKeys = Object.keys(matches)
    .filter(key => key != 'facet_search_weight')
  return (<>
    {matchedKeys.map((key, index) => {
      const helpText = `Metadata match for ${key}`
      return (
        <span key={index}
          className="badge badge-secondary facet-match"
          data-toggle="tooltip"
          title={helpText}>
          {
            matches[key].map(filter => {
              if ('min' in filter) { // numeric facet
                return `${getDisplayNameForFacet(key)} ${filter.min}-${filter.max} ${filter.unit}`
              } else {
                return filter.name
              }
            }).join(',')
          }
        </span>)
    })}
  </>)
}

/** Generate a cell count badge for SCP studies */
function cellCountBadge(study) {
  if (study.study_source === 'SCP') {
    return <span className="badge cell-count">
      {study.cell_count} Cells
    </span>
  }
}

// generate the inferredBadge for SCP studies
function inferredBadge(study, termMatches) {
  if (study.inferred_match && study.study_source === 'SCP') {
    const helpText = `${termMatches.join(', ')} was not found in study metadata,
     only in study title or description`
    return <span className="badge soft-badge" data-toggle="tooltip" title={helpText}>text match only</span>
  }
}

/* generate a badge to indicate to users the study origin for non-SCP studies */
function studyTypeBadge(study) {
  if (study.study_source === 'TDR') {
    return <span className="badge badge-secondary study-type" data-toggle="tooltip"
      title={'Study comes from Terra Data Repo'}> TDR </span>
  }
}

/* displays a brief summary of a study, with a link to the study page */
export default function StudySearchResult({ study }) {
  const termMatches = study.term_matches
  const studyTitle = highlightText(study.name, termMatches).styledText
  const studyDescription = formatDescription(study.description, termMatches)
  const displayStudyTitle = { __html: studyTitle }

  return (
    <>
      <div key={study.accession}>
        <label htmlFor={study.name} id="result-title" className={'study-label'}>
          <a href={study.study_url} dangerouslySetInnerHTML={displayStudyTitle} />
          {inferredBadge(study, termMatches)}
          {studyTypeBadge(study)}
        </label>
        <div>
          {cellCountBadge(study)}
          {facetMatchBadges(study)}
        </div>
        {studyDescription}
      </div>
    </>
  )
}
