!
! Test_Adjoint
!
! Program to run the CRTM Adjoint model code and compare the output
! with baseline results.
!
!
! CREATION HISTORY:
!       Written by:     Paul van Delst, CIMSS/SSEC 30-Jun-2004
!                       paul.vandelst@ssec.wisc.edu
!

PROGRAM Test_Adjoint

  ! -----------------
  ! Environment setup
  ! -----------------
  ! Module usage
  USE CRTM_Module
  USE CRTM_Atmosphere_Binary_IO
  USE CRTM_Surface_Binary_IO
  USE CRTM_Test_Utility, &
        ONLY: ATMDATA_FILENAME, SFCDATA_FILENAME, USED_N_PROFILES, &
              EMISSIVITY_TEST, CLOUDS_TEST, AEROSOLS_TEST, ANTCORR_TEST, MAX_N_TESTS, &
              TEST_ZENITH_ANGLE, TEST_SCAN_ANGLE, &
              D_PERCENT, &
              Perform_Test, &
              Print_ChannelInfo, &
              Write_AtmSfc_TestFile, Read_AtmSfc_TestFile
  USE SensorInfo_Define, &
        ONLY: SensorInfo_type, &
              Destroy_SensorInfo
  USE SensorInfo_LinkedList, &
        ONLY: SensorInfo_List_type, &
              Count_SensorInfo_Nodes, &
              GetFrom_SensorInfo_List, &
              Destroy_SensorInfo_List
  USE SensorInfo_IO, &
        ONLY: Read_SensorInfo
  USE Timing_Utility, &
        ONLY: Timing_type, &
              Begin_Timing, End_Timing, Display_Timing
  USE Unit_Test, &
        ONLY: UTest_type, &
              Init_AllTests, Init_Test, Assert_Equal, &
              Report_AllTests, n_Tests_Failed
  USE SignalFile_Utility, &
        ONLY: Create_SignalFile
  ! Disable all implicit typing
  IMPLICIT NONE


  ! ----------
  ! Parameters
  ! ----------
  CHARACTER(*), PARAMETER :: PROGRAM_NAME   = 'Test_Adjoint'
  CHARACTER(*), PARAMETER :: PROGRAM_RCS_ID = &
    '$Id$'
  CHARACTER(*), PARAMETER :: SENSORINFO_FILE = 'Test.SensorInfo'
  CHARACTER(*), PARAMETER :: MESSAGE_LOG = 'Test.Report'


  ! ---------
  ! Variables
  ! ---------
  CHARACTER(256) :: Message, Answer
  CHARACTER(256) :: Filename
  CHARACTER(256) :: Exp_ID, Exp_Description
  LOGICAL :: Compare_Results
  INTEGER :: i, m, n, n_Channels, n_Sensors
  INTEGER :: Error_Status
  INTEGER :: Allocate_Status
  INTEGER :: Atm_Status, Sfc_Status
  INTEGER, DIMENSION(USED_N_PROFILES) :: n_Clouds
  INTEGER, DIMENSION(USED_N_PROFILES) :: n_Aerosols
  CHARACTER(256)             , ALLOCATABLE :: Sensor_Id(:)
  TYPE(CRTM_ChannelInfo_type), ALLOCATABLE :: ChannelInfo(:)
  TYPE(CRTM_Atmosphere_type)  , DIMENSION(USED_N_PROFILES)  :: Atm, Atm_AD, Atm_Baseline
  TYPE(CRTM_Surface_type)     , DIMENSION(USED_N_PROFILES)  :: Sfc, Sfc_AD, Sfc_Baseline
  TYPE(CRTM_GeometryInfo_type), DIMENSION(USED_N_PROFILES)  :: GeometryInfo
  TYPE(CRTM_RTSolution_type)  , DIMENSION(:,:), ALLOCATABLE :: RTSolution, RTSolution_AD
  TYPE(CRTM_Options_type)     , DIMENSION(USED_N_PROFILES)  :: Options
  TYPE(SensorInfo_type)      :: SensorInfo
  TYPE(SensorInfo_List_type) :: SensorInfo_List
  TYPE(UTest_type)           :: UTest
  TYPE(Timing_type)          :: Timing

  ! Program header
  ! --------------
  CALL Program_Message( PROGRAM_NAME, &
                        'Program to run the CRTM Forward model code and '//&
                        'compare the output with baseline results.', &
                        '$Revision$' )

  ! Get user input
  ! --------------
  WRITE( *,FMT='(/5x,"Perform baseline comparison? [y]: ")', &
           ADVANCE='NO')
  READ( *,'(a)' ) Answer
  Answer = ADJUSTL(Answer)
  Compare_Results = .TRUE.
  IF ( Answer(1:1) == 'N' .OR. Answer(1:1) == 'n' ) Compare_Results = .FALSE.
  
  ! Read the SensorInfo list file
  ! -----------------------------
  Error_Status = Read_SensorInfo( SENSORINFO_FILE, &
                                  SensorInfo_List, &
                                  Quiet=SET        )
  IF ( Error_Status /= SUCCESS ) THEN
    CALL Display_Message( PROGRAM_NAME, &
                          'Error reading SensorInfo file '//SENSORINFO_FILE, &
                          FAILURE )
    STOP
  END IF
  ! Count the sensors to process
  n_Sensors = Count_SensorInfo_Nodes( SensorInfo_List )
  IF ( n_Sensors < 1 ) THEN
    CALL Display_Message( PROGRAM_NAME, &
                          'SensorInfo_List is empty.', &
                          FAILURE )
    STOP
  END IF
  ! Allocate the sensor dependent arrays
  ALLOCATE( Sensor_Id(n_Sensors), &
            ChannelInfo(n_Sensors), &
            STAT=Allocate_Status )
  IF ( Allocate_Status /= 0 ) THEN 
    CALL Display_Message( PROGRAM_NAME, &
                          'Error allocating Sensor_Id and ChannelInfo arrays', &
                          Error_Status)  
    STOP
  END IF
  ! Fill the sensor id array
  DO n = 1, n_Sensors
    Error_Status = GetFrom_SensorInfo_List( SensorInfo_List, n, SensorInfo )
    IF ( Error_Status /= SUCCESS ) THEN
      WRITE( Message,'("Error retrieving SensorInfo data for sensor # ",i0)' ) n
      CALL Display_Message( PROGRAM_NAME, &
                            TRIM(Message), &
                            FAILURE )
      STOP
    END IF
    Sensor_Id(n) = SensorInfo%Sensor_Id
    Error_Status = Destroy_SensorInfo( SensorInfo )
    IF ( Error_Status /= SUCCESS ) THEN
      CALL Display_Message( PROGRAM_NAME, &
                            'Error destroying SensorInfo data structure.', &
                            FAILURE )
      STOP
    END IF
  END DO
  ! Clean up
  Error_Status = Destroy_SensorInfo_List( SensorInfo_List )
  IF ( Error_Status /= SUCCESS ) THEN
    CALL Display_Message( PROGRAM_NAME, &
                          'Error destroying SensorInfo linked list.', &
                          WARNING )
  END IF

  ! Read the atmosphere and surface structure data files
  ! ----------------------------------------------------
  WRITE( *, '( /5x, "Reading ECMWF Atmosphere structure file..." )' )
  Error_Status = CRTM_Read_Atmosphere_Binary( ATMDATA_FILENAME, &
                                              Atm )
  IF ( Error_Status /= SUCCESS ) THEN 
     CALL Display_Message( PROGRAM_NAME, &
                           'Error reading Atmosphere structure file '//&
                           ATMDATA_FILENAME, & 
                           Error_Status )
   STOP
  END IF

  WRITE( *, '( /5x, "Reading Surface structure file..." )' )
  Error_Status = CRTM_Read_Surface_Binary( SFCDATA_FILENAME, &
                                           Sfc )
  IF ( Error_Status /= SUCCESS ) THEN 
     CALL Display_Message( PROGRAM_NAME, &
                           'Error reading Surface structure file '//&
                           SFCDATA_FILENAME, & 
                           Error_Status )
   STOP
  END IF

  ! Save the number of clouds and
  ! aerosols in each profile
  n_Clouds   = Atm%n_Clouds
  n_Aerosols = Atm%n_Aerosols


  ! Initialise the CRTM
  ! -------------------
  WRITE( *, '( /5x, "Initializing the CRTM..." )' )
  Error_Status = CRTM_Init( ChannelInfo, &
                            SensorId=Sensor_Id )
  IF ( Error_Status /= SUCCESS ) THEN 
     CALL Display_Message( PROGRAM_NAME, &
                           'Error initializing CRTM', & 
                            Error_Status)  
   STOP
  END IF


  ! Allocate output arrays
  ! ----------------------
  n_Channels = SUM(ChannelInfo%n_Channels)
  ALLOCATE( RTSolution(    n_Channels, USED_N_PROFILES ), &
            RTSolution_AD( n_Channels, USED_N_PROFILES ), &
            STAT = Allocate_Status )
  IF ( Allocate_Status /= 0 ) THEN 
    CALL Display_Message( PROGRAM_NAME, &
                          'Error allocating RTSolution structure arrays', & 
                           Error_Status)  
    STOP
  END IF


  ! Allocate the RTSolution structures
  ! ----------------------------------
  Error_Status = CRTM_Allocate_RTSolution( Atm(1)%n_Layers, RTSolution )
  IF ( Error_Status /= SUCCESS ) THEN 
    CALL Display_Message( PROGRAM_NAME, &
                          'Error allocating RTSolution', & 
                           Error_Status)  
    STOP
  END IF
  Error_Status = CRTM_Allocate_RTSolution( Atm(1)%n_Layers, RTSolution_AD )
  IF ( Error_Status /= SUCCESS ) THEN 
    CALL Display_Message( PROGRAM_NAME, &
                          'Error allocating RTSolution_AD', & 
                           Error_Status)  
    STOP
  END IF


  ! Set the adjoint values
  ! ----------------------
  ! Copy and then zero the adjoint atmosphere structure
  Error_Status = CRTM_Assign_Atmosphere( Atm, Atm_AD )
  IF ( Error_Status /= SUCCESS ) THEN 
    CALL Display_Message( PROGRAM_NAME, &
                          'Error copying Atmosphere structure array.', &
                          Error_Status )
    STOP
  END IF
  CALL CRTM_Zero_Atmosphere( Atm_AD )
  ! Copy and then zero the adjoint surface structure
  Error_Status = CRTM_Assign_Surface( Sfc, Sfc_AD )
  IF ( Error_Status /= SUCCESS ) THEN 
    CALL Display_Message( PROGRAM_NAME, &
                          'Error copying Surface structure array.', &
                          Error_Status )
    STOP
  END IF
  CALL CRTM_Zero_Surface( Sfc_AD )


  ! Allocate the Options input
  ! --------------------------
  Error_Status = CRTM_Allocate_Options( n_Channels, Options )
  IF ( Error_Status /= SUCCESS ) THEN 
    CALL Display_Message( PROGRAM_NAME, &
                          'Error allocating Options structure array', & 
                           Error_Status)  
    STOP
  END IF


  ! Set the adjoint values
  ! ----------------------
  RTSolution_AD%Brightness_Temperature = ONE
  
  
  ! Assign some values
  ! ------------------
  GeometryInfo%Sensor_Zenith_Angle = TEST_ZENITH_ANGLE
  GeometryInfo%Sensor_Scan_Angle   = TEST_SCAN_ANGLE
  GeometryInfo%iFOV = 1
  DO m = 1, USED_N_PROFILES
    Options(m)%Emissivity = 0.8_fp
  END DO


  ! Print some initialisation info
  ! ------------------------------
  DO n=1, n_Sensors
    CALL Print_ChannelInfo(ChannelInfo(n))
  END DO


  ! Initialise the test counters
  ! ----------------------------
  CALL Init_AllTests(UTest)

  
  ! Call the Adjoint model
  ! ----------------------
  DO i = 0, MAX_N_TESTS

    Exp_ID = ''
    Exp_Description = ''

    
    ! Turn experiments on and off
    ! ---------------------------
    ! Turn emissivity option on and off
    IF ( Perform_Test(i,EMISSIVITY_TEST) ) THEN
      Options%Emissivity_Switch = 1
      Exp_ID = TRIM(Exp_ID)//'.eON'
      Exp_Description = TRIM(Exp_Description)//' Emissivity ON'
    ELSE
      Options%Emissivity_Switch = 0
      Exp_ID = TRIM(Exp_ID)//'.eOFF'
      Exp_Description = TRIM(Exp_Description)//' Emissivity OFF'
    END IF
    
    ! Turn clouds on and off
    IF ( Perform_Test(i,CLOUDS_TEST) ) THEN
      Atm%n_Clouds = n_Clouds
      Exp_ID = TRIM(Exp_ID)//'.cON'
      Exp_Description = TRIM(Exp_Description)//' Clouds ON'
    ELSE
      Atm%n_Clouds = 0
      Exp_ID = TRIM(Exp_ID)//'.cOFF'
      Exp_Description = TRIM(Exp_Description)//' Clouds OFF'
    END IF
    
    ! Turn aerosols on and off
    IF ( Perform_Test(i,AEROSOLS_TEST) ) THEN
      Atm%n_Aerosols = n_Aerosols
      Exp_ID = TRIM(Exp_ID)//'.aON'
      Exp_Description = TRIM(Exp_Description)//' Aerosols ON'
    ELSE
      Atm%n_Aerosols = 0
      Exp_ID = TRIM(Exp_ID)//'.aOFF'
      Exp_Description = TRIM(Exp_Description)//' Aerosols OFF'
    END IF

    ! Turn antenna correction on and off
    IF ( Perform_Test(i,ANTCORR_TEST) ) THEN
      Options%Antenna_Correction = 1
      Exp_ID = TRIM(Exp_ID)//'.acON'
      Exp_Description = TRIM(Exp_Description)//' Antenna Correction ON'
    ELSE
      Options%Antenna_Correction = 0
      Exp_ID = TRIM(Exp_ID)//'.acOFF'
      Exp_Description = TRIM(Exp_Description)//' Antenna Correction OFF'
    END IF

    WRITE(*,'(/5x,"Experiment: ",a)') TRIM(ADJUSTL(Exp_Description))


    ! Initialise the test
    ! -------------------
    CALL Init_Test( UTest, &
                    TRIM(ADJUSTL(Exp_Description)), &
                    Caller     =PROGRAM_NAME, &
                    Message_Log=MESSAGE_LOG)


    ! Call the CRTM adjoint model
    ! ---------------------------
    CALL Begin_Timing( Timing )
    Error_Status = CRTM_Adjoint( Atm            , &
                                 Sfc            , &
                                 RTSolution_AD  , &
                                 GeometryInfo   , &
                                 ChannelInfo    , &
                                 Atm_AD         , &
                                 Sfc_AD         , &
                                 RTSolution     , &
                                 Options=Options  )
    CALL End_Timing( Timing )
    IF ( Error_Status /= SUCCESS ) THEN 
       CALL Display_Message( PROGRAM_NAME, &
                             'Error in CRTM Adjoint Model', & 
                              Error_Status)  
     STOP
    END IF
    CALL Display_Timing( Timing, &
                         Caller     =PROGRAM_NAME, &
                         Message_Log=MESSAGE_LOG )


    ! Output results
    ! --------------
    CALL Write_AtmSfc_TestFile( Exp_ID, Atm_AD, Sfc_AD )
    
    ! Test results for equality
    ! -------------------------
    IF ( Compare_Results ) THEN
      ! Read baseline results
      CALL Read_AtmSfc_TestFile( Exp_ID, Atm_Baseline, Sfc_Baseline )
    
      ! Compare them
      Atm_Status = CRTM_Equal_Atmosphere( Atm_Baseline, Atm_AD, &
                                          Percent_Difference=D_PERCENT, &
                                          Check_All=1 )
      CALL Assert_Equal(Atm_Status,SUCCESS,UTest)
      Sfc_Status = CRTM_Equal_Surface( Sfc_Baseline, Sfc_AD, &
                                       Percent_Difference=D_PERCENT, &
                                       Check_All=1 )
      CALL Assert_Equal(Sfc_Status,SUCCESS,UTest)
    END IF

  END DO


  ! Report all the test results
  ! ---------------------------
  CALL Report_AllTests( UTest, Message_Log=MESSAGE_LOG )


  ! Create successful completion signal
  ! file if there are no failed tests
  ! -----------------------------------
  IF ( n_Tests_Failed(UTest) == 0 ) THEN
    Error_Status = Create_SignalFile( PROGRAM_NAME, &
                                      Message_Log=MESSAGE_LOG ) 
    IF ( Error_Status /= SUCCESS ) THEN 
      CALL Display_Message( PROGRAM_NAME, &
                            'Error creating '//PROGRAM_NAME//' signal file', &
                             Error_Status, &
                             Message_Log=MESSAGE_LOG )
    END IF
  END IF
  
  
  ! Destroy the CRTM
  ! ----------------
  WRITE( *, '( /5x, "Destroying the CRTM..." )' )
  Error_Status = CRTM_Destroy( ChannelInfo )
  IF ( Error_Status /= SUCCESS ) THEN 
    CALL Display_Message( PROGRAM_NAME, &
                          'Error destroying CRTM', & 
                           Error_Status, &
                           Message_Log=MESSAGE_LOG )
  END IF


  ! --------
  ! Clean up
  ! --------
  Error_Status = CRTM_Destroy_Options(Options)
  Error_Status = CRTM_Destroy_RTSolution(RTSolution_AD)
  Error_Status = CRTM_Destroy_RTSolution(RTSolution)
  DEALLOCATE(RTSolution, RTSolution_AD, STAT=Allocate_Status)
  Error_Status = CRTM_Destroy_Surface(Sfc)
  Error_Status = CRTM_Destroy_Surface(Sfc_AD)
  Error_Status = CRTM_Destroy_Atmosphere(Atm)
  Error_Status = CRTM_Destroy_Atmosphere(Atm_AD)

END PROGRAM Test_Adjoint
