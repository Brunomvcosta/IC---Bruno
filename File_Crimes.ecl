EXPORT File_Crimes := MODULE
	EXPORT Layout:= RECORD
		UNSIGNED ID;
		STRING Case_Number;
		STRING Date;
		STRING Block;
		STRING IUCR;
		STRING Primary_Type;
		STRING Description;
		STRING Location_Description;
		BOOLEAN Arrest;
		BOOLEAN Domestic;
		UNSIGNED2 Beat;
		UNSIGNED2 District;
		UNSIGNED2 Ward;
		UNSIGNED2 Community_Area;
		STRING FBI_Code;
		UNSIGNED6 X_Coordinate;
		UNSIGNED6 Y_Coordinate;
		STRING Year;
		STRING Updated_On;
		REAL4 Latitude;
		REAL4 Longitude;
		STRING Location;
		END;
	EXPORT File:=DATASET('~class::bmvc::intro::crimes',Layout,CSV(heading(1)));
END;