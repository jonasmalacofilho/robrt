> Hi, I'm Robrt!  I'm a robot that listens to GitHub events and deploys stuff.

# About

[...]

# Dependencies

## Daemons

Builds execute in Docker containers, so that's one dependecy.  It's minimum
required version is yet to be determinated.

 - docker

## Executables

Some work is done by common executables:

 - git
 - tar

## Node and NPM

Robrt runs in Node.js and requires some NPM packages.

 - node 4.x (currently tested on 4.x, based on 4.x common API)
 - dockerode
 - docopt
 - remove

## Haxe and haxelibs

Finally, it's written in Haxe and, to build, requires both Haxe and some
Haxelib libraries:

 - HaxeFoundation/haxe@development
 - HaxeFoundation/hxnodejs@master
 - jonasmalacofilho/haxe-continuation@transform-later
 - jonasmalacofilho/jmf-npm-externs@master

