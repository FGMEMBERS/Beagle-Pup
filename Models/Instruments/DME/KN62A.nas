################################################################################
#
# KN62A DME Support
#
# Usage:
#     KN62A.new(index: 0, rmtIndex: 0);
#
# For multiple DME receivers, vary the 'index' argument. To connect to 
# different NAV radios for DME remote operation, vary the rmtIndex argument.
#
# The default is to use a zero index, so KN62A.new() creates a single DME
# receiver with NAV[0] as the remote.
#
# ------------------------------------------------------------------------------
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
################################################################################

# Helper functions

# Clamp a value between a minimum and maximum.
#   n -- the number to clamp
#   min -- the minimum return value
#   max -- the maximum return value
#
var clamp = func(n, min, max) {
    if (n == nil) n = 0;
    if (n < min) return min;
    if (n > max) return max;
    return n;
};

# Enumerations

var DMEMode = {remote: 0, frequency: 1, hold: 2};
var DisplayMode = {frequency: 0, speedAndTime: 1};
var SourceType = {remote: 0, internal: 1};

var KN62A = {

    # Constructor
    #
    new: func(index = 0, rmtIndex = 0) {
        var m = {parents: [KN62A], index: index, rmtIndex: rmtIndex};

        var instrumentationN = props.globals.getNode('instrumentation');
        m.rootN = instrumentationN.getChild('dme', index);

        m.modeBtnN = m.rootN.getChild('mode-btn');

        var freqN = m.rootN.getChild('frequencies');
        m.internalFreqN = freqN.initNode('internal-mhz', 0.0); 

        # Remote frequency comes from one of the NAV radios
        var rmtN = instrumentationN.getChild('nav', rmtIndex);
        m.rmtFreqN = rmtN.getChild('frequencies').getChild('selected-mhz');
    
        m.leftDisplayN = m.rootN.initNode('left-display', 0, 'INT');
        m.leftDotN = m.rootN.initNode('left-dot', 0, 'BOOL');
        m.centerDisplayN = m.rootN.initNode('center-display', 0, 'INT');
        m.centerDotN = m.rootN.initNode('center-dot', 0, 'BOOL');
        m.rightDisplayN = m.rootN.initNode('right-display', 0, 'INT');

        m.ktsAnnunciatorN = m.rootN.initNode('kts-annunciator', 1, 'BOOL');
        m.mhzAnnunciatorN = m.rootN.initNode('mhz-annunciator', 0, 'BOOL');
        m.minAnnunciatorN = m.rootN.initNode('min-annunciator', 1, 'BOOL');
        m.rmtAnnunciatorN = m.rootN.initNode('rmt-annunciator', 1, 'BOOL');
        
        # Initialize the internal frequency to the remote NAV frequency. It's an
        # arbitrary value but this makes the most sense of any value.
        m.internalFreqN.setValue(m.rmtFreqN.getValue());

        setlistener(
            node: m.modeBtnN.getPath(), 
            fn: func { m.modeListenerFunc() },
            init: 1, 
            runtime: 0
        );

        # Use a listener for updating the internal frequency display so we
        # get real time updates rather than the delay of the update timer.
        setlistener(
            node: m.internalFreqN.getPath(), 
            fn: func { m.internalFreqListenerFunc() },
            runtime: 0
        );

        m.update();
        print('KN62A DME #', index, ' loaded'); 
        return m;
    },

    # Update the DME display. The internal frequency is updated in real
    # time using a listener. Everything else is done with this timer loop.
    update: func {
        if (me.getDisplayMode() == DisplayMode.speedAndTime) {
            me.centerDisplayN.setIntValue(me.getGroundSpeed());
            me.centerDotN.setBoolValue(0);
            me.rightDisplayN.setIntValue(me.getTimeToStation());
        }

        var d = me.getDistanceFromStation();
        var showsDecimalPoint = d < 100; 
        me.leftDotN.setBoolValue(showsDecimalPoint);
        me.leftDisplayN.setIntValue(showsDecimalPoint ? d * 10 : d);

        # Slower aircraft don't need frequent updates to DME, 0.5s is fine.
        settimer(func { me.update() }, 0.5);
    },

    # Accessors

    getDistanceFromStation: func {
        var indicatedDistanceN = me.rootN.getChild('indicated-distance-nm');
        return clamp(indicatedDistanceN.getValue(), 0, 999);
    },

    getGroundSpeed: func {
        var groundSpeedN = me.rootN.getChild('indicated-ground-speed-kt');
        return int(clamp(groundSpeedN.getValue(), 0, 999));
    },

    getTimeToStation: func {
        var indicatedTimeN = me.rootN.getChild('indicated-time-min');
        return int(clamp(indicatedTimeN.getValue(), 0, 99));
    },

    getDisplayMode: func {
        var frequency = me.getDMEMode() == DMEMode.frequency;
        return frequency ? DisplayMode.frequency : DisplayMode.speedAndTime;
    },

    getDMEMode: func {
        return me.modeBtnN.getValue();
    },

    setKtsAnnunciator: func(on) {
        me.ktsAnnunciatorN.setBoolValue(on);
    },

    setMhzAnnunciator: func(on) {
        me.mhzAnnunciatorN.setBoolValue(on);
    },

    setMinAnnunciator: func(on) {
        me.minAnnunciatorN.setBoolValue(on);
    },

    setRmtAnnunciator: func(on) {
        me.rmtAnnunciatorN.setBoolValue(on);
    },

    setSource: func(sourceType) {
        var sourceN = me.rootN.getChild('frequencies').getChild('source');
        if (sourceType == SourceType.remote)
            sourceN.setValue(me.rmtFreqN.getPath());
        else
            sourceN.setValue(me.internalFreqN.getPath());
    },

    # Listeners

    # Listen for changes in the internal frequency and update the display.
    #
    internalFreqListenerFunc: func {
        var f = me.internalFreqN.getValue();
        me.centerDisplayN.setIntValue(int(f));
        me.centerDotN.setBoolValue(1);
        me.rightDisplayN.setIntValue(100 * (0.0001 + f - int(f)));
    },

    # Listen for changes in the mode switch and update the display. Setting
    # the source to the internal or remote property triggers the underlying
    # C++ code to update the DME from the correct source.
    #
    modeListenerFunc: func {
        var remote = me.getDMEMode() == DMEMode.remote;
        me.setSource(remote ? SourceType.remote : SourceType.internal);

        me.setKtsAnnunciator(me.getDMEMode() != DMEMode.frequency);
        me.setMhzAnnunciator(me.getDMEMode() == DMEMode.frequency);
        me.setMinAnnunciator(me.getDMEMode() != DMEMode.frequency);
        me.setRmtAnnunciator(me.getDMEMode() == DMEMode.remote);
        
        # Ensure display is updated when switching to frequency mode.
        if (me.getDMEMode() == DMEMode.frequency)
            me.internalFreqListenerFunc();
    },
};
