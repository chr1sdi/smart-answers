require 'gds_api/publishing_api_v2'
require 'gds_api/imminence'
require 'gds_api/worldwide'
require 'gds_api/content_api'
require 'gds_api/rummager'
require 'gds_api/base'
require 'json'

module Services
  def self.publishing_api
    @publishing_api ||= GdsApi::PublishingApiV2.new(
        Plek.new.find('publishing-api'),
        bearer_token: ENV['PUBLISHING_API_BEARER_TOKEN'] || 'example'
    )
  end

  def self.imminence_api
    @imminence_api ||= GdsApi::Imminence.new(Plek.new.find('imminence'))
  end

  def self.worldwide_api
    @worldwide_api ||= GdsApi::Worldwide.new(Plek.new.find('whitehall-admin'))
  end

  def self.content_api
    @content_api ||= GdsApi::ContentApi.new(Plek.new.find("contentapi"))
  end

  def self.rummager
    @rummager ||= GdsApi::Rummager.new(Plek.find("search"))
  end


  def self.open_register_api
    @somink ||= OpenRegister.new("https://country.register.gov.uk")
  end

  class OpenRegister < GdsApi::Base

    def countries
      file_data = YAML.load_file(Rails.root.join('lib', 'data', 'country_register_records.yml'))

      file_data.map{ |l|
          vals = l[1]
          next if vals.has_key? 'end-date'
      
          temp = {
            title: vals['name'],
            details: {
              slug: vals['name'].downcase.parameterize,
              iso2: vals['country'],
            },
            organisations: {},
            code: vals['country']
          }
          WorldLocation.new(build_ostruct_recursively(temp))
        }.compact
      # url = url_for_slug("records", "page-index": 1, "page-size": 1000)
      # result = get_json!(url) do |r|

      #   country_list = JSON.parse(r).map{ |country|
      #     country_data = country[1]
      #     next if country_data.has_key? 'end-date'
      #     {
      #         title: country_data['name'],
      #         details: {
      #             slug: country_data['name'].downcase.parameterize,
      #             iso2: country_data['country'],
      #         },
      #         organisations: {},
      #         code: country_data['country']
      #     }
      #   }.compact

      #   country_list_response_body = JSON.generate(results: country_list)

      #   new_response = Net::HTTPResponse.new(1.0, r.code, "Ok")
      #   new_response.body=(country_list_response_body)

      #   GdsApi::ListResponse.new(new_response, self)
      # end


      # somink = get_list!(url)
      # somink2 = get_list!("https://www.gov.uk/api/world-locations")
      # somink.map{ |country|
      #   country
      # }

      # result
    end

    def country(location_slug)
      # get_json "#{base_url}/world-locations/#{location_slug}"
      countries.detect { |l| l.slug == location_slug }
    end


    private
    def base_url
      "#{endpoint}"
    end

    def build_ostruct_recursively(value)
      case value
        when Hash
          OpenStruct.new(Hash[value.map { |k, v| [k, build_ostruct_recursively(v)] }])
        when Array
          value.map { |v| build_ostruct_recursively(v) }
        else
          value
      end
    end
  end


end
