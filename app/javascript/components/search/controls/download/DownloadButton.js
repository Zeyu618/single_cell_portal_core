import React, { useState, useContext } from 'react'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faDownload } from '@fortawesome/free-solid-svg-icons'
import Tooltip from 'react-bootstrap/lib/Tooltip'
import OverlayTrigger from 'react-bootstrap/lib/OverlayTrigger'

import DownloadSelectionModal from './DownloadSelectionModal'
import { UserContext } from 'providers/UserProvider'

/**
 * Component for "Download" button which shows a Bulk Download modal on click.
 * DemoMode is included which will limit the number of TDR files queried, and make sure
 * analysis files are seeded as well.  Ordinarily, we wouldn't merge demo code, but this feature may be in demo-only
  * state for a long time, and need lots of demos
 */
export default function DownloadButton({ searchResults={}, isDemoMode=false }) {
  const userContext = useContext(UserContext)

  const [showModal, setShowModal] = useState(false)

  const matchingAccessions = searchResults.matchingAccessions || []

  /**
   * Reports whether Download button should be active,
   * i.e. user is signed in, has search results,
   * and search has parameters (i.e. user would not download all studies)
   * and download context (i.e. download size preview) has loaded
   */
  const active = (
    userContext.accessToken !== '' &&
    matchingAccessions.length > 0 &&
    (searchResults?.terms?.length > 0 || searchResults?.facets?.length > 0)
  )

  let hint = 'Download files for your search results'
  if (!active) {
    if (userContext.accessToken === '') {
      hint = 'To download, please sign in'
    } else {
      hint = 'To download, first do a search'
    }
  }

  /** Note that we are reading the TDR file information from the search results object, which
   * means we are reliant on the TDR results being on the current page.  Once we begin paging/sorting
   * TDR results, this approach will have to be revisited */
  const tdrFileInfo = searchResults.studies
    ?.filter(result => result.study_source === 'TDR')
    ?.map(result => ({
      accession: result.accession,
      name: result.name,
      description: result.description,
      studyFiles: isDemoMode ? makeDemoAppropriate(result.file_information) : result.file_information
    }))

  return (
    <>
      <OverlayTrigger
        placement='top'
        overlay={<Tooltip id='download-tooltip'>{hint}</Tooltip>}>
        <button
          id='download-button'
          className={`btn btn-primary ${active ? 'active' : 'disabled'}`}
          disabled={!active}
          onClick={() => {setShowModal(!showModal)}}>
          <span>
            <FontAwesomeIcon className="icon-left" icon={faDownload}/>
          Download
          </span>
        </button>
      </OverlayTrigger>
      { showModal &&
        <DownloadSelectionModal
          show={showModal}
          setShow={setShowModal}
          tdrFileInfo={tdrFileInfo}
          studyAccessions={matchingAccessions}/> }
    </>
  )
}

/** limit the files returned to 10, and add two fake analysis files
  */
function makeDemoAppropriate(fileInfomation) {
  return fileInfomation.slice(0, 10).concat(FAKE_ANALYSIS_FILES)
}

/** these are real (sequence file) DRS ids */
const FAKE_ANALYSIS_FILES = [{
  drs_id: 'drs://jade.datarepo-dev.broadinstitute.org/v1_257c5646-689a-4f25-8396-2500c849cb4f_7e3fb399-325f-42a5-bca1-3b8659f2c287', // eslint-disable-line max-len
  file_type: 'analysis_file'
}, {
  drs_id: 'drs://jade.datarepo-dev.broadinstitute.org/v1_257c5646-689a-4f25-8396-2500c849cb4f_8326615b-d61f-420a-b22c-ef637e79e551', // eslint-disable-line max-len
  file_type: 'analysis_file'
}]
