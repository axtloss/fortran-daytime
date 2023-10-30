LDFLAGS="-lcurl"
CC="gfortran"

main: libs
	mkdir -p build
	cd build && ${CC} ../src/main.f90 libfortran-curl.a -lcurl -o ../fort-daytime

libs:
	git submodule init
	git submodule update
	make -C fortran-curl/
	mkdir -p build
	cp fortran-curl/*.mod build/
	cp fortran-curl/*.a build/
