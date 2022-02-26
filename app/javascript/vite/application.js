import React from 'react'
import ReactDOM from 'react-dom'
import 'react-notifications-component/dist/theme.css'
import '~/styles/application.scss'

import HomePageContent from '~/components/HomePageContent'
import ExploreView from '~/components/explore/ExploreView'
import UploadWizard from '~/components/upload/UploadWizard'
import ValidationMessage from '~/components/validation/ValidationMessage'
import ClusterAssociationSelect from '~/components/upload/ClusterAssociationSelect'
import RawAssociationSelect from '~/components/upload/RawAssociationSelect'
import { validateFileContent } from '~/lib/validation/validate-file-content'
import { getFeatureFlagsWithDefaults } from '~/providers/UserProvider'
import checkMissingAuthToken from '~/lib/user-auth-tokens'
import { validateRemoteFileContent } from '~/lib/validation/validate-remote-file-content'
import {
  logPageView, logClick, logMenuChange, setupPageTransitionLog, log, logCopy, logContextMenu
} from '~/lib/metrics-api'


document.addEventListener('DOMContentLoaded', () => {
  // Logs only page views for faceted search UI
  logPageView()

  $(document).on('click', 'body', logClick)
  $(document).on('change', 'select', logMenuChange)
  $(document).on('copy', 'body', logCopy)
  // contextmenu event is to handle when users use context menu "copy email address" instead of cmd+C copy event as
  // this does not emit the copy event
  $(document).on('contextmenu', 'body', logContextMenu)

  setupPageTransitionLog()

  checkMissingAuthToken()
})

const componentsToExport = {
  HomePageContent, ExploreView, UploadWizard, ValidationMessage, ClusterAssociationSelect, RawAssociationSelect
}

/** helper to render React components from non-react portions of the app */
function renderComponent(targetId, componentName, props) {
  ReactDOM.render(React.createElement(componentsToExport[componentName], props),
    document.getElementById(targetId))
}
window.SCP.renderComponent = renderComponent

/** render any components that were registered to render prior to this script loading */
window.SCP.componentsToRender.forEach(componentToRender => {
  renderComponent(componentToRender.targetId, componentToRender.componentName, componentToRender.props)
})

window.SCP.log = log
window.SCP.getFeatureFlagsWithDefaults = getFeatureFlagsWithDefaults
window.SCP.validateFileContent = validateFileContent
window.SCP.validateRemoteFileContent = validateRemoteFileContent
