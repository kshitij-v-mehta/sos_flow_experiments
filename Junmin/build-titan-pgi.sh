#!/bin/bash -e
set -x

tau=1
impact_makefile=Makefile
reader_script=compile
export COMPILER=ftn 
export C_COMPILER=cc 
export ADIOSDIR=${ADIOS_DIR}

if [ ${tau} == 1 ] ; then
    #export TAU_ROOT=/ccs/proj/csc143/CODAR_Demo/titan.gnu/tau
    export TAU_ROOT=/ccs/proj/csc143/tau_mona/titan.pgi/tau
    export TAU_ARCH=craycnl
    export TAU_CONFIG=tau-mpi-pthread-pdt-sos-adios-pgi
	export TAU_MAKEFILE=${TAU_ROOT}/${TAU_ARCH}/lib/Makefile.${TAU_CONFIG}
	echo ${TAU_MAKEFILE}
	#kill -INT $$
	export PATH=${TAU_ROOT}/${TAU_ARCH}/bin:${PATH}
	impact_makefile=Makefile.pgi.tau
	reader_script=compile.pgi.tau
fi

impact()
{
	cd ImpactTv1betaAdios
	make clean
	make -f ${impact_makefile}
	cd ..
}

reader()
{
	cd readerFull
	rm -f *.o reader2
	./${reader_script}
	cd ..
}

impact
reader
