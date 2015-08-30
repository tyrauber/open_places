module OpenPlaces
  class AutocompleteController < ApplicationController

    def index
 
      query_string = (params[:q] || params[:like] || params[:contains] || params[:starts] || params[:ends] || nil)
      raise "A query param (q, like, contains, starts or ends) or location (near, e.g. 42.0-120.0) is requered" unless query_string.present?

      op = (params.keys & ['q', 'like', 'contains', 'starts', 'ends']).flatten.shift
      @results = OpenPlaces::Geo
      @results = @results.where(geotype: params[:type].split(",").map{|t| "OpenPlaces::#{t}" }) if params[:type].present?
      @results = @results.order('scalerank ASC')
      @results = @results.autocomplete(query_string, op) if query_string.present?
      @results = @results.near(params[:near]) if params[:near].present?
      @results = @results.limit(params[:limit])
      
      respond_to do |format|
        format.json do
          render json: @results.to_json(except: OpenPlaces::Geo.GEO_FIELDS), root: false, status: 200, :callback => params['callback']
        end
        format.geojson do
          render text: @results.to_geojson('latlng').first["geojson"], status: 200, :callback => params['callback']
        end
      end
    rescue ActionController::UnknownFormat => e
     render json: @results.to_json(except: 'geom'), root: false, status: 200, :callback => params['callback']
    rescue => e
     render json: { error: e.message }, status: 400, :callback => params['callback']
    end
    
    def show
      @results = OpenPlaces::Geo.where("id = ?", params[:id])
      @results = @results.merge(@results.first.provinces)
      respond_to do |format|
        format.json do
          render json: @results.to_json(only: params[:fields].split(",")), root: false, status: 200, :callback => params['callback']
        end
        format.geojson do
          render text: @results.to_geojson('latlng').first["geojson"], status: 200, :callback => params['callback']
        end
      end

    rescue => e
      render json: { error: e.message }, status: 400, :callback => params['callback']
    end
  end
end
