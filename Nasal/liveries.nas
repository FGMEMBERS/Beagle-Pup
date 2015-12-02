################################################################################
#
# Beagle Pup Liveries
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

var variant = getprop("sim/aero");

aircraft.livery.init("Models/Liveries/"~variant);

# This is not the usual way to set the initial livery before a selection is
# made but it allows the material animation for the livery to go into the
# pup-common.xml, which means other material animations in pup-common.xml
# can be arranged to come after the livery initialization.
#
setlistener("sim/signals/fdm-initialized", func(v) {
    var texture = "sim/model/livery/texture";
    if (v.getBoolValue() and !getprop(texture))
        if (variant == "pup100")
            setprop(texture, "Liveries/pup100/G-AXDV.png");
        elsif (variant == "pup150")
            setprop(texture, "Liveries/pup150/G-AVLN.png");
        elsif (variant == "pup160")
            setprop(texture, "Liveries/pup160/VH-EPI.png");
}, 0, 0);
