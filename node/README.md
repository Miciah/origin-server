OpenShift Origin - Node Component
=================================

Hosted applications are run in containers called "gears." These gears
are run on hosts (which can be physical hosts or virtual machines)
called "nodes."

Each node runs a system Apache instance that listens on port 80 on
a public-facing network interface.  Each gear is assigned an address in
the 127.0.0.0/8 block, and a hosted Web application listens on port 8080
on its assigned private 127.x.y.z address.

When a Web client requests a URL for a hosted Web application, the
request goes to the node's system Apache instance.  The system Apache
instance examines the virtual-host header (the "Host:" HTTP header) and
dispatches the request to the appropriate private address.

XXX Talk about port-proxy.

Notice of Export Control Law
----------------------------

This software distribution includes cryptographic software that is subject to the U.S. Export Administration Regulations (the "*EAR*") and other U.S. and foreign laws and may not be exported, re-exported or transferred (a) to any country listed in Country Group E:1 in Supplement No. 1 to part 740 of the EAR (currently, Cuba, Iran, North Korea, Sudan & Syria); (b) to any prohibited destination or to any end user who has been prohibited from participating in U.S. export transactions by any federal agency of the U.S. government; or (c) for use in connection with the design, development or production of nuclear, chemical or biological weapons, or rocket systems, space launch vehicles, or sounding rockets, or unmanned air vehicle systems.You may not download this software or technical information if you are located in one of these countries or otherwise subject to these restrictions. You may not provide this software or technical information to individuals or entities located in one of these countries or otherwise subject to these restrictions. You are also responsible for compliance with foreign law requirements applicable to the import, export and use of this software and technical information.
