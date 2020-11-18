FactoryBot.define do
  # gets a ClusterGroup object, defaulting to the first user found.
  factory :cluster_group do
    cluster_type { '2d' }
    cell_annotations { [] }
    name { study_file.name }
    study { study_file.study }

    # create a cluster group with data arrays populated according to a passed-in cell_input object
    factory :cluster_group_with_cells do
      transient do
        # cell_input is a hash of three (or 4) arrays: cells, x and y and z
        # {
        #   x: [1, 2, 3],
        #   y: [1, 2, 3],
        #   cells: ['cellA', 'cellB', 'cellC']
        # }
        cell_input {
          {}
        }
        # annotation_input is an array of objects specifying name, type, and values for annotations
        # values should be an array in the same length and order as the 'cells' array above
        # e.g. [{ name: 'category', type: 'group', values: ['foo', 'foo', 'bar'] }]
        annotation_input {
          []
        }
      end
      cell_annotations {
        annotation_input.map { |a| { name: a[:name], type: a[:type], values: a[:values].uniq } }
      }

      after(:create) do |cluster, evaluator|
        [
          {name: :x, type: 'coordinates', array_name: 'x'},
          {name: :y, type: 'coordinates', array_name: 'y'},
          {name: :z, type: 'coordinates', array_name: 'z'},
          {name: :cells, type: 'cells', array_name: 'text'}
        ].each do |input_type|
          if evaluator.cell_input[input_type[:name]]
            FactoryBot.create(:data_array,
                              cluster_group: cluster,
                              array_type: input_type[:type],
                              name: input_type[:array_name],
                              array_index: 0,
                              values: evaluator.cell_input[input_type[:name]],
                              study_file: evaluator.study_file)

          end
        end
        evaluator.annotation_input.each do |annotation|
          FactoryBot.create(:data_array,
                            cluster_group: cluster,
                            array_type: 'annotations',
                            name: annotation[:name],
                            array_index: 0,
                            values: annotation[:values],
                            study_file: evaluator.study_file)
        end
      end
    end
  end
end
