GDC=gdc

all: rebound

rebound: src/program.d src/generator.d
	cd build; $(GDC) -g ../src/program.d ../src/generator.d -orebound

generator: src/generator.d
	cd build; $(GDC) -g -fversion=Standalone ../src/generator.d -ogenerator
