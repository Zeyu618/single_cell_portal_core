// mock various modules from genome tab as these aren't being used, and throw compilation errors from jest
jest.mock('components/explore/GenomeView', () => {
  return {
    igv: jest.fn(() => mockPromise)
  }
})

jest.mock('components/visualization/RelatedGenesIdeogram', () => {
  return {
    Ideogram: jest.fn(() => mockPromise)
  }
})

jest.mock('components/visualization/InferCNVIdeogram', () => {
  return {
    Ideogram: jest.fn(() => mockPromise)
  }
})

import { getEnabledTabs } from 'components/explore/ExploreDisplayTabs'

// mock explore info from a study
const defaultExploreInfo =  {
  cluster: 'foo',
  taxonNames: ['Homo sapiens'],
  inferCNVIdeogramFiles: null,
  bamBundleList: [],
  uniqueGenes: ['Agpat2', 'Apoe', 'Gad1', 'Gad2'],
  geneLists: [],
  annotationList: [],
  clusterGroupNames: ['foo', 'bar'],
  spatialGroupNames: [],
  spatialGroups: [],
  clusterPointAlpha: 1.0
}

describe("explore tabs are activated based on study info and parameters", () => {
  it('should enable cluster tab', async () => {
    const exploreInfo = defaultExploreInfo
    const exploreParams = {
      cluster: 'foo', // request params loading only a cluster
      annotation: { name: 'bar', type: 'group', scope: 'study' },
      userSpecified: {
        annotation: true,
        cluster: true
      }
    }
    const expectedResults = {
      enabledTabs: ['scatter'],
      isGeneList: false,
      isGene: false,
      isMultiGene: false,
      hasIdeogramOutputs: false
    }

    expect(expectedResults).toEqual(getEnabledTabs(exploreInfo, exploreParams))
  })

  it('should enable cluster and genome tab', async () => {
    // mock exploreInfo from study
    const exploreInfo = {
      ...defaultExploreInfo,
      bamBundleList: [
        {"name": "sample1.bam", "file_type": "BAM"},
        {"name": "sample1.bam.bai", "file_type": "BAM Index"}
      ]
    }

    const exploreParams = {
      cluster: 'foo',
      annotation: { name: 'bar', type: 'group', scope: 'study' },
      bamFileName: 'sample1.bam',
      userSpecified: {
        annotation: true,
        cluster: true,
        bamFileName: true
      }
    }
    const expectedResults = {
      enabledTabs: ['scatter', 'genome'],
      isGeneList: false,
      isGene: false,
      isMultiGene: false,
      hasIdeogramOutputs: false
    }

    expect(expectedResults).toEqual(getEnabledTabs(exploreInfo, exploreParams))
  })

  it('should enable heatmap tab for gene lists', async () => {
    // mock exploreInfo from study
    const exploreInfo = {
      ...defaultExploreInfo,
      geneLists: ['Gene List 1', 'Gene List 2'],
    }

    const exploreParams = {
      geneList: 'Gene List 1',
      userSpecified: {
        geneList: true
      }
    }
    const expectedResults = {
      enabledTabs: ['heatmap'],
      isGeneList: true,
      isGene: false,
      isMultiGene: false,
      hasIdeogramOutputs: false
    }

    expect(expectedResults).toEqual(getEnabledTabs(exploreInfo, exploreParams))
  })

  it ('should enable scatter/distribution tabs when searching one gene', async () => {
    const exploreInfo = defaultExploreInfo

    const exploreParams = {
      cluster: 'foo',
      genes: ['Agpat2'],
      annotation: {name: 'bar', type: 'group', scope: 'study'},
      userSpecified: {
        annotation: true,
        cluster: true,
        genes: true
      }
    }

    const expectedResults = {
      enabledTabs: ['scatter', 'distribution'],
      isGeneList: false,
      isGene: true,
      isMultiGene: false,
      hasIdeogramOutputs: false
    }

    expect(expectedResults).toEqual(getEnabledTabs(exploreInfo, exploreParams))
  })

  it ('should enable dotplot/heatmap tabs when searching multiple genes', async () => {
    const exploreInfo = {
      ...defaultExploreInfo
    }

    const exploreParams = {
      cluster: 'foo',
      genes: ['Agpat2', 'Apoe'],
      annotation: {name: 'bar', type: 'group', scope: 'study'},
      userSpecified: {
        annotation: true,
        cluster: true,
        genes: true
      }
    }

    const expectedResults = {
      enabledTabs: ['dotplot', 'heatmap'],
      isGeneList: false,
      isGene: true,
      isMultiGene: true,
      hasIdeogramOutputs: false
    }

    expect(expectedResults).toEqual(getEnabledTabs(exploreInfo, exploreParams))
  })

  it ('should enable scatter/dotplot/heatmap tabs when searching multiple genes', async () => {
    const exploreInfo = {
      ...defaultExploreInfo,
      spatialGroupNames: ['bing', 'baz'],
      spatialGroups: [
        {'name': 'bing', 'associated_clusters': ['foo']},
        {'name': 'baz', 'associated_clusters': ['bar']}
      ]
    }

    const exploreParams = {
      cluster: 'foo',
      genes: ['Agpat2', 'Apoe'],
      annotation: { name: 'bar', type: 'group', scope: 'study' },
      spatialGroups: ['square', 'circle'],
      userSpecified: {
        annotation: true,
        cluster: true,
        genes: true,
        spatialGroups: true
      }
    }

    const expectedResults = {
      enabledTabs: ['scatter', 'dotplot', 'heatmap'],
      isGeneList: false,
      isGene: true,
      isMultiGene: true,
      hasIdeogramOutputs: false
    }

    expect(expectedResults).toEqual(getEnabledTabs(exploreInfo, exploreParams))
  })

  it ('should enable scatter/distribution/dotplot tabs when searching multiple genes w/ consensus', async () => {
    const exploreInfo = defaultExploreInfo

    const exploreParams = {
      cluster: 'foo',
      genes: ['Agpat2', 'Apoe'],
      annotation: { name: 'bar', type: 'group', scope: 'study' },
      consensus: 'mean',
      userSpecified: {
        annotation: true,
        cluster: true,
        genes: true,
        consensus: true
      }
    }

    const expectedResults = {
      enabledTabs: ['scatter', 'distribution', 'dotplot'],
      isGeneList: false,
      isGene: true,
      isMultiGene: true,
      hasIdeogramOutputs: false
    }

    expect(expectedResults).toEqual(getEnabledTabs(exploreInfo, exploreParams))
  })

  it ('should enable infercnv-genome tab when selecting Ideogram annotations', async () => {
    const ideogramOpts = {
      "604fc5c4e241391a8ff93271": {
        "cluster": "foo",
        "annotation": "bar--group--study",
        "display": "Observations: foo",
        "ideogram_settings": {
          "organism": "human",
          "assembly": "GRCh38",
          "annotationsPath": "https://www.googleapis.com/storage/v1/b/my-bucket/o/ideogram_exp_means__Observations--foo--group--study.json?alt=media"
        }
      }
    }
    const exploreInfo = {
      ...defaultExploreInfo,
      clusterGroupNames: [],
      inferCNVIdeogramFiles: ideogramOpts
    }

    const exploreParams = {
      ideogramFileId: Object.keys(ideogramOpts)[0],
      userSpecified: {
        ideogramFileId: true
      }
    }

    const expectedResults = {
      enabledTabs: ['infercnv-genome'],
      isGeneList: false,
      isGene: false,
      isMultiGene: false,
      hasIdeogramOutputs: true
    }

    expect(expectedResults).toEqual(getEnabledTabs(exploreInfo, exploreParams))
  })
})
