################################################################################
#
# Beagle Pup Controls Overrides
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

print("Controls overrides loaded");
