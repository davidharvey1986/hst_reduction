pro acs_correct_cte, FILES, $
                     SUFFIX=suffix, $
                     EXTENSION=extension, $
                     DATA_DIR=data_dir, $
                     INDEX=index, $
                     START=start, $
                     FINISH=finish, $
                     AMPLIFIERS=amplifiers, $
                     DELETE_OLD=delete_old, $
                     REVERSE_ORDER=reverse_order, $
                     HUFF=huff, $
                     EXPRESS=express, $
                     JAVA=JAVA, $
                     DIR_JAVA=dir_java, $
                     WELL_DEPTH=well_depth, $
                     WELL_NOTCH_DEPTH=well_notch_depth, $
                     WELL_FILL_POWER=well_fill_power, $
                     TRAP_DENSITY=trap_density, $
                     TRAP_LIFETIME=trap_lifetime, $
                     TRAP_LOCATION_SEED=trap_location_seed, $
                     TRAP_INITIAL_DENSITY=trap_initial_density, $
                     TRAP_PERMANENT_RATE=trap_permanent_rate, $
                     TRAP_REMOVABLE_RATE=trap_removable_rate, $
                     TRAP_POOLING=trap_pooling, $
                     DATE_OBS=date_obs, $
                     QUANTIZE_TRAPS=quantize_traps, $
                     QUANTIZE_CHARGE=quantize_charge, $
                     N_ITERATIONS=n_iterations, $
                     KEEP_TEMP_FILES=keep_temp_files, $
                     CLUSTER_FARM=cluster_farm, $
                     CLUSTER_BOSS=cluster_boss, $
                     CLUSTER_NODES=cluster_nodes, $
                     CLUSTER_PROCESSORS=cluster_processors, $
                     CLUSTER_WAIT_TIME=cluster_wait_time, $
                     CLUSTER_TEMPDIRS=cluster_tempdirs, $
                     CLUSTER_LOADS=cluster_loads, $
                     CLUSTER_CHECK=cluster_check
                      
;+
; NAME:
;      ACS_CORRECT_CTE
;
; CATEGORY:
;      Pixel-by-pixel correction of trailing due to charge transfer inefficiency in CCD
;      detectors.
;
; PURPOSE:
;      Iteratively uses Chris Stoughton's CCD readout model code to remove CTI trails.
;
; INPUTS:
;      If none are specified, it takes a guess at everything.
;
; OPTIONAL INPUTS:
;      FILES    - String or string array containing the absolute file name of the science
;                 image(s) to be corrected, stripped of the suffix and extension.
;      If that is not specified, the routine looks for files in:
;      DATA_DIR - The directory where the _raw.fits (and _bia.fits) files are stored.
;      A subset of the images can be selected via (either INDEX or START/FINISH, not both)
;      INDEX    - Which of the input files to correct e.g. [0,13,14] DEFAULT: all
;      START    - The index of the first image to correct DEFAULT: the first one
;      FINISH   - The index of the final image to correct DEFAULT: the last one
;      AMPLIFIER- Which of the amplifiers to correct DEFAULT: ["A","B","C","D"]
;      Many options concerning the correction itself can also be specified here. These are
;      merely passed on to acs_clock_charge.pro, which also contains the default values.
;      CLUSTER_B- Name of the master node (used to simplify farming jobs to this machine)
;                 DEFAULT: this one, as determined by the *nix command 'hostname'.
;      CLUSTER_N- String array containing a list of the slave machine names. They can include
;                 username information (e.g. rjm@ishtar.caltech.edu) if required, although
;                 ssh keys need to be set up to allow non-interactive login to all these
;                 machines. The IDL and Java code also need to be available on all of them.
;                 NB: this can also be just a sinlge string containing the current host name,
;                 if that has more than one processor/core, and you want to hit them all.
;      CLUSTER_P- Integer array specifying the number of processors/cores on each slave.
;                 This variable needs to have the same number of elements as cluster_nodes.
;      CLUSTER_T- Either a string array containing the path to a directory on each slave
;                 where temporary files can be stored, or a single string that works on them 
;                 all. In the latter case, it could be a different disc on each node, which 
;                 just symbolic links with the same name, or a cross-mounted disc readable 
;                 everywhere.
;      CLUSTER_L- Floating point array containing the current loads on the cluster nodes. If
;                 this is not specified, they will be checked, but this is useful internally.
;
; KEYWORD PARAMETERS:
;      DELETE_OL- 
;      CLUSTER_F- Run, in the background, on a free processor from a cluster. This feature 
;                 is intended to emulate a formal job queueing/scheduling system, which was not  
;                 available on the processors that I used for the COSMOS analysis.
;                    NB: SSH public/private keys need to be set up so that it is possible to
;                        log into the target nodes without interatively entering a password.
;                    NB: Once the process starts, this routine returns, and IDL moves on
;                        to the next task. No reporting is done when the image is ready!
;                    Clashes between temporary file names should not occur, so long as input
;                    images are not processed twice simultaneously.
;      CLUSTER_C- Check the load on each cluster node EVERY time a new job is farmed out.
;                 DEFAULT: gas bill style estimate, interpolating a while from last reading. 
;
; OUTPUTS:
;      Four images are written to disc, each containing the data read through one amplifier.
;
; EXAMPLE USE:
; acs_correct_cte,data="~/data/cte/acs_data/A520/",cluster_nodes="oich.ulan.roe.ac.uk",cluster_processors=6,/cluster_farm,/java,/quantize_traps 
; acs_correct_cte,data="~/data/cte/acs_data/A520_late/",cluster_nodes="oich.ulan.roe.ac.uk",cluster_processors=6,/cluster_farm,/express
;
;
; PROCEDURES USED:
;      acs_split.pro, acs_clock_charge.pro, acs_trap_species and various others from the IDL 
;      Astronomy Users' Library (including fits_read.pro, fits_write.pro, etc.)
;
; MODIFICATION HISTORY:
;      May 10 - Forcing of Java routines as a default imposed by RM
;      Nov 09 - DIR_JAVA keyword parsed through to acs_clock_charge.pro
;      Jul 08 - Cluster control mechanisms moved here from acs_clock_charge.pro by RM.
;      Feb 08 - Written by Richard Massey.
;-

; Parse inputs
starttime=systime(/seconds)
if not keyword_set(express)               then express=1-keyword_set(java)
if not keyword_set(suffix)                then suffix=["_raw","_cte"] else if n_elements(suffix) eq 1 then suffix=[suffix,"_cte"]
if keyword_set(huff)                      then suffix=[suffix,"_cth"]
if not keyword_set(exposure_time)         then if suffix[0] eq "_drk" then exposure_time=1000 ; Superdarks come from 1000s dark exposures, but are stored in units of e-/s with no mention of this
if not keyword_set(extension)             then extension="fits"
if not keyword_set(files)                 then files=acs_find_data(index=index,reverse=reverse_order,data_dir=data_dir,check_bias=suffix[0] ne "_drk",suffix=suffix[0],extension=extension) & n_files=n_elements(files)
if not keyword_set(amplifiers)            then amplifiers=["A","B","C","D"] & n_amplifiers=n_elements(amplifiers)
if n_elements(start) ne 1                 then start=0
if n_elements(finish) ne 1                then finish=n_files-1
if keyword_set(cluster_farm) then begin
  ;cluster_nodes=["rjm@oich.ulan.roe.ac.uk","rjm@moel.caltech.edu"] & cluster_processors=[4,0]
  ;if not keyword_set(cluster_nodes)       then cluster_nodes=["oich.local","rjm@"+["moel","kishar"+strtrim(indgen(12)+1,2),"elen","hebog","elidir"]+".caltech.edu"];,"ishtar.caltech.edu"]
  if not keyword_set(cluster_nodes)       then cluster_nodes="rjm@"+["moel","kishar"+strtrim(indgen(12)+1,2),"ishtar","elen","hebog","elidir"]+".caltech.edu"
  if not keyword_set(cluster_processors)  then cluster_processors=[4.3,0,2,0,2,0,0,replicate(2,6),0,1,1,2]
  if not keyword_set(cluster_tempdirs)    then cluster_tempdirs="/scr2/rjm/cte/" ; This could also be an array, with one string for each node
  if not keyword_set(cluster_load_thresh) then cluster_load_thresh=0.8 ; This much load needs to be free for a process to run
  if not keyword_set(cluster_boss)        then spawn,"hostname",cluster_boss
  if not keyword_set(cluster_wait_time)   then cluster_wait_time=60 ; Seconds between checking for free processors
  if n_elements(cluster_nodes) ne n_elements(cluster_processors) then message,"The number of defined cluster names and the number of their processors do not agree!"
  if not keyword_set(max_processes) then begin 
    ;spawn,"sudo sysctl -w kern.maxproc=400 ; sudo sysctl -w kern.maxprocperuid=400" ; You may want to run this, but it requires root access to the master node
    spawn,"sysctl -a | grep kern.maxprocperuid:",max_processesperuid,junk
    spawn,"sysctl -a | grep kern.maxproc:",max_processes,junk
    max_processes=fix(strmid(max_processes,(reverse(strsplit(max_processes)))[0]))<fix(strmid(max_processesperuid,(reverse(strsplit(max_processesperuid)))[0]))
    message,/INFO,"Maximum number of allowed processes: "+strtrim(max_processes,2)
  endif
endif

; Look at each image in turn
process_id=lonarr(n_files,n_amplifiers)
for i=start,finish do begin
  ;
  ;
  ; Delete any previous versions
  ;
  ;
  if keyword_set(delete_old) then begin
    message,/INFO,"Deleting older versions of corrected images"
    file_delete,files[i]+suffix[1:*]+"."+extension,/ALLOW_NONEXISTENT
    ;file_delete,files[i]+suffix[1:*]+amplifiers+"."+extension,/ALLOW_NONEXISTENT
  endif

  ;
  ;
  ; Loop over all files
  ;
  ;
  if file_test(files[i]+(reverse(suffix))[0]+"."+extension) then begin  ; Skip if already done Huff correction
  ;if 1 eq 2 then begin  ; Skip if already done Huff correction
    message,/INFO,"Already corrected "+files[i]+(reverse(suffix))[0]+"."+extension
  endif else begin
    if file_test(files[i]+suffix[1]+"."+extension) then begin  ; Skip if already done CTI correction
      message,/INFO,"Already corrected "+files[i]+suffix[1]+"."+extension
    endif else begin

      ;
      ;
      ; Split regions of the CCD read through separate amplifiers into separate files, and convert into units of electrons/pixel
      ;
      ;
      ; RAW images downloaded from HST
      acs_split, files[i]+suffix[0]+"."+extension, extension=extension, /blev_linear, no_bias_correction=suffix[0] eq "_drk", exposure_time=exposure_time, date_obs=date_obs
      if keyword_set(date_obs) then jdcnv,date_obs[0],date_obs[1],date_obs[2],0.,date else delvarx,date
      ; Any intermediate steps already processed
      

      ;
      ;
      ; Undo CTE trailing on images from individual amplifiers
      ;
      ;
      for j=0,n_amplifiers-1 do begin
        file_input=files[i]+suffix[0]+amplifiers[j]+"."+extension
        file_output=files[i]+suffix[1]+amplifiers[j]+"."+extension
        if file_test(file_output) then message,/INFO,"Already corrected "+file_output
        if file_test(file_output) then continue ; Skip if already done
        message,/INFO,(n_files le 2)?"Correcting image "+file_input:"Correcting image "+file_input+" ("+strtrim(i+1,2)+"/"+strtrim(n_files,2)+")"
        if not keyword_set(cluster_farm) then begin 
          
          ; Run correction on this processor - this will be sequential and slow for a large set of images!
          acs_clock_charge, /UNCLOCK, FILE_INPUT, FILE_OUTPUT,$
                            JAVA=JAVA, DIR_JAVA=dir_java, $
                            EXPRESS=express, $
                            WELL_DEPTH=well_depth, $
                            WELL_NOTCH_DEPTH=well_notch_depth, $
                            WELL_FILL_POWER=well_fill_power, $
                            QUANTIZE_TRAPS=quantize_traps, $
                            QUANTIZE_CHARGE=quantize_charge, $
                            TRAP_DENSITY=trap_density, $
                            TRAP_INITIAL_DENSITY=trap_initial_density, $
                            TRAP_PERMANENT_RATE=trap_permanent_rate, $
                            TRAP_REMOVABLE_RATE=trap_removable_rate, $
                            TRAP_LIFETIME=trap_lifetime, $
                            TRAP_LOCATION_SEED=trap_location_seed, $
                            TRAP_DECAY_SEED=trap_decay_seed, $
                            TRAP_POOLING=trap_pooling, $
                            DATE=date, $
                            KEEP_TEMP_FILES=keep_temp_files, $
                            N_ITERATIONS=n_iterations

        endif else begin
          
          ; Run correction on a cluster of processors
          file_log=file_input+".log"   & file_delete,file_log,/ALLOW_NONEXISTENT
          file_script=file_input+".sh" & file_delete,file_script,/ALLOW_NONEXISTENT
          while not keyword_set(cluster_target) do begin
            ; Checking current cluster loads
            message,/INFO,"Finding an available processor for "+file_basename(file_input)
            if keyword_set(cluster_check) or not keyword_set(cluster_loads) then begin
              cluster_loads=float(cluster_processors)
              for k=n_elements(cluster_nodes)-1,0,-1 do begin
                if cluster_processors[k] gt 0 then begin
                  if stregex(cluster_nodes[k],cluster_boss,/BOOLEAN) then spawn,"uptime",uptime,error else spawn,"ssh "+cluster_nodes[k]+" uptime",uptime,error
                  stop
                  if strlen(uptime) gt 0 then cluster_loads[k]=float((reverse(strsplit(uptime,", ",/extract)))[2])
                  if total(strlen(error)) gt 0 then print,error
                  message,/INFO,"Load on "+cluster_nodes[k]+" during previous minute: "+strmid(strtrim(cluster_loads[k],2),0,4)
                endif
              endfor
            endif else begin
              ;for k=n_elements(cluster_nodes)-1,0,-1 do message,/INFO,"Load on "+cluster_nodes[k]+" specified by user: "+strmid(strtrim(cluster_loads[k],2),0,4)
            endelse
            ; Find (the most) free machine
            if max(cluster_processors-cluster_loads,cluster_free) gt cluster_load_thresh then cluster_target=cluster_nodes[cluster_free] else begin
              message,/INFO,"No processors available at "+strmid(systime(0), 11, 5)+". Will look again in a minute."
              cluster_loads=0
              wait,cluster_wait_time
            endelse
          endwhile
          cluster_loads[cluster_free]=cluster_loads[cluster_free]+1.2;0.9999
          if n_elements(cluster_tempdirs) eq 1 then cluster_tempdir=cluster_tempdirs else cluster_tempdir=cluster_tempdirs[cluster_free]

          ; Write self-contained script to manage subsequent processing
          openw,lun,file_script,/get_lun
          printf,lun,"echo Clocking charge for image "+file_input+" on "+cluster_target
          ; Copy input file to slave machine
          cluster_file_input=cluster_tempdir+file_basename(file_input)
          cluster_file_output=cluster_tempdir+file_basename(file_output)
          if stregex(cluster_target,cluster_boss,/BOOLEAN) then begin
            printf,lun,"\cp "+file_input+" "+cluster_file_input
          endif else if stregex(cluster_target,"caltech.edu",/BOOLEAN) then begin
            printf,lun,"\ssh rjm@moel.caltech.edu \scp "+file_input+" "+cluster_target+":"+cluster_file_input
          endif else begin
            printf,lun,"\scp "+file_input+" "+cluster_target+":"+cluster_file_input
          endelse
          ; Remove trailing (IDL and Java scripts must be available on the remote machine)
          options="UNCLOCK=1";,/JAVA"
          if keyword_set(java)                 then options=options+",/JAVA"
          if keyword_set(express)              then options=options+",EXPRESS="+strtrim(express,2)
          if keyword_set(well_depth)           then options=options+",WELL_DEPTH="+strtrim(well_depth,2)
          if keyword_set(well_notch_depth)     then options=options+",WELL_NOTCH_DEPTH="+strtrim(well_notch_depth,2)
          if keyword_set(well_fill_power)      then options=options+",WELL_FILL_POWER="+strtrim(well_fill_power,2)
          case n_elements(trap_density) of
            0: 
            1: options=options+",TRAP_DENSITY="+strtrim(trap_density,2)
            else: options=options+",TRAP_DENSITY=\["+strjoin(strtrim(trap_density,2)+[replicate(",",n_elements(trap_density)-1),""])+"\]"
          endcase
          case n_elements(trap_lifetime) of
            0: 
            1: options=options+",TRAP_LIFETIME="+strtrim(trap_lifetime,2)
            else: options=options+",TRAP_LIFETIME=\["+strjoin(strtrim(trap_lifetime,2)+[replicate(",",n_elements(trap_lifetime)-1),""])+"\]"
          endcase
          if keyword_set(trap_initial_density) then options=options+",TRAP_INITIAL_DENSITY="+strtrim(trap_initial_density,2)
          if keyword_set(trap_permanent_rate)  then options=options+",TRAP_PERMANENT_RATE="+strtrim(trap_permanent_rate,2)
          if keyword_set(trap_removable_rate)  then options=options+",TRAP_REMOVABLE_RATE="+strtrim(trap_removable_rate,2)
          if keyword_set(trap_location_seed)   then options=options+",TRAP_LOCATION_SEED="+strtrim(trap_location_seed,2)
          if keyword_set(trap_decay_seed)      then options=options+",TRAP_DECAY_SEED="+strtrim(trap_decay_seed,2)
          if keyword_set(quantize_traps)       then options=options+",QUANTIZE_TRAPS="+strtrim(quantize_traps,2)
          if keyword_set(quantize_charge)      then options=options+",QUANTIZE_CHARGE="+strtrim(quantize_charge,2)
          if keyword_set(n_iterations)         then options=options+",N_ITERATIONS="+strtrim(n_iterations,2)
          if keyword_set(date)                 then options=options+",DATE="+strtrim(date,2)
          if keyword_set(keep_temp_files)      then options=options+",KEEP_TEMP_FILES="+strtrim(keep_temp_files,2)
          if stregex(cluster_target,cluster_boss,/BOOLEAN) then quote='\"' else begin
            printf,lun,"\ssh "+cluster_target+" ",format="($,A0)" & quote='\\\"'
          endelse
          printf,lun,"nice +"+strtrim(fix(20-3*randomu(seed))<19,2)+" "+$ ; Nice to 17, 18 or 19 - the random element helps clear processes that queue on one machine that later gets occupied by active processes
                     "idl -e acs_clock_charge,"+ $
                      quote+cluster_file_input+quote+","+ $
                      quote+cluster_file_output+quote+","+ $ 
                      options
          if stregex(cluster_target,cluster_boss,/BOOLEAN) then begin ; is this going to be running on the master node anyway?
            if keyword_set(keep_temp_files) then begin
              printf,lun,"\cp "+cluster_file_output+" "+file_output ; Copy output file to desired location (on master node)
            endif else begin
              printf,lun,"\mv "+cluster_file_output+" "+file_output ; Move output file to desired location (on master node)
              printf,lun,"\rm "+cluster_file_input ; Remove temporary files
            endelse
          endif else begin
            printf,lun,"\scp "+cluster_target+":"+cluster_file_output+" "+file_output ; Copy output file from slave machine back to master node
            if not keyword_set(keep_temp_files) then printf,lun,"\ssh "+cluster_target+" \rm "+cluster_file_output+" "+cluster_file_input ; Remove temporary files from slave machine
          endelse
          if not keyword_set(keep_temp_files) then printf,lun,"\rm "+file_script;+" "+file_input ; Remove temporary files from master node
          free_lun,lun

          ; Spawn script as a child process in the background so we can move on to the next image. Note that this can fork a lot of child processes, of which there is a maximum allowed, and also use up lot of IDL licences...
          ;spawn,"cat "+file_script
          spawn,"source "+file_script+" >& "+file_log+" &",junk,PID=pid  
          message,/INFO,"Executing local process "+strtrim(pid,2)+" to manage a remote script on "+cluster_target+"."
          delvarx,cluster_target
          process_id[i,j]=pid>1
          wait,59 ; Pause a moment to allow copying some time to at least get going before we move on to the next image

        endelse ; Spawn parallel subprocesses or run in series
      endfor ; Loop over amplifiers
    endelse ; Do CTI correction 

    ;
    ;
    ; Reassemble the four amplifiers into one combined fits file
    ;
    ;
    if total(process_id[i,*]) eq 0 then begin
    
      ; This includes the cases of not keyword_set(cluster_farm) and images for all the individual amps being done but the final 
      ;acs_split, files[i]+suffix[1]+"."+extension, suffix="cte", extension=extension, no_bias_correction=suffix[0] eq "_drk", exposure_time=exposure_time
      acs_split, /unsplit, files[i]+suffix[1]+"."+extension, suffix=suffix, extension=extension, no_bias_correction=suffix[0] eq "_drk", exposure_time=exposure_time
      if keyword_set(huff) then begin ; Perform Huff noise correction
        ;print,"Pausing to make sure all files are written out..." & wait,30
        for j=0,n_amplifiers-1 do acs_huff_transform,files[i]+suffix[1]+amplifiers[j]+"."+extension,files[i]+suffix[2]+amplifiers[j]+"."+extension,delete_old=1;delete_old
        acs_split, /unsplit, files[i]+suffix[2]+"."+extension, suffix=[suffix[0],suffix[2]], extension=extension, no_bias_correction=suffix[0] eq "_drk", exposure_time=exposure_time
      endif
      message,/INFO,"Still running at "+systime()+", for "+strmid(strtrim((systime(/seconds)-starttime)/3600,2),0,5)+" hours."
    
    endif else begin
      
      ; Otherwise, periodically check progress on those processes that we know have been started on slave nodes
      n_loop=-1
      if (i gt 2 or i eq finish) then while n_loop lt 200*(i eq finish) do begin
        in_progress=start+where(total(process_id[start:start>(i+n_loop-2)<finish,*],2) ne 0,n_in_progress)
        if n_in_progress gt 0 then begin
          print & print,"-------------------------------------------------------"
          if n_loop ge 0 then wait,30
          for ii=0,n_in_progress-1 do begin
            print,"Checking progress on files "+files[in_progress[ii]]+suffix[1]+"?."+extension+" ("+strtrim(in_progress[ii]+1,2)+"/"+strtrim(n_files,2)+")... ",format="(A0,$)"
            for j=0,n_amplifiers-1 do begin
              file_age=((file_info(files[in_progress[ii]]+suffix[1]+amplifiers[j]+"."+extension)).ctime-starttime)*(total(process_id[in_progress[ii],*],2) gt 0)
              file_size=(file_info(files[in_progress[ii]]+suffix[1]+amplifiers[j]+"."+extension)).size
              ; The following condition checks whether an image has been corrected and fully copied back to the master node. However, checking by size is not robust to changes in e.g. the FITS header or number of bits per pixel. An alternative could be "if file_age gt 60..." although this requires the time (in seconds) to be longer than the time taken to copy a file back to the master node, and this can depend on the local network capabilities.
;              if file_size eq 16781760 then process_id[in_progress[ii],j]=0
              if file_size eq 17144640 then process_id[in_progress[ii],j]=0
            endfor
            if total(process_id[in_progress[ii],*],2) eq 0 then begin
              ;print,"Finished! Pausing to make sure all files are written out..." & wait,30
              acs_split, /unsplit, files[in_progress[ii]]+suffix[1]+"."+extension, suffix=suffix, extension=extension, no_bias_correction=suffix[0] eq "_drk", exposure_time=exposure_time
              if keyword_set(huff) then begin ; Perform Huff noise correction
                for j=0,n_amplifiers-1 do acs_huff_transform,files[in_progress[ii]]+suffix[1]+amplifiers[j]+"."+extension,files[in_progress[ii]]+suffix[2]+amplifiers[j]+"."+extension,delete_old=1;delete_old
                acs_split, /unsplit, files[in_progress[ii]]+suffix[2]+"."+extension, suffix=[suffix[0],suffix[2]], extension=extension, no_bias_correction=suffix[0] eq "_drk", exposure_time=exposure_time
              endif
              message,/INFO,"Still running at "+systime()+", for "+strmid(strtrim((systime(/seconds)-starttime)/3600.,2),0,5)+" hours."
            endif else begin
              print,amplifiers[where(process_id[in_progress[ii],*] ne 0)]
            endelse
          endfor
          print,"-------------------------------------------------------" & print
        endif else break
        n_loop=n_loop+1
      endwhile
    endelse ; Reassemble separate amplifier images

  endelse ; Do Huff correction

  ;
  ;
  ; Delay moving on to the next image if the master node is running a number of processes anywhere near its maximum allowed
  ;
  ;
  free_processes=0B
  while not free_processes and keyword_set(cluster_farm) do begin
    spawn,"ps -A | wc -l",n_processes,error
    if keyword_set(error) or n_processes gt max_processes-50 then begin
      message,/INFO,systime()+" "+error
      message,/INFO,"Waiting for a few of the "+strtrim(n_processes,2)+"/"+strtrim(max_processes,2)+" processes to clear..."
      wait,30
    endif else begin
      message,/INFO,"Currently running "+strtrim(n_processes,2)+"/"+strtrim(max_processes,2)+" processes"
      free_processes=1B
    endelse
  endwhile  
  
endfor

;  ;
;  ;
;  ; Perform Huff noise correction
;  ;
;  ;
;if keyword_set(huff) then begin
;  for i=start,finish do begin
;    if not file_test(files[i]+suffix[2]+"."+extension) then begin
;      for j=0,n_amplifiers-1 do begin
;        acs_huff_transform,files[i]+suffix[1]+amplifiers[j]+"."+extension,files[i]+suffix[2]+amplifiers[j]+"."+extension
;      endfor
;      acs_split, /unsplit, files[i]+suffix[2]+"."+extension, suffix=[suffix[0],suffix[2]], extension=extension, no_bias_correction=suffix[0] eq "_drk", exposure_time=exposure_time
;    endif
;  endfor
;endif

; Report on total time taken
message,/INFO,"Finished at "+systime()+", after "+strmid(strtrim((systime(/seconds)-starttime)/3600,2),0,5)+" hours." & print

end
