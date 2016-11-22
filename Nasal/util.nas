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

# A rather elaborate sound click function with the ability to call a callback
# function after the sound as played and after a further delay. This allows
# for single or multiple clicks, e.g.
#
# click(); # Single click
# click(func{click();}, 0.5); # Two clicks, separated by approx 0.5s
#
var click = func(callback = nil, delay = 0)
{
    var duration = 0.1;

    setprop("sim/sound/click", 1);
    var t = maketimer(duration, func {
        setprop("sim/sound/click", 0);
        if (callback != nil) {
            var u = maketimer(delay < duration ? duration : delay, func {
                call(callback);
            });
            u.singleShot = 1;
            u.start();
        }
    });
    t.singleShot = 1;
    t.start();
}

# Convenience function for up to three clicks with delay, e.g. fuel, mags
#
var multi_click = func(count, delay = 0)
{
    if (count == 1)
        click();
    elsif (count == 2)
        click(func{click();}, delay);
    elsif (count == 3)
        click(func{click(func{click();}, delay)}, delay);
}

################################################################################
# Beacon
################################################################################

var beacon = maketimer(1, func {
    setprop("controls/lighting/beacon-state", 1);
    var flash = maketimer(0.2, func {
        setprop("controls/lighting/beacon-state", 0);
    });
    flash.singleShot = 1;
    flash.start();
});

# Beacon listener
#
# Assumes electrical system only propagates stable values, otherwise this
# listener will fire too often.
#
setlistener("systems/electrical/outputs/beacon", func (volts) {
    if (volts.getValue() == 0) {
        beacon.stop();
    } else if (!beacon.isRunning) {
        beacon.start();
        setprop("sim/checklists/status/beacon", 1);
    }
}, 0, 0);

################################################################################
# Navigation Lights
################################################################################

setlistener("systems/electrical/outputs/nav-lights", func (volts) {
    if (volts.getValue() > 0) {
        setprop("sim/checklists/status/nav-lights", 1);
    }
}, 0, 0);

################################################################################
# Gyro
################################################################################

var spindown_gyro = func(time = 10)
{
    if (getprop("sim/model/preferences/realism/gyro-spindown")) {
        var spin = rand() * 360;
        interpolate("instrumentation/heading-indicator/offset-deg", spin, time);
    }
}

setlistener("sim/signals/fdm-initialized", func(node) {
    if (node.getBoolValue())
        spindown_gyro(0);
}, 0, 0);

setlistener("systems/vacuum/vacuum-norm", func(node) {
    if (!node.getBoolValue())
        spindown_gyro();
}, 0, 0);

print ("Utility functions loaded");
