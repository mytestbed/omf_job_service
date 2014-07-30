#!/usr/bin/env ruby

# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

# This is a testing OML-instrumented application which will generate WGS84
# coordinates based on a Random Walk. Default starting location is Centenial Park,
# Sydney, Australia.
#
# Example:
#
# Generate a random walk that starts in Paris, with speed of 30 m/s, and a 
# duration 120 s. Also generate a Google Earth KML file in the current directory
# which draws this walk.
#
# random_walk.rb -k -s 30 -d 120 -L 2.352222 -l 48.856614 
#
# Usage: random_walk [options]
# -d, --duration TIME              Random walk duration in second (default 30s)
# -i, --interval TIME              Update interval in second (default 1s)
# -s, --speed TIME                 Walk speed in m/s (default 3 m/s)
# -L, --longitude LONG             Start longitude based on WGS84 datum (default: 151.234907)
# -l, --latitude LAT               Start latitude based on WGS84 datum (default: -33.897154)
# -r, --radius DISTANCE            Walk boundaries in m from its starting point (default 10000 m)
# -k, --generate-kml               Generate a KML file (default: FALSE)
#     --oml-id id                  Name to identify this app instance [undefined]
#     --oml-domain domain          Name of experimental domain [foo] *EXPERIMENTAL*
#     --oml-collect uri            URI of server to send measurements to
#     --oml-protocol p             Protocol number [4]
#     --oml-log-level l            Log level used (info: 0 .. debug: 1)
#     --oml-noop                   Do not collect measurements
#     --oml-config file            File holding OML configuration parameters
#     --oml-exp-id domain          Obsolescent equivalent to --oml-domain domain
#     --oml-file localPath         Obsolescent equivalent to --oml-collect file:localPath
#     --oml-server uri             Obsolescent equivalent to --oml-collect uri
#     --oml-help                   Show this message

require 'oml4r'
#puts OML4R::VERSION

APPNAME = 'randomwalk'
# Mostly accurate when not at the poles
# GIS people will say this is false, but it is good enough for our testing
# purpose here.
ONE_DEGREE_IN_METER = 111133 # = 10001966 m / 90 degree (http://home.online.no/~sigurdhu/WGS84_Eng.html)
ONE_METER_IN_DEGREE = 0.00000898231 # = 90 degree / 10001966 m

# Define your own Measurement Points
class PositionMP < OML4R::MPBase
  name :position
  param :longitude, :type => :double
  param :latitude, :type => :double
  param :drift, :type => :double
end

# From a Google example of KML files for drawing paths...
def start_kml
  @kml = File.open("#{APPNAME}.#{Time.now.to_i}.kml",'w')
  @kml << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
  @kml << "<kml xmlns=\"http://www.opengis.net/kml/2.2\">\n"
  @kml << "  <Document>\n"
  @kml << "    <name>Paths</name>\n"
  @kml << "    <description>Testing Random Walk</description>\n"
  @kml << "    <Style id=\"yellowLineGreenPoly\">\n"
  @kml << "      <LineStyle>\n"
  @kml << "        <color>7f00ffff</color>\n"
  @kml << "        <width>4</width>\n"
  @kml << "      </LineStyle>\n"
  @kml << "      <PolyStyle>\n"
  @kml << "        <color>7f00ff00</color>\n"
  @kml << "      </PolyStyle>\n"
  @kml << "    </Style>\n"
  @kml << "    <Placemark>\n"
  @kml << "      <name>My Path</name>\n"
  @kml << "      <description>Test path</description>\n"
  @kml << "      <styleUrl>#yellowLineGreenPoly</styleUrl>\n"
  @kml << "      <LineString>\n"
  @kml << "        <extrude>0</extrude>\n"
  @kml << "        <tessellate>1</tessellate>\n"
  @kml << "        <altitudeMode>clampToGround</altitudeMode>\n"
  @kml << "        <coordinates>\n"
end
# From a Google example of KML files for drawing paths...
def stop_kml
  @kml << "          </coordinates>\n"
  @kml << "      </LineString>\n"
  @kml << "    </Placemark>\n"
  @kml << "  </Document>\n"
  @kml << "</kml>\n"
  @kml.close
end

# Initialise the OML4R module for your application
# 'collect' could also be tcp:host:port
opts = {:appName => APPNAME, :domain => 'foo', :collect => 'file:-'}

begin
  @duration = 30
  @interval = 1
  @speed = 3
  @olong = 151.234907 # Centenial Park, Sydney, Australia
  @olat = -33.897154  # Centenial Park, Sydney, Australia
  @radius = 10000
  @generate_kml = false
  @kml = nil
  OML4R::init(ARGV, opts) do |ap|
    ap.on("-d","--duration TIME","Random walk duration in second (default 30s)") { |t| @duration = t.to_i }
    ap.on("-i","--interval TIME","Update interval in second (default 1s)") { |t| @interval = t.to_i }
    ap.on("-s","--speed TIME","Walk speed in m/s (default 3 m/s)") { |t| @speed = t.to_i }
    ap.on("-L","--longitude LONG","Start longitude based on WGS84 datum (default: 151.234907)") { |l| @olong = l.to_f }
    ap.on("-l","--latitude LAT","Start latitude based on WGS84 datum (default: -33.897154)") { |l| @olat = l.to_f }
    ap.on("-r","--radius DISTANCE","Walk boundaries in m from its starting point (default 10000 m)") { |l| @radius = l.to_f }
    ap.on("-k","--generate-kml","Generate a KML file (default: FALSE)") { |l| @generate_kml = true }
  end
rescue OML4R::MissingArgumentException => mex
  $stderr.puts mex
  exit
end

# Record some metatada
PositionMP.inject_metadata('duration',@duration)
PositionMP.inject_metadata('interval',@interval)
PositionMP.inject_metadata('speed',@speed)
PositionMP.inject_metadata('origin_lat',@olat)
PositionMP.inject_metadata('origin_long',@olong)
PositionMP.inject_metadata('radius',@radius)
PositionMP.inject_metadata('datum','WGS84')

# Now generate and inject some measurements
# All computation below is using base SI units and WFS84 datum
long = @olong
lat = @olat
distance = @speed * @interval * ONE_METER_IN_DEGREE
start_kml if @generate_kml
(@duration/@interval).times do |i|
  drift = @radius + 1
  while drift > @radius 
    sleep(@interval)
    angle = rand() * 2 * Math::PI
    long = long + (distance * Math.cos(angle))
    lat = lat + (distance * Math.sin(angle))
    drift = Math.sqrt( (lat - @olat)**2 + (long - @olong)**2 ) * ONE_DEGREE_IN_METER
    PositionMP.inject(long,lat,drift) if drift <= @radius
    @kml << "#{long},#{lat},100\n" if drift <= @radius && @generate_kml
  end
end
stop_kml if @generate_kml
# Don't forget to close when you are finished
OML4R::close()



