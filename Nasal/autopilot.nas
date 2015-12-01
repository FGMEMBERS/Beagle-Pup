###############################################################################
#
# Nonspecific Autopilot Functions
#
# Copyright (c) 2014, Richard Senior
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
###############################################################################

# Capture the current altitude when locking altitude or glideslope
#
var autopilot_locks_altitude_listener = func()
{
    var locks_altitude = getprop("autopilot/locks/altitude");

    if (locks_altitude != nil and (locks_altitude == "altitude-hold" or locks_altitude == "gs1-hold")) {
        var current_altitude = getprop("instrumentation/altimeter/indicated-altitude-ft");
        setprop("autopilot/settings/target-altitude-ft", current_altitude);        
    }
}

setlistener("autopilot/locks/altitude", autopilot_locks_altitude_listener);

print("Autopilot loaded");
