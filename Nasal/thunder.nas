################################################################################
#
# Thunder
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

var C = 340; # Approximate speed of sound
var durations = [11, 10, 20, 14]; # Length of sound clips, in seconds
var distances = [2000, 6000, 10000, 20000]; # Max distance for each clip

# Build property tree structure to manage thunder events
#
var sound = props.globals.getNode("sim/sound");
for (var i = 0; i < size(durations); i += 1) {
    var thunder = sound.getChild("thunder", i, 1);
    thunder.initNode("active", 0, "BOOL", 1);
    thunder.initNode("distance-m", 0.0, "DOUBLE", 1);
    thunder.initNode("pending", 0, "BOOL", 1);
    thunder.initNode("volume", 0.0, "DOUBLE", 1);
}

# Determine the index of sound samples to use based on distance
# Returns -1 if the distance is beyond the range of the last element.
#
var index = func(distance)
{
    for (var i = 0; i < size(distances); i += 1)
        if (distance < distances[i])
            return i;
    return -1;
}

# Get the distance of a lightning event, in metres
#
var lightning_distance = func()
{
    var x = getprop("environment/lightning/lightning-pos-x");
    var y = getprop("environment/lightning/lightning-pos-y");
    return math.sqrt(x * x + y * y);
}

# Calculate a volume for the sample. Full volume up to half the limit
# of audibility, then falls off linearly to zero.
#
var volume = func(distance)
{
    var limit = distances[size(distances) - 1];
    var volume = (limit - distance) / limit + 0.5;
    return volume <= 1.0 ? volume : 1.0;
}

# Listener for the lightning event. Creates thunder after a delay.
#
setlistener("environment/lightning/lightning-pos-x", func(node) {

    var d = lightning_distance();
    var i = index(d);
    if (i < 0) return;

    var thunder = sound.getChild("thunder", i);
    if (thunder.getChild("pending").getBoolValue()) return;

    thunder.getChild("pending").setBoolValue(1);
    thunder.getChild("distance-m").setValue(d);
    thunder.getChild("volume").setValue(volume(d));

    var t = maketimer(d / C, func {
        thunder.getChild("active").setBoolValue(1);
        var u = maketimer(durations[i], func {
            thunder.getChild("active").setBoolValue(0);
            thunder.getChild("pending").setBoolValue(0);
        });
        u.singleShot = 1;
        u.start();
    });
    t.singleShot = 1;
    t.start();
}, 0, 0);

