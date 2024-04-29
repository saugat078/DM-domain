proc sort data=dm_out.final out=sorted_dm;
	by studyid usubjid;
run;
proc sort data=dm_out.final_supp_dm out=sorted_suppdm;
	by studyid usubjid;
run;

data array_transpose;
	length IEPVDT $31 PROTVER $5 RNNUM $24;
	set sorted_suppdm;
	by studyid usubjid;
	retain iepvdt protver rnnum;
	
	array testcd[3] $10 _temporary_ ("IEPVDT" "PROTVER" "RNNUM");
	array newvars[3] $40 iepvdt protver rnnum;
	
	if first.usubjid then call missing(of newvars[*]);
	do i=1 to dim(testcd);
		if qnam=testcd[i] and qval ne "" then newvars[i]=qval;
	end;
	
	if last.usubjid then flag=1;
	drop i;
	label IEPVDT="Protocol Deviation Date";
    label PROTVER="Protocol Version";
    label RNNUM="Randomization Number";
run;

data final_transposed_supp;
	set array_transpose;
	where flag=1;
	drop flag qnam qlabel qeval  qval;
run;

data merged_dm_suppdm;
	merge sorted_dm final_transposed_supp;
	by studyid usubjid;
run;



/* ****************DS AND SUPPDS TRANSPOSE/MERGING***************** */

data transpose;
	length EXDOSADJ	EXDSRED	EXVOLP $10;
	set dm_sdtm.suppex;
	by studyid usubjid idvarval;
	retain exdosadj exdsred exvolp;
	array testcd[3] $10 _temporary_("EXDOSADJ" "EXDSRED" "EXVOLP");
	array newvars[3] $10 exdosadj exdsred exvolp;
	
	if first.idvarval then call missing (of newvars[*]);
	do i=1 to dim(testcd);
		if qnam=testcd[i] and qval ne "" then newvars[i]=qval;
	end;
	if last.idvarval then flag=1;
	drop i;
	label EXDOSADJ="Dose Adjusted";
    label EXDSRED="Dose Level Reduced";
    label EXVOLP="Volume of Treatment";
run;
data final_transposed_supex;
	set transpose;
	where flag=1;
	drop flag qnam qlabel qeval  qval;
run;
data final_suppex;
	set final_transposed_supex;
	by usubjid;
	if last.usubjid then output;
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
	drop exstdtc exendtc;
run;
data dm6II;
	set dm_ex_remake(rename=(exdt_start=EXSTDTC exdt_end=EXENDTC));
	by usubjid;
	if last.usubjid then output;
run;

data final_merged_suppex_ex;
	merge final_suppex dm6II;
	by usubjid studyid;
run;


/* ******************exercises******************* */
data sex_race;
	set merged_dm_suppdm;
	if sex="M" then asexn=1;
	else asexn=2;
	if race="AMERICAN INDIAN OR ALASKA NATIVE" then aracen=1;
	else if race="ASIAN" then aracen=2;
	else if race="BLACK OR AFRICAN AMERICAN" then aracen=3;
	else if race="WHITE" then aracen=4;
	else aracen=5;
run;
data dm7;
	length RFICDTC $10;
	set dm_raw.ie_new;
	RFICDTC=put(DSSTDT,yymmdd10.);
	keep subject RFICDTC;
run;	
data dm8;
	length RFSTDTC $16 RFENDTC $16 RFXSTDTC $16 RFXENDTC $16 CSTUDYID $9;
	merge dm7 dm_out.fdose dm_out.ldose;
	by subject;
	RFSTDTC=First_Exposure_DateTime;
	RFXSTDTC=First_Exposure_DateTime;
	RFENDTC=Last_Exposure_DateTime;
	RFXENDTC=Last_Exposure_DateTime;
	CSTUDYID=PUT(STUDYID,BEST.);
	keep subject RFSTDTC RFENDTC RFXSTDTC RFXENDTC RFICDTC CSTUDYID;
run;
data dm4;
	set dm_raw.rand_new;
	keep subject rndt rndose;
run;
data dm5;
	set dm_out.dm6III;
run;

data merged_sex_extrt(rename=(subjid=subject));
	merge sex_race dm5;
	by usubjid;
run;

data final_merged;
	merge merged_sex_extrt dm8(rename=(CSTUDYID=STUDYID)) dm4;
	by subject;
run;
data flags;
	length SAFFL ITTFL ENRFL $5;
	set final_merged;
	if not missing(EXTRT) and not missing(exstdtc) then saffl='Y';
	else saffl='N';
	if not missing(rndt) then ittfl='Y';else ittfl='N';
	if not missing(rficdtc) then enrfl='Y'; else enrfl='N';
run;
data trt_flags;
	length TRTA $7 TRTAN $5;
	set FLAGS;
	if extrt='Placebo' then do;
		TRTA='Placebo';
		TRTAN='2';
	end;
	else do;
		TRTA='NC55';
		TRTAN='1';
	end;
run;
data trt_flags1;
	length TRTP $7 TRTPN $5;
	set FLAGS;
	if rndose='Placebo' then do;
		TRTP='Placebo';
		TRTPN='2';
	end;
	else do;
		TRTP='NC55';
		TRTPN='1';
	end;
run;
data final_flags;
	merge trt_flags trt_flags1;
	by usubjid;
run;
data time;
	length TRTSDT TRTEDT 8;
	set final_flags;
	TRTSDT=input(substr(RFXSTDTC,1,10),yymmdd10.);
	TRTSDTM=input(RFXSTDTC,e8601dt.);
	TRTEDT=input(substr(RFXENDTC,1,10),yymmdd10.);
	TRTEDTM=input(RFXENDTC,e8601dt.);
	format trtsdtm trtedtm e8601dt16.;
	format trtsdt trtedt date9.;
run;
data adsl;
	merge time dm_out.final(keep=studyid subjid usubjid);
	by usubjid;
run;
data final_adsl;
	length RNNUM1 $6 RANDFL $6;
	set adsl;
	RANDFL="Y";
	ARACE=RACE;
	AETHNIC=ETHNIC;
	STUDYID="NIM-55-22";
	DOMAIN="DM";
	RNNUM1="";
	drop rnnum;
run;
data final_adsl1(rename=(rnnum1=RNNUM) label="Subject Level Analysis");
	set final_adsl;
	label STUYDID= "Study Identifier"
		TRTSDT="Date of First Exposure to Treatment"
		TRTEDT="Date of Last Exposure to Treatment"
		TRTA="Actual Treatment"
		TRTAN="Actual Treatment (N)"
		SAFFL="Safety Population Flag"
		ITTFL="Intent-To-Treat Population Flag"
		RNNUM="Randomization Number"
		TRTP="Planned Treatment"
		TRTPN="Planned Treatment (N)"
		TRTSDTM="Datetime of First Exposure to Treatment"
		TRTEDTM="Datetime of Last Exposure to Treatment"
		RANDFL="Randomization Flag"
		ARACE="Analysis Race"
		AETHNIC="Analysis Ethnicity"
		RNNUM1="Randomization Number";
	keep studyid domain usubjid subjid rfstdtc rfendtc rfxstdtc rfxendtc rficdtc rfpendtc dthdtc dthfl siteid  age ageu sex race ethnic armcd arm actarmcd actarm country randfl rnnum1 saffl ittfl arace aethnic trtp trtpn trta trtan trtsdt trtedt trtsdtm trtedtm;
run;
proc contents data=final_adsl;
run;
proc contents data=dm_adam.adsl;
run;
proc compare base=final_adsl1 compare=dm_adam.adsl;
run;