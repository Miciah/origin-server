Glossary
========

Following is a glossary of terms for key high-level concepts within
OpenShift.

The abstract cartridge
: A quasi cartridge that cannot be instantiated but which provides default hooks on which other cartridges can fall back as well as a library of shell scripts which hooks can call.  The abstract cartridge can be regarded as an abstract class and the superclass of all other cartridges.

Application
: A set of one or more instantiated cartridges running on one or more gears.

Cartridge
: A plug-in that is installed on nodes, and is instantiated in ("added to" or "embedded in") gears, that provides functionality to applications running on OpenShift.
: An instance of a cartridge.
: Synonym for "regular cartridge."

Custom cartridge
: A cartridge that is not shipped with OpenShift Enterprise.

Gear
: A container that includes a limited amount of CPU resources, memory, and
storage.  A gear is hosted on a node and can be thought of as a VM, but it is
implemented as a Unix user and contained using cgroups, SELinux, and other Linux
security features instead of virtualisation.

Regular cartridge
: Provides support for functionality on which an OpenShift application may rely.
For example, cartridges exist for the MySQL and PostgreSQL database servers.
Formerly known as an "embedded" cartridge.

Web cartridge
: Provides support for a specific type of application to run on OpenShift.
For example, a Web cartridge exists that supports PHP development, and another
exists for Ruby development.  Formerly known as a "standalone" cartridge or
"framework" cartridge.
