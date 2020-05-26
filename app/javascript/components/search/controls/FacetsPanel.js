import React, { useContext } from 'react'
import _find from 'lodash/find'

import FacetControl from './FacetControl'
import CombinedFacetControl from './CombinedFacetControl'
import MoreFacetsButton from './MoreFacetsButton'
import { SearchFacetContext } from 'providers/SearchFacetProvider'

const defaultFacetIds = ['disease', 'species']
const moreFacetIds = [
  'sex', 'race', 'library_preparation_protocol', 'organism_age'
]

/**
 * Container for horizontal list of facet buttons, and "More Facets" button
 */
export default function FacetsPanel() {
  const searchFacetContext = useContext(SearchFacetContext)
  const defaultFacets = searchFacetContext.facets.filter(facet => defaultFacetIds.includes(facet.id))
  const moreFacets = searchFacetContext.facets.filter(facet => moreFacetIds.includes(facet.id))
  return (
    <>
      <CombinedFacetControl controlName="cell type" facetNames={ ['cell_type', 'cell_type__custom'] }/>
      <CombinedFacetControl controlName="organ" facetNames={ ['organ', 'organ_region'] }/>
      {
        defaultFacets.map((facet, i) => {
          return <FacetControl facet={facet} key={i}/>
        })
      }
      <MoreFacetsButton facets={moreFacets} />
    </>
  )
}
