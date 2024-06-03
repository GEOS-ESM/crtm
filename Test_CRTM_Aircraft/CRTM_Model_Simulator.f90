!-------------------------------------------------------------------------------
! PURPOSE: A simple example for similating radiance for JPSS-2 instruments.
!        
! Quanhua Liu, NOAA/NESDIS Center for Satellite Applications and Research
!    quanhua.liu@noaa.gov        October 26, 2022
!-------------------------------------------------------------------------------
PROGRAM CRTM_Model_J2_Simulator
  USE CRTM_Module
  USE CRTM_Model_Profiles   , ONLY: MODEL_LEVEL_PRESSURE, CRTM_Get_Model_Profile 
  USE CRTM_SpcCoeff
  USE SpcCoeff_Define

  IMPLICIT NONE
  CHARACTER( * ), PARAMETER :: PROGRAM_NAME   = 'CRTM_Model_J2_Simulator'
  INTEGER :: Error_Status, L, i, k, kk, Allocate_Status, n_Channels
  INTEGER, PARAMETER :: N_PROFILES=1, n_Sensors = 1, M_nz = 97  !number of atmospheric levels  
  CHARACTER( 256 ) :: Sensor_ID(n_Sensors)
  CHARACTER( 256 ) :: AerosolCoeff_File,EmisCoeff_File,CloudCoeff_File,fixcrtm
  TYPE( CRTM_Atmosphere_type )   :: Atmosphere(1), Atmosphere_TL(1), Atmosphere_AD(1)
  TYPE( CRTM_Surface_type )      :: Surface(1), Surface_TL(1), Surface_AD(1)
    
  TYPE(CRTM_ChannelInfo_type)             :: ChannelInfo(N_SENSORS)
  TYPE(CRTM_Geometry_type)                :: Geometry(N_PROFILES)
  TYPE( CRTM_RTSolution_type ), ALLOCATABLE, DIMENSION( :,: ) :: RTSolution, RTSolution_TL, &
        RTSolution_AD
  TYPE( CRTM_Options_type )  :: Options(N_PROFILES)
  REAL(fp) :: level_p(0:M_nz),level_t(0:M_nz),le_absorber(0:M_nz,2),total_OD,u,tt

  REAL(fp), Allocatable :: transmittance(:)
  INTEGER :: mProfile
  INTEGER :: n_Layers, n_Absorbers, n_Clouds, n_Aerosols, chan_index

!  INTEGER, PARAMETER :: absorb_id(3)=(/ 1,3,2/)

  INTEGER :: Err_Atm, Err_Sfc, Ki
  INTEGER :: used_n_channel, n_channel, channel_index(1000), used_channel_index(1000)
!
  TYPE(CRTM_Atmosphere_type)  , DIMENSION(:,:), ALLOCATABLE       :: Atmosphere_K
  TYPE(CRTM_Surface_type)     , DIMENSION(:,:), ALLOCATABLE       :: Surface_K
  TYPE(CRTM_RTSolution_type)  , DIMENSION(:,:), ALLOCATABLE       :: RTSolution_K 
!
  PRINT *,' Please input sensor id, for example: atms_j2 , cris_j2 '
  PRINT *,' u.omps-npAllFOV_j2 , u.omps-tcAllFOV_j2 , '
  PRINT *,' viirs-i_j2 , viirs-m_j2 , v.viirs-i_j2 , v.viirs-m_j2 '
  READ(5,'(A)') Sensor_ID(1)


  Error_Status = CRTM_Init( Sensor_Id, ChannelInfo, File_Path='/data/smcd8/qliu/JPSS_CRTM_20221019/CRTM_coeff/')

  n_Channels = sum(CRTM_ChannelInfo_n_Channels(ChannelInfo(:))  ) 
  CALL CRTM_Options_Create( Options, n_Channels )

  print *,' number of channels = ',n_Channels,' for ',Sensor_ID(1)

  IF( trim(Sensor_ID(1)) == 'u.omps-npAllFOV_j2' .or. trim(Sensor_ID(1)) == 'u.omps-tcAllFOV_j2' ) THEN
    PRINT *,' input nFOV, if enter  0  then nadir FOV will be used '
!    READ(5,*)  Options(1)%nFOV
!    IF(  Options(1)%nFOV < 0 )  Options(1)%nFOV = 0
  END IF
!
   !  for a model profile under clear-sky condition.
   n_Layers = 97
   n_Clouds = 1
   n_Aerosols = 0
   n_Absorbers = 2             ! two absorbers, H2O & O3

  ! Allocate atmospheric arrays for atmospheric structure
  Allocate( transmittance(0:n_Layers) )
  CALL CRTM_Atmosphere_Create( Atmosphere,n_Layers, n_Absorbers, n_Clouds, n_Aerosols )
  CALL CRTM_Atmosphere_Create( Atmosphere_TL,n_Layers, n_Absorbers, n_Clouds, n_Aerosols )
  CALL CRTM_Atmosphere_Create( Atmosphere_AD,n_Layers, n_Absorbers, n_Clouds, n_Aerosols )  

  ALLOCATE( Atmosphere_K( n_Channels, n_Profiles ), &
            Surface_K( n_Channels, n_Profiles ), &
            STAT = Allocate_Status )

  IF ( Allocate_Status /= 0 ) THEN                                                       
    Allocate_Status = FAILURE                                                               
    CALL Display_Message( PROGRAM_NAME, &                                                
                          'Error allocating structure arrays Atm_K, Sfc_K & RTSolution_K', &                         
                           Allocate_Status)                                                 
    STOP                                                                                 
  END IF
  ! Allocate atmospheric arrays for atmospheric structure
  CALL CRTM_Atmosphere_Create( Atmosphere,n_Layers, n_Absorbers, n_Clouds, n_Aerosols )
  CALL CRTM_Atmosphere_Create( Atmosphere_TL,n_Layers, n_Absorbers, n_Clouds, n_Aerosols )
  CALL CRTM_Atmosphere_Create( Atmosphere_AD,n_Layers, n_Absorbers, n_Clouds, n_Aerosols )  


  CALL CRTM_Atmosphere_Create( Atmosphere_K,n_Layers, n_Absorbers, n_Clouds, n_Aerosols ) 

   print *,' input a number 1 to 6 for following standard profile '
   print *,' 1 :  TROPICAL '
   print *,' 2 :  MIDLATITUDE_SUMMER '
   print *,' 3 :  MIDLATITUDE_WINTER '
   print *,' 4 :  SUBARCTIC_SUMMER '
   print *,' 5 :  SUBARCTIC_WINTER '
   print *,' 6 :  US_STANDARD_ATMOSPHERE '

  READ(5, *) mProfile
  GET_Poption: SELECT CASE (mProfile)

  CASE (TROPICAL)
    Atmosphere(1)%Climatology = TROPICAL      ! using tropical atmosphere

  CASE (MIDLATITUDE_SUMMER)
    Atmosphere(1)%Climatology = MIDLATITUDE_SUMMER

  CASE (MIDLATITUDE_WINTER)
    Atmosphere(1)%Climatology = MIDLATITUDE_WINTER
   
  CASE (SUBARCTIC_SUMMER)
    Atmosphere(1)%Climatology = SUBARCTIC_SUMMER
   
  CASE (SUBARCTIC_WINTER)
    Atmosphere(1)%Climatology = SUBARCTIC_WINTER
   
  CASE (US_STANDARD_ATMOSPHERE)
    Atmosphere(1)%Climatology = US_STANDARD_ATMOSPHERE

  CASE DEFAULT
    Atmosphere(1)%Climatology = US_STANDARD_ATMOSPHERE  
  END SELECT GET_Poption

    Atmosphere(1)%Absorber_Id    = (/ H2O_ID, O3_ID /)
    Atmosphere(1)%Absorber_Units = (/ MASS_MIXING_RATIO_UNITS,VOLUME_MIXING_RATIO_UNITS /)

    Atmosphere(1)%level_pressure(0) = 0.005_fp

   !  -- CALL CRTM ROUTINE TO GET MODEL ATMOSPHERE --
   CALL CRTM_Get_Model_Profile(Atmosphere(1)%Absorber_Id, level_p,level_t,le_Absorber, &
                                Model=Atmosphere(1)%Climatology)

   ! -- SUM OF CHANNELS FROM ALL SENSORS AND ALLOCATE OUTPUT RTSolution --
   ALLOCATE( RTSolution( n_Channels,N_PROFILES ), STAT = Allocate_Status )  

   ! open an array for holding optical depth
   CALL CRTM_RTSolution_Create( RTSolution, Atmosphere(1)%n_Layers )

  ALLOCATE( RTSolution_TL( n_Channels,N_PROFILES ), STAT = Allocate_Status ) 
  CALL CRTM_RTSolution_Create( RTSolution_TL, Atmosphere(1)%n_Layers )
  ALLOCATE( RTSolution_AD( n_Channels,N_PROFILES ), STAT = Allocate_Status ) 
  CALL CRTM_RTSolution_Create( RTSolution_AD, Atmosphere(1)%n_Layers )
  ALLOCATE( RTSolution_K( n_Channels,N_PROFILES ), STAT = Allocate_Status ) 
  CALL CRTM_RTSolution_Create( RTSolution_K, Atmosphere(1)%n_Layers )


   !  -- SETTING GEOMETRY PARAMETERS --
   Geometry(1)%Source_Zenith_Angle  = 30.0_fp  !150.00_fp   ! >= 90 at night
   Geometry(1)%Sensor_Zenith_Angle  = ZERO 
   Geometry(1)%Sensor_Scan_Angle  = ZERO   ! 400 km above the height

   ! needed for Cross-scan MW sensors
   Geometry(1)%Sensor_Azimuth_Angle = 0.0_fp   ! needed for WINDSAT sensor
   Geometry(1)%Source_Azimuth_Angle = 150.0_fp ! needed by IR sensors for day time

   !  -- CONSTRUCT LAYER VALUES FROM LEVEL VALUES --
   Atmosphere(1)%Level_Pressure(0) = 0.005_fp
   Layer_Loop: DO kk = 1, Atmosphere(1)%n_Layers
     i = kk 
     Atmosphere(1)%Level_Pressure(kk) = level_p(i)
     Atmosphere(1)%Temperature(kk) = (level_t(i-1)+level_t(i))/2.0_fp
     Atmosphere(1)%Pressure(kk)    = (level_p(i-1)+level_p(i))/2.0_fp
     
     Absorber_Loop: DO k = 1, Atmosphere(1)%n_Absorbers
       IF( k <= 2 ) THEN
         Atmosphere(1)%Absorber(kk,k)=(le_absorber(i-1,k)+le_absorber(i,k))/2.0_fp
       ELSE
         Atmosphere(1)%Absorber(kk,k)= 382.5  !1.75 
       END IF
     END DO Absorber_Loop
   END DO Layer_Loop
  
   !  -- SETTING SURFACE PARAMETERS --
   Surface(1)%Water_Type = 1 
   Surface(1)%Land_Coverage = 0.0_fp
   Surface(1)%Water_Coverage = 1.0_fp
   Surface(1)%Snow_Coverage = 0.0_fp
   Surface(1)%Ice_Coverage = 0.0_fp
   Surface(1)%Water_Temperature = level_t( n_Layers )
   Surface(1)%Land_Temperature = level_t( n_Layers )
   Surface(1)%Wind_Speed = 7.1_fp
   Surface(1)%Wind_Direction = 120.5018_fp
   Surface(1)%Salinity = 33.0_fp


!    Options(1)%RT_Algorithm_Id = RT_ADA !RT_VMOM  !RT_SOI  !RT_ADA 

    Options(1)%Use_Emissivity = .TRUE.
    Options(1)%Use_Direct_Reflectivity = .TRUE.
    Options(1)%Emissivity(:) = (ONE-0.4)
    Options(1)%Direct_Reflectivity(:) = (ONE-Options(1)%Emissivity(:)) !* PI  


    Options(1)%Aircraft_Pressure = Atmosphere(1)%level_pressure(80)

   print *,' Aircraft ',Atmosphere(1)%level_pressure(80),Atmosphere(1)%temperature(80)
!    Options(1)%obs_4_downward_P = ZERO
    
     IF( Atmosphere(1)%n_Clouds > 0 ) THEN
       Atmosphere(1)%Cloud_Fraction(:) = ONE
       Atmosphere(1)%Cloud(1)%Type = RAIN_CLOUD
       Atmosphere(1)%Cloud(1)%Effective_Radius(90) = 500.0_fp
       Atmosphere(1)%Cloud(1)%Effective_Variance(90) = 2.0_fp
       Atmosphere(1)%Cloud(1)%Water_Content(90) = 0.3
   print *,' Cloud ',Atmosphere(1)%level_pressure(89),Atmosphere(1)%level_pressure(90),&
         Atmosphere(1)%temperature(90)
   
     END IF

     IF( Atmosphere(1)%n_Clouds > 1 ) THEN
       Atmosphere(1)%Cloud(2)%Type = SNOW_CLOUD
       Atmosphere(1)%Cloud(2)%Effective_Radius(60) = 300.0_fp
       Atmosphere(1)%Cloud(2)%Effective_Variance(60) = 2.0_fp
       Atmosphere(1)%Cloud(2)%Water_Content(60) = 0.3
     END IF     

   tt = 28.9644/47.9982 * 0.021415
    total_od = 0.0
    DO K = 1, Atmosphere(1)%n_Layers
    total_od = total_od + Atmosphere(1)%Absorber(k,2)/tt* &
        (Atmosphere(1)%Level_Pressure(k)-Atmosphere(1)%Level_Pressure(k-1))/9.8/10.0
    END DO
! normalize O3 to 300 DU    
    Atmosphere(1)%Absorber(:,2) = Atmosphere(1)%Absorber(:,2)*300.d0/total_od
    
    Geometry(1)%Sensor_Zenith_Angle = 50.0
    print *,' column ozone = ',total_od
  print *,' n_Clouds ',n_Clouds,Geometry(1)%Sensor_Zenith_Angle
   u = cos( Geometry(1)%Sensor_Zenith_Angle*3.14159/180.0)

  ! ---------------------------------------------------------
  ! ***********  nFOV is only used for OMPS   **************

  print *,' atm ',Atmosphere(1)%level_pressure(80),Atmosphere(1)%pressure(80), &
      Atmosphere(1)%Temperature(80)

  write(60,'(2I10)') n_Channels, Atmosphere(1)%n_layers
  DO k = 1,  Atmosphere(1)%n_layers
    write(60,'(I5,3f10.3,E15.6)') k, Atmosphere(1)%level_pressure(k),Atmosphere(1)%pressure(k), &
        Atmosphere(1)%Temperature(k),Atmosphere(1)%Absorber(k,1)
  END DO

   Error_Status = CRTM_Forward( Atmosphere , &  
                               Surface    , & 
                               Geometry   , &  
                               ChannelInfo, &  
                               RTSolution,  &
                               Options = Options )
  IF( SpcCoeff_IsUltravioletSensor(SC(1)).or.SpcCoeff_IsVisibleSensor(SC(1)) ) THEN
    PRINT *,' UV or Visible Sensor'
  print *,'  channel     wavelength    Radiance    solarIrradiance   Radiance/sIrradiance'
    DO k = 1, n_Channels
!!      write(6,'(I5,8x,f12.5,2ES14.5,3ES17.5)') k,10000.0/SC(1)%wavenumber(k),RTSolution(k,1)%Radiance, &
!!        RTSolution(k,1)%SolarIrradiance,RTSolution(k,1)%Radiance/RTSolution(k,1)%SolarIrradiance
    END DO
  ELSE IF( SpcCoeff_IsInfraredSensor(SC(1)) ) THEN
  print *,'  channel     wavenumber    Radiance    Brightness Temperature '
    DO k = 1, n_Channels
      write(6,'(I5,8x,f12.5,ES14.5,f12.5)') k,SC(1)%wavenumber(k),RTSolution(k,1)%Radiance, &
         RTSolution(k,1)%Brightness_Temperature
      write(60,'(I5,f12.5,ES14.5,f12.5)') k,SC(1)%wavenumber(k),RTSolution(k,1)%Radiance, &
         RTSolution(k,1)%Brightness_Temperature
    END DO  
  ELSE IF( SpcCoeff_IsMicrowaveSensor(SC(1)) ) THEN  
  print *,'  channel     Frequency    Radiance    Brightness Temperature '
    DO k = 1, n_Channels
      write(6,'(I5,6x,f12.5,ES14.5,f12.5)') k,SC(1)%Frequency(k),RTSolution(k,1)%Radiance,RTSolution(k,1)%Brightness_Temperature
    END DO
  END IF  
!

  IF( k > 0 ) STOP
!
      CALL CRTM_RTSolution_Zero( RTSolution_K )
      RTSolution_K(:,1)%Brightness_Temperature    = ONE
      RTSolution_K(:,1)%Radiance = ZERO

     Error_Status = CRTM_K_Matrix( Atmosphere , &  
                               Surface    , & 
                               RTSolution_K(:,1:1)  , &  ! K   Input
                               Geometry   , &  
                               ChannelInfo, &  
                               Atmosphere_K , &  ! K   Output
                               Surface_K  , &  ! K   Output
                               RTSolution , &  ! FWD Output
                           Options = Options ) 
    transmittance(0) = 1.0
    DO k = 1, Atmosphere(1)%n_Layers
    tt = exp(-RTSolution(1,1)%Layer_Optical_Depth(k)/u)
      transmittance(k) = transmittance(k-1) * tt
    END DO
    DO k = 1, Atmosphere(1)%n_Layers
      tt = Atmosphere(1)%Level_Pressure(k)-Atmosphere(1)%Level_Pressure(k-1)
      u = log(Atmosphere(1)%Level_Pressure(k)/Atmosphere(1)%Level_Pressure(k-1))
!      write(6,511) k,Atmosphere(1)%Level_Pressure(k),Atmosphere(1)%Temperature(k), &
!      Atmosphere_K(1,1)%Temperature(k),Atmosphere(1)%Absorber(k,1), &
!      Atmosphere_K(1,1)%Absorber(k,1),transmittance(k), &
!      (transmittance(k-1)-transmittance(k))/tt,(transmittance(k-1)-transmittance(k))/u
    END DO
 511 FORMAT(I5,3f12.5,5E12.4)
   Error_Status = CRTM_Destroy( ChannelInfo )
END PROGRAM CRTM_Model_J2_Simulator
!   
