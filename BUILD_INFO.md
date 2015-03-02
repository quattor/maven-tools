BUILD INFO
----------

To build this project, three profiles must be explicitly deactivated.
These are associated with the standard build pom, but we need to make
sure that they aren't executed here.  

Use the following command options:

```bash
$ mvn -P\!cfg-module-dist -P\!cfg-module-rpm -P\!module-test <phase>
```

Note that the three main phases that really make sense for the build tools are
`package`, `integration-test` and `install`. In particular the phase `test` is 
generally expected to fail in `build-profile` if you have not run `install` before 
as there is a chicken-and-egg issue: `build-profile` component requires the other
components built as part of this command. Use `integration-test` rather than `test`.

To perform a release, do the following:

```bash
$ mvn -P\!cfg-module-dist -P\!cfg-module-rpm \
      -Darguments="-P\!cfg-module-dist -P\!cfg-module-rpm -P\!module-test" \
      clean release:prepare

$ mvn -P\!cfg-module-dist -P\!cfg-module-rpm \
      -Darguments="-P\!cfg-module-dist -P\!cfg-module-rpm -P\!module-test" \
      release:perform
```

The backslashes are important to avoid shell expansion of the history.

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

To update the version used for a given component to the last release available, 
check out its repository and in the top-level directory, execute the following 
command:

```bash
mvn versions:update-parent
```

For Quattor configuration modules, this will update the build tools version used
by all configuration modules in the repository, when run in the top-level directory.


UNDERSTANDING Maven
-------------------

Maven is a powerful and extensible build tool. The build process is driven by file
`pom.xml` that can look complex... One important concept behind Maven is the
*build lifecyle* that is an ordered list of phase, namely:

 * validate: validate the project is correct and all necessary information is available
 * compile: compile the source code of the project
 * test: test the compiled source code using a suitable unit testing framework. These tests should not require the code be packaged or deployed
 * package: take the compiled code and package it in its distributable format, such as a JAR.
 * integration-test: process and deploy the package if necessary into an environment where integration tests can be run
 * verify: run any checks to verify the package is valid and meets quality criteria
 * install: install the package into the local repository, for use as a dependency in other projects locally

Specifying one of these phases imply execution of all the previous ones. There is an additional phase, `clean`, that
can be used with any other phase. It must be specified before any other phase and will remove all the files that could
have been produced by a previous Maven run.

Before doing any modifications in the `pom.xml`
files, particularly in this repository, be sure to understand Maven basics.
Fortunately, there is a lot of documentation available on the web about Maven. A good
starting point is http://maven.apache.org/guides/getting-started/maven-in-five-minutes.html.

