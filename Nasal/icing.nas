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

var carb_temp = "engines/engine/carb-temp-degc";
var timer = nil;

var init = func
{
    var oat = getprop("environment/temperature-degc");
    props.globals.initNode(carb_temp, oat, "DOUBLE");
}

var simulate_carb_temp = func
{
    var oat = getprop("environment/temperature-degc");
    var target_temp = oat;

    if (getprop("engines/engine/running")) {
        var pressure = getprop("environment/pressure-inhg");
        var manifold_pressure = getprop("engines/engine/mp-inhg");
        var max_temp_drop = (pressure - manifold_pressure) * 21 / (30 - 12);
        var engine_temp = getprop("engines/engine/cht-degc");
        var compartment_heat = engine_temp / 20;
        target_temp = oat + compartment_heat - max_temp_drop;
    } else {
        # Follow the temperature directly, rather than simulating any
        # thermal mass. User could be changing weather scenarios,
        # or weather might not be loaded.
        setprop(carb_temp, oat);
        return;
    }

    var ct = getprop(carb_temp);
    ct -= (ct - target_temp) / 120;
    setprop(carb_temp, ct);
}

setlistener("sim/signals/fdm-initialized", func(v) {
    if (v.getBoolValue()) {
      init();
      timer = maketimer(1.0, simulate_carb_temp);
      timer.start();
    }
}, 0, 0);

print("Icing simulation loaded");

