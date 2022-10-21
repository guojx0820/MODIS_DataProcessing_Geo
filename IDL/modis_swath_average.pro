pro modis_swath_average
  start_time=systime(1)
  input_directory='D:/Experiments/MODIS_DataProcessing/Data/Results/OutTiff/'
  output_directory='D:/Experiments/MODIS_DataProcessing/Data/Results/MODIS_Swath_Mean/'
  dir_test=file_test(output_directory)
  if dir_test eq 0 then file_mkdir,output_directory
  file_list=file_search(input_directory,'*.tiff')
  file_n=n_elements(file_list)
  output_resolution=0.03
  output_name=output_directory+'avr.tiff'
  
  lon_min=9999.0
  lon_max=-9999.0
  lat_min=9999.0
  lat_max=-9999.0
  
  for file_i=0,file_n-1 do begin
    data=read_tiff(file_list[file_i],geotiff=geo_info)
    resolution_tag=geo_info.(0)
    geo_tag=geo_info.(1)
    data_size=size(data)
    data_col=data_size[1]
    data_line=data_size[2]
    temp_lon_min=geo_tag[3]
    temp_lon_max=temp_lon_min+data_col*resolution_tag[0]
    temp_lat_max=geo_tag[4]
    temp_lat_min=temp_lat_max-data_line*resolution_tag[1]
    if temp_lon_min lt lon_min then lon_min=temp_lon_min
    if temp_lon_max gt lon_max then lon_max=temp_lon_max
    if temp_lat_min lt lat_min then lat_min=temp_lat_min
    if temp_lat_max gt lat_max then lat_max=temp_lat_max
  endfor
  print,lon_min,lon_max,lat_min,lat_max
  data_box_geo_col=ceil((lon_max-lon_min)/output_resolution)
  data_box_geo_line=ceil((lat_max-lat_min)/output_resolution)
  data_box_geo_sum=fltarr(data_box_geo_col,data_box_geo_line)
  data_box_geo_num=fltarr(data_box_geo_col,data_box_geo_line)
  for file_i=0,file_n-1 do begin
    ;print,file_list[file_i]
    data=read_tiff(file_list[file_i],geotiff=geo_info)
    data_size=size(data)
    data_col=data_size[1]
    data_line=data_size[2]
    resolution_tag=geo_info.(0)
    geo_tag=geo_info.(1)
    temp_lon_min=geo_tag[3]
    temp_lat_max=geo_tag[4]
    
    for data_col_i=0,data_col-1 do begin
      for data_line_i=0,data_line-1 do begin
        temp_lon=temp_lon_min+data_col_i*resolution_tag[0]
        temp_lat=temp_lat_max-data_line_i*resolution_tag[1]
        data_box_col_pos=floor((temp_lon-lon_min)/output_resolution)
        data_box_line_pos=floor((lat_max-temp_lat)/output_resolution)
        if (data[data_col_i,data_line_i] eq 0.0)then continue
        data_box_geo_sum[data_box_col_pos,data_box_line_pos]+=data[data_col_i,data_line_i]
        data_box_geo_num[data_box_col_pos,data_box_line_pos]+=1.0
      endfor
    endfor

  endfor
  data_box_geo_num=(data_box_geo_num gt 0.0)*data_box_geo_num+(data_box_geo_num eq 0.0)
  data_box_geo_avr=data_box_geo_sum/data_box_geo_num
  
  geo_info={$
      MODELPIXELSCALETAG:[output_resolution,output_resolution,0.0],$;X,Y,Z方向的像元分辨率
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
      
    write_tiff,output_name,data_box_geo_avr,geotiff=geo_info,/float
    end_time=systime(1)
    print,'Time consuming:'+strcompress(string(end_time-start_time))
end