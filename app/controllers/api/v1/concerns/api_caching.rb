module Api
  module V1
    module Concerns
      module ApiCaching
        extend ActiveSupport::Concern

        # check Rails cache for JSON response based off url/params
        # cache expiration is still handled by CacheRemovalJob
        def check_api_cache!
          cache_path = RequestUtils.get_cache_path(request.path, params.to_unsafe_hash)
          if check_caching_config && Rails.cache.exist?(cache_path)
            Rails.logger.info "Reading from API cache: #{cache_path}"
            json_response = Rails.cache.fetch(cache_path)
            render json: json_response
          end
        end

        # write to the cache after a successful response
        def write_api_cache!
          cache_path = RequestUtils.get_cache_path(request.path, params.to_unsafe_hash)
          if check_caching_config && !Rails.cache.exist?(cache_path)
            Rails.logger.info "Writing to API cache: #{cache_path}"
            Rails.cache.write(cache_path, response.body)
          end
        end

        private

        # check if caching is enabled/disabled in development environment
        # will always return true in all other environments
        def check_caching_config
          if Rails.env.development?
            Rails.root.join('tmp/caching-dev.txt').exist?
          else
            true
          end
        end
      end
    end
  end
end
