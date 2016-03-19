> Hi, I'm Robrt!  I'm a robot that listens to GitHub events and deploys stuff.

Robrt is a simple, automated and configurable build system for projects hosted on GitHub.

It's main purpose is to provide flexible automated builds – and even
deployments – for projects where Travis is either too expensive, or somewhat
unpractical.


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

## Repository basics

TODO: repo stuff (`.robrt.json` and `.robrt.Dockerfile`)

## Server basics

TODO: server stuff (`/etc/robrt` and environment variables)


# Build and run

## Building

Robrt is written in Haxe and, to build, requires both Haxe and some additional
libraries:

 - HaxeFoundation/haxe@development
 - HaxeFoundation/hxnodejs@master
 - jonasmalacofilho/haxe-continuation@transform-later
 - jonasmalacofilho/jmf-npm-externs@master

Since we're targeting Node.js, the easiest way to have an runnable Robrt is to
execute `npm pack`.  This will compile the Haxe project into a JS file and
generate a local NPM package with a pseudo-executable `robrt`.

Alternatively, you can simply run the Haxe compiler with `haxe build.hxml`.

## Dependencies

Besides the Haxe dependencies, Robrt requires Node.js (4.x) and some NPM
packages: `dockerode`, `docopt` and `remove`.

Builds execute in Docker containers, so that is another dependency; it's minimum
required version is yet to be determinated.

Finally, some common executables are also required at runtime: `git` and `tar`.

## Running

TODO: ssl, proxy, run as service

