pro modis_sinusoidal_to_geographic
  input_directory='D:/Experiments/MODIS_DataProcessing/Data/MYD11A1/'
  output_directory='D:/Experiments/MODIS_DataProcessing/Data/Results/SinToGeo/'
  directory_exist=file_test(output_directory,/directory)
  if (directory_exist eq 0) then begin
    file_mkdir,output_directory
  endif
  file_list=file_search(input_directory,'*.hdf')
  for file_i=0,n_elements(file_list)-1 do begin
    start_time=systime(1)
    result_name=output_directory+file_basename(file_list[file_i],'.hdf')+'_geo.tiff'
    sd_id=hdf_sd_start(file_list[file_i],/read)
    gindex=hdf_sd_attrfind(sd_id,'StructMetadata.0')
    hdf_sd_attrinfo,sd_id,gindex,data=metadata
    
    ul_start_pos=strpos(metadata,'UpperLeftPointMtrs')
    ul_end_pos=strpos(metadata,'LowerRightMtrs')
    ul_info=strmid(metadata,ul_start_pos,ul_end_pos-ul_start_pos)
    ul_info_spl=strsplit(ul_info,'=(,)',/extract)
    ul_prj_x=double(ul_info_spl[1])
    ul_prj_y=double(ul_info_spl[2])
    
    lr_start_pos=strpos(metadata,'LowerRightMtrs')
    lr_end_pos=strpos(metadata,'Projection')
    lr_info=strmid(metadata,lr_start_pos,lr_end_pos-lr_start_pos)
    lr_info_spl=strsplit(lr_info,'=(,)',/extract)
    lr_prj_x=double(lr_info_spl[1])
    lr_prj_y=double(lr_info_spl[2])
    
    sds_index=hdf_sd_nametoindex(sd_id,'LST_Day_1km')
    sds_id=hdf_sd_select(sd_id,sds_index)
    hdf_sd_getdata,sds_id,data
    index=hdf_sd_attrfind(sds_id,'scale_factor')
    hdf_sd_attrinfo,sds_id,index,COUNT=cali_num,DATA=cali_scale
    data=data*cali_scale[0]
    hdf_sd_endaccess,sds_id
    hdf_sd_end,sd_id
    
    sin_prj=map_proj_init('sinusoidal',/gctp,sphere_radius=6371007.181,center_longitude=0.0,false_easting=0.0,false_northing=0.0)
    data_size=size(data)
    sin_resolution=(lr_prj_x-ul_prj_x)/(data_size[1])
    proj_x=fltarr(data_size[1],data_size[2])
    proj_y=fltarr(data_size[1],data_size[2])
    for col_i=0,data_size[1]-1 do begin
      proj_x[col_i,*]=ul_prj_x+(sin_resolution*col_i) 
    endfor
    for line_i=0,data_size[2]-1 do begin
      proj_y[*,line_i]=ul_prj_y+(sin_resolution*line_i)
    endfor
    print,proj_x[0],proj_y[0]
    geo_loc=map_proj_inverse(proj_x,proj_y,map_structure=sin_prj)
    ;help,geo_loc
    geo_x=geo_loc[0,*]
    geo_y=geo_loc[1,*]
    ;print,geo_x[0,0]
    lon_min=min(geo_x)
    lon_max=max(geo_x)
    lat_min=min(geo_y)
    lat_max=max(geo_y)
    ;print,lon_min,lon_max,lat_min,lat_max
    geo_resolution=0.01
    data_box_geo_col=ceil((lon_max-lon_min)/geo_resolution)
    data_box_geo_line=ceil((lat_max-lat_min)/geo_resolution)
    data_box_geo=fltarr(data_box_geo_col,data_box_geo_line)
    data_box_geo[*,*]=-9999.0
    data_box_geo_col_pos=floor((geo_x-lon_min)/geo_resolution)
    data_box_geo_line_pos=floor((lat_max-geo_y)/geo_resolution)
    data_box_geo[data_box_geo_col_pos,data_box_geo_line_pos]=data
    
    data_box_geo_out=fltarr(data_box_geo_col,data_box_geo_line)
    for data_box_geo_col_i=1,data_box_geo_col-2 do begin
      for data_box_geo_line_i=1,data_box_geo_line-2 do begin
        if data_box_geo[data_box_geo_col_i,data_box_geo_line_i] eq -9999.0 then begin
          temp_window=data_box_geo[data_box_geo_col_i-1:data_box_geo_col_i+1,data_box_geo_line_i-1:data_box_geo_line_i+1]
          temp_window=(temp_window gt 0.0)*temp_window
          temp_window_sum=total(temp_window)
          temp_window_num=total(temp_window gt 0.0)
          if (temp_window_num gt 3) then begin
            data_box_geo_out[data_box_geo_col_i,data_box_geo_line_i]=temp_window_sum/temp_window_num
          endif else begin
            data_box_geo_out[data_box_geo_col_i,data_box_geo_line_i]=0.0
          endelse
        endif else begin
          data_box_geo_out[data_box_geo_col_i,data_box_geo_line_i]=data_box_geo[data_box_geo_col_i,data_box_geo_line_i]
        endelse
      endfor
    endfor
    
    geo_info={$
      MODELPIXELSCALETAG:[geo_resolution,geo_resolution,0.0],$;X,Y,Z方向的像元分辨率
      MODELTIEPOINTTAG:[0.0,0.0,0.0,lon_min,lat_max,0.0],$
      ;坐标转换信息，前三个0.0代表栅格图像上的第0，0，0个像元位置（z方向一般不存在），
      ;后面-180.0代表x方向第0个位置对应的经度是-180.0度，90.0代表y方向第0个位置对应的经度是90.0度。
      GTMODELTYPEGEOKEY:2,$
      GTRASTERTYPEGEOKEY:1,$
      GEOGRAPHICTYPEGEOKEY:4326,$
      GEOGCITATIONGEOKEY:'GCS_WGS_1984',$
      GEOGANGULARUNITSGEOKEY:9102,$
      GEOGSEMIMAJORAXISGEOKEY:6378137.0,$
      GEOGINVFLATTENINGGEOKEY:298.25722}
      
    write_tiff,result_name,data_box_geo_out,/float,geotiff=geo_info
    end_time=systime(1)
    print,'Reprojection time consuming of file '+file_basename(file_list[file_i])+':'+strcompress(string(end_time-start_time))+'s.'
  endfor
  
end