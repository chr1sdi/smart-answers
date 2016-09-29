require 'lrucache'
require 'ostruct'

class WorldLocation
  extend Forwardable

  def self.cache
    @cache ||= LRUCache.new(max_size: 250, soft_ttl: 24.hours, ttl: 1.week)
  end

  def self.reset_cache
    @cache = nil
  end

  def self.all(use_open_register=false)
    cache_fetch("all") do
      world_locations = 
        if use_open_register
          
          some_data = YAML.load_file(Rails.root.join('lib', 'data', 'country_register_records.yml'))

          transformed = some_data.map{ |l|
              vals = l[1]
              next if vals.has_key? 'end-date'

              temp = {
                :title => vals['name'],
                :details => {
                  :slug => vals['name'].downcase.gsub(' ', '-'),
                  :iso2 => vals['country']
                }
              }
              puts temp.inspect
              new(build_ostruct_recursively(temp))
            }

          
          transformed
        else
          Services.worldwide_api.world_locations.with_subsequent_pages.map do |l|
            new(l) if l.format == "World location" && l.details && l.details.slug.present?
        end
      end

      world_locations.compact.sort_by{ |l| l.name }
    end
  end

  def self.find(location_slug, use_open_register=false)
    cache_fetch("find_#{location_slug}") do
      data = Services.worldwide_api.world_location(location_slug)
      self.new(data) if data
    end
  end

  # Fetch a value from the cache.
  #
  # On GdsApi errors, returns a stale value from the cache if available,
  # otherwise re-raises the original GdsApi exception
  def self.cache_fetch(key)
    inner_exception = nil
    cache.fetch(key) do
      begin
        yield
      rescue GdsApi::BaseError => e
        inner_exception = e
        raise RuntimeError.new("use_stale_value")
      end
    end
  rescue RuntimeError => e
    if e.message == "use_stale_value"
      raise inner_exception
    else
      raise
    end
  end

  def initialize(data)
    @data = data
  end

  def self.build_ostruct_recursively(value)
    case value
    when Hash
      OpenStruct.new(Hash[value.map { |k, v| [k, build_ostruct_recursively(v)] }])
    when Array
      value.map { |v| build_ostruct_recursively(v) }
    else
      value
    end
  end

  def ==(other)
    other.is_a?(self.class) && other.slug == self.slug
  end

  def_delegators :@data, :title, :details
  def_delegators :details, :slug
  alias_method :name, :title

  def organisations
    @organisations ||= WorldwideOrganisation.for_location(self.slug)
  end

  def fco_organisation
    self.organisations.find(&:fco_sponsored?)
  end
end
