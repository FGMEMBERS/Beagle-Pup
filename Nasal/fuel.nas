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

var tank_selector = "controls/fuel/tank-selector";
var feed = {OFF: 0, LEFT: 1, BOTH: 2, RIGHT: 3};

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

# Infer the position of the fuel tank selector from the checkboxes in the 
# fuel and payload dialog
#
var infer_fuel_tank_selector = func
{
    var l = getprop("consumables/fuel/tank[1]/selected");
    var r = getprop("consumables/fuel/tank[2]/selected");

    if (!l and !r)
        setprop(tank_selector, feed.OFF);
    elsif (l and !r)
        setprop(tank_selector, feed.LEFT);
    elsif (!l and r)
        setprop(tank_selector, feed.RIGHT);
    else
        setprop(tank_selector, feed.BOTH);
}

################################################################################
# Listeners
################################################################################

# Update the fuel and payload dialog from the fuel selection
#
setlistener(tank_selector, func(node) {
    lock(func {
        var selection = node != nil and node.getValue();
        var l = selection == feed.LEFT or selection == feed.BOTH;
        var r = selection == feed.RIGHT or selection == feed.BOTH;
        setprop("consumables/fuel/tank[0]/selected", 1);
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

print("Fuel system loaded");
