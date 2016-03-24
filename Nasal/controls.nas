################################################################################
#
# Beagle Pup Controls
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

var Magnetos = {OFF: 0, LEFT: 1, RIGHT: 2, BOTH: 3};

var defaultStartEngine = controls.startEngine;

controls.startEngine = func(v = 1, which...)
{
    if (getprop("systems/electrical/outputs/starter") > 0.0)
        defaultStartEngine(v, size(which) ? which : 0);
}

var defaultFlapsDown = controls.flapsDown;

controls.flapsDown = func(step)
{
    if (getprop("systems/electrical/outputs/flaps") > 0.0)
        defaultFlapsDown(step);
}

var defaultStepMagnetos = controls.stepMagnetos;

controls.stepMagnetos = func(change)
{
    var m = getprop("controls/engines/engine/magnetos");
    if (m + change <= 3 and m + change >= 0)
        multi_click(abs(change));
    defaultStepMagnetos(change);
}

var select_magnetos = func(n)
{
    var m = getprop("controls/engines/engine/magnetos");
    var steps = abs(n - m);
    multi_click(steps);
    setprop("controls/engines/engine/magnetos", n);
}

setlistener("sim/signals/fdm-initialized", func(v) {
    # Sometimes the parking brake causes jumping when JSBSim initializes,
    # so parking brake is off at start and only set when JSBSim is ready
    if (v.getValue())
        setprop("controls/brake/parking", 1.0);
}, 0, 0);

print("Controls overrides loaded");
