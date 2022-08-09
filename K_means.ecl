IMPORT $, std, Visualizer, Arquivos, KMeans, ML_Core;
Crimes := $.File_Crimes.File;
//numero de centroides
k := 3;


//reduzindo  o dataset
Layout_reduzido := RECORD
	Primary_type := Crimes.Primary_type;
	community_area := Crimes.community_area;
	date := Crimes.date;
END;
reduced_file := TABLE( Crimes (Year = '2001'), Layout_reduzido);

//Colocando um campo de ID do tipo de crime
contador_Primary_type := RECORD
	UNSIGNED2 codigo_Primary_type := 0;
	reduced_file.Primary_type;
	cnt := COUNT(GROUP);
END;
IDs := SORT(TABLE( reduced_file, contador_Primary_type, Primary_type), Primary_type);

//Cruando o ID de cada tipo de crime
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
	community_area := reduced_file.community_area;
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
	Hora_em_string.community_area;
	hora := (REAL4)Hora_em_string.hora;
  minuto := (REAL4)Hora_em_string.minuto;
	segundo := (REAL4)Hora_em_string.segundo;
	REAL4 AMPM := IF (Hora_em_string.AMPM = 'AM', 0, 12);
END;
Hora_separada := TABLE(Hora_em_string, Layout_resumo2);

//juntando hora, minuto e segundo em um unico campo decimal
Layout_final := RECORD
	UNSIGNED4 id;
	Hora_em_string.codigo_Primary_type;
	Hora_em_string.community_area;
	REAL4 hora := 0.0;
END;

Layout_final transf2 (Hora_separada Le, INTEGER C) := TRANSFORM
	 SELF.id := C;
   SELF.hora  :=  Le.hora + Le.minuto/60 + Le.segundo/3600 + Le.AMPM;
	 SELF := Le;
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
//Predict the cluster index of the new samples
Labels := KMeans.KMeans().Labels(Model);


SSS := ML_Core.Analysis.Clustering.SilhouetteScore(ML_data,Labels);
OUTPUT(Final);
OUTPUT(Centers);
OUTPUT(Iterations);
OUTPUT(SSS);
