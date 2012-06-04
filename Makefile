DMD=dmd

all: bcdgen

bcdgen: src/rebound.d
	$(DMD) -g src/rebound.d -ofbuild/rebound
