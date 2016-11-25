function acs_find_data, data_dir=data_dir, $
                        suffix=suffix, $
                        extension=extension, $
                        n_files=n_files, $
                        dates=dates, $
                        check_bias=check_bias, $
                        index=index, $
                        reverse=reverse

;+
; NAME:
;      ACS_FIND_DATA
;
; CATEGORY:
;      Pixel-by-pixel correction of trailing due to charge transfer inefficiency in CCD detectors.
;
; PURPOSE:
;      Locate relevant data files on disc.
;      Can also check for the presence of bias files, which are required for later steps.
;
; INPUTS:
;      None.
;
; OPTIONAL INPUTS:
;      DATA_DIR   - Where to look for the files. Can be relative or absolute.
;      INDEX      - Specify only to look at certain files, e.g. [0, 2, 7]
;      SUFFIX     - A code added to filenames immediately before the extension, e.g. "_RAW" in HST/ACS data.
;      EXTENSION  - File name extension. DEFAULT: "fits"
;
; KEYWORD PARAMETERS:
;      CHECK_BIAS - Look in the FITS headers, and try to determine the relevant superbias frames.
;                   Then search for these in the same directory, and halt proceedings if any are not present.
;
; OUTPUTS:
;      Returns an array of strings, containg absolute filenames but with the suffixes and extensions stripped off.
;
; MODIFICATION HISTORY:
;      Jan 08 - Written by Richard Massey.
;-

; Parse inputs and revert to defaults if nothing else is specified
if not keyword_set(data_dir)  then data_dir="~/data/cte/acs_data/sm43/"
if not keyword_set(suffix)    then suffix="_raw"
if not keyword_set(extension) then extension="fits"

; Find the relevant files
files=file_search(data_dir,"*"+strcompress(suffix[0]+"."+extension),count=count)
if count eq 0 then message,"No files matching "+data_dir+"*"+strcompress(suffix[0]+"."+extension)+" found!" else message,/info,"Found "+strtrim(count,2)+" images"

; Strip suffix and extension
files=file_dirname(files,/mark_directory)+file_basename(files,strcompress(suffix[0]+"."+extension))

; Select only a subset of them
if keyword_set(n_files) then files=files[0:n_files-1]
if n_elements(index) gt 0 then begin
  if min(index,max=max) lt 0 or max gt (n_elements(files)-1) then $
    message,"INDEX specified out of range (there are "+strtrim(n_elements(files),2)+" images)."
  files=files[index]
endif
if keyword_set(reverse) then message,/INFO,"REVERSING ORDER OF FILES"
if keyword_set(reverse) then files=reverse(files)

; Check that the bias files exist
if keyword_set(check_bias) or arg_present(dates) then begin
  message,/INFO,"Checking for bias images and obtaining dates of exposure."
  bias_files=strarr(n_elements(files))
  bias_present=bytarr(n_elements(files))
  dates=dblarr(n_elements(files))
  for i=0,n_elements(files)-1 do begin
    junk=mrdfits(files[i]+strcompress(suffix[0]+"."+extension),0,header,SILENT=0)
    bias_files[i]=sxpar(header,"BIASFILE")
    date_obs=strsplit(sxpar(header,"DATE-OBS"),"-",/extract)
    time_obs=strsplit(sxpar(header,"TIME-OBS"),":",/extract)
    jdcnv,date_obs[0],date_obs[1],date_obs[2],time_obs[0]+time_obs[1]/60.+time_obs[2]/3600.,jd
    dates[i]=jd
    jref=strpos(bias_files[i],"jref$") & if jref ge 0 then bias_files[i]=file_dirname(files[i],/MARK_DIRECTORY)+strmid(bias_files[i],jref+5)
    ;jref=strpos(bias_files[i],"jref$") & if jref ge 0 then bias_files[i]='/home/drh/drh/CTI/bias/'+strmid(bias_files[i],jref+5)
   ; spawn,'cp '+strtrim(bias_files[i],2)+' '+strtrim(data_dir,2) ; Since all the bias files are in one I want to locate it and then copy it to the data_dir to use.
    print, bias_files[i]
    if file_test(bias_files[i]) then bias_present[i]=1B
  endfor
  print,"Date range: "+strtrim(min(dates),2)+"-"+strtrim(max(dates),2)+" ("+strtrim(max(dates)-min(dates),2)+" days)"
  bias_missing=where(bias_present eq 0B,n_bias_missing)
  if keyword_set(check_bias) then begin
    if n_bias_missing gt 1 then begin
      bias_files_missing=bias_files[bias_missing] 
      bias_files_missing=bias_files_missing[sort(bias_files_missing)]
      bias_files_missing=bias_files_missing[uniq(bias_files_missing)]
      message,/INFO,"The following bias images are missing:"
      for i=0,n_elements(bias_files_missing)-1 do print,file_basename(bias_files_missing[i])
      print, "Attempting to download the missing bias images"
      for i=0,n_elements(bias_files_missing)-1 do $
         spawn, 'ftp -m -nd ftp://ftp.stsci.edu/cdbs/jref/'+strtrim(file_basename(bias_files_missing[i]))

      bias_present=bytarr(n_elements(files))
      for i=0,n_elements(files)-1 do $
         if file_test(bias_files[i]) then bias_present[i]=1B
      
      bias_missing=where(bias_present eq 0B,n_bias_missing)
      if n_bias_missing gt 1 then begin
         bias_files_missing=bias_files[bias_missing] 
         bias_files_missing=bias_files_missing[sort(bias_files_missing)]
         bias_files_missing=bias_files_missing[uniq(bias_files_missing)]
         message,/INFO,"The following bias images are STILL missing:"
         for i=0,n_elements(bias_files_missing)-1 do print,file_basename(bias_files_missing[i])
         stop
      endif
      
      
   endif else message,/INFO,"All bias images have been found!"

 endif
endif

; report back
return,files

end
