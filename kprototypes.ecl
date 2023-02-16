#OPTION('outputLimitMb', 100);
#OPTION('outputLimit', 300);
#OPTION('OutputLimitMB','257');
#OPTION('WUResultMaxSizeMB','257');
IMPORT $, std, Visualizer, Arquivos, KMeans, ML_Core_2;
Crimes := $.File_Crimes.File;
OUTPUT(Crimes);
//----------------------------------------Distancia lat/lon -------------------------------------------------
Layout_lat_lon := RECORD
	Primary_type := Crimes.Primary_type;
	Latitude := Crimes.Latitude;
	Longitude := Crimes.Longitude;
	date := Crimes.date;
END;
arquivo_red := TABLE(Crimes(Latitude != 0 OR Longitude != 0), Layout_lat_lon);

//41°52'43.0"N 87°38'09.0"W
//https://maps.app.goo.gl/diJxrTMWxf1uWGup9?g_st=ic
Latitude_base := 41.878611;
Longitude_base := -87.635833;
raio_terra := 6371;
Deg2Rad := 0.0174532925119;

Layout_distancia := RECORD
	Primary_type := arquivo_red.Primary_type;
	REAL4 Latitude;
	REAL4 Longitude;
	date := arquivo_red.date;
END;
Layout_distancia calc_dist (arquivo_red F) := TRANSFORM
	SELF.Primary_type := F.Primary_type;
	SELF.date := F.date;
	SELF.Latitude := Deg2Rad*(Latitude_base-F.Latitude)*raio_terra;
	SELF.Longitude := Deg2Rad*(Longitude_base*COS(Deg2Rad*Latitude_base)*raio_terra-F.Longitude*COS(Deg2Rad*F.Latitude)*raio_terra);
END;


Crimes_reduzido := PROJECT(arquivo_red, calc_dist (LEFT));


Layout_distancia_stdev := RECORD
	UNSIGNED6 ID;
	Latitude := Crimes_reduzido.Latitude;
	Longitude := Crimes_reduzido.Longitude;
END;
Layout_distancia_stdev calc_dist_stdev (Crimes_reduzido F, INTEGER C) := TRANSFORM
	SELF.ID := C;
	SELF.Latitude := F.Latitude;
	SELF.Longitude := F.Longitude;
END;
Lat_lon := PROJECT(Crimes_reduzido, calc_dist_stdev(LEFT, COUNTER));

ML_Core_2.ToField(Lat_lon, nf_latlon);

myAggs := ML_Core_2.FieldAggregates(nf_latlon).Simple;
lat_stdev := SUM(myAggs(number=1),sd);
lat_average := SUM(myAggs(number=1),mean);
lon_stdev := SUM(myAggs(number=2),sd);
lon_average := SUM(myAggs(number=2),mean);

//----------------------------------------Data em Decimal -------------------------------------------------
//Discretizando a hora
Layout_resumo := RECORD
	STRING Primary_type;
	REAL4 Latitude;
	REAL4 Longitude;
	hora := Crimes_reduzido.date;
	STRING2 minuto := '00';
	STRING2 segundo := '00';
	STRING2 AMPM := '00';
END;
//Colocando o ID de cada tipo de crime e discretizando a hora
Layout_resumo transf1 (Crimes_reduzido Le) := TRANSFORM
   SELF.hora  :=  (Le.date[12] + Le.date[13]);
	 SELF.minuto := Le.date[15] + Le.date[16];
	 SELF.segundo := Le.date[18] + Le.date[19];
	 SELF.AMPM := Le.date[21]+Le.date[22];
	 SELF := Le;
END;
Hora_em_string := PROJECT(Crimes_reduzido, transf1(LEFT));
//Transformando a hora de string em numero real
Layout_resumo2 := RECORD
	Hora_em_string.Primary_type;
	Hora_em_string.Latitude;
	Hora_em_string.Longitude;
	hora := (REAL4)Hora_em_string.hora;
  minuto := (REAL4)Hora_em_string.minuto;
	segundo := (REAL4)Hora_em_string.segundo;
	REAL4 AMPM := IF (Hora_em_string.AMPM = 'AM', 0, 12);
END;
Hora_separada := TABLE(Hora_em_string, Layout_resumo2);
//juntando hora, minuto e segundo em um unico campo decimal
Layout_final := RECORD
	UNSIGNED4 id;
	UNSIGNED4 hora := 0.0;
	STRING Primary_type;
	Real4 Latitude;
	Real4 Longitude;
END;
media_lat := AVE(Hora_separada, Latitude);
media_lon := AVE(Hora_separada, Longitude);
Layout_final transf2 (Hora_separada Le, INTEGER C) := TRANSFORM
	 SELF.id := C;
   SELF.hora  :=  IF((Le.hora + Le.minuto/60 + Le.segundo/3600 + Le.AMPM)>=2 AND (Le.hora + Le.minuto/60 + Le.segundo/3600 + Le.AMPM)<6, 1, 
											IF((Le.hora + Le.minuto/60 + Le.segundo/3600 + Le.AMPM)>=6 AND (Le.hora + Le.minuto/60 + Le.segundo/3600 + Le.AMPM)<10, 2,
												IF((Le.hora + Le.minuto/60 + Le.segundo/3600 + Le.AMPM)>=10 AND (Le.hora + Le.minuto/60 + Le.segundo/3600 + Le.AMPM)<15, 3, 
													IF((Le.hora + Le.minuto/60 + Le.segundo/3600 + Le.AMPM)>=15 AND (Le.hora + Le.minuto/60 + Le.segundo/3600 + Le.AMPM)<20, 4,
														5))));
	 //SELF.hora  :=  (Le.hora+Le.AMPM);
	 SELF.Primary_type := Le.Primary_type;
	 SELF.Latitude := ((Le.Latitude-lat_average)/(lat_stdev)-1)/2;
	 SELF.Longitude := ((Le.Longitude-lon_average)/(lon_stdev)-1)/2;
END;
Crimes_final := PROJECT(Hora_separada, transf2(LEFT, COUNTER));

Layout_final2 := RECORD
	STRING hora;
	STRING latitude;
	STRING longitude;
	STRING crime;
END;
//OUTPUT(Crimes_final);
IMPORT Python3 AS Python;  
//OUTPUT(CHOOSEN(Crimes_final,300000),,'~bmvc::class::intro::teste2',CSV);													 								


// Declaracao da funcao de conversao das informacoes binarias do blob em formato relacional
DATASET (Layout_final2) Kprot(DATASET (Layout_final) myData) := EMBED(Python)
		import pandas as pd
		import numpy as np
		from kmodes.kprototypes import KPrototypes
		pd.set_option('display.float_format', lambda x: '%.3f' % x)

		df = pd.DataFrame (myData, columns = ['id', 'hora','Primary_type','Latitude','Longitude'])
		df.pop('id')
		df_churn = pd.DataFrame(df.value_counts()).reset_index()
		catColumnsPos = [df.columns.get_loc(col) for col in list(df.select_dtypes('object').columns)]
		dfMatrix = df_churn.to_numpy()


		kprototype = KPrototypes(n_jobs = -1, n_clusters = 4, init = 'Huang', random_state = 0)
		kprototype.fit_predict(dfMatrix, categorical = catColumnsPos)
		kprototype.n_iter_
		kprototype.cost_
		df2 = pd.DataFrame(kprototype.cluster_centroids_,columns = ['hora','latitude','longitude','??' ,'crime'] )
		df2.pop('??')
		return list(df2.itertuples(index=False))

ENDEMBED;

myds := Kprot(Crimes_final);
OUTPUT(myds);

