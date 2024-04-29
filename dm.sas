libname dm_adam "/home/u63805844/sasuser.v94/workshop/domain training/04_dm/adam";
libname dm_out "/home/u63805844/sasuser.v94/workshop/domain training/04_dm/output";
libname dm_raw "/home/u63805844/sasuser.v94/workshop/domain training/04_dm/raw";
libname dm_sdtm "/home/u63805844/sasuser.v94/workshop/domain training/04_dm/sdtm";
libname dm_table "/home/u63805844/sasuser.v94/workshop/domain training/04_dm/table";


/* **********sdtm mapping*********** */
/* ******1******* */
data dm1;
	set dm_raw.ie_new;
	if iesfyn='Yes' then output;
run;
proc sort data=dm_raw.ex_new out=sorted;
	by subject;
run;
/* ******2**** */
data dm2;
	set sorted;
	by subject;
	retain Exposure_Start_Date_Time;
	exdt_char=put(exdt,yymmdd10.);
	if first.subject then do;
		if exadmyn='Yes' then do;
			Exposure_Start_Date_Time=catx('T',exdt_char,exsttm);
		end;
		output;
	end;
	if last.subject then do;
		if exadmyn='Yes' then do;
			Exposure_End_Date_Time=catx('T',exdt_char,exentm);
		end;
		output;
	end;
run;
data dm2II;
	set dm2;
	by subject;
	if last.subject then output;
	drop exdt_char;
run;
proc print data=dm2II;
run;
data dm_out.fdose(drop= Exposure_Start_Date_Time Exposure_End_Date_Time Last_Exposure_DateTime) 
	 dm_out.ldose(drop= Exposure_Start_Date_Time Exposure_End_Date_Time First_Exposure_DateTime);
	set dm2II;
	if not missing(Exposure_Start_Date_Time) and not missing(Exposure_End_Date_Time) then do;
		First_Exposure_DateTime=Exposure_Start_Date_Time;
		output  dm_out.fdose;
		Last_Exposure_DateTime=Exposure_End_Date_Time;
		output dm_out.ldose;
	end;
run;

/* **********3******* */
data dm3;
	merge dm2II(in=a) dm_raw.dd;
	if a;
	DTHDTC=dthdt;
	if DTHDTC ne'' then DTHFL='Y';
	drop dthdt deathreas;
run;
/* ********4********* */
data dm4;
	length RFPENDTC $10;
	set dm_raw.ds;
	RFPENDTC=put(DSENDT,yymmdd10.);
run;
/* *********5********** */
data dm5;
	set dm_raw.dm;
	if race1=1 then RACE='AMERICAN INDIAN OR ALASKA NATIVE';
	else if race2=1 then RACE='ASIAN';
	else if race3=1 then RACE='BLACK OR AFRICAN AMERICAN';
	else if race4=1 then RACE='NATIVE HAWAIIAN OR PACIFIC ISLANDER';
	else if race5=1 then RACE='WHITE';
	else RACE='NOT REPORTED';
run;
/* ***********6************ */
data dm6;
	length ARMCD $5 ARM $7;
	set dm_raw.rand_new;
	if rndose='Placebo' then do;
		ARM='Placebo';
		ARMCD='PLAC';
	end;
	else do;
		ARM='NC55';
		ARMCD='NC55';
	end;
run;
data dm_ex_remake;
	set dm_sdtm.ex;
	by usubjid;
	retain exdt_start;
	if exseq=1 then do;
			Exdt_start=exstdtc;
		end;
		output;
	if exseq=5 then do;
			Exdt_end=exendtc;
		end;
		output;
run;
data dm_out.dm6II;
	set dm_ex_remake;
	by usubjid;
	if last.usubjid then output;
	drop exstdtc exendtc;
run;
data dm_out.dm6III(rename=(exdt_start=EXSTDTC exdt_end=EXENDTC));
	length ACTARMCD $8 ACTARM $7;
	set dm_out.dm6II;
	if extrt='Placebo' then do;
		ACTARM='Placebo';
		ACTARMCD='PLAC';
	end;
	else do;
		ACTARM='NC55';
		ACTARMCD='NC55';
	end;
run;

/* ************7************ */

data dm7;
	length RFICDTC $10;
	set dm_raw.ie_new;
	RFICDTC=put(DSSTDT,yymmdd10.);
	keep subject RFICDTC;
run;

data dm8;
	length RFSTDTC $16 RFENDTC $16 RFXSTDTC $16 RFXENDTC $16;
	merge dm7 dm_out.fdose dm_out.ldose;
	by subject;
	RFSTDTC=First_Exposure_DateTime;
	RFXSTDTC=First_Exposure_DateTime;
	RFENDTC=Last_Exposure_DateTime;
	RFXENDTC=Last_Exposure_DateTime;
	keep subject RFSTDTC RFENDTC RFXSTDTC RFXENDTC RFICDTC;
run;

data dm9;
	merge dm8 dm4;
	by subject;
	keep subject RFSTDTC RFENDTC RFXSTDTC RFXENDTC RFICDTC RFPENDTC;
run;

data dm10(rename=(agec=AGE sitec=SITEID sexc=SEX ethnicc=ETHNIC));
	length DTHDTC $6 DTHFL $5 AGEU $5 RACE $32 ETHNIC $22 BRTHDTC $7 SITEC $6 SEXC $3;
	merge dm9 dm5;
	by subject;
	DTHDTC='';
	DTHFL='';
	sitec=put(scan(SITE,1),$CHAR12.);
	BRTHDTC=BRTHYR_RAW;
	agec=strip(put(age, 3.));
	AGEU='YEARS';
	if sex='Male' then sexc='M';
	else sexc='F';
	ethnicc=upcase(ETHNIC);
	keep subject RFSTDTC RFENDTC RFXSTDTC RFXENDTC RFICDTC RFPENDTC DTHDTC DTHFL sitec BRTHDTC AGEC AGEU SEXC 
	RACE ETHNICC;
run;

data dm11;
	merge dm10 dm6;
	by subject;
	keep subject RFSTDTC RFENDTC RFXSTDTC RFXENDTC RFICDTC RFPENDTC DTHDTC DTHFL SITEID BRTHDTC AGE AGEU SEX 
	RACE ETHNIC ARM ARMCD;
run;

data dm6IV;
	set dm_out.dm6III;
	SUBJECT=put(substr(usubjid,11,9),$char9.);
	drop usubjid;
run;
data dm12;
	merge dm11 dm6IV;
	by subject;
	keep subject RFSTDTC RFENDTC RFXSTDTC RFXENDTC RFICDTC RFPENDTC DTHDTC DTHFL SITEID BRTHDTC AGE AGEU SEX 
	RACE ETHNIC ARM ARMCD ACTARM ACTARMCD;
run;

data dm13;
	length DOMAIN $6 USUBJID $19 COUNTRY $7;
	set dm12;
	STUDYID='NIM-55-22';
	DOMAIN='DM';
	USUBJID=catx('-',STUDYID,SUBJECT);
	SUBJID=subject;
	COUNTRY='USA';
	keep STUDYID DOMAIN USUBJID SUBJID RFSTDTC RFENDTC RFXSTDTC RFXENDTC RFICDTC RFPENDTC DTHDTC DTHFL SITEID BRTHDTC AGE AGEU SEX 
	RACE ETHNIC ARM ARMCD ACTARM ACTARMCD COUNTRY;
run;


data dm_out.Final;
	set dm13;
	label studyid='Study Identifier'
	domain='Domain Abbreviation'
	usubjid='Unique Subject Identifier'
	subjid='Subject Identifier for the Study'
	rfstdtc='Subject Reference Start Date/Time'
	rfendtc='Subject Reference End Date/Time'
	rfxstdtc='Date/Time of First Study Treatment'
	rfxendtc='Date/Time of Last Study Treatment'
	rficdtc='Date/Time of Informed Consent'
	rfpendtc='Date/Time of End of Participation'
	dthdtc='Date/Time of Death'
	dthfl='Subject Death Flag'
	siteid='Study Site Identifier'
	brthdtc='Date/Time of Birth'
	age='Age'
	ageu='Age Units'
	sex='Sex'
	race='Race'
	ethnic='Ethnicity'
	armcd='Planned Arm Code'
	arm='Description of Planned Arm'
	actarmcd='Actual Arm Code'
	actarm='Description of Actual Arm'
	country='Country'; 
run;
proc compare base=dm_sdtm.dm compare=dm_out.final;
run;
proc print data=dm_out.final;
run;

/* **********************SUPPDM CREATION******************** */
data supp_dm(rename=(iepvdtc=IEPVDT));
	length USUBJID $19;
	merge dm_raw.dm(keep=subject rpres) dm_raw.ie_new(keep= subject protver iepvdt) dm_raw.rand_new(keep= subject rnnum);
	by subject;
	USUBJID=catx('-','NIM-55-22',SUBJECT);
	IEPVDTC=put(iepvdt,yymmdd10.);
	keep  rpres protver iepvdtc rnnum usubjid;
	label iepvdtc='Protocol Deviation Date' protver='Protocol Version';
run;

proc transpose data=supp_dm out=transposed_suppdm;
	by usubjid;
	var protver rnnum iepvdt rpres;
run;

data supp_dm2(rename=(COL1=QVAL));
	length QNAM $7 QLABEL $36;
	set transposed_suppdm;
	if col1 ne "" then do; 
		QNAM=_NAME_;
		QLABEL=_LABEL_;
	output;
	end;
	drop _name_ _label_;
run;

data final_suppdm;
	length STUDYID $9 RDOMAIN $2  IDVAR $1 IDVARVAL $1  QORIG $3 QEVAL $1 QNAM $7 QLABEL $36 QVAL1 $10;
	label STUDYID='Study Identifier' 
	RDOMAIN='Related Domain Abbreviation'
	USUBJID='Unique Subject Identifier' 
	IDVAR='Identifying Variable'
	IDVARVAL='Identifying Variable Value' 
	QNAM='Qualifier Variable Name'
	QLABEL='Qualifier Variable Label'
	QVAL1='Data Value' 
	QORIG='Qrigin'
	QEVAL='Evaluator';
	set supp_dm2;
	if qnam='RPRES' then do;
	qlabel="Is Subject of Childbearing Potential";
	end;
	STUDYID="NIM-55-22";
	RDOMAIN="DM";
	QORIG="CRF";
	QVAL1=compress(PUT(QVAL,10.));
	drop qval;
	proc sort;by usubjid qnam;
run;

data dm_out.final_supp_dm(label=Supplemental Qualifiers for SUPPDM rename=(QVAL1=QVAL));
	set final_suppdm;
run;
	
proc compare base=dm_sdtm.suppdm compare=dm_out.final_supp_dm;
run;

