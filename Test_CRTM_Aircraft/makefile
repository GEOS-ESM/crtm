#==============================================================================
#
# Makefile for users to simulate radiance 
#
#==============================================================================

#-----------------------------------------------------------------------------
#                          -- Define macros --
#-----------------------------------------------------------------------------

include ./make.macros

# -------------
# This makefile
# -------------

MAKE_FILE = makefile
# ---------------
# Executable file
# ---------------

#EXE_FILE = CRTM_OMPS_Simulation
EXE_FILE = CRTM_Model_Simulator
#EXE_FILE = CRTM_Model_atms
OBJ_FILES = $(EXE_FILE).o
# ------ Please revise two lines below for your netcdf  ----------------------------
INCLUDES = -I../libsrc -I/data/starfs1/libs/netcdf-4.2-ifort/include 
LIBRARIES = -qopenmp -L../libsrc -lcrtm -L/data/starfs1/libs/netcdf-4.2-ifort/lib -lnetcdff

all:
	@echo "OS type detected: "`uname -s`
	@case `uname -s` in \
	  "SunOS")   make -f $(MAKE_FILE) test_program $(SUNOS_FLAGS) ;; \
	  "AIX")     make -f $(MAKE_FILE) test_program $(AIX_FLAGS) ;; \
	  "IRIX64" ) make -f $(MAKE_FILE) test_program $(IRIX64_FLAGS) ;; \
	  "Linux" )  make -f $(MAKE_FILE) test_program $(LINUX_FLAGS) ;; \
	  *) echo "This system is not supported" ;; \
       esac


# -- Targets for specific Linux compilers.
#
# *** NOTE: The PGI compiler must be v6 or later but even ***
# ***       that may not work due to compiler bugs        ***
# IBM AIX Compiler
ibm_debug:
	make -f $(MAKE_FILE) test_program $(AIX_FLAGS_DEBUG)

ibm:
	make -f $(MAKE_FILE) test_program $(AIX_FLAGS_PROD)

intel_debug:
	make -f $(MAKE_FILE) test_program $(LINUX_FLAGS_INTEL_DEBUG)

intel:
	make -f $(MAKE_FILE) test_program $(LINUX_FLAGS_INTEL_PROD)

lahey_debug:
	make -f $(MAKE_FILE) test_program $(LINUX_FLAGS_LAHEY_DEBUG)

lahey:
	make -f $(MAKE_FILE) test_program $(LINUX_FLAGS_LAHEY_PROD)

pgi_debug:
	make -f $(MAKE_FILE) test_program $(LINUX_FLAGS_PGI_DEBUG)

pgi:
	make -f $(MAKE_FILE) test_program $(LINUX_FLAGS_PGI_PROD)

g95_debug:
	make -f $(MAKE_FILE) test_program $(LINUX_FLAGS_G95_DEBUG)

g95:
	make -f $(MAKE_FILE) test_program $(LINUX_FLAGS_G95_PROD)

gfortran_debug:
	make -f $(MAKE_FILE) test_program $(LINUX_FLAGS_GFORTRAN_DEBUG)
gfortran:
	make -f $(MAKE_FILE) test_program $(LINUX_FLAGS_GFORTRAN_PROD)


# ----------------
# Make the program
# ----------------

test_program: $(OBJ_FILES)
	$(FL) $(OBJ_FILES) $(EXTRA_FL_FLAGS) $(FL_FLAGS) $(EXE_FILE)



# --------
# Clean up
# --------

clean:
	$(REMOVE) $(OBJ_FILES) $(EXE_FILE) *.mod *.MOD *.stb


# ---------------
# Dependency list
# ---------------
$(EXE_FILE).o : $(EXE_FILE).f90
#-----------------------------------------------------------------------------
#                          -- Define default rules --
#-----------------------------------------------------------------------------

include ./make.rules
