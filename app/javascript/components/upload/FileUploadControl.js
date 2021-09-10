import React, { useEffect } from 'react'

import { bytesToSize } from 'lib/stats'
import { getAccessToken } from 'providers/UserProvider'
import { formatFileForApi } from './uploadUtils'

/** renders a file upload control for the given file object */
export default function FileUploadControl({ file, updateFile, handleSaveResponse }) {
  const inputId = `fileInput-${file._id}`

  /** Initializes a blueimp fileupload widget on the given elementId that will be bound to the
   * passed-in file.  For now, we destroy and re-bind the widget on each render to ensure
   * callbacks always operate on the latest version of data */
  function initializeUploadWidget() {
    let url = `/single_cell/api/v1/studies/${file.study_id}/study_files/${file._id}`
    if (file.status === 'new') {
      url = `/single_cell/api/v1/studies/${file.study_id}/study_files`
    }
    const selector = `#${inputId}`
    if ($(selector).data('fileupload')) {
      $(selector).fileupload('destroy')
    }
    $(selector).fileupload({
      url,
      maxChunkSize: 10000000,
      type: file.status === 'new' ? 'POST' : 'PATCH',
      formData: () => formatForBlueImp(file),
      add: (e, data) => {
        updateFile(file._id, {
          submitData: data,
          selectedFile: data.files[0],
          name: file.name ? file.name : data.files[0].name
        })
        $.blueimp.fileupload.prototype.options.add.call(selector, e, data)
      },
      headers: { Authorization: `Bearer ${getAccessToken()}` },
      acceptFileTypes: window.ALLOWED_FILE_TYPES['plainText'],
      filesContainer: null,
      uploadTemplateId: null,
      uploadTemplate: uploadObj => '',
      downloadTemplateId: null,
      downloadTemplate: () => '',
      done: (event, data) => {
        console.log('WOOOOOO!!!!')
        handleSaveResponse(data)
      }
    })
  }

  useEffect(() => {
    initializeUploadWidget()
  })

  return <div className="form-group">
    <label>File{ file.status !== 'new' && <span>: {file.upload_file_name}</span> }</label>
    <br/>
    <button className="fileinput-button btn btn-secondary" id={`fileButton-${file._id}`}>
      { file.upload_file_name ? 'Change file' : 'Choose file' }
      <input className="file-upload" type="file" name="study_file[upload]" id={inputId}/>
    </button>
    { file.selectedFile &&
      <span> {file.selectedFile.name} ({bytesToSize(file.selectedFile.size)})</span>
    }
    <div className="file-container" id={`clusterFileList-${file._id}`}></div>
  </div>
}

/** blueimp expects a form-type submission,
    so convert a file object into a hash of 'name' -> 'value' pairs */
function formatForBlueImp(file) {
  const cleanFile = formatFileForApi(file)
  return Object.keys(cleanFile).map(key => ({ name: `study_file[${key}]`, value: cleanFile[key] }))
}
