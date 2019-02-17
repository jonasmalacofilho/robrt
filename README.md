# Robrt

[![Build Status](https://travis-ci.org/jonasmalacofilho/robrt.svg?branch=master)](https://travis-ci.org/jonasmalacofilho/robrt)

Robrt is a simple, automated and configurable build system for projects hosted
on GitHub.

> Hi, I'm Robrt!  I'm a robot that listens to GitHub events and deploys stuff.

It's main purpose is to provide flexible automated builds – and even
deployments – for projects where using Travis is either too expensive, or
somewhat unpractical.

Robrt runs each build – either a pushed commit or updated pull request – in a
Docker container; the thing is, each build can choose, or even create, the
Docker image it will run in.

There's no UI.  Yeah, Robrt is (_still?_) geeky like that.  On the other hand,
it can post customizable messages on Slack and add customizable commit statuses
on GitHub (commit statuses are shown in the branch list and in each pull
request).


# Usage

## Security considerations

_Security has not been solved yet._

Mainly, we want Robrt to allow arbitrary Docker images – actually, arbitrary
Dockerfiles – and, at the same time, support GitHub pull requests; we are still
working on isolating each build request from the repository, the host, and
other builds, while maintaining this much flexibility.  We welcome any
contributions.

For the time being, we strongly advise anyone trying out Robrt to do so without
exposing sensitive data to it.  Or, at the very least, untrusted users should
not be allowed push access, and pull requests should thus be disabled in public
repositories.

## On the repository

Similarly to Travis – and other CI systems out there – Robrt expects each tree
to have a settings file called `.robrt.json`.  This file will give it
instructions on which Docker image to use (or, more specifically, on how to
build it) and which commands should be executed in that image.

A very simple example:

```
{
	"prepare" : {
		"dockerfile" : { "type" : "path", "data" : ".robrt.Dockerfile" }
	}, "build" : {
		"cmds" : [
			"cd $ROBRT_REPOSITORY_DIR",
			"echo 'I'm a build, test or export command' > .out",
			"cp -r .out $ROBRT_OUTPUT_DIR/echo"
		]
	}
}
```

First, in the preparation stage, `.robrt.Dockerfile` will be used to build a
corresponding Docker image.  For now, let's assume that it is a simple clone of
a recent Linux image:

```
FROM ubuntu:latest
```

Then, in the build phase, the following will be executed:

 - _cd_ into the repository directory; `ROBRT_REPOSITORY_DIR` is a standard
   environment variable that will always point to where in that container has
   the repository been mounted to.
 - _echo_ a constant string to file `.out`
 - export the `.out` file to the world, by placing it where, if so configured,
   Robrt will let the host see it (and the host can then serve it via HTTP, for
   instance); `ROBRT_OUTPUT_DIR` is another standard environment variable
   pointing to where in the container has Robrt reserved some space for
   exported data

The undocumented (_we're sorry about that!_) structure of `.robrt.json` can be
seen in [`robrt.repository.RepoConfig`](src/robrt/repository/RepoConfig.hx).

## On the server

TODO: server stuff (`/etc/robrt` and environment variables)

A running Robrt instance will read from `/etc/robrt` (or from the path
specified in the `ROBRT_CONFIG_PATH` environment variable) to know which
repositories to listen to and to proceed on each `push` or `pull_request`
event.

## Notifications

TODO: GitHub commit statuses, Slack posts.

## The log viewer

Robrt logs need to carry lots of instrumental information and are thus not the
of the friendliest kind.

To improve that we've created a [log viewer](https://github.com/protocubo/robrt-log-viewer).
It's a web app than parses the raw log and generates a user-friendly view for
it, with fences, timing and exit code information and, with ANSI escape
sequences, support for colors.


# Build and run

## Building

Robrt is written in Haxe and uses [hmm](https://github.com/andywhite37/hmm) to
manage the required Haxe libraries.  To install the dependencies, run `hmm install`
on the project root.

Since we're targeting Node.js, the easiest way to have a runnable Robrt is to
execute `npm pack`.  This will compile the Haxe project into a JS file and
generate a local NPM package with a pseudo-executable `robrt`.

Alternatively, you can simply run the Haxe compiler with `haxe build.hxml`.

## Dependencies

Besides the Haxe dependencies, Robrt requires Node.js (4+) and some NPM
packages: `dockerode`, `docopt` `remove`, `mkdir-p`, `ncp` and `source-map-support`.

Builds execute in Docker containers, so that is another dependency; it's minimum
required version is yet to be determinated.

Finally, some common executables are also required at runtime: `git` and `tar`.

## Testing locally during developing

TODO: checkout the docs/testing folder; also, ngrok might be very convenient
for inspecting and replaying requests.

## Running in production

TODO: ssl, proxy, run as service

