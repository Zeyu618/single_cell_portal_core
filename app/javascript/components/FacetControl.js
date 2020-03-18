
import React, { useState, useEffect, useRef, useContext } from 'react'
import FiltersBoxSearchable from './FiltersBoxSearchable'
import { StudySearchContext } from 'components/search/StudySearchProvider'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faTimesCircle } from '@fortawesome/free-solid-svg-icons'
import { SearchSelectionContext } from './search/SearchSelectionProvider'

/**
 * Converts string value to lowercase, hyphen-delimited version
 * e.g. "Cell type" -> "cell-type"
 */
function slug(value) {
  return value.toLowerCase().replace(/ /g, '-')
}

/**
 * Button for facets, and associated functions
 */
export default function FacetControl(props) {
  const [showFilters, setShowFilters] = useState(false)

  const facetName = props.facet.name
  const facetId = `facet-${slug(facetName)}`
  const searchContext = useContext(StudySearchContext)
  const appliedSelection = searchContext.params.facets[props.facet.id]
  const selectionContext = useContext(SearchSelectionContext)
  const selection = selectionContext.facets[props.facet.id] ?
                      selectionContext.facets[props.facet.id] :
                      []

  let selectedFilterString
  if (appliedSelection && appliedSelection.length) {
    const selectedFilters =
      props.facet.filters.filter(filter => appliedSelection.includes(filter.id))
    if (selectedFilters.length > 1) {
      selectedFilterString = `${facetName} (${selectedFilters.length})`
    } else if (selectedFilters.length === 1) {
      selectedFilterString = selectedFilters[0].name
    } else {
      // it's a numeric range filter
      selectedFilterString = `${facetName}:
                              ${appliedSelection[0]}-${appliedSelection[1]}
                              ${appliedSelection[2]}`
    }
  }

  const clearNode = useRef()
  /**
    * Click on the facet control itself
    */
  function handleButtonClick(e) {
    if (clearNode.current && clearNode.current.contains(e.target)) {
      setShowFilters(false)
    } else {
      setShowFilters(!showFilters)
    }
  }

  /**
    * Clear the selection and update search results
    */
  function clearFacet() {
    selectionContext.updateFacet(props.facet.id, [], true)
  }


  const node = useRef()
  const handleOtherClick = e => {
    if (node.current.contains(e.target)) {
      // click was inside the modal, do nothing
      return
    }
    setShowFilters(false)
  }

  // add event listener to detect clicks outside the modal,
  // so we know to close it
  // see https://medium.com/@pitipatdop/little-neat-trick-to-capture-click-outside-with-react-hook-ba77c37c7e82
  useEffect(() => {
    // add when mounted
    document.addEventListener('mousedown', handleOtherClick)
    // return function to be called when unmounted
    return () => {
      document.removeEventListener('mousedown', handleOtherClick)
    }
  }, [])

  let controlContent = facetName
  if (selectedFilterString) {
    controlContent =
      <>
        {selectedFilterString }
        <button
          ref={clearNode}
          className='facet-clear'
          onClick={ clearFacet }
        >
          <FontAwesomeIcon icon={faTimesCircle}/>
        </button>
      </>
  }

  return (
    <span ref={node}
      id={facetId}
      className={`facet ${showFilters ? 'active' : ''} ${selectedFilterString ? 'selected' : ''}`} // eslint-disable-line max-len
    >
      <a onClick={handleButtonClick}>
        { controlContent }
      </a>
      <FiltersBoxSearchable
        show={showFilters}
        facet={props.facet}
        setShow={setShowFilters}
        selection={selection}
        setSelection={selection =>
          selectionContext.updateFacet(props.facet.id, selection)
        }/>
    </span>
  )
}
