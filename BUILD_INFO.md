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

For Quattor configuration modules, this will update the build tools version used
by all configuration modules in the repository, when run in the top-level directory.


UNDERSTANDING Maven
===================

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

* `release:prepare`: initialization of the release process. This produces a few files that allow to revert the release process.
* `release:perform`: build and publish the new release

The `release` plugin is taking care of updating the pom file, before and after deploying the release and doing a few other things (like
tagging the repo). It can be viewed as sort of a wrapper over the `deploy` phase, which does the real deployment. It should be
considered mandatory to use the `release` plugin to deploy releases.

*Note: deploying a release requires to have GPG keys: create them if necessary before producing a release. Also, as for any `gpg` command,
you need to have a running `gpg-agent`. It also requires that you have the appropriate Maven configuration in `~/.m2/settings.xml` (see below).* 

To start a `gpg-agent`, use the following command

```bash
eval `gpg-agent --daemon`
```

To perform a release, execute the following Maven commands:

```bash
$ mvn -P\!cfg-module-dist -P\!cfg-module-rpm \
      -Darguments="-P\!cfg-module-dist -P\!cfg-module-rpm -P\!module-test" \
      clean release:prepare

$ mvn -P\!cfg-module-dist -P\!cfg-module-rpm \
      -Darguments="-P\!cfg-module-dist -P\!cfg-module-rpm -P\!module-test" \
      release:perform
```

You cannot use --batch-mode at the moment because you need to enter your GPG key password.
If the userid used to push the package is incorrect, you will probably need to use the -Dusername=XXX property.

Before deploying a release, this is a good practice to deploy a snapshot. This is done with the `deploy` phase: before running
the `deploy` phase, check that the artifact version is ending with `-SNAPSHOT`.

If you want to cancel the release process after doing `release:prepare` but before doing `release:perform`, you need to issue
the appropriate commands depending on whether `release:prepare` added some commits to the upstream branch whose commit message
starts with `[maven-release-plugin]`:

* No commit added (`release:prepare` failed):

  ```bash
  $ mvn release:clean
  $ git reset --hard
  ```

* Commits added (2 commits if `release:prepare` succeeds):


  ```bash
  $ mvn release:clean
  # For each commit added by Maven, in reverse order
  $ git revert commit_id -m 'prepare release canceled'
  $ git push -n upstream (or whatever your upstream remote is): checks that it will do what is expected!
  $ git push upstream  (never use -f)
  Connect to GitHub and delete the new tag if it has been created
  ```

Maven recommended configuration
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
