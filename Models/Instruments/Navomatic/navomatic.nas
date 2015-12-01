###############################################################################
#
# Navomatic Autopilot Functions
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

var _has_power = func()
{
    var volts = getprop('systems/electrical/outputs/autopilot');
    return volts != nil and volts > 12.0;
}

var _autopilot_active = func()
{
    var ap_on = getprop('Navomatic400A/switches/ap-on');
    return _has_power() and ap_on;
}

var _configure_vertical_mode = func()
{
    var alt = getprop('Navomatic400A/switches/alt');
    var pitch_select = getprop('autopilot/settings/pitch-select');
    var pitch_detent = math.abs(pitch_select) < 0.01;

    setprop('autopilot/locks/altitude', alt and pitch_detent ? 'altitude-hold' : 'pitch-hold');
}

var _configure_lateral_mode = func()
{
    var nav = getprop('Navomatic400A/switches/nav');
    var pulled_out = getprop('Navomatic400A/push-pull-dial/pulled-out');
    var bank_select = getprop('autopilot/settings/bank-select');
    var bank_detent = math.abs(bank_select) < 0.01;

    if (pulled_out) {
        setprop('autopilot/locks/heading', bank_detent ? 'wing-leveler' : 'bank-hold');
    } else {
        setprop('autopilot/locks/heading', nav ? 'nav1-hold' : 'dg-heading-hold');
    }
}

var _configure_both_modes = func()
{
    if (_autopilot_active()) {
        _configure_vertical_mode();
        _configure_lateral_mode();

    } else {
        setprop('autopilot/locks/altitude', '');
        setprop('autopilot/locks/heading', '');
        
        # Auto-trim elevator when autopilot disconnects to avoid pitch change
        # when using a joystick that has been centered while the AP was active
        var elevator = getprop('controls/flight/elevator');
        var trim = getprop('controls/flight/elevator-trim');
        setprop('controls/flight/elevator-trim', trim + elevator);
        setprop('controls/flight/elevator', 0);
    }
}

###############################################################################
# Listeners
###############################################################################

var pitch_select_listener = func()
{
    if (_autopilot_active()) {
        _configure_vertical_mode();
    }
}

var bank_select_listener = func() 
{
    if (_autopilot_active()) {
        _configure_lateral_mode();
    }
}

# Electrical output varies constantly and is not suitable for detecting changes
# to the on-off state, so create a new property that only switches on or off
# when the autopilot gains or loses functional power.
var electrical_output_listener = func() 
{
    var powered = getprop('Navomatic400A/powered');

    if ((powered and !_has_power()) or (!powered and _has_power())) {
        setprop('Navomatic400A/powered', !getprop('Navomatic400A/powered'));
    }
}

var powered_listener = func() 
{
    _configure_both_modes();
}

var ap_on_switch_listener = func() 
{
    _configure_both_modes();
}

var alt_switch_listener = func() 
{
    if (_autopilot_active()) {
        _configure_vertical_mode();
    }
}

var nav_switch_listener = func() 
{
    if (_autopilot_active()) {
        _configure_lateral_mode();
    }
}

var push_pull_listener = func()
{
    if (_autopilot_active()) {
        _configure_lateral_mode();
    }
}

# The Navomatic autopilots do not have an approach mode but they do track a 
# glideslope, so presumably they just switch implicitly to an approach mode 
# when there is a glideslope and they are tracking the localizer heading.
#
var gs_in_range_listener = func()
{
    var locks_heading = getprop('autopilot/locks/heading');
    var locks_altitude = getprop('autopilot/locks/altitude');

    var altitude_hold = locks_altitude != nil and locks_altitude == 'altitude-hold';
    var nav1_hold = locks_heading != nil and locks_heading == 'nav1-hold';
    var gs_in_range = getprop('instrumentation/nav/gs-in-range');

    if (altitude_hold and nav1_hold and gs_in_range) {
        setprop('autopilot/locks/altitude', 'gs1-hold');
    }
}

# Start listeners

setlistener('autopilot/settings/pitch-select', pitch_select_listener);
setlistener('autopilot/settings/bank-select', bank_select_listener);

setlistener('systems/electrical/outputs/autopilot', electrical_output_listener);

setlistener('Navomatic400A/powered', powered_listener);
setlistener('Navomatic400A/switches/ap-on', ap_on_switch_listener);
setlistener('Navomatic400A/switches/alt', alt_switch_listener);
setlistener('Navomatic400A/switches/nav', nav_switch_listener);
setlistener('Navomatic400A/push-pull-dial/pulled-out', push_pull_listener);

setlistener('instrumentation/nav/gs-in-range', gs_in_range_listener);

print('Navomatic 400A Autopilot Loaded');
