_rebound_ is a [D](http://dlang.org) bindings generator for C libraries. 

It is based on [bcd.gen](http://www.dsource.org/projects/bcd), a D binding generator that has not been maintained for a number of years.

## Building ##

rebound requires no dependencies for compilation. Running make in the top level directory will compile it using gdc, the Makefile does not support building with dmd. The binaries can be found in the build directory.

## Usage ##

rebound requires [gccxml](http://www.gccxml.org/) at runtime.

Executing rebound is as simple as

	bastian@foo: rebound my_header.h

All the command line options can be found using the _-h_ switch.
