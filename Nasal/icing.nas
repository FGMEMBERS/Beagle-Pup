################################################################################
#
# Beagle Pup Icing
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

var carb_temp = "engines/engine/carb-temp-degf";
var timer = nil;

var init = func
{
    var oat = getprop("environment/temperature-degf");
    props.globals.initNode("engines/engine/carb-temp-degf", oat, "DOUBLE");
}

var simulate_carb_temp = func
{
    var temperature = getprop("environment/temperature-degf");
    var humidity = getprop("environment/relative-humidity");
    var pressure = getprop("environment/pressure-inhg");

    var manifold_pressure = getprop("engines/engine/mp-inhg");
    var cylinder_temp = getprop("engines/engine/cht-degf");

    var max_temp_drop = (pressure - manifold_pressure) * 70 / 30;
    var target_temp = temperature + (cylinder_temp / 30) - max_temp_drop;

    setprop("engines/engine/carb-temp-target-degf", target_temp);

    var ct = getprop(carb_temp);
    ct -= (ct - target_temp) / 300; 
    setprop(carb_temp, ct);
}

setlistener("engines/engine/running", func(v) {
    if (v.getValue()) {
      init();
      timer = maketimer(1.0, simulate_carb_temp);
      timer.start();
    } else {
      timer.stop();
    }
}, 0, 0);

print("Icing simulation loaded");

