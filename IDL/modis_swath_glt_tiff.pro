function hdf4_data_get,file_name,sds_name
  sd_id=hdf_sd_start(file_name,/read)
  sds_index=hdf_sd_nametoindex(sd_id,sds_name)
  sds_id=hdf_sd_select(sd_id,sds_index)
  hdf_sd_getdata,sds_id,data
  hdf_sd_endaccess,sds_id
  hdf_sd_end,sd_id
  return,data
end

function hdf4_attdata_get,file_name,sds_name,att_name
  sd_id=hdf_sd_start(file_name,/read)
  sds_index=hdf_sd_nametoindex(sd_id,sds_name)
  sds_id=hdf_sd_select(sd_id,sds_index)
  att_index=hdf_sd_attrfind(sds_id,att_name)
  hdf_sd_attrinfo,sds_id,att_index,data=att_data
  hdf_sd_endaccess,sds_id
  hdf_sd_end,sd_id
  return,att_data
end

pro modis_swath_glt_tiff
  compile_opt idl2
  envi,/restore_base_save_files
  envi_batch_init

  input_directory='D:/Experiments/MODIS_DataProcessing/Data/MOD04_3KA2022/'
  output_directory='D:/Experiments/MODIS_DataProcessing/Data/Results/OutTiff/'
  directory_exist=file_test(output_directory,/directory)
  if (directory_exist eq 0) then begin
    file_mkdir,output_directory
  endif

  file_list=file_search(input_directory,'*.hdf')
  file_n=n_elements(file_list)

  for file_i=0,file_n-1 do begin
    start_time=systime(1)
    result_name=output_directory+file_basename(file_list[file_i],'.hdf')+'_geo.tiff'
    modis_lon_data=hdf4_data_get(file_list[file_i],'Longitude')
    modis_lat_data=hdf4_data_get(file_list[file_i],'Latitude')
    modis_target_data=hdf4_data_get(file_list[file_i],'Image_Optical_Depth_Land_And_Ocean')
    scale_factor=hdf4_attdata_get(file_list[file_i],'Image_Optical_Depth_Land_And_Ocean','scale_factor')
    fill_value=hdf4_attdata_get(file_list[file_i],'Image_Optical_Depth_Land_And_Ocean','_FillValue')
;    data_size=size(modis_lon_data)
;    mid_lon=modis_lon_data[data_size[1]/2,0]
    modis_target_data=(modis_target_data gt 0.0 and modis_target_data ne fill_value[0])*modis_target_data*scale_factor[0]

    out_lon=output_directory+'lon_out.tiff'
    out_lat=output_directory+'lat_out.tiff'
    out_target=output_directory+'target.tiff'
    write_tiff,out_lon,modis_lon_data,/float
    write_tiff,out_lat,modis_lat_data,/float
    write_tiff,out_target,modis_target_data,/float

    envi_open_file,out_lon,r_fid=lon_fid;打开经度数据，获取经度文件id
    envi_open_file,out_lat,r_fid=lat_fid;打开纬度数据，获取纬度文件id
    envi_open_file,out_target,r_fid=target_fid;打开目标数据，获取目标文件id

    out_name_glt=output_directory+file_basename(file_list[file_i],'.hdf')+'_glt.img'
    out_name_glt_hdr=output_directory+file_basename(file_list[file_i],'.hdf')+'_glt.hdr'
    input_proj=envi_proj_create(/geographic)
    output_proj=envi_proj_create(/geographic)
    envi_glt_doit,$
      x_fid=lon_fid,y_fid=lat_fid,x_pos=0,y_pos=0,i_proj=input_proj,$;指定创建GLT所需输入数据信息
      o_proj=output_proj,pixel_size=pixel_size,rotation=0.0,out_name=out_name_glt,r_fid=glt_fid;指定输出GLT文件信息

    out_name_geo=output_directory+file_basename(file_list[file_i],'.hdf')+'_georef.img'
    out_name_geo_hdr=output_directory+file_basename(file_list[file_i], '.hdf')+'_georef.hdr'
    envi_georef_from_glt_doit,$
      glt_fid=glt_fid,$;指定重投影所需GLT文件信息
      fid=target_fid,pos=0,$;指定待投影数据id
      out_name=out_name_geo,background=0,r_fid=geo_fid;指定输出重投影文件信息


    map_info=envi_get_map_info(fid=geo_fid)
    geo_loc=map_info.(1)
    px_size=map_info.(2)
    envi_file_query,geo_fid,dims=data_dims
    target_data=envi_get_data(fid=geo_fid,pos=0,dims=data_dims)
;    print,geo_loc,px_size
    geo_info={$
      MODELPIXELSCALETAG:[px_size[0],px_size[1],0.0],$;X,Y,Z方向的像元分辨率
      MODELTIEPOINTTAG:[0.0,0.0,0.0,geo_loc[2],geo_loc[3],0.0],$
      ;坐标转换信息，前三个0.0代表栅格图像上的第0，0，0个像元位置（z方向一般不存在），
      ;后面-180.0代表x方向第0个位置对应的经度是-180.0度，90.0代表y方向第0个位置对应的经度是90.0度。
      GTMODELTYPEGEOKEY:2,$
      GTRASTERTYPEGEOKEY:1,$
      GEOGRAPHICTYPEGEOKEY:4326,$
      GEOGCITATIONGEOKEY:'GCS_WGS_1984',$
      GEOGANGULARUNITSGEOKEY:9102,$
      GEOGSEMIMAJORAXISGEOKEY:6378137.0,$
      GEOGINVFLATTENINGGEOKEY:298.25722}
    write_tiff,result_name,target_data,/float,geotiff=geo_info
    
    envi_file_mng,id=lon_fid,/remove
    envi_file_mng,id=lat_fid,/remove
    envi_file_mng,id=target_fid,/remove
    envi_file_mng,id=glt_fid,/remove
    envi_file_mng,id=geo_fid,/remove
    file_delete,[out_lon,out_lat,out_target,out_name_glt,out_name_glt_hdr,out_name_geo,out_name_geo_hdr]
    end_time=systime(1)
    print,'The GLT file creating time is:'+strcompress(string(end_time-start_time))+' s'
  endfor
  envi_batch_exit,/no_confirm
end