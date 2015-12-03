################################################################################
#
# Beagle Pup Utility Functions
#
# Copyright (c) 2015 Richard Senior
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
################################################################################

# Get the current position of the aircraft as a geo.Coord object
#
var current_position = func()
{
    var lat = getprop("position/latitude-deg");
    var lon = getprop("position/longitude-deg");
    return geo.Coord.new().set_latlon(lat, lon);
}

# Get the distance to the nearest runway in metres
#
var distance_to_nearest_runway = func(from)
{
    var airport = airportinfo();
    var distance = 99999;

    foreach (var runway; values(airport.runways)) {
        var r = geo.Coord.new().set_latlon(runway.lat, runway.lon);
        var d = from.distance_to(r);
        if (d < distance) distance = d;
    }
    return distance;
}

# Check if the aircraft is near a runway threshold
#
var is_near_runway = func()
{
    return distance_to_nearest_runway(from:current_position()) < 50.0;
}

print ("Utility functions loaded");
