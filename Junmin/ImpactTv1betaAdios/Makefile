#*****************************************************
#  General Makefile
#
#*****************************************************

#**************************************************************************
# Macros defining the Fortran, C/C++ compiler and linker.

COMPILER = mpif90 -ffree-line-length-0
#LINK = mpif90
FFLAGS = -O2 -g

#CC = ${COMPILER} -DHAVE_CONFIG_H -I. -I/global/project/projectdirs/m1248/edison/adios-flexpath/adios-1.10.0 -I/project/projectdirs/m1248/SENSEI//ADIOS/src
#CC = ${COMPILER} -DHAVE_CONFIG_H -I. -I/global/project/projectdirs/m1248/edison/adios-flexpath/adios-1.10.0/src
CC = ${COMPILER} -DHAVE_CONFIG_H -I. -I/home/khuck/src/chaos/adios/ADIOS-gcc/include
#LINK = ${COMPILER} -dynamic  
LINK = ${COMPILER} -dynamic

#**************************************************************************
# List of .o files that EXENAME depends on.  Edit as appropriate for MP.

OBJS = \
	DataStruct/NumConst.o DataStruct/PhysConst.o DataStruct/Pgrid.o DataStruct/Data.o \
	Func/Timer.o Func/Transpose.o Func/Fldmger.o Func/Ptclmger.o  \
	Func/FFT.o  \
        Appl/BPM.o \
	Appl/DriftTube.o \
	Appl/BeamLineElem.o \
	Appl/CompDom.o Appl/BeamBunch.o Appl/Depositor.o Appl/Ranger.o Appl/Field.o Appl/Distribution.o \
	Contrl/Input.o  Contrl/adiosUtil.o Contrl/Output.o Contrl/AccSimulator.o Contrl/main.o 

# the adios_config script did not include this
FLEXPATH=-lenet

#IPM=-L/usr/common/usg/ipm/2.0.3/gnu/lib -lipm

OBJS2 = \
	NumConst.o PhysConst.o Pgrid.o Data.o \
        Timer.o Transpose.o Fldmger.o Ptclmger.o FFT.o \
	BPM.o DriftTube.o \
	BeamLineElem.o CompDom.o BeamBunch.o Depositor.o Ranger.o Field.o Distribution.o \
	Input.o Output.o adiosUtil.o AccSimulator.o main.o $(KITWAREOBJ)
#**************************************************************************
# Change this line if you don't like 'a.out'.

EXENAME = xmain

#************************************************************************
# disable predefined suffixes and define your own set of allowed suffixes
 .SUFFIXES:
 .SUFFIXES: .o .f .F .c .f90 .F90

#*************************************************************************
# inference rules (how to compile object files that have no explicit rules)
#  $* = name part of target
#  $@ = full target name
#  $< = dependent name

.f90.o:
	$(CC) -c $(FFLAGS) $<

#**************************************************************************
# Rules for building EXENAME from OBJS and OBJS from your source.

$(EXENAME):  $(OBJS) 
	$(LINK) -o $(EXENAME) $(OBJS2) `/home/khuck/src/chaos/adios/ADIOS-gcc/bin/adios_config -l -f` $(FLEXPATH) ${IPM}

#************************************************************************
# if you wish to compile a certain object with different flags
# or in some special way, then specify the target & dependency explicitly
# the following line say Timer.o is depended on Timer.f90
#Timer.o: Timer.f90
#	$(CC) -c -O3 Timer.f90

	cp  AccSimulator.o main.o Input.o Output.o Contrl
	cp  BPM.o DriftTube.o \
	    BeamLineElem.o BeamBunch.o Field.o CompDom.o \
	    Distribution.o \
	    Depositor.o Ranger.o Appl
	cp  Timer.o Transpose.o Fldmger.o Ptclmger.o FFT.o Func	
	cp  NumConst.o PhysConst.o Pgrid.o Data.o DataStruct 
#***********************************************************************
clean:
	-rm *.o $(EXENAME) *.mod */*.o
