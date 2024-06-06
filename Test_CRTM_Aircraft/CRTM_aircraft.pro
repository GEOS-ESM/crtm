;
PRO plot_crtm_aircraft, ps=ps

; The data in crtm_aircraft_result.dat were copied and pased from
;  fort.60 (output of "CRTM_Model_Simulator" fot atms_j2 and TROPICAL
;  from BT on screen,
; and copied & pasted BT for "old" (comment out lines 316 and 317 in ADA_Module.f90
; and remove the "!" from lines 320 to 326
input_file = 'crtm_aircraft_result.dat'
 openr, lun, input_file, /get_lun
 n_channels = 0L  &  n_layers = 0L
 readf, lun, n_channels,  n_layers
 freq = fltarr(n_channels)
 channel_index = fltarr(n_channels)
 Tradiance = fltarr(n_channels, 2)
 TBT = fltarr(n_channels, 2)
 radiance_up = fltarr(n_channels, n_layers, 2)
 BT_up = fltarr(n_channels, n_layers, 2)
 radiance_down = fltarr(n_channels, n_layers, 2)
 BT_down = fltarr(n_channels, n_layers, 2)


  lev_p = fltarr(n_layers)  &  p = fltarr(n_layers)  &  T = fltarr(n_layers)  &  h2o = fltarr(n_layers)
   i = 0L  & data4 = fltarr(4) & data5 = fltarr(5)
  for k = 0, n_layers-1 do begin
    readf, lun, i, data4
    lev_p[k] = data4[0]
    p[k] = data4[1]
    T[k] = data4[2]
    h2o[k] = data4[3]
  endfor

  for k = 0, n_channels-1 do begin
    readf, lun, i, data5
    channel_index[k] = i + 1
    freq[k] = data5[0]
    Tradiance[k,0] = data5[1]
    TBT[k,0] = data5[2]
    Tradiance[k,1] = data5[3]
    TBT[k,1] = data5[4]
  endfor

  for k = 0, n_channels-1 do begin
    for j = 0, n_layers-1 do begin
    readf, lun, i, data4
     radiance_up[k,j,0] = data4[0]
     radiance_up[k,j,1] = data4[1]
     radiance_down[k,j,0] = data4[2]
     radiance_down[k,j,1] = data4[3]
     BT_up[k,j,*] = radiance_up[k,j,*]/Tradiance[k,0]*TBT[k,0]
     BT_down[k,j,*] = radiance_down[k,j,*]/Tradiance[k,0]*TBT[k,0]
    endfor
  endfor
  FREE_LUN, lun


  if ( keyword_set(ps) ) then begin
    psfilename='liu1.eps'
   print,' file = ',psfilename
    SET_PLOT, 'PS'
    device, /encapsul, bits_per_pixel=8, /COLOR, $
       filename=psfilename, /PORTRAIT, xsize=8, ysize=9,/inches
    !p.font = 1
  endif


  Fig_no = 1

 IF Fig_no eq 1 THEN BEGIN
  cgPlot, channel_index, TBT[0:n_channels-1,0], Background='ivory', AxisColor='black', Color='Black',xstyle=1,ystyle=1, $
      XTICKFORMAT='(I4)', CHARSIZE=1.2,Xtitle='channel', Ytitle='Brightness Temperature (K)',$
       title='ATMS Aircraft Simulation ', $
       YRANGE=[200, 300], XRANGE=[1,22], XTICKINTERVAL=10, /NOERASE, position = [0.15, 0.07, 0.90, 0.94]

  cgoPlot, channel_index, TBT[0:n_channels-1,1], Color='red',linestyle=2
  cgAxis, YAxis=1, Ystyle=1, YRange=[-1, 60], ytitle=' BTnew - BT (K)',/Save
  cgoPlot, channel_index, TBT[*,0]-TBT[*,1], Color='green'

;  cgtext, 1990, 3.7, 'surface pressure ',Color='black',CHARSIZE=1.5
;  cgtext, 1983, 3.5, 'surface pressure trend = 0.0649 hPa/decade',Color='black',CHARSIZE=1.5
;  cgtext, 1990, 2.0, 'total water vapor pressure (right y-axis)',Color='green',CHARSIZE=1.5
 ENDIF ELSE BEGIN

  cgPlot, BT_up[3,*,0], lev_p, Background='ivory', AxisColor='black', Color='Black',xstyle=1,ystyle=1, $
      XTICKFORMAT='(I4)', CHARSIZE=1.2,Xtitle='Brightness Temperature (K)', Ytitle='Pressure (hPa)',$
       title='Upward radiance profiles ATMS ch. 4 ', $
       YRANGE=[1020, 0.01], XRANGE=[230, 300], XTICKINTERVAL=10, /NOERASE, position = [0.15, 0.07, 0.90, 0.94]

  cgoPlot, BT_up[3,*,1], lev_p, Color='red',linestyle=2
;  cgAxis, YAxis=1, Ystyle=1, YRange=[-1, 60], ytitle=' BTnew - BT (K)',/Save
;  cgoPlot, channel_index, TBT[*,0]-TBT[*,1], Color='green'

;  cgtext, 1990, 3.7, 'surface pressure ',Color='black',CHARSIZE=1.5
;  cgtext, 1983, 3.5, 'surface pressure trend = 0.0649 hPa/decade',Color='black',CHARSIZE=1.5
;  cgtext, 1990, 2.0, 'total water vapor pressure (right y-axis)',Color='green',CHARSIZE=1.5

 print,' BT ',BT_up[3,80,*], BT_down[3,80,*]
 ENDELSE

  if keyword_set(ps) then begin
    print,' in ps '
    DEVICE, /CLOSE
    SET_PLOT, 'X'
     print,' generate PS file '
    spawn, 'convert -density 256x256 -quality 100 ' + psfilename + ' ' $
      + 'test4' + '.png'
  endif else begin 
    image = TVRD(/TRUE)
;    image = Reverse(image, 3)
    WRITE_PNG, 'test.png', image
  endelse



END
