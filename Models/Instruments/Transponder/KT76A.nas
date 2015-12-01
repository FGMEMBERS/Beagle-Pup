################################################################################
#
# KT76A Transponder Functions
#
# This script handles the lights on the transponder -- the power light and
# the "ping" light that indicates the device has been scanned by the air 
# traffic control radar beacon system (ATCRBS).
#
# Scanning is simulated by periodically finding airports within a suitable
# radar range, filtering those that have towers and creating a random 
# pattern of pings based on those towers. In an area with lots of airports
# and towers, the ping light flickers frequently. In a remote area, there
# are fewer pings.
#
# Usage:
#     KT76A.new(index: 0)
#
# For a single transponder, the argument can be omitted and defaults to zero.
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

var RadarSimulator = {

    # Constructor:
    # ATCRBS sweep times vary between 4.6s and 11s, so use an average of 8s 
    # for the default sweep time for this simulation.
    # 
    # delegate -- the object to be notified of a radar ping
    # sweepTime -- average time for a simulated radar sweep
    # pulseTime -- duration of pulse
    #
    new: func(delegate, sweepTime = 8.0, pulseTime = 0.1) {
        var m = { 
            parents: [RadarSimulator], 
            delegate: delegate,
            sweepTime: sweepTime, 
            pulseTime: pulseTime 
        };
        m.delegate = delegate;
        m.sweepTime = sweepTime;
        m.pulseTime = pulseTime;

        m.pingPattern = [];
        m.index = 0;
        m.active = 0;

        m._generatePingPattern();

        return m;
    },

    # Public Methods

    # Start the radar simulation. Does nothing if already started.
    #
    start: func {
        if (me.active) return;
        me.active = 1;
        me._refresh();
        me._sweep();
    },

    # Stop the radar simulation. Does nothing if already stopped.
    #
    stop: func {
        if (!me.active) return;
        me.active = 0;
    },

    # Private methods

    # Generate the ping pattern. This is simply a list of the ICAO codes of
    # airports within range that have towers. They are inserted into the 
    # list at random positions and some codes may be overwritten, but that is
    # consistent with two pings arriving simultaneously from two radars.
    #
    _generatePingPattern: func {
        var slots = [];
        var nslots = int(me.sweepTime / me.pulseTime);
        for (var i = 0; i < nslots; i += 1)
            append(slots, '');
        towers = me._nearbyTowers();
        foreach (tower; towers) {
            i = int(rand() * nslots);
            slots[i] = tower;
        }
        me.pingPattern = slots;
        # me._printPingPattern();
    },

    # Whether the aircraft is moving.
    #
    _moving: func {
        var ias = getprop(
            'instrumentation/airspeed-indicator/indicated-speed-kt' 
        );
        return ias > 30.0;
    },

    # Airport towers within a given range.
    # range -- the range to search for airport towers
    #
    _nearbyTowers: func(range = 60) {
        var towers = [];
        foreach (var airport; findAirportsWithinRange(range)) {
            if (size(airport.comms('tower')))
                append(towers, airport.id);
        }
        return towers;
    },

    # Get the next ping from the ping pattern.
    #
    _nextPing: func {
        if (size(me.pingPattern) == 0)
            me._generatePingPattern();
        var ping = me.pingPattern[me.index];
        me.index += 1;
        if (me.index == size(me.pingPattern))
            me.index = 0;
        return ping;
    },

    # Print the ICAO codes in the ping pattern. For debugging.
    #
    _printPingPattern: func {
        var s = '';
        foreach (tower; me.pingPattern)
            if (tower != '')
                s = s == '' ? s~tower : s~' '~tower;
        print('Radar pings: ', s);
    },

    # Regenerate the ping pattern, but only when moving.
    #
    _refresh: func {
        if (!me.active) return;
        if (me._moving())
            me._generatePingPattern();
        settimer(func { me._refresh() }, 120);
    },

    # Radar sweep. Iterates over the ping pattern and calls the delegate
    # with the contents of each slot. This will be the ICAO code of the 
    # airport or an empty string.
    #
    _sweep: func {
        if (!me.active) return;
        me.delegate.ping(me._nextPing());
        settimer(func { me._sweep() }, me.pulseTime);
    },
};

var TransponderMode = {
    off:     0,
    standby: 1,
    test:    2,
    on:      4,
    alt:     5,
};

var KT76A = {

    # Constructor:
    #
    new: func(index = 0) {
        var m = {parents: [KT76A], index: index};

        var instrumentationN = props.globals.getNode('instrumentation');
        m.rootN = instrumentationN.getChild('transponder', index, 1);

        m.inputsN = m.rootN.getChild('inputs', 0, 1);
        m.outputsN = m.rootN.getChild('outputs', 0, 1);
        m.radar = RadarSimulator.new(delegate: m);

        m.rootN.initNode('powered', 0, 'BOOL');
        m.outputsN.initNode('ident-light-on', 0, 'BOOL');
        m.outputsN.initNode('power-light-on', 0, 'BOOL');

        settimer(func { m.electricalPollFunc() }, 0.1);

        setlistener(
            node: m.rootN.getChild('ident').getPath(),
            fn: func { m.identListenerFunc() },
            runtime: 0
        );
        setlistener(
            node: m.rootN.getChild('powered').getPath(),
            fn: func { m.poweredListenerFunc() },
            runtime: 0
        );
        setlistener(
            node: m.inputsN.getChild('knob-mode').getPath(), 
            fn: func { m.transponderModeListenerFunc() },
            runtime: 0
        );

        print('KT76A Transponder #', index, ' loaded');
        return m;
    },

    # Accessors

    getMode: func {
        return me.inputsN.getChild('knob-mode').getValue();
    },

    getIdent: func {
        return me.rootN.getChild('ident').getValue();
    },

    getIdentLight: func {
        return me.outputsN.getChild('ident-light-on').getValue();
    },

    setIdentLight: func(on) {
        me.outputsN.getChild('ident-light-on').setValue(on);
    },

    getPowerLight: func {
        return me.outputsN.getChild('power-light-on').getValue();
    },

    setPowerLight: func(on) {
        me.outputsN.getChild('power-light-on').setValue(on);
    },

    # Delegate Method
    
    # Called by the radar simulator for each on/off slot in the ping pattern.
    #
    ping: func(icao) {
        var on = me.getMode() == TransponderMode.on;
        var alt = me.getMode() == TransponderMode.alt;
        if ((on or alt) and !me.getIdent())
            me.setIdentLight(icao != '');
    },

    # Helper methods

    hasPower: func {
        var n = props.globals.getNode('systems/electrical/outputs/transponder');
        var volts = n.getValue();
        return volts != nil and volts > 14.0;
    },

    # Basic configuration of on/off light and ident light. Pings from the
    # radar simulator are handled by the delegate method.
    #
    _configure: func {
        var off = !me.hasPower() or me.getMode() == TransponderMode.off;
        me.setPowerLight(!off);

        if (off) {
            me.radar.stop();
            me.setIdentLight(0);
        } else {
            me.radar.start();
            if (me.getMode() == TransponderMode.test) {
                me.setIdentLight(1);
            } else {
                # Could be standby, on or alt
                me.setIdentLight(me.getIdent());
            }
        }
    },

    # Listeners

    # Electrical output seems to vary with frame rate, so it is cheaper to
    # poll for changes rather than use a listener.
    #
    electricalPollFunc: func {
        var powered = me.rootN.getChild('powered').getValue();
        if ((powered and !me.hasPower()) or (!powered and me.hasPower())) {
            me.rootN.getChild('powered').setValue(me.hasPower());
        }
        settimer(func { me.electricalPollFunc() }, 0.1);
    },

    identListenerFunc: func {
        me._configure();
    },

    poweredListenerFunc: func {
        me._configure();
    },

    transponderModeListenerFunc: func {
        me._configure();
    },

};
