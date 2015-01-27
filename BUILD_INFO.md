BUILD INFO
----------

To build this project, three profiles must be explicitly deactivated.
These are associated with the standard build pom, but we need to make
sure that they aren't executed here.  

Use the following command options:

```bash
$ mvn '-P!cfg-module-dist' '-P!cfg-module-rpm' '-P!module-test' <goal> [goal...]
```

To perform a release, do the following:

```bash
$ mvn '-P!cfg-module-dist' '-P!cfg-module-rpm' \
      -Darguments="-P\!cfg-module-dist -P\!cfg-module-rpm '-P!module-test'" \
      clean release:prepare

$ mvn '-P!cfg-module-dist' '-P!cfg-module-rpm' \
      -Darguments="-P\!cfg-module-dist -P\!cfg-module-rpm '-P!module-test'" \
      release:perform
```

The backslashes are important to avoid shell expansion of the history: unfortunately it
requires using bash and doesn't work with csh/tcsh. 

'-P!module-test' disable unit tests in build-profile even if PERL5LIB is defined
(build-profile delivers a parent pom for other Quattor projects: unit tests
don't make sense in this context). This allows to run unit tests in other modules.

To run unit tests in build-scripts only, without building other modules, use:

```bash
$ mvn -pl build-scripts test
```

When modifying maven build tools, it is possible to test a version snapshot without
making a release. To do this, use the 'install' goal that will put the snapshot
version in the local repository area defined in your ~m2/settings. To use this
snapshot version, edit your module (e.g. configuration module) pom.xml and
update the build-profile version to match the snapshot version.

You cannot use --batch-mode at the moment because you need to enter
your SourceForge password as well as the GPG key password.

You will probably also need to use the -Dusername=XXX property if your
account username is not the same as on SourceForge.


UPDATING BUILD TOOLS VERSION USED BY OTHER COMPONENTS
-----------------------------------------------------

The version of the build tools used by other Quattor components is defined in the
pom.xml of the component (for Quattor configuration modules, in the pom.xml of
each configuration module), as part of the '<parent>' information.

To update the version used for a given component, check out its repository and
in the top-level directory, execute the following command:

```bash
mvn versions:update-parent
```

For Quattor configuration modules, this will update the build tools version used
by all configuration modules in the repository, when run in the top-level directory.


