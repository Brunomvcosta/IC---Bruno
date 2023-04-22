EXPORT Elbow_oneHotEncoder(Crimes, k) := FUNCTIONMACRO

//reduzindo  o dataset
Layout_reduzido := RECORD
	Primary_type := Crimes.Primary_type;
	Latitude := Crimes.Latitude;
	Longitude := Crimes.Longitude;
	date := Crimes.date;
END;
reduced_file := Crimes;
numero_crimes := COUNT(GROUP(reduced_file));
//Colocando um campo de ID do tipo de crime
contador_Primary_type := RECORD
	UNSIGNED2 codigo_Primary_type := 0;
	reduced_file.Primary_type;
	cnt := COUNT(GROUP);
END;
IDs := SORT(TABLE( reduced_file, contador_Primary_type, Primary_type), Primary_type);

//Croando o ID de cada tipo de crime
Layout_dummy_Primary_type := RECORD
	UNSIGNED2 codigo_Primary_type := 0;
	reduced_file.Primary_type;
END;
Layout_dummy_Primary_type coloca_ID (IDs Le, INTEGER C) := TRANSFORM
   SELF.codigo_Primary_type  :=  C;
	 SELF := Le;
END;
dummy_Primary_type := PROJECT(IDs, coloca_ID(LEFT, COUNTER));
//Discretizando a hora
Layout_resumo := RECORD
	UNSIGNED2 codigo_Primary_type := 0;
	Latitude := reduced_file.Latitude;
	Longitude := reduced_file.Longitude;
	hora := reduced_file.date;
	STRING2 minuto := '00';
	STRING2 segundo := '00';
	STRING2 AMPM := '00';
END;
//Colocando o ID de cada tipo de crime e discretizando a hora
Layout_resumo transf1 (reduced_file Le, dummy_Primary_type R) := TRANSFORM
   SELF.hora  :=  (Le.date[12] + Le.date[13]);
	 SELF.minuto := Le.date[15] + Le.date[16];
	 SELF.segundo := Le.date[18] + Le.date[19];
	 SELF.AMPM := Le.date[21]+Le.date[22];
	 SELF.codigo_Primary_type := R.codigo_Primary_type;
	 SELF := Le;
END;
Hora_em_string := JOIN(reduced_file, dummy_Primary_type, (LEFT.Primary_type = RIGHT.Primary_type), transf1(LEFT, RIGHT),ALL);
//Transformando a hora de string em numero real
Layout_resumo2 := RECORD
	Hora_em_string.codigo_Primary_type;
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
	REAL4 hora := 0.0;
	REAL4 codigo_Primary_type;
	Real4 Latitude;
	Real4 Longitude;
END;

Layout_final transf2 (Hora_separada Le, INTEGER C) := TRANSFORM
	 SELF.id := C;
   SELF.hora  :=  (Le.hora + Le.minuto/60 + Le.segundo/3600 + Le.AMPM)*10/24;
	 SELF.codigo_Primary_type := ((REAL4)Le.codigo_Primary_type)*10/71;
	 SELF.Latitude := (Le.Latitude);
	 SELF.Longitude := (Le.Longitude);
END;
Final := PROJECT(Hora_separada, transf2(LEFT, COUNTER));

//Selecionando k centroides aleatorios
Layout_com_aleatorio := RECORD
	UNSIGNED4 rnd;
	id := Final.id;
END;
Layout_com_aleatorio coloca_random (Final Le) := TRANSFORM
   SELF.rnd  :=  RANDOM();
	 SELF := Le;
END;
ID_aleatorio := SORT(PROJECT(Final, coloca_random(LEFT)), rnd);
IDs_gerados := ID_aleatorio[1..k];

ML_Core.ToField(Final, ML_data);
//Criando os centroides
Layout_NMF := RECORD
	RECORDOF(ML_data);
END;
Layout_NMF transfNMF (ML_data Le, IDs_gerados R) := TRANSFORM
	 SELF := Le;
END;
Centroids := JOIN(ML_data, IDs_gerados, (LEFT.id = RIGHT.id), transfNMF(LEFT, RIGHT),ALL);

Max_iterations := 30;
Tolerance := 0.03;
//Train K-Means Model
//Setup the model
Pre_Model := KMeans.KMeans(Max_iterations, Tolerance);
//Train the model
Model := Pre_Model.Fit( ML_Data, Centroids);
//Coordinates of cluster centers
Centers := KMeans.KMeans().Centers(Model);
Iterations := KMeans.KMeans().Iterations(Model);
//Predict the cluster index of the new sample
Labels := KMeans.KMeans().Labels(Model);

Layout_centro := RECORD
	UNSIGNED4 id;
	REAL4 hora;
	REAL4 codigo_Primary_type;
	REAL4 Latitude;
	REAL4 Longitude;
END;

Layout_centro transfcentro (Centers L, Centers R) := TRANSFORM
	 SELF.id := R.id;
	 SELF.hora := IF(L.number = 1, L.value, 0); 
	 SELF.codigo_Primary_type := IF(L.number = 2, L.value, 0); 
	 SELF.Latitude := IF(L.number = 3, L.value, 0); 
	 SELF.Longitude := IF(L.number = 4, L.value, 0); 
END;
Centroides := GROUP(DEDUP(JOIN(Centers, Centers, (LEFT.id = RIGHT.id), transfcentro (LEFT, RIGHT), all)), id);
Layout_centro transfcentro2(Centroides L, Centroides R) := TRANSFORM
	SELF.id := R.id;
	SELF.hora := L.hora + R.hora;
	SELF.codigo_Primary_type := L.codigo_Primary_type + R.codigo_Primary_type;
	SELF.Latitude := L.Latitude + R.Latitude;
	SELF.Longitude := L.Longitude + R.Longitude;
END;
Centroides2 := ROLLUP(Centroides, LEFT.id = RIGHT.id, transfcentro2(LEFT,RIGHT));


Layout_label := RECORD
	UNSIGNED4 id;
	UNSIGNED4 label;
	REAL4 hora;
	REAL4 codigo_Primary_type;
	REAL4 Latitude;
	REAL4 Longitude;
END;
Layout_label coloca_label( Labels L, Final F) := TRANSFORM
	SELF.id := F.id;
	SELF.label := L.label;
	SELF := F;
END;
com_label := JOIN(Labels, Final, (LEFT.id = RIGHT.id), coloca_label(LEFT,RIGHT));
Layout_erro := RECORD
	UNSIGNED4 id;
	UNSIGNED4 label;
	REAL4 erro;
END;
Layout_erro calc_dist (Centroides2 C, com_label F) := TRANSFORM
	SELF.id := F.id;
	SELF.label := F.label; 
	SELF.erro := SQRT((F.hora-C.hora)*(F.hora-C.hora)+
							(F.codigo_Primary_type-C.codigo_Primary_type)*(F.codigo_Primary_type-C.codigo_Primary_type)+
							(F.Latitude-C.Latitude)*(F.Latitude-C.Latitude)+
							(F.Longitude-C.Longitude)*(F.Longitude-C.Longitude));
END;
erros := JOIN(Centroides2, com_label, (LEFT.id = RIGHT.Label), calc_dist (LEFT, RIGHT));
//SSS := ML_Core.Analysis.Clustering.SilhouetteScore(ML_data,Labels);
erro_final := SUM(erros, erro)/numero_crimes;
return teste;
ENDMACRO;