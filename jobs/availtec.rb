require 'net/http'
require 'uri'
require 'json'

AGENCY_URL="https://realtimebjcta.availtec.com/InfoPoint"
STOP_IDS = [2492, 1464, 1430]
UPDATE_INTERVAL = '30s'

class AvailTec

  def initialize(options)
    @stop_ids = options[:stop_ids]

    @routes = Hash.new
    @stops = Hash.new
  end

  def update
    arrivals = Hash.new
    
    @stop_ids.each do |stop_id|
      arrivals[stop_id] = Hash.new

      # Get the upcoming departures for this stop
      uri = URI(AGENCY_URL + "/rest/StopDepartures/Get/" + stop_id.to_s)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(Net::HTTP::Get.new(uri.request_uri))
      r = JSON.parse(response.body)

      r.each do |stop|
        # get the stop info (if we don't have it cached)
        unless @stops.has_key?(stop_id)
          uri = URI(AGENCY_URL + "/rest/Stops/Get/" + stop_id.to_s)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          response = http.request(Net::HTTP::Get.new(uri.request_uri))
          stop_info = JSON.parse(response.body)
          @stops[stop_id] = stop_info
        end
        
        stop["RouteDirections"].each do |direction|
          route_id = direction["RouteId"]

          # get the vehicles on this route
          uri = URI(AGENCY_URL + "/rest/Vehicles/GetAllVehiclesForRoutes")
          uri.query = URI.encode_www_form({:routeIds => [route_id]})
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          response = http.request(Net::HTTP::Get.new(uri.request_uri))
          vehicles = JSON.parse(response.body)

          # get the route info (if we don't have it cached)
          unless @routes.has_key?(route_id)
            uri = URI(AGENCY_URL + "/rest/Routes/Get/" + route_id.to_s)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            response = http.request(Net::HTTP::Get.new(uri.request_uri))
            route = JSON.parse(response.body)
            @routes[route_id] = route
          end
                   
          direction["Departures"].each do |departure|
            unless arrivals[stop_id].has_key?(route_id)
              arrivals[stop_id][route_id] = Array.new
            end

            trip_id = departure["Trip"]["TripId"]
            run_id = departure["Trip"]["RunId"]
            block_farebox_id = departure["Trip"]["BlockFareboxId"]

            # find the vehicle (use the BlockFareboxId. I have no idea what this is,
            #  but it is the only thing that seems to match. The TripId and RunId are crazy
            #  inconsistent.
            # match_run_id = run_id - 10000
            # vehicle = vehicles.find {|v| v["TripId"] == trip_id && v["RunId"] == match_run_id }
            vehicle = vehicles.find {|v| v["BlockFareboxId"] == block_farebox_id }
            
            edt = parse_json_datetime(departure["EDT"])
            sdt = parse_json_datetime(departure["SDT"])
            now = Time.now

            obj = {
              "trip_id" => trip_id,
              "run_id" => run_id,
              "edt" => ((edt - now) / 60).to_i,
              "sdt" => ((sdt - now) / 60).to_i,
              "stop" => {
                "name" => @stops[stop_id]["Name"],
                "latitude" => @stops[stop_id]["Latitude"],
                "longitude" => @stops[stop_id]["Longitude"]
              },
              "color" => "#" + @routes[route_id]["Color"],
              "kmlUrl" => AGENCY_URL + "/Resources/Traces/" + @routes[route_id]["RouteTraceFilename"],
              "vehicle" => nil
            }
            if vehicle
              obj["vehicle"] = {
                "latitude" => vehicle["Latitude"],
                "longitude" => vehicle["Longitude"],
                "iconUrl" => build_icon_url(@routes[route_id]["Color"], vehicle["Heading"])
              }
            end
            
            arrivals[stop_id][route_id] << obj
          end
        end
      end
    rescue StandardError => e
      puts response.body
      puts e.inspect
      puts "\e[33mUnable to retrieve availtec data\e[0m"
    end

    arrivals
  end

  def build_icon_url(color, heading)
    AGENCY_URL + "/IconFactory.ashx?library=busIcons%5Cmobile&colortype=hex&color=" + color + "&bearing=" + heading.to_s
  end
  
  def parse_json_datetime(datetime)
    #
    # from: https://stackoverflow.com/a/34059193/4122137
    #
    
    # "/Date(-62135575200000-0600)/" seems to be the default date returned
    # if the value is null:
    if datetime == "/Date(-62135575200000-0600)/"
      # Return nil because it is probably a null date that is defaulting to 0.
      # To be more technically correct you could just return 0 here if you wanted:
      return nil
    elsif datetime =~ %r{/Date\(([-+]?\d+)([-+]\d+)?\)/}
      # We've now parsed the string into:
      # - $1: Number of milliseconds since the 1/1/1970 epoch.
      # - $2: [Optional] timezone offset.
      # Divide $1 by 1000 because it is in milliseconds and Time uses seconds:
      seconds_since_epoch = $1.to_i / 1000.0
      time = Time.at(seconds_since_epoch.to_i).utc 
      # We now have the exact moment in history that this represents,
      # stored as a UTC-based "Time" object.
      
      if $2
        # We have a timezone, so convert its format (adding a colon)...
        timezone = $2.gsub(/(...)(..)/, '\1:\2')
        # ...then apply it to the Time object:
        time = time.getlocal(timezone)
      end
      time
    else
      raise "Unrecognized date format."
    end
  end
  
end

@Arriver = AvailTec.new({stop_ids: STOP_IDS})

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
SCHEDULER.every UPDATE_INTERVAL, :first_in => 0 do |job|
  arrivals = @Arriver.update
  send_event('availtec', arrivals)
end
