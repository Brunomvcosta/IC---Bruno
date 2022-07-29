EXPORT qui_quad(inFile,
               Par1,
               Par2) := FUNCTIONMACRO
							 
	Layout_reduzido := RECORD
		Variavel1 := (STRING)inFile.Par1;
		Variavel2 := (STRING)inFile.Par2;
	END;
	//Crimes_reduzido := TABLE( Crimes((primary_type = 'THEFT' OR  primary_type = 'BATTERY' OR primary_type = 'CRIMINAL DAMAGE' OR primary_type = 'NARCOTICS') AND (location_description = 'STREET' OR location_description = 'SIDEWALK' OR location_description = 'RESIDENCE')), layout_reduzido);
	reduced_file := TABLE( inFile, layout_reduzido);

	//Calculando graus de liberdade
	Layout_agrupado_1 := RECORD	
		reduced_file.Variavel1;
		cnt := COUNT(GROUP);
		END;
	tot1 := COUNT(SORT(TABLE(reduced_file, Layout_agrupado_1,Variavel1),Variavel1));

	Layout_agrupado_2 := RECORD	
		reduced_file.Variavel2;
		cnt := COUNT(GROUP);
		END;
	tot2 := COUNT(SORT(TABLE(reduced_file, Layout_agrupado_2, Variavel2), Variavel2)) ;



Layout_agrupado := RECORD	
	Variavel1 := reduced_file.Variavel1;
	Variavel2 := reduced_file.Variavel2;
	cnt := COUNT(GROUP);
	END;
Matriz_observada_1 := SORT(TABLE(reduced_file, Layout_agrupado,Variavel1, Variavel2),Variavel1, Variavel2) ;

//Preenchendo matriz observada
Layout_observada_1 := RECORD
	Variavel1 := Matriz_observada_1.Variavel1;
	Variavel2 := Matriz_observada_1.Variavel2;
	UNSIGNED4 cnt;
END;
Layout_observada_1 colocar_0(Matriz_observada_1 L, Matriz_observada_1 R) := TRANSFORM
	SELF.Variavel1 := L.Variavel1;
	SELF.Variavel2 := R.Variavel2;
	SELF.cnt := IF(L.Variavel2 = R.Variavel2 AND L.Variavel1 = R.Variavel1, R.cnt, 0);
END;
Matriz_observada_2 := DEDUP(SORT(JOIN(Matriz_observada_1, Matriz_observada_1, (LEFT.Variavel1 = RIGHT.Variavel2 OR LEFT.Variavel1 != RIGHT.Variavel2), colocar_0(LEFT, RIGHT),ALL), Variavel1, Variavel2, -cnt), Variavel1, Variavel2);
/*
Layout_observada_1 colocar_valores(Matriz_zerada L, Matriz_observada_1 R) := TRANSFORM
	SELF.Variavel1 := L.Variavel1;
	SELF.Variavel2 := L.Variavel2;
	SELF.cnt := IF(L.Variavel2 = R.Variavel2 AND L.Variavel1 = R.Variavel1, R.cnt, 0);
END;
Matriz_observada_2 := SORT(JOIN(Matriz_zerada, Matriz_observada_1, (LEFT.Variavel1 = RIGHT.Variavel1), colocar_valores(LEFT, RIGHT),ALL), Variavel1, Variavel2, cnt);

//output(Matriz_observada_2);
total := SUM(Matriz_observada_2, cnt);
//OUTPUT(total);
//OUTPUT(Matriz_observada_2, NAMED('Valores_observados'));
*/


//Preenchendo matriz esperada
Layout_totais_1 := RECORD
	Variavel1 := reduced_file.Variavel1;
	Variavel2 := reduced_file.Variavel2;
	UNSIGNED4 cnt;
END;
Layout_totais_1 calculo_E_1(Matriz_observada_2 L) := TRANSFORM
	SELF.Variavel1 := L.Variavel1;
	SELF.Variavel2 := L.Variavel2;
	SELF.cnt := (SUM(Matriz_observada_2(Variavel1 =L.Variavel1) , cnt)/SUM(Matriz_observada_2, cnt))*(SUM(Matriz_observada_2(Variavel2 =L.Variavel2), cnt)/SUM(Matriz_observada_2, cnt))*SUM(Matriz_observada_2, cnt);
END;
Matriz_esperada_1 := PROJECT(Matriz_observada_2, calculo_E_1(LEFT));
//OUTPUT(Matriz_esperada_1, NAMED('Valores_esperados'));


	//calculando qui quadrado
	
	Layout_chi_quadrado := RECORD
		REAL4 chi;
	END;
	Layout_chi_quadrado calculo_X(Matriz_observada_2 L, Matriz_esperada_1 R) := TRANSFORM
		SELF.chi := (L.cnt-R.cnt)*(L.cnt-R.cnt)/R.cnt;
	END;
	Chi := SUM(JOIN(Matriz_observada_2,Matriz_esperada_1, (LEFT.Variavel1 = RIGHT.Variavel1 AND  LEFT.Variavel2 = RIGHT.Variavel2), calculo_X(LEFT, RIGHT)),chi);
	//OUTPUT(Chi, NAMED('Chiquadrado'));
	z_alpha := 2*SQRT(Chi)-SQRT(2*((tot1-1)*(tot2-1))-1);
	//output(z_alpha, NAMED('z_alpha'));
	RETURN DATASET([{Chi, z_alpha,(tot1-1)*(tot2-1) }],{REAL4 qui_quadrado, REAL4 zalpha, UNSIGNED3 Graus_de_liberdade});

	//RETURN Matriz_zerada;
ENDMACRO;





