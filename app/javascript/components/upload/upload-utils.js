import _uniqueId from 'lodash/uniqueId'

/** properties used to track file state on the form, but that should not be sent to the server
 *  this also includes properties that are only modifiable on the server (and so should also
 * be ignored server side, but for best hygiene are also just not sent ) */
const PROPERTIES_NOT_TO_SEND = [
  'selectedFile',
  'uploadSelection',
  'submitData',
  'saveProgress',
  'isDirty',
  'isSaving',
  'isDeleting',
  'isError',
  'oldId',
  'generation',
  'created_at',
  'updated_at',
  'queued_for_deletion',
  'upload_file_size',
  'data_dir',
  'options',
  'version',
  'status',
  'upload',
  'parse_status'
]

const ARRAY_PROPERTIES = [
  'spatial_cluster_associations'
]

/** gets an object representing a new, empty study file.  Does not communicate to server */
export function newStudyFileObj(studyId) {
  return {
    name: '',
    _id: _uniqueId('newFile-'), // we just need a temp id to give to form controls, the real id will come from the server
    status: 'new',
    description: '',
    parse_status: 'unparsed',
    spatial_cluster_associations: [],
    expression_file_info: {}
  }
}

/** reworks the file object to make it easier to work with
  * maps the id property to _id, and sets undefined properties
  * this modifies the object in-place, but also returns it for easy chaining
  */
export function formatFileFromServer(file) {
  file._id = file._id.$oid
  file.description = file.description ? file.description : ''
  delete file.study_id
  if (file.taxon_id) {
    // Note that taxon_id here is a MongoDB object ID, not an NCBI Taxonomy ID like "9606".
    file.taxon_id = file.taxon_id.$oid
  }
  if (file.genome_assembly_id) {
    file.genome_assembly_id = file.genome_assembly_id.$oid
  }
  if (!file.expression_file_info) {
    file.expression_file_info = {}
  }
  return file
}

/** find the bundle children of 'file', if any, in the given 'files' list */
export function findBundleChildren(file, files) {
  return files.filter(f => {
    const parentFields = [f.options?.matrix_id, f.options?.bam_id, f.options?.cluster_file_id]
    return parentFields.includes(file._id) || (file.oldId && parentFields.includes(file.oldId))
  })
}

/** return a new FormData based on the given file object, formatted as the api endpoint expects,
    cleaning out any excess params */
export function formatFileForApi(file, chunkStart, chunkEnd) {
  const data = new FormData()
  Object.keys(file).filter(key => !PROPERTIES_NOT_TO_SEND.includes(key)).forEach(key => {
    if (ARRAY_PROPERTIES.includes(key)) {
      // because we are sending as FormData, rather than JSON, we need to split
      // arrays across multiple entries to deliver what Rails expects.
      file[key].map(val => {
        data.append(`study_file[${key}][]`, val)
      })
    } else if (key === 'expression_file_info') {
      Object.keys(file.expression_file_info).forEach(expKey => {
        data.append(`study_file[expression_file_info_attributes][${expKey}]`, file.expression_file_info[expKey])
      })
    } else {
      data.append(`study_file[${key}]`, file[key])
    }
  })
  if (file.uploadSelection) {
    if (chunkStart || chunkEnd) {
      data.append('study_file[upload]', file.uploadSelection.slice(chunkStart, chunkEnd), file.name)
    } else {
      data.append('study_file[upload]', file.uploadSelection)
    }
    data.append('study_file[parse_on_upload]', true)
  }
  if (file.options) {
    Object.keys(file.options).forEach(key => {
      data.append(`study_file[options][${key}]`, file.options[key])
    })
  }
  return data
}


