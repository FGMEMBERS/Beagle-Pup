################################################################################
#
# Beagle Pup Messages
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

var status = screen.window.new(0, 0, 1, 5);
status.fg = [0, 0.1, 0, 1];

################################################################################
# Autopilot controls
################################################################################

setlistener("autopilot/locks/heading-hold", func(node) {
    if (node.getBoolValue()) {
        var h = getprop("autopilot/settings/heading-bug-deg");
        status.write(sprintf("Heading Hold: %.0f deg", h));
    }
}, 0, 0);

setlistener("autopilot/sperry/elev-trim", func(node) {
    status.write(sprintf("Elev Trim: %.2f deg", node.getValue()));
}, 0, 0);

setlistener("autopilot/sperry/pitch-select", func(node) {
    status.write(sprintf("Pitch Select: %.1f deg", node.getValue()));
}, 0, 0);

setlistener("autopilot/sperry/roll-trim", func(node) {
    status.write(sprintf("Roll Trim: %.2f deg", node.getValue()));
}, 0, 0);

setlistener("autopilot/sperry/turn-select", func(node) {
    status.write(sprintf("Turn Select: %.0f deg", node.getValue()));
}, 0, 0);

################################################################################
# Crash detection
################################################################################

var report_crash = func(msg)
{
    # Don't report multiple crashes. The crash detection system will
    # set sim/crashed when it detects the first one.
    if (getprop("sim/crashed")) return;

    setprop("sim/messages/ai-plane", msg);
    print(msg);
}

var start_crash_reporting = func
{
    var crash = "fdm/jsbsim/systems/crash-detect/";

    setlistener(crash~"heavy-impact", func(node) {
        if (node.getBoolValue())
            report_crash("The aircraft crashed into the ground.");
    }, 0, 0);

    setlistener(crash~"wing-strike", func(node) {
        if (node.getBoolValue())
            report_crash("One of the main wings struck the ground.");
    }, 0, 0);

    setlistener(crash~"tail-strike", func(node) {
        if (node.getBoolValue())
            report_crash("Part of the tail struck the ground.");
    }, 0, 0);

    setlistener(crash~"fuselage-strike", func(node) {
        if (node.getBoolValue())
            report_crash("Part of the fuselage struck the ground.");
    }, 0, 0);

    setlistener(crash~"propeller-strike", func(node) {
        if (node.getBoolValue())
            report_crash("The propeller struck the ground.");
    }, 0, 0);
}

setlistener("sim/signals/fdm-initialized", func {
    start_crash_reporting();
}, 0, 0);

