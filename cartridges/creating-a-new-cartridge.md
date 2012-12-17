Creating a New Cartridge
========================

This guide explains how to create a new Web or regular cartridge,
step by step.

The reader is assumed to be familiar with the definitions provided in
the [terminology document](../documentation/terminology.md).  The
general [documentation on cartridges](./README.md) may be helpful in
understanding this guide.  That document provides a lot of high-level
concepts, low-level technical details, and explanations of why things
are done as they are.  However, it is not assumed that the reader has
read that document, and it should be possible to follow the steps in
this guide without having read the other document.


Copy Template
-------------

A template for new cartridges exists in the template/ directory.  The
first step in creating a new cartridge is to make a copy of this
template/ directory:

    $ cp -r template my-new-cartridge/


Update Documentation
--------------------

Change the copyright, license information, and README as appropriate:

    $ vim my-new-cartridge/COPYRIGHT my-new-cartridge/LICENSE my-new-cartridge/README.md


Update Packaging Information
----------------------------

Rename and edit the RPM .spec file:

    $ mv my-new-cartridge/openshift-origin-cartridge-template-0.1.spec my-new-cartridge/openshift-origin-cartridge-my-new-cartridge-0.1.spec
    $ vim my-new-cartridge/openshift-origin-cartridge-my-new-cartridge-0.1.spec

Modify the name, version, source, URL, and description information as
appropriate.  Also be sure to add Requires: lines for any packages that
are required on the node.  Finally, edit the initial changelog entry.

Within the %install section of the .spec file, you will see that many
symlinks are created of the form info/hooks/*foo* ->
../abstract/info/hooks/*foo*.  Cartridges use these symlinks to use the
default hooks provided by the abstract cartridge.  If you need a custom
implementation of any of these hooks, you can delete the command that
creates the symlink and ship your own custom hook instead.


Edit Control Script
-------------------

Edit the info/bin/app_ctl.sh script:

    $ vim my-new-cartridge/info/bin/app_ctl.sh

Modify the start and stop functions as appropriate for your application.


Modify the template/
--------------------

The included template includes a template git repository, under the
template/ directory.  When a cartridge is instantiated, it creates a new
git repo for the instantiated cartridge, and the contents of the
cartridge's template/ directory are used as the initial contents of the
instances's new git repo.

For most cartridges, it makes sense to have a git repository for
application developers' code.  If having a git repository does not make
sense for the cartridge you are creating, you can delete the template/
directory entirely:

    $ rm -rf my-new-cartridge/template

If you do not include a git repository in the cartridge, you can drop
the corresponding lines from the .spec file:

    $ vim my-new-cartridge/openshift-origin-cartridge-my-new-cartridge-0.1.spec
    Delete 'BuildRequires: git'.
    Delete the stanza under "%build" (everything from the first line
    following "%build" to the next empty line).
    Delete the line begining with "cp -rp git_remplate.git."

The template git repository includes a template README file and
a .openshift/ directory.  Modify the README file as appropriate:

    $ vim my-new-cartridge/template/README

Within the .openshift directory, there are two additionial directories:
action_hooks/ and cron/:

    my-new-cartridge/template/.openshift/
        action_hooks/
            ...
        cron/
            daily/
            hourly/
            minutely/
            monthly/
            README.cron/
            weekly/
                ...

See [the documentation on git hooks](./git-hooks.md) for an explanation
of the action_hooks/ directory and a list of the hooks thereunder.  The
cron/ directory is used if the cron cartridge is installed; the
cartridge looks for the cronjobs here.
