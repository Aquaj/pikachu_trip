require 'json'

class Trip
  attr_reader :label, :source, :destination, :cost, :duration

  def initialize(label, source, destination, cost, duration)
    @label = label
    @source = Place[source]
    @destination = Place[destination]
    @cost = cost
    @duration = duration

    Trip.place_route self

    source.register self
    destination.register self
  end

  def ends
    Set.new([source, destination])
  end

  def other_end_of(place)
    destination = ends.dup
    destination.delete(Place[place])
    destination.first
  end

  def inspect
    %(Trip<"#{label}" — #{cost.to_i}>)
  end

  class << self
    attr_accessor :routes

    def place_route(trip)
      @routes ||= {}
      @routes[trip.ends] ||= []
      @routes[trip.ends] << trip
    end

    def [](place, other)
      @routes ||= {}
      place = Place[place]
      other = Place[other]
      pair = Set.new([place, other])
      @routes[pair]
    end
  end
end

class Place
  attr_reader :label, :trips

  def initialize(label)
    @label = label
    @trips = []

    Place.place_on_map self
  end

  def register(trip)
    @trips << trip
  end

  def neighbours
    Place.all.select { |p| Trip[self, p] && Trip[self, p].any? }
  end

  def routes
    neighbours.flat_map { |n| Trip[self, n] }
  end

  def travel_cost_to(place)
    trip = Trip[self, place]
    trip && trip.cost
  end

  def travel_time_to(place)
    trip = Trip[self, place]
    trip && trip.duration
  end

  def inspect
    %(Place<"#{label}">)
  end

  class << self
    attr_accessor :map

    def all
      self.map ||= {}
      self.map.values
    end

    def place_on_map(place)
      self.map ||= {}
      self.map[place.label] = place
    end

    def [](label_or_place)
      return label_or_place if label_or_place.is_a? Place
      self.map ||= {}
      self.map[label_or_place] || new(label_or_place)
    end
  end
end

class Travel
  attr_reader :path, :route

  def initialize(source, trips)
    @route = trips
    @path = route.reduce([source]) { |path, route| path << route.other_end_of(path.last) }
  end

  def cost
    @route.map(&:cost).reduce(&:+)
  end

  def duration
    @route.map(&:duration).reduce(&:+)
  end

  def destination
    @path.last
  end

  def inspect
    %(Travel<"#{source} – #{destination}" | #{cost} | #{duration}>)
  end
end

class PikachuTrip
  attr_reader :source, :budget

  def initialize(source, budget)
    @source = Place[source]
    @budget = budget
  end

  def route_to(label_or_place)
    place = Place[label_or_place]
    # min_cost_routes[place]
    # travel = min_time_routes[place]
    routes = routes_to(place)
    routes.select { |travel| travel.cost <= @budget }.min_by(&:duration)
  end

  def routes_to(label_or_place)
    paths = []
    paths_to(label_or_place, paths: paths)
    paths.map { |path| Travel.new(@source, path.compact) }
  end

  private
    def paths_to(label_or_place, current: @source, visited: {}, from: nil,path: [], paths: [])
      path << from
      visited[from] = true
      if current == Place[label_or_place] && path.size > 1
        paths << path.dup
      else
        current.routes.reject { |r| visited[r] }.each do |route|
          neighbour = route.other_end_of(current)
          paths_to(label_or_place, current: neighbour, from: route, visited: visited, path: path, paths: paths)
        end
      end

      path.pop
      visited[from] = false
    end
end

data = JSON.parse(File.read('data.json'))

data.map do |(label, path, price, duration)|
  source, destination = *path.split(" → ")
  source = Place[source]
  destination = Place[destination]
  price = price.gsub(/\s?P\$/, '').to_f
  hours, minutes = duration.split('h').map(&:to_i)
  duration = hours + (minutes / 60.0)
  Trip.new(label, source, destination, price, duration)
end

@trip = PikachuTrip.new("Club Hano-Hano", 6000)
travel = @trip.route_to "Bourg-Palette"
travel.duration
