(this file is better displayed as Markdown).

BUILD INFO
==========

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

The backslashes are important to avoid shell expansion of the history.

'-P!module-test' disable unit tests in build-profile even if PERL5LIB is defined
(build-profile delivers a parent pom for other Quattor projects: unit tests
don't make sense in this context). This allows to run unit tests in other modules.

To run unit tests in build-scripts only, without building other modules, use:

```bash
$ mvn -pl build-scripts test
```

When modifying maven build tools, it is possible to test a version snapshot without
making a release. To do this, use the 'install' phase that will put the snapshot
version in the local repository area defined in your `~/.m2/settings.xml`. To use this
snapshot version, edit your module (e.g. configuration module) pom.xml and
update the build-profile version to match the snapshot version.


UPDATING BUILD TOOLS VERSION USED BY OTHER COMPONENTS
=====================================================

The version of the build tools used by other Quattor components is defined in the
pom.xml of the component (for Quattor configuration modules, in the pom.xml of
each configuration module), as part of the '<parent>' information.

To update the version used for a given component to the last release available, 
check out its repository and in the top-level directory, execute the following 
command:

```bash
mvn versions:update-parent
```

After you have checked that everything is ok, commit the modified pom files and
remove the backup files created with:

```bash
git clean -f
```

For Quattor configuration modules, this will update the build tools version used
by all configuration modules in the repository, when run in the top-level directory.


UNDERSTANDING Maven
===================

Maven is a powerful and extensible build tool. The build process is driven by file
`pom.xml` that can look complex... One important concept behind Maven is the
*build life-cycle* that is an ordered list of phase, namely:

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


Updating the pom files
----------------------

Pom files (`pom.xml`) are used to drive the building process. They are XML files. For some advanced 
operations it is possible to edit them but for most of the operations, there are Maven plugins available
to do it. **It is strongly recommended** to use Maven when possible rather than editing the pom files.

We have already seen above how to update the *parent* information. Another useful plugin allows to updates
the plugins used by the pom file: [versions](http://mojo.codehaus.org/versions-maven-plugin/). Particularly
useful goals of this plugin are:

* `versions:display-dependency-updates`: display dependencies for which a newer version exists
* `versions:use-latest-versions`: update version of dependencies used to last version available
* `versions:display-plugin-updates`: display used plugins for which a newer version exists. The version
must be updated manually in the pom file if a new version exists and you want to use it.

*Note: it is important to define the version to use for dependencies and plugins present in the configuration. Maven raises a
warning if this is not the case. When this is not done in the parent pom, if any defined, it has to be done in the child pom.*


Producing a new release of the build tools
------------------------------------------

A release of a component (*artifact* in Maven terminology) managed by Maven is done with the Maven 
[release](http://maven.apache.org/maven-release/maven-release-plugin/) plugin. The main goals are:

* `release:prepare`: build everything to be released, update/tag the source repositories, update the pom files. 
It produces also a few files that allow to revert the release process.
* `release:perform`: publish the new release

The `release` plugin be viewed as sort of a wrapper over the `deploy` phase. It should be
considered **mandatory** to use the `release` plugin to deploy releases.

In case of an error during of the goals above, they can be run again as many times as necessary
until completion. At each run, Maven will guess what has already been done and do only the other
part.

*Note:* deploying a release requires to have GPG keys: create them if necessary before producing a release 
and publish your public key on one GPG key server (they are all synchronised, see 
http://central.sonatype.org/pages/working-with-pgp-signatures.html#distributing-your-public-key) and wait for
your key to be present on http://pgp.mit.edu:11371. Also, as for any `gpg` command,
you need to have a running `gpg-agent`. It also requires that you have the appropriate Maven configuration 
in `~/.m2/settings.xml` (see below).

It is not possible to use `--batch-mode` at the moment because you need to enter your GPG key password during the release process.

If the userid used to push the package is incorrect, you will probably need to use the `-Dusername=XXX` property.

*Before deploying a release, in particular if you are not familiar with the process,
it is a good practice to deploy a snapshot. This is done with the `deploy` phase: before running
the `deploy` phase, check that the artifact version in the pom file is ending with `-SNAPSHOT`. It
allows to check that the basic configuration, in particular to interact with Sonatype, is correct.*

### Build release and push to nexus

1. Start a `gpg-agent`, using the following command ``eval `gpg-agent --daemon` ``

1. Before starting doing the release, also ensure that you have the environment variable
`QUATTOR_TEST_TEMPLATE_LIBRARY_CORE` defined to a directory (absolute path) containing
an up-to-date version of `template-library-core` repository (required by tests).

  For example:
  1. `git clone https://github.com/quattor/template-library-core.git /tmp/template-library-core-master`
  2. `export QUATTOR_TEST_TEMPLATE_LIBRARY_CORE=/tmp/template-library-core-master` 

1. Prepare the release:

  `$ mvn -P\!cfg-module-dist -P\!cfg-module-rpm -Darguments="-P\!cfg-module-dist -P\!cfg-module-rpm -P\!module-test" clean release:prepare`

1. Perform the release:

  `$ mvn -P\!cfg-module-dist -P\!cfg-module-rpm -Darguments="-P\!cfg-module-dist -P\!cfg-module-rpm -P\!module-test" release:perform`

### Promoting from staging to release

1. After successfully executing `release:perform`, the new release will be in a staging area on Sonatype nexus server
(https://oss.sonatype.org). Before the release can be used, you must log in to the nexus server, close the staging
area and ask for the staging area being released.

1. Select `Staging Repositories` in the left side menu (appearing
after you logged in) and search for [org.quattor.maven](https://oss.sonatype.org/#nexus-search;quick~org.quattor.maven).

1. Select the appropriate repository (you may have several if you did several attempts from different machines) and close it.

1. When the operation is successful (click on `Refresh`), click on the `Release` button. Once successfully released, you may have to wait a couple of hours before the release appears on the [Maven Central Repository](http://search.maven.org/#search%7Cga%7C1%7Corg.quattor.maven).

### Additional notes

* If something went wrong during `release:perform` (which pushes the release to the staging area), it is sometimes necessary to drop the staging directory after closing it to be able to run `release:perform` again (particularly if it complains that the packages are already present in the repository).
 * A good documentation of the staging process can be found at http://books.sonatype.com/nexus-book/reference/staging-repositories.html
 * Detailed information on using Maven to deploy releases at Sonatype is available at http://central.sonatype.org/pages/apache-maven.html.

* If when the release becomes available on http://search.maven.org Maven complains that it cannot find the new release, add the `-U` option to the Maven command line. The execution of Maven may still result in an error but the local repository should be updated allowing the next execution of Maven to work.

* If you really want to cancel the release process after doing `release:prepare` but before doing `release:perform` (it is preferable to fix the problem and rerun `release:prepare`), you need to issue the appropriate commands depending on whether `release:prepare` added some commits to the upstream branch whose commit message starts with `[maven-release-plugin]`:

  * No commit added (`release:prepare` failed):

  ```bash
  $ mvn release:clean
  $ git reset --hard
  ```

  * Commits added (2 commits if `release:prepare` succeeds):

  ```bash
  $ mvn release:clean
  # For each commit added by Maven, in reverse order
  $ git revert commit_id -m 'prepare release cancelled'
  $ git push -n upstream (or whatever your upstream remote is): checks that it will do what is expected!
  $ git push upstream  (never use -f)
  Connect to GitHub and delete the new tag if it has been created
  ```

  * **Note: after a first execution of `release:perform` which pushed things to Sonatype Central Repository, it is not recommended that you attempt to revert a failed release. If the problems with the release in progress cannot be fixed, simply start a new release.**

Recommended Maven configuration
-------------------------------

Below is a typical Maven configuration file (`~/.m2/settings.xml`) to be able to manage the build tools.

```xml
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                      http://maven.apache.org/xsd/settings-1.0.0.xsd">

  <localRepository>/where/you/want/to/put/maven/local/repository</localRepository>
  <interactiveMode/>
  <usePluginRegistry/>
  <offline/>
  <pluginGroups/>
  <mirrors/>
  <proxies/>
  <activeProfiles/>

  <servers>
    <server>
      <id>sonatype-nexus-snapshots</id>
      <username>your_userid</username>
      <password>xxxxx</password>
    </server>
    <server>
      <id>sonatype-nexus-staging</id>
      <username>your_userid</username>
      <password>xxxxx</password>
    </server>
  </servers>

</settings>
```

In the above example `your_userid` and the password refer to your account at http://sonatype.org.
To get an account at Sonatype, follow the instructions at http://central.sonatype.org/pages/ossrh-guide.html.
