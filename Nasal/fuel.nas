################################################################################
#
# Beagle Pup Fuel System Helpers
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

var _lock = 0;

var Tank = {OFF: 0, LEFT: 1, BOTH: 2, RIGHT: 3};

# Lock changes through listeners. If a function is wrapped in this lock
# function, listeners will not fire and cause an endless loop.
#
var lock = func(f)
{
    if (_lock) return;
    _lock = 1;
    call(f);
    _lock = 0;
}

################################################################################
# Helpers
################################################################################

var select_fuel_tank = func(n)
{
    var s = getprop("controls/fuel/tank-selector");
    var steps = abs(n - s);
    multi_click(steps == 3 ? 1 : steps);
    setprop("controls/fuel/tank-selector", n);
}

# Infer the position of the fuel tank selector from the checkboxes in the 
# fuel and payload dialog
#
var infer_fuel_tank_selector = func
{
    var l = getprop("consumables/fuel/tank[1]/selected");
    var r = getprop("consumables/fuel/tank[2]/selected");

    if (!l and !r)
        select_fuel_tank(Tank.OFF);
    elsif (l and !r)
        select_fuel_tank(Tank.LEFT);
    elsif (!l and r)
        select_fuel_tank(Tank.RIGHT);
    else
        select_fuel_tank(Tank.BOTH);
}

################################################################################
# Listeners
################################################################################

var start_listeners = func()
{
    # Update the fuel and payload dialog from the fuel selection
    #
    setlistener("controls/fuel/tank-selector", func(node) {
        lock(func {
            var selection = node != nil and node.getValue();
            var l = selection == Tank.LEFT or selection == Tank.BOTH;
            var r = selection == Tank.RIGHT or selection == Tank.BOTH;
            setprop("consumables/fuel/tank[1]/selected", l);
            setprop("consumables/fuel/tank[2]/selected", r);
        });
    }, startup = 1, runtime = 0);

    # Update the fuel selection from the fuel and payload dialog (left tank)
    #
    setlistener("consumables/fuel/tank[1]/selected", func(node) {
        lock(func {
            infer_fuel_tank_selector();
        });
    }, startup = 1, runtime = 0);

    # Update the fuel selection from the fuel and payload dialog (right tank)
    #
    setlistener("consumables/fuel/tank[2]/selected", func(node) {
        lock(func {
            infer_fuel_tank_selector();
        });
    }, startup = 1, runtime = 0);
}

setlistener("sim/signals/fdm-initialized", start_listeners, 0, 0);

print("Fuel system loaded");
