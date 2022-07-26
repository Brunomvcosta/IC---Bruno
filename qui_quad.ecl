

EXPORT qui_quad(inFile,
               Par1,
               Par2) := FUNCTIONMACRO //(Dataset, first parameter, second parameter)
							 
	Layout_reduced := RECORD
		Var1 := inFile.Par1;
		Var2 := inFile.Par2;
	END;
	reduced_file := TABLE( inFile, Layout_reduced);

	//Degrees of freedom
	Layout_grouped_1 := RECORD	
		reduced_file.Var1;
		cnt := COUNT(GROUP);
		END;
	tot1 := COUNT(SORT(TABLE(reduced_file, Layout_grouped_1,Var1),Var1));
	Layout_grouped_2 := RECORD	
		reduced_file.Var2;
		cnt := COUNT(GROUP);
		END;
	tot2 := COUNT(SORT(TABLE(reduced_file, Layout_grouped_2, Var2), Var2)) ;



Layout_grouped := RECORD	
	Var1 := reduced_file.Var1;
	Var2 := reduced_file.Var2;
	cnt := COUNT(GROUP);
	END;
Observed_matrix_1 := SORT(TABLE(reduced_file, Layout_agrupado,Var1, Var2),Var1, Var2) ;

//Preenchendo matriz observada
Layout_observed_1 := RECORD
	Variavel1 := Observed_matrix_1.Var1;
	Variavel2 := Observed_matrix_1.Var2;
	UNSIGNED4 cnt;
END;
Observed_matrix_1 colocar_0(Observed_matrix_1 L, Observed_matrix_1 R) := TRANSFORM
	SELF.Var1 := L.Var1;
	SELF.Var2 := R.Var2;
	SELF.cnt := 0;
END;
Matriz_zerada := SORT(JOIN(Observed_matrix_1, Observed_matrix_1, (LEFT.Var1 = RIGHT.Var2 OR LEFT.Var1 != RIGHT.Var2), colocar_0(LEFT, RIGHT),ALL), Var1, Var2);
Layout_observada_1 colocar_valores(Matriz_zerada L, Matriz_observada_1 R) := TRANSFORM
	SELF.Variavel1 := L.Var1;
	SELF.Variavel2 := L.Var2;
	SELF.cnt := IF(L.Var2 = R.Var2, R.cnt, 0);
END;
Matriz_observada_2 := SORT(JOIN(Matriz_zerada, Matriz_observada_1, (LEFT.Var1 = RIGHT.Var1), colocar_valores(LEFT, RIGHT),ALL), Var1, Var2);
//output(Matriz_observada_2);
total := SUM(Matriz_observada_2, cnt);
//OUTPUT(total);
//OUTPUT(Matriz_observada_2, NAMED('Valores_observados'));



//Preenchendo matriz esperada
Layout_totais_1 := RECORD
	Var1 := reduced_file.Var1;
	Var2 := reduced_file.Var2;
	UNSIGNED4 cnt;
END;
Layout_totais_1 calculo_E_1(Matriz_observada_2 L) := TRANSFORM
	SELF.Var1 := L.Var1;
	SELF.Var2 := L.Var2;
	SELF.cnt := (SUM(Matriz_observada_2(Var1 =L.Var1) , cnt)/SUM(Matriz_observada_2, cnt))*(SUM(Matriz_observada_2(Var2 =L.Var2), cnt)/SUM(Matriz_observada_2, cnt))*SUM(Matriz_observada_2, cnt);
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
	Chi := SUM(JOIN(Matriz_observada_2,Matriz_esperada_1, (LEFT.Var1 = RIGHT.Var1 AND  LEFT.Var2 = RIGHT.Var2), calculo_X(LEFT, RIGHT)),chi);
	//OUTPUT(Chi, NAMED('Chiquadrado'));
	z_alpha := 2*SQRT(Chi)-SQRT(2*((tot1-1)*(tot2-1))-1);
	//output(z_alpha, NAMED('z_alpha'));
	RETURN DATASET([{Chi, z_alpha,(tot1-1)*(tot2-1) }],{REAL4 qui_quadrado, REAL4 zalpha, UNSIGNED3 Graus_de_liberdade});
	//RETURN Chi;
ENDMACRO;



