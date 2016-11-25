;+
; NAME:
;      ACS_TRAP_SPECIES
;
; CATEGORY:
;      Pixel-by-pixel correction of trailing due to charge transfer inefficiency in CCD
;      detectors.
;
; PURPOSE:
;      Model the density of charge traps (defects in the silicon substrate) in the HST
;      Advanced Camera for Surveys. The density grows over time.
;
; INPUTS:
;      DATES - Either a single floating point number or an array, which is the Modified
;              Julian Date(s) of interest.
;
; OPTIONAL INPUTS:
;      PARAMS- Shorthand alternative notation to enter following three parameters.
;      INITIA- Initial model density of charge traps per pixel on launch.
;      PERMAN- Rate of increase of traps per pixel per day that are permanent.
;      REMOVA- Rate of increase of traps per pixel per day that get fixed at next anneal.
;      ANNEAL- List of (MJD) dates when CCD was annealed DEFAULT: read in from file.
;      LAUNCH- Launch (MJD) date of camera DEFAULT: 2452334.5
;
; KEYWORD PARAMETERS:
;      None.
;
; OUTPUTS:
;      The density of charge traps per pixel on each date.
;      For the default model, this is the total density of traps; the density of traps with
;      release time tau=10.4 pixels is 3/4 that, and the density of traps with tau=0.88 pixels 
;      is that 1/4 that.
;
; MODIFICATION HISTORY:
;      Sep 10 - Updated by RM for post-SM4 observations with tau a function of temperature.
;      May 10 - Updated by RM for post-SM4 observations 
;      Jul 09 - Need to read in an external file removed by RM, since no effect of anneals.
;      Jul 08 - Written by Richard Massey.
;-

; Read in a list of the dates (MJD) when ACS was annealed to remove charge traps. LEGACY CODE.
function acs_find_anneals
;anneal_file="~/idl/cte/ACS_anneal_dates.txt"
;if not file_test(anneal_file) then message,"Cannot find list of anneal dates "+anneal_file
;readcol,anneal_file,format="A,I,I,I,I,I",month_string,day,year,hour,minute,second,/SILENT
;n_dates=n_elements(month_string) & if n_dates le 1 then message,"File format not recognised for list of anneal dates "+anneal_file
;month=intarr(n_dates) & for i=0,n_dates-1 do month[i]=where(strmatch(["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],month_string[i]))+1
year=[2003,2003,2003,2003,2004,2004,2004,2004,2004,2004,2004,2004,2004,2004,2004,2004,2004,2004,2005,2005,2005,2005,2005,2005,2004,2005,2005,2005,2005,2005,2005,2005,2005]
month=[9,10,11,12,1,1,3,3,4,5,6,7,8,9,10,11,12,12,1,3,3,4,5,2,7,6,7,8,9,10,11,11,12]
day=[9,12,6,1,4,30,4,27,25,22,18,14,10,8,8,5,2,30,29,4,24,19,20,12,6,12,16,11,9,8,3,25,31]
hour=[8,7,15,15,9,1,1,0,21,7,4,16,4,6,9,19,14,12,11,22,9,7,5,9,16,22,7,20,8,10,15,8,4]
minute=[34,9,11,48,1,8,21,59,31,34,36,52,41,1,5,42,11,40,0,55,12,33,0,4,28,35,58,37,45,6,20,37,30]
second=[58,36,6,13,30,26,4,38,0,57,37,5,59,41,45,53,50,0,0,30,24,57,0,52,51,22,20,49,56,47,0,56,0]
jdcnv,year,month,day,hour+minute/60.+second/360.,dates
return, dates
end

; ************************************************************************

pro acs_trap_species, DATES, TRAP_RELEASE_TIME, TRAP_DENSITY,                    $
                      OPERATING_TEMPERATURE=operating_temperature,               $
                      TRAP_INITIAL_DENSITY=trap_initial_density,                 $
                      TRAP_PERMANENT_RATE=trap_permanent_rate,                   $
                      TRAP_REMOVABLE_RATE=trap_removable_rate,                   $
                      ANNEAL_DATES=anneal_dates,                                 $
                      LAUNCH_DATE=launch_date,                                   $
                      TEMPERATURE_DATE=temperature_date,                         $
                      REPAIR_date=REPAIR_DATE, JAVA=java

COMPILE_OPT idl2

; Parse inputs
n_dates=n_elements(dates) & if n_dates lt 1 then message,"Please specify the date of observation!"
if keyword_set(trap_removable_rate)  then message,"Accumulation of traps that are removed at the next annealing is no longer supported"
if not keyword_set(launch_date)      then launch_date=2452334.5      ; Date of SM3B when ACS was installed
if not keyword_set(temperature_date) then temperature_date=2453920.0 ; Date of temperature decrement
if not keyword_set(repair_date)      then repair_date=2454968L       ; Date of SM4 when ACS was repaired
if keyword_set(trap_initial_density) then trap_initial_density_presm4 =trap_initial_density else trap_initial_density_presm4=0.017845
if keyword_set(trap_permanent_rate)  then trap_growth_rate_presm4     =trap_permanent_rate  else trap_growth_rate_presm4=3.5488e-4
; Values according to Massey (2010)
;if keyword_set(trap_initial_density) then trap_initial_density_postsm4=trap_initial_density else trap_initial_density_postsm4=0.404611;1.17698
;if keyword_set(trap_growth_rate)     then trap_growth_rate_postsm4    =trap_growth_rate     else trap_growth_rate_postsm4=2.93286e-4
; Given to Tim Schrabback, Dec 2012
;if keyword_set(trap_initial_density) then trap_initial_density_postsm4=trap_initial_density else trap_initial_density_postsm4=-0.159069  *1.07 ; Final first-order correction to account for residual
;if keyword_set(trap_permanent_rate)  then trap_growth_rate_postsm4    =trap_permanent_rate  else trap_growth_rate_postsm4=0.000491395    *1.07 
if keyword_set(java) then begin
  ; Updated for Massey et al. (2013) WITH JAVA SLOW MEASUREMENT
  if keyword_set(trap_initial_density) then trap_initial_density_postsm4=trap_initial_density else trap_initial_density_postsm4=-0.246591 *1.011
  if keyword_set(trap_permanent_rate)  then trap_growth_rate_postsm4    =trap_permanent_rate  else trap_growth_rate_postsm4=0.000558980   *1.011
endif else begin
  ; Updated for Massey et al. (2013)
  if keyword_set(trap_initial_density) then trap_initial_density_postsm4=trap_initial_density else trap_initial_density_postsm4=-0.246591 *1.011
  if keyword_set(trap_permanent_rate)  then trap_growth_rate_postsm4    =trap_permanent_rate  else trap_growth_rate_postsm4=0.000558980   *1.011
endelse
sm4_trap_release_time=[0.74,7.7,37] ; pixels
; Values according to Massey (2010)
; ...and given to Tim Schrabback, Dec 2012
sm4_trap_ratio=[0.18,0.61,0.51]     ; relative densities
; Updated for Massey et al. (2013)
sm4_trap_ratio=[1.27,3.38,2.85]     ; relative densities
sm4_temperature=273.15-81           ; K
k=8.617343e-5                       ; eV/K
DeltaE=[0.31,0.34,0.44]             ; eV
n_species=n_elements(sm4_trap_release_time)

; Prepare empty variables to contain the answers
trap_release_time=fltarr(n_dates,3)
trap_density=fltarr(n_dates,3)

; Work out operating temperature during each observation
if not keyword_set(operating_temperature) then begin
  operating_temperature=fltarr(n_dates)
  warm=where(dates lt temperature_date,n_warm) & if n_warm gt 0 then operating_temperature[warm]=273.15-77
  cold=where(dates ge temperature_date,n_cold) & if n_cold gt 0 then operating_temperature[cold]=273.15-81
endif
if n_elements(operating_temperature) eq 1 and n_dates gt 1 then operating_temperature=replicate(operating_temperature,n_dates)

; Trap release time propto exp(DeltaE/kT)/T^2
trap_release_time=sm4_trap_release_time##replicate(1.,n_dates) * $
                  (operating_temperature#replicate(1.,n_species)/sm4_temperature)^2 * $
                  exp(DeltaE##replicate(1.,n_dates)/(k*sm4_temperature*operating_temperature#replicate(1.,n_species)) * $
                     (operating_temperature#replicate(1.,n_species)-sm4_temperature))

; Work out total trap densities at each observation
presm4=where(dates lt repair_date,n_presm4)
if n_presm4 gt 0 then trap_density[presm4,*]=trap_initial_density_presm4+trap_growth_rate_presm4*(dates[presm4]-launch_date)#replicate(1.,n_species)
postsm4=where(dates ge repair_date,n_postsm4)
; Corrected June 2010
;if n_postsm4 gt 0 then trap_density[postsm4,*]=trap_initial_density_postsm4+trap_growth_rate_postsm4*(dates[postsm4]-repair_date)#replicate(1.,n_species)
if n_postsm4 gt 0 then trap_density[postsm4,*]=trap_initial_density_postsm4+trap_growth_rate_postsm4*(dates[postsm4]-launch_date)#replicate(1.,n_species)

; Split traps between the species
trap_density=trap_density*(sm4_trap_ratio##replicate(1.,n_dates))/total(sm4_trap_ratio)

; Report to world
message,/INFO,"Model has "+strtrim(total(trap_density[0,*]),2)+" traps per pixel, "+strtrim(dates[0]-launch_date,2)+" days after launch."

end
