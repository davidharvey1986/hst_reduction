pro acs_clock_charge, FILE_INPUT, FILE_OUTPUT, $
                      IMAGE=image, $
                      HEADER=header, $
                      UNCLOCK=unclock, $
                      WELL_DEPTH=well_depth, $
                      WELL_NOTCH_DEPTH=well_notch_depth, $
                      WELL_FILL_POWER=well_fill_power, $
                      TRAP_DENSITY=trap_density, $
                      TRAP_LIFETIME=trap_lifetime, $
                      TRAP_LOCATION_SEED=trap_location_seed, $
                      TRAP_DECAY_SEED=trap_decay_seed, $
                      TRAP_INITIAL_DENSITY=trap_initial_density, $
                      TRAP_PERMANENT_RATE=trap_permanent_rate, $
                      TRAP_REMOVABLE_RATE=trap_removable_rate, $
                      TRAP_POOLING=trap_pooling, $
                      MARGINAL_TRAP=marginal_trap, $
                      XRANGE=xrange, YRANGE=yrange, $
                      QUANTIZE_TRAPS=quantize_traps, $
                      QUANTIZE_CHARGE=quantize_charge, $
                      DATE=DATE, $
                      N_ITERATIONS=n_iterations, $
                      N_LEVELS_INPUT=n_levels_input, $
                      N_PHASES=n_phases, $
                      ACTIVE_PHASE=active_phase, $
                      KEEP_TEMP_FILES=keep_temp_files, $
                      EXPRESS=express, $
                      CDM03=cdm03, $
                      JAVA=java, $
                      DIR_JAVA=dir_java, $
                      PID=pid

;+
; NAME:
;      ACS_CLOCK_CHARGE
;
; CATEGORY:
;      Pixel-by-pixel correction of trailing due to charge transfer inefficiency in CCD detectors.
;
; PURPOSE:
;      Add or remove image trailing due to charge transfer inefficiency (CTI) in CCD detectors.
;      To add trails, this simply acts as an IDL wrapper for Chris Stoughton's CCD readout code,
;      which is written in Java. However, removal requires iteration within IDL. If a whole set
;      of images need correcting, this routine can also farm out the operation to a cluster node
;      and then return. A wrapper routine should therefore repeatedly call this one with new
;      file names.
;
; NOTES:
;      In some configurations (esp involving java), this spawns all sorts of UNIX child processes.
;      That is very unlikely to ever work on Windows machines or anything like that. 
;
; INPUTS:
;      FILE_INPUT  - String containing the absolute file name a (single) input FITS image.
;      FILE_OUTPUT - String containing the absolute file name for the desired output image.
;      IMAGE       - Optionally, input the image array (then date must also be specified, and
;                    a fits header if an output file is desired with more than a basic header).
;
; KEYWORD PARAMETERS:
;      UNCLOCK     - Undo the CCD readout, rather than doing it.
;      CLUSTER_FARM- Run, in the background, on a free processor from a cluster.
;                    NB: SSH public/private keys need to be set up so that it is possible to
;                        log into the target nodes without interatively entering a password.
;                    NB: Once the process starts, this routine returns, and IDL moves on
;                        to the next task. No reporting is done when the image is ready!
;                    Clashes between temporary file names should not occur, so long as input
;                    images are not processed twice simultaneously.
;      KEEP_TEMP_FI- Do not delete temporary files an difference images (only relevant during
;                    unclocking).
;      JAVA        - Use Chris Stoughton's external Java code to implement clocking.
;      EXPRESS     - If set, use Jay Anderson's trick to speed up runtime.
;
; OPTIONAL INPUTS:
;      DIR_JAVA    - String containing the directory with Chris's ClockCharge Java code.
;      EXPRESS     - Can be >1 to improve nonlinear performance of Jay's algortihm.
;      TRAP_POOLING- Set to 1 to implement CDM-like coarse trap management.
;      N_ITERATIONS- Number of iterations used if unclocking the CCD readout.
;                    Residuals of order N+1 will remain.
;      N_PHASES    - Number of (equally timed) phases of the cycle to clock one row of pixels.
;                    Traps are equally spread through the corresponding region of silicon. 
;      ACTIVE_PHASE- In which phase electrons are initially collected (this is assumed to be only one of the
;                    phases). If ACTIVE_PHASE=N_PHASES-1, results are identical to N_PHASES=1
;      WELL_DEPTH  - Depth of CCD pixel [electrons].
;      WELL_NOTCH_D- Depth of supplementary buried channel in each pixel [electrons].
;      WELL_FILL_PO- Describes rate at which pixel well fills up above the notch.
;      TRAP_DENSITY- Scalar or array containing 3D density of (each species of) charge trap.
;      TRAP_LIFETIM- Scalar or array containing characteristic release timescale for 
;                    (each species of) charge trap. This is the 1/e NOT half-life.
;      TRAP_LOCATIO- Random seed used to initally scatter charge traps about the CCD.
;      TRAP_DECAY_S- Random seed used to decide when traps release charge.
;      X/YRANGE    - [minimum,maximum] pixel number to clock.
;
; OUTPUTS:
;      A new FITS image is written to FILE_OUTPUT.
;
; OPTIONAL OUTPUTS:
;      PID         - The ID number of the child process managing a farmed-out job. Note that
;                    the returned value can be systematically lower than the actual process ID, 
;                    due to any any extra processes started when a new shell is initialised.
;
; PROCEDURES USED:
;      Various FITSIO routines from the IDL Astronomy Users' Library are required, including
;      fits_read.pro, fits_write.pro and sxaddpar.pro
;
; MODIFICATION HISTORY:
;      Aug 13 - V1.6 Double subtraction of notch_depth bug fixed by Oliver Corders & TRAP_POOLING and MARGINAL_TRAP options added by RM.
;      Dec 12 - V1.5 Improved well filling model (and trap densities) using latest HST data by RM.
;      Oct 10 - V1.4 IDL version of clocking (using Jay's "EXPRESS" trick for speed) completed by RM.
;      May 10 - V1.3 clocking begun to be internalised, and option to input image array added by RM.
;      Mar 10 - V1.2 option to keep temporary files added by RM.
;      Oct 09 - V1.1 dir_java correctly parsed for unclocking, and move of all cluster control code to acs_correct_cte completed by RM.
;      Jul 09 - V1.0 used by RM for COSMOS v2.0 images and analysis in Massey et al. (2010).
;      Mar 09 - V0.3 but with new parameters and allowing negative pixels by RM.
;      Jul 08 - V0.3 used by RM for first pass of the COSMOS correction (which was flawed and never went public).
;      Jun 08 - CLUSTER_LOCAL option added by RM.
;      Mar 08 - CLUSTER options added by RM.
;      Feb 08 - Written by Richard Massey.
;-

; Version numbering
version="v1.6 - Aug 2013"

; Parse inputs
if n_elements(n_iterations) eq 0        then n_iterations=3
if not keyword_set(well_depth)          then well_depth=84700
if not keyword_set(well_notch_depth)    then well_notch_depth=1e-9;96.5
if not keyword_set(well_fill_power)     then well_fill_power=0.478;0.465;0.576
if not keyword_set(trap_location_seed)  then trap_location_seed=12
if not keyword_set(trap_decay_seed)     then trap_decay_seed=13
if not keyword_set(n_phases)            then n_phases=1 else n_phases=round(n_phases)
if not keyword_set(dir_java)            then dir_java="~/bin/CTE/snapSim-current-20090328.230001/"
if keyword_set(trap_pooling) then begin & n_levels=1 & message,/info,"Trap pooling to speed up runtime" & endif


; File handling
if keyword_set(image) then message,/INFO,(["Adding","Removing"])[keyword_set(unclock)]+" CTI trails" else if keyword_set(file_input) then begin
  if not file_test(file_input) then message,"Input file does not exist!"
  message,/INFO,(["Adding CTI trails to ","Removing CTI trails from "])[keyword_set(unclock)]+file_input
  fits_read,file_input,image,header
endif else message,"No input image supplied!"
if keyword_set(keep_temp_files) then message,/INFO,"Keeping temporary files"
if not keyword_set(file_output) then message,/INFO,"No output file will be written!" else if file_test(file_output) then message,/INFO,"CAUTION: output file "+file_output+" will be overwritten!"


if keyword_set(unclock) then begin

  ; Pick up where interrupted
  if keyword_set(file_input) then temp_files=file_search(file_dirname(file_input,/mark_directory)+file_basename(file_input,".fits")+"_model?.fits") else temp_files=""
  if temp_files[0] ne "" then begin
    message,/INFO,"Found preexisting files "+temp_files
    temp_file_input=(reverse(temp_files))[0] ; select highest iteration reached so far
    first_iteration=fix(strmid(temp_file_input,5,1,/reverse_offset))
    fits_read,temp_file_input,model,header
    model=double(model)
    message,/INFO,"Resuming with iteration "+strtrim(first_iteration,2)+"/"+strtrim(n_iterations,2)
  endif else begin
    model=double(image)
    first_iteration=1
  endelse
  
  ; Iterate to a model that, when trailed, most closely resembles the observed image
  for iteration=first_iteration,n_iterations do begin
    message,/INFO,"Iteration "+strtrim(iteration,2)+"/"+strtrim(n_iterations,2)
    sxaddpar,header,"CTE_ITER",iteration," Number of iterations used during CTE correction"
    if min(model) lt 0 then message,"Image contains negative pixels!",/INFO
    model_readout=model
    if keyword_set(java) or keyword_set(keep_temp_files) then begin
     ;if not keyword_set(file_input) then file_input="~/temp.fits" 
      temp_file_input=file_dirname(file_input,/mark_directory)+file_basename(file_input,".fits")+"_model"+strtrim(iteration,2)+".fits"
      temp_file_output=file_dirname(file_input,/mark_directory)+file_basename(file_input,".fits")+"_modelread"+strtrim(iteration,2)+".fits"
      temp_file_residual=file_dirname(file_input,/mark_directory)+file_basename(file_input,".fits")+"_modelresidual"+strtrim(iteration,2)+".fits"
    endif
    acs_clock_charge, temp_file_input, temp_file_output, $
                      IMAGE=model_readout, $
                      WELL_DEPTH=well_depth, $
                      WELL_NOTCH_DEPTH=well_notch_depth, $
                      WELL_FILL_POWER=well_fill_power, $
                      TRAP_DENSITY=trap_density, $
                      TRAP_INITIAL_DENSITY=trap_initial_density, $
                      TRAP_PERMANENT_RATE=trap_permanent_rate, $
                      TRAP_REMOVABLE_RATE=trap_removable_rate, $
                      TRAP_LIFETIME=trap_lifetime, $
                      TRAP_LOCATION_SEED=trap_location_seed, $
                      TRAP_DECAY_SEED=trap_decay_seed, $
                      XRANGE=xrange, YRANGE=yrange, $
                      QUANTIZE_TRAPS=quantize_traps, $
                      QUANTIZE_CHARGE=quantize_charge, $
                      DATE=DATE, $
                      N_LEVELS=n_levels, $
                      N_PHASES=n_phases, $
                      KEEP_TEMP_FILES=0, $
                      EXPRESS=express, $
                      JAVA=java, $
                      DIR_JAVA=dir_java
    if keyword_set(keep_temp_files) then begin
      fits_write,temp_file_input,model,header
      fits_write,temp_file_residual,model_readout-image,header
    endif else if keyword_set(java) then file_delete,temp_file_input,temp_file_output;,/allow_nonexistent
    print,"Minmax(change):   ",minmax((image-model_readout)[*,1024:*])
    model=(temporary(model)-model_readout+image)<((2.^16)-3) ; No longer truncating at zero
    print,"Minmax(new image):",minmax(model)
    print,"Minmax(change):   ",minmax((image-model_readout)[*,1024:*])
    print,"Mean(change):     ",mean((image-model_readout)[*,1024:*])
    print,"Mean(|change|):   ",mean((abs(image-model_readout))[*,1024:*])
    print,"Minmax(old image):",minmax(model)
  endfor

  ; Store best-fit image that, when read out using software, matches the observed data
  image=temporary(model)

endif else begin

  ; Extract metaparameters needed for CTE model
  if not keyword_set(xrange)          then xrange=[1,(size(image,/DIMENSIONS))[0]]-1 else xrange=0>xrange<((size(image,/DIMENSIONS))[0]-1)
  if not keyword_set(yrange)          then yrange=[1,(size(image,/DIMENSIONS))[1]]-1 else yrange=0>yrange<((size(image,/DIMENSIONS))[1]-1)
 ;if not keyword_set(trap_lifetime)   then trap_lifetime=[0.88,10.4] & n_species=n_elements(trap_lifetime)
 ;if not keyword_set(trap_density)    then trap_density=[0.25,0.75]*acs_trap_density(date,TRAP_INITIAL_DENSITY=trap_initial_density,TRAP_PERMANENT_RATE=trap_permanent_rate,TRAP_REMOVABLE_RATE=trap_removable_rate)

  if not keyword_set(trap_lifetime) or not keyword_set(trap_density) then begin
    if not keyword_set(date)          then if keyword_set(header) then date=sxpar(header,"DATE")+2452334.5 else message,"Must enter Julian date of exposure" ; Launch date of ACS
    acs_trap_species,date,trap_lifetime,trap_density,java=java,TRAP_INITIAL_DENSITY=trap_initial_density,TRAP_PERMANENT_RATE=trap_permanent_rate,TRAP_REMOVABLE_RATE=trap_removable_rate
  endif

  n_species=n_elements(trap_lifetime)
  if n_elements(quantize_traps) eq 0  then quantize_traps=0B
  if n_elements(quantize_charge) eq 0 then quantize_charge=0B
  if n_elements(marginal_trap) eq 0   then marginal_trap=1
  if keyword_set(n_levels_input) then n_levels=n_levels_input else begin
    if keyword_set(quantize_traps) then n_levels=round(2.0/total(trap_density))>1 $
      else n_levels=ceil(max(trap_density)*yrange[1]*marginal_trap);+1+ceil(max(trap_density)) ; used to be simply 10000    
  endelse

print,"*******************"
print,trap_lifetime
print,trap_density
print,"*******************"


  ; Expand image so that the clocking effectively has multiple phases
  if n_phases gt 1 then begin
    message,/INFO,"Expanding image to incorporate "+strtrim(n_phases,2)+"-phase clocking cycle"
    expanded_image=make_array((size(image,/DIMENSIONS))[0],n_phases*(size(image,/DIMENSIONS))[1],TYPE=size(image,/TYPE))
    if n_elements(active_phase) eq 0 then active_phase=0 & active_phase=0>active_phase<(n_phases-1)
    for i=(size(image,/DIMENSIONS))[1]-1,0,-1 do expanded_image[*,i*n_phases+active_phase]=image[*,i]
    image=temporary(expanded_image)
    yrange=yrange*n_phases+[0,n_phases-1]
    trap_lifetime=trap_lifetime*n_phases
    trap_density=trap_density/n_phases
  endif
  n_electrons_per_trap=trap_density/n_levels

  
  ; Warning
  sparse_pixels=where(image gt 0 and image lt total(trap_density),n_sparse_pixels)
  if n_sparse_pixels gt 0 then message,/info,"There are "+strtrim(n_sparse_pixels,2)+" pixels containing more traps than charge. The order in which these traps should be filled is ambiguous." ; The default choice is from the bottom up.

  if keyword_set(java) then begin
  
    ; Execute Chris Stoughton's java readout code
    if keyword_set(express) then message,"Sorry, express mode is not yet available in the Java version of this code!"
    if n_elements(trap_density) ne n_elements(trap_lifetime) then message,"Trap properties incorrectly specified!"
    if n_elements(trap_density) gt 4 then message,/INFO,"Information about some species of charge trap will be missing from the FITS header!"
    if n_elements(trap_density) eq 1 then trap_density_string=strtrim(trap_density,2) else trap_density_string=strjoin(strtrim(reform(trap_density),2)+[replicate(",",n_elements(trap_density)-1),""])
    if n_elements(trap_lifetime) eq 1 then trap_lifetime_string=strtrim(trap_lifetime,2) else trap_lifetime_string=strjoin(strtrim(reform(trap_lifetime),2)+[replicate(",",n_elements(trap_lifetime)-1),""])
    if not keyword_set(file_output) then file_output="~/temp.fits"
    if not keyword_set(file_input) then begin & file_input=file_output & file_delete,file_input,/allow_nonexistent & endif
    if not file_test(file_input) then fits_write,file_input,image;,header
    command=dir_java+'eagRunner.sh '+dir_java+' -Xmx2048m gov.fnal.eag.sim.pixel.ClockCharge'+$
                                   ' --gain 1 --skyPerPixel 0 --verbosity 1 --showStopwatch 1'+$
                                  ;' --quantizeTraps false --quantizeCharge false --nLevels 3'+$ ; Used for COSMOS & A2744 correction
                                  ;' --quantizeTraps false --quantizeCharge false --nLevels 10000'+$ ; Continuum version
                                   ' --quantizeTraps '+(['false','true'])[keyword_set(quantize_traps)]+$
                                   ' --quantizeCharge '+(['false','true'])[keyword_set(quantize_charge)]+$
                                   ' --nLevels '+strtrim(n_levels,2)+$ ; This can be increased if the trap density is particularly low
                                   ' --serialTrapsPerPixel "0." --serialTrapLifetime "1."'+$
                                   ' --trapLocationRandomSeed '+strtrim(trap_location_seed,2)+$
                                   ' --trapDecayRandomSeed '+strtrim(trap_decay_seed,2)+$
                                   ' --parallelFullWell '+strtrim(well_depth,2)+$
                                   ' --parallelNotchDepth "'+strtrim(well_notch_depth,2)+'" '+$
                                   ' --parallelPower "'+strtrim(well_fill_power,2)+'" '+$
                                   ' --parallelTrapsPerPixel "'+trap_density_string+'"'+$
                                   ' --parallelTrapLifetime "'+trap_lifetime_string+'" '+$
                                   ' --range "'+strjoin(strtrim([yrange[0],xrange[0],yrange[1]+1,xrange[1]+1],2)+[",",",",",",""])+'" '+$
                                   file_input+' '+file_output
    delvarx,image
    print & print,command & print
    ;file_copy,file_input,file_output,/overwrite ; A cheat!
    spawn,"time "+command
    if file_test(file_output) then fits_read,file_output,image,header else message,"Java code did not produce an output file!"
    if file_output eq "~/temp.fits" then begin & file_delete,file_output & delvarx,file_output & endif
  
  endif else   if keyword_set(cdm03) then begin

    beta=0.      ; charge cloud expansion parameter
    fwc=175000.  ; full well capacity [electrons]
    vth=1.168e7  ; electron thermal velocity [cm/s]
    vg=6.e-11    ; effective geometrical confinement volume of image pixels [cm^3]
    st=1.e-6     ; serial pixel transfer period [s]
    sfwc=730000. ; serial (readout register) pixel Full Well Capacity [electrons]
    svg=2.5e-10  ; geometrical confinement volume of serial register pixels [cm^3]
    t=2.07e-3    ; parallel line time or pixel transfer period [s] WHAT ALEX HAD
    t=10.4e-3    ; parallel line time or pixel transfer period [s]

    ; relative density and release times for -120 degrees [from Gordon Hopkinson final report for Euclid]
    ;kdim=7
    ;nt=[5.0,0.22,0.2,0.1,0.043,0.39,1.0] ; What Alex had
    ;nt=[1.0,0.22,0.2,0.1,0.043,0.29,1.0] ; Numbers in final SSTL report are really this
    ;tr=[0.00000082,0.0003,0.002,0.025,0.124,16.7,496.0]
    kdim=n_species
    tr=trap_lifetime*t
    nt=trap_density
    fwc=well_depth
    idim=xrange[1]+1
    jdim=yrange[1]+1
    y=yrange[0]+1
    print,xrange,yrange
    s=image[xrange[0]:xrange[1],yrange[0]:yrange[1]]

    ;absolute trap density which should be scaled according to radiation dose (nt=1.5e10 gives approx fit to GH data for a dose of 8e9 10MeV equiv. protons)
    nt=nt*4.5e10*2./3./6

    ; capture cross sections from Gaia data assumed to correspond with traps seen in Euclid testing
    sigma=[2.2e-13,2.2e-13,4.72e-15,1.37e-16,2.78e-17,1.93e-17,6.39e-18]

    ;set charge injection lines for comparison with GH results
;s(:,1:10)=44500.

    ;add some background electrons
;s=s+5.

    alpha=t*sigma*vth*fwc^beta/2./vg
    g=nt*2.*vg/fwc^beta
    no=fltarr(idim,kdim)

    help,alpha,g
    print,alpha
    print,"Pc",(1.-exp(-alpha[*]))

    for j=0,jdim-1 do begin
      gamma=g*(y+j)
      for k=0,kdim-1 do begin
        for i=0,idim-1 do begin
          nc=0. ; Number of captured electrons
          if s[i,j] gt 0.01 then begin
            nc=((gamma[k]*s[i,j]^beta-no[i,k])/(gamma[k]*s[i,j]^(beta-1.)+1.)*(1.-exp(-alpha[k]*s[i,j]^(1.-beta))))>0.
          endif
          s[i,j]=s[i,j]-nc
          no[i,k]=no[i,k]+nc ; number of occupied traps
          nr=no[i,k]*(1.-exp(-t/tr[k])) ; number of electrons released from traps
          s[i,j]=s[i,j]+nr
          no[i,k]=no[i,k]-nr
        endfor
      endfor
    endfor

    image[xrange[0]:xrange[1],yrange[0]:yrange[1]]=s

  endif else begin

    ; Trick to help vectorisation later (used for express and slow versions)
    if n_species eq 1 then begin & n_species=2 & trap_lifetime=[trap_lifetime,1e-7] & trap_density=[trap_density,0] & n_electrons_per_trap=[n_electrons_per_trap,0] & endif ; Catch an error to allow vector operations later


    ; Trick from Anderson et al to reduce number of traps that need to be considered
    if keyword_set(express) and keyword_set(marginal_trap) and keyword_set(fast) and 1 eq 2 then begin

      ;
      ; Define required constants for speed later
      ;
      
;      trap_height_boundaries=well_range*(dindgen(n_levels_required)/yrange[1]/marginal_trap/max_trap_density)^(1./well_fill_power)
;      trap_heights=shift(trap_height_boundaries,-1)-trap_height_boundaries
      trapped_electrons=dblarr(n_levels+ceil(max(trap_density)),n_species)
      well_range=float(well_depth-well_notch_depth)
      exponential_factor=(1-exp(-1.0D/trap_lifetime))##replicate(1,n_levels+ceil(max(trap_density)))
      time=systime(/sec)

      message,/info,"Using Jay Anderson's trick to speed up runtime (E="+strtrim(express,2)+") and reduce number of traps"
      express_multiplier=(indgen(yrange[1]+1)+1)##[0,replicate(1,express)]
      for i_express=1,express do express_multiplier[i_express,*]=(express_multiplier[i_express,*]<((yrange[1]+1)*i_express/express))-total(express_multiplier[0:i_express-1,*],1)
           
      ;
      ; Swipe a set of charge traps up each column in turn
      ;
      for i_column=xrange[0],xrange[1] do begin        
        for i_express=1,express do begin
          
 max_height=(((1+total(exponential_factor[0,*]*trap_density,2))<2)*((max(image[i_column,yrange[0]:yrange[1]])-well_notch_depth)/well_range)^well_fill_power)>0
 max_height=1>ceil(n_levels*max_height)<n_levels
 print,"max_height=",max_height
          
          free_electrons=double(0<image[i_column,yrange[0]:yrange[1]]<well_depth)
          trapped_electrons[*]=0.
          used_traps=0
          
          for i_pixel=0,yrange[1]-yrange[0] do begin
            
            ;
            ; Release any trapped electrons, using the appropriate decay half-life
            ;
            help,trapped_electrons
            release=trapped_electrons[0:used_traps,*]*exponential_factor[0:used_traps,*]
            trapped_electrons[0:used_traps,*]-=release
            free_electrons[i_pixel]+=total(release)
            
            ;height=(total(total(traps[0:max_height-1,*],2) gt 0,/integer))>1
            ;release=traps[0:height-1,*]*exponential_factor[0:height-1,*]
            ;traps[0:height-1,*]-=release
            ;free[i_pixel]+=total(release)

            ;
            ; Capture any free electrons in the vicinity of empty traps
            ;
            traps_seen=((0>((free_electrons[i_pixel]-well_notch_depth)/well_range)<1)^well_fill_power) * n_levels
            used_traps=used_traps>fix(traps_seen)
            
            mtime=systime(/sec)
            
            
            fraction_of_traps_seen=trap_height_boundaries[0:used_traps]
            
            used_traps=used_traps>ceil(traps_seen)
            full_traps_seen=fix(traps_seen)
            part_traps_seen=traps_seen-fix(traps_seen)
            
            
            
            capture=0>((n_electrons_per_trap##height_frac)-traps[0:ceil(height)-1,*])
            
            
            
            print,traps_seen,part_traps_seen
            print,trap_height_boundaries[full_traps_seen],trap_heights[full_traps_seen+1]
            stop
            traps_seen=(0>(((free[i_pixel]-well_notch_depth)/well_range)^well_fill_power)<1)
            
            if free[i_pixel] gt well_notch_depth then begin
              height=n_levels*(0>(((free[i_pixel]-well_notch_depth)/well_range)^well_fill_power)<1)
              height_frac=(height-indgen(ceil(height)))<1
              capture=0>((n_electrons_per_trap##height_frac)-traps[0:ceil(height)-1,*])
              
              
              total_capture=total(capture)>1e-14 & capture=temporary(capture)*((free[i_pixel]/total_capture)<1)
              traps[0:ceil(height)-1,*]+=capture
              free[i_pixel]-=total(capture)
   ; Cope with ambiguous order of trap filling (if there are lots of traps) by filling fast-release ones first.
   ;           for i_species=0,n_species-1 do begin
   ;             want_to_capture=total(capture[*,i_species])>1e-14
   ;             capture[*,i_species]=capture[*,i_species]*((free[i_pixel]/want_to_capture)<1)
   ;             traps[0:ceil(height)-1,i_species]+=capture[*,i_species]
   ;             free[i_pixel]-=total(capture[*,i_species])
   ;           endfor
            endif

          endfor

print,"used_traps=",used_traps

          ;
          ; Evaluate the delta trail, and add it to the image
          ;
          trail=(temporary(free)-double(((image[i_column,yrange[0]:yrange[1]]<well_depth)-well_notch_depth)>0))*express_multiplier[i_express,yrange[0]:yrange[1]]
          if yrange[0] eq 0 then image[i_column,yrange[0]:yrange[1]]+=trail else image[i_column,yrange[0]+1:yrange[1]]+=trail[1:*]
          
        endfor
        if i_column eq xrange[0] or (i_column-xrange[0]) mod 200 eq 199 then begin
          time_taken=systime(/sec)-time
          print,"Clocking column #"+strtrim(i_column+1-xrange[0],2)+"/"+strtrim(xrange[1]+1-xrange[0],2)+" in "+strtrim(time_taken,2)+"s, or "+strtrim(time_taken/(i_column+1-xrange[0]),2)+"s/column. ETA "+strtrim(round((xrange[1]-i_column)*time_taken/(i_column+1-xrange[0])),2)+"s."
        endif
      endfor

    endif else if keyword_set(express) then begin

      ;
      ; Define required constants for speed later
      ;
      message,/INFO,"Using "+strtrim(n_levels,2)+" charge trap levels"
      message,/info,"Using Jay Anderson's trick to speed up runtime (E="+strtrim(express,2)+")"
      express_multiplier=(indgen(yrange[1]+1)+1)##[0,replicate(1,express)]
      for i_express=1,express do express_multiplier[i_express,*]=(express_multiplier[i_express,*]<((yrange[1]+1)*i_express/express))-total(express_multiplier[0:i_express-1,*],1)
      
      exponential_factor=(1-exp(-1.0/trap_lifetime))##replicate(1,n_levels)
      well_range=float(well_depth-well_notch_depth)
      traps=fltarr(n_levels,n_species)
      time=systime(/sec)
     
      ;
      ; Swipe a set of charge traps up each column in turn
      ;
      for i_column=xrange[0],xrange[1] do begin        
        for i_express=1,express do begin
          
          max_height=(((1+total(exponential_factor[0,*]*trap_density,2))<2)*((max(image[i_column,yrange[0]:yrange[1]])-well_notch_depth)/well_range)^well_fill_power)>0
          max_height=1>ceil(n_levels*max_height)<n_levels
          free=((image[i_column,yrange[0]:yrange[1]]<well_depth)-well_notch_depth)>0
          traps[*]=0.
          
          for i_pixel=0,yrange[1]-yrange[0] do begin
            
            ;
            ; Release any trapped electrons, using the appropriate decay half-life
            ;
            height=(total(total(traps[0:max_height-1,*],2) gt 0,/integer))>1
            release=traps[0:height-1,*]*exponential_factor[0:height-1,*]
            ;total_release=total(release)>1e-14 & release=temporary(release)*(((well_range-free[i_pixel])/total_release)<1) ; it would be possible to delay the release of electrons into completely full wells, but as long as we catch the possibility that wells might be overfull later, it doesn't matter
            ;release=release*(release gt 1d-9)+traps*(release le 1d-9) ; it would be nice to completely empty some traps, then not have to look at them for the rest of the column, but the net effect on a typical image is to slow down the clocking
            traps[0:height-1,*]-=release
            free[i_pixel]+=total(release)

            ;
            ; Capture any free electrons in the vicinity of empty traps
            ;
;if free[i_pixel] gt total(release) then begin
            if free[i_pixel] gt well_notch_depth then begin
              height=n_levels*(0>(((free[i_pixel]-well_notch_depth)/well_range)^well_fill_power)<1)
              height_frac=(height-indgen(ceil(height)))<1
              capture=0>((n_electrons_per_trap##height_frac)-traps[0:ceil(height)-1,*])
              
              
              total_capture=total(capture)>1e-14 & capture=temporary(capture)*((free[i_pixel]/total_capture)<1)
              traps[0:ceil(height)-1,*]+=capture
              free[i_pixel]-=total(capture)
   ; Cope with ambiguous order of trap filling (if there are lots of traps) by filling fast-release ones first.
   ;           for i_species=0,n_species-1 do begin
   ;             want_to_capture=total(capture[*,i_species])>1e-14
   ;             capture[*,i_species]=capture[*,i_species]*((free[i_pixel]/want_to_capture)<1)
   ;             traps[0:ceil(height)-1,i_species]+=capture[*,i_species]
   ;             free[i_pixel]-=total(capture[*,i_species])
   ;           endfor
            endif
;endif

          endfor
          
          ;
          ; Evaluate the delta trail, and add it to the image
          ;
          trail=(temporary(free)-double(((image[i_column,yrange[0]:yrange[1]]<well_depth)-well_notch_depth)>0))*express_multiplier[i_express,yrange[0]:yrange[1]]
          if yrange[0] eq 0 then image[i_column,yrange[0]:yrange[1]]+=trail else image[i_column,yrange[0]+1:yrange[1]]+=trail[1:*]
          
        endfor
        if i_column eq xrange[0] or (i_column-xrange[0]) mod 200 eq 199 then begin
          time_taken=systime(/sec)-time
          print,"Clocking column #"+strtrim(i_column+1-xrange[0],2)+"/"+strtrim(xrange[1]+1-xrange[0],2)+" in "+strtrim(time_taken,2)+"s, or "+strtrim(time_taken/(i_column+1-xrange[0]),2)+"s/column. ETA "+strtrim(round((xrange[1]-i_column)*time_taken/(i_column+1-xrange[0])),2)+"s."
        endif
      endfor

    endif else begin
      if keyword_set(quantize_traps) or keyword_set(quantize_charge) then message,"No, you don't really want to quantize anything, do you?"

      ;
      ; Define required constants for speed later
      ;
      n_pixels=yrange[1]+1
      well_range=float(well_depth-well_notch_depth)
      traps=dblarr(n_levels,n_pixels,n_species) ; Ordered this way because total() operations are fastest on the leftmost dimensions, and if dimension1>dimension2
      n_electrons_per_trap=fltarr(n_levels,n_pixels,n_species) & for i_species=0,n_species-1 do n_electrons_per_trap[*,*,i_species]=trap_density[i_species]/n_levels
      exponential_factor  =fltarr(n_levels,n_pixels,n_species) & for i_species=0,n_species-1 do exponential_factor[*,*,i_species]  =1-exp(-1.0/trap_lifetime[i_species])
      trap_height_index   =rebin(indgen(n_levels),n_levels,n_pixels,/sample)
      time=systime(/sec)
      
      ;
      ; Swipe a set of charge traps up each column in turn
      ;
      t=systime(/s)
      for i_column=xrange[0],xrange[1] do begin
        free=double(((image[i_column,0:n_pixels-1]<well_depth)-well_notch_depth)>0)
        traps[*]=0.

        for i_pixel=0,n_pixels-1 do begin
          print,i_pixel,n_pixels
          ;
          ; Release any trapped electrons, using the appropriate decay half-life
          ;
          ; Calculate how many electrons are released from every trap
          height=total(total(traps[*,0:n_pixels-1-i_pixel,*] gt 0,3)<1,1,/integer) & max_height=max(height)>1 ; Could also do this, but it turns out to give no net speedup (or slowdown) for a typical image
          ;max_height=n_levels
          release=traps[0:max_height-1,0:n_pixels-1-i_pixel,*]*exponential_factor[0:max_height-1,i_pixel:n_pixels-1,*]
          ; Remove those electrons from the traps
          traps[0:max_height-1,0:n_pixels-1-i_pixel,*]-=release
          ; Add them to the reservoir of free charge in the CCD
          free[i_pixel:n_pixels-1]+=total(total(release,1),2)
          
          ;
          ; Capture any free electrons in the vicinity of empty traps
          ;
          ; Calculate the height of the 3D electron cloud within the CCD
          height=(n_levels*((free[i_pixel:n_pixels-1]-well_notch_depth)/well_range)^well_fill_power)>0 & max_height=max(ceil(height))
          ; How far up each trap layer do the electrons reach?
          height_frac=0>(rebin(transpose(height),max_height,n_pixels-i_pixel,/sample)-trap_height_index[0:max_height-1,0:n_pixels-1-i_pixel])<1
          ; How many electrons get captured by each trap
          capture=rebin(height_frac,max_height,n_pixels-i_pixel,n_species,/sample)*(n_electrons_per_trap[0:max_height-1,0:n_pixels-1-i_pixel,*]-traps[0:max_height-1,0:n_pixels-1-i_pixel,*])
          ; Make sure no more electrons are captured than are present in the CCD (this only acts very rarely, if the trap density is huge and the number of electrons very low. If it does, the way they should be filled is ambiguous - here, they are allocated equally between all exposed traps, while they were allocated from the bottom up in Chris's Java code. However, since this is only a question for very low electron densities, unless n_levels is huge, they should all be in the bottom one.
          total_capture=total(total(capture[*,0:n_pixels-i_pixel-1,*],1),2)>1e-14 & capture=temporary(capture)*rebin(transpose(free[i_pixel:n_pixels-1]/total_capture)<1,max_height,n_pixels-i_pixel,n_species,/sample)
          ; Add electrons to the traps
          traps[0:max_height-1,0:n_pixels-1-i_pixel,*]+=capture
          ; Remove electrons from the free cloud in the CCD
          free[i_pixel:n_pixels-1]-=total(total(capture,1),2)

        endfor
        
        ;
        ; Evaluate the delta trail, and add it to the image
        ;
        trail=temporary(free)-double(((image[i_column,0:n_pixels-1]<well_depth)-well_notch_depth)>0)
        image[i_column,0:n_pixels-1]+=trail
        if i_column mod 10 eq 9 then $
         print,"Clocking column #"+strtrim(i_column+1-xrange[0],2)+"/"+strtrim(xrange[1]+1-xrange[0],2)+" in "+strtrim(systime(/sec)-time,2)+"s, or "+strtrim((systime(/sec)-time)/(i_column+1-xrange[0]),2)+"s/column. ETA "+strtrim(round((xrange[1]-1-i_column)*(systime(/sec)-time)/(i_column+1-xrange[0])/60.),2)+"min."
      endfor

    endelse

    ; Undo trick to help vectorisation
    if trap_density[n_species-1] eq 0 then begin & n_species=n_species-1 & trap_lifetime=trap_lifetime[0:n_species-1] & trap_density=trap_density[0:n_species-1] & endif

  endelse

  ; Collapse image if the clocking had multiple phases
  if n_phases gt 1 then begin
    for i=0,(size(image,/DIMENSIONS))[1]/n_phases-1 do image[*,i]=total(image[*,i*n_phases:(i+1)*n_phases-1],2)
    image=image[*,0:(size(image,/DIMENSIONS))[1]/n_phases-1]
    yrange=(yrange-[0,n_phases-1])/n_phases
    trap_lifetime=trap_lifetime/n_phases
    trap_density=trap_density*n_phases
  endif
  image=float(image)
  
  ; Update header to include CTE model parameters
  if keyword_set(header) then begin
    message,/INFO,"Updating FITS header in output image "+file_output
    sxaddpar,header,"CTE_VERS",version," CTE model applied "+systime()
    sxaddpar,header,"CTE_WELD",well_depth," Assumed pixel well depth [electrons]"
    sxaddpar,header,"CTE_WELN",well_notch_depth," Assumed notch depth [electrons]"
    sxaddpar,header,"CTE_WELP",well_fill_power," Power law controlling filling of pixel well"
    sxaddpar,header,"CTE_NTRS",n_species," Number of charge trap species"
    for i=0,n_elements(trap_density)-1  do sxaddpar,header,"CTE_TR"+strtrim(i+1,2)+"D", trap_density[i]," Density of "+strtrim(i+1,2)+(["st","nd","rd",replicate("th",n_elements(trap_density))])[i]+" charge trap species [pixel^-1]"
    for i=0,n_elements(trap_lifetime)-1 do sxaddpar,header,"CTE_TR"+strtrim(i+1,2)+"T",trap_lifetime[i]," Decay halflife of "+strtrim(i+1,2)+(["st","nd","rd",replicate("th",n_elements(trap_density))])[i]+" charge trap species"
    if keyword_set(express) then sxaddpar,header,"CTE_EXPR",express," Express readout mode" else sxaddpar,header,"CTE_EXPR",0," Express readout mode" 
    if keyword_set(java) then sxaddpar,header,"CTE_JAVA",dir_java," Directory of Java ClockCharge code" else sxaddpar,header,"CTE_JAVA",0," Java ClockCharge code not used" 
    sxaddpar,header,"CTE_NLEV",n_levels," N_levels parameter in ClockCharge code"
    sxaddpar,header,"CTE_NPHA",n_phases," N_phases parameter in ClockCharge code"
    sxaddpar,header,"CTE_QUAT",keyword_set(quantize_traps)," Quantize_traps parameter in ClockCharge code"
    sxaddpar,header,"CTE_QUAC",keyword_set(quantize_charge)," Quantize_charge parameter in ClockCharge code"
    sxaddpar,header,"CTE_RND1",trap_location_seed," Random seed for charge trap locations"
    sxaddpar,header,"CTE_RND2",trap_decay_seed," Random seed for charge trap decays"
  endif
;  if keyword_set(file_output) then fits_write,file_output,image,header

endelse

if keyword_set(file_output) then begin
  message,/INFO,"Saving image "+file_output
  fits_write,file_output,image,header
endif

end
