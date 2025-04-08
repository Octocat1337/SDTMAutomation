/* Output excel and datasets. 
maps form,field,and pgm, then store to lib.other */

Options notes nomprint nosymbolgen nomlogic nofmterr nosource nosource2 missing=' ' noquotelenmax linesize=max noBYLINE SPOOL  VALIDVARNAME=v7 msglevel=I device=emf;
title ; footnote ;
proc datasets lib=work nolist  memtype=DATA kill; quit;

%*-------------------------------------------------------------------------------*;
%* Step 01: Config
%*-------------------------------------------------------------------------------*;
%global _currentroot _currentfile _sbar;
%let _currentroot=&SYSINCLUDEFILEDIR.; %let _currentfile=&SYSINCLUDEFILENAME.;
%macro currentroot_sasserver;
  %local _pathfile;
  %if "&SYSSCPL."="Linux" %then %let _sbar=/; %else  %let _sbar=\;
  %if %length(&_currentroot.)=0 %then %do;
    %if %symexist(_SASPROGRAMFILE) and "&SYSSCPL."="Linux" %then %do;
      %let _pathfile=%sysfunc(translate(%sysfunc(tranwrd(%sysfunc(tranwrd(&_SASPROGRAMFILE.,Z:,/data1)),\\172.16.10.70\,/)),%str( /),%str(%'\)));
    %end;
    %else %do;
      %let _pathfile= %sysfunc(getoption(sysin))%sysget(SAS_EXECFILEPATH);
    %end;
    %let _currentroot=%substr(&_pathfile.,1,%eval(%sysfunc(find(&_pathfile., &_sbar., -400))-1));
    %let _currentfile=%scan(&_pathfile.,-1,&_sbar.);
  %end;
%mend;
%currentroot_sasserver;

%include "&_currentroot.&_sbar.init.sas";

libname SDTMLIB "/data1/utility/template/SDTM半自动化工具/20240517";


/* read study level ALS file into sas*/
proc import datafile="&_doc./dm/specification/als" out=forms dbms=xlsx replace;
sheet="Form";
run;

proc import datafile="&_doc./dm/specification/als" out=fields dbms=xlsx replace;
sheet="Field";
run;

proc import datafile="&_doc./dm/specification/als" out=datadict dbms=xlsx replace;
sheet="DataDictionaryEntry";
run;




data forms_study;
   set forms;
   where isActive=1;
   drop isActive;
   rename ordinalPos= formorder;
   label ordinalPos="FormOrder" formName="FormName";
run;

data fields1;
   length dataformat $200;
   set fields;
   where fieldActive=1;
   if unit ne '' then dataFormat=strip(unit);
   if index(dataformat,"$") then dataformat= substr(dataformat,2);
   keep formOID fieldOID fieldName dataDictionaryOID dataFormat controlType ordinal;
   rename ordinal=fieldorder;
   label ordinal="FieldOrder" fieldName="FieldName" controltype="ControlType" dataformat="DataFormat";
run;

data datadict1;
   set datadict;
   where isActive=1;
   keep dataDictionaryOID itemDataString ordinal;
run;

proc sort data=datadict1;
   by dataDictionaryOID ordinal;
run;

data datadict2;
   set datadict1;
   by dataDictionaryOID ordinal;
   retain itemDataString_all;
   length itemDataString_all $2000;
   if first.dataDictionaryOID then itemDataString_all=strip(itemDataString);
   else itemDataString_all=catx(" ; ",itemDataString_all,itemDataString);
   if last.dataDictionaryOID;
run;

proc sql;
   create table fields_study as select distinct a.formOID,b.formname,b.formorder,a.fieldOID,a.fieldName,a.fieldorder
          ,a.controlType ,a.dataFormat,c.itemDataString_all as codelist 
      from fields1 as a left join forms_study as b
      on strip(a.formOID)=strip(b.formOID)
      left join datadict2 as c
      on strip(a.dataDictionaryOID)=strip(c.dataDictionaryOID)
      order by formorder,fieldorder
      ;
quit;



/* merge with the ALS standard library */
proc sort data=forms_study;
   by formoid;
run;

proc sort data=SDTMLIB.forms_lib(rename=(formname=formname_lib)) out=forms_lib;
   by formoid;
run;

data forms_out;
   format FormOID $10. FormName $200. FormOrder 8. In_Standard_Library $1. Target_Domains $50. Tool_Notes $2000. new_formoid 8. diff_formname 8. formname_lib $200.;
   informat FormOID $10. FormName $200. FormOrder 8. In_Standard_Library $1. Target_Domains $50. Tool_Notes $2000. new_formoid 8. diff_formname 8. formname_lib $200.;
   length FormOID $10 FormName $200 In_Standard_Library $1 Target_Domains $50 Tool_Notes $2000 formname_lib $200;
   merge forms_lib(in=lib) forms_study(in=study);
   by formoid;
   if study;
   if lib then In_Standard_Library="Y";
   else do; new_formoid=1; In_Standard_Library="N"; Tool_Notes="标准库中没有与当前相同的FormOID"; end;
   if lib and formname ne formname_lib then do;
      diff_formname=1;
      Tool_Notes="尽管标准库中有相同的FormOID，但对应的Study Level Formname与标准库中的Formname不同，后者是`"||strip(formname_lib)||"`";
   end;
run;

proc sort data=forms_out;
   by FormOrder;
run;

proc sort data=fields_study;
   by formoid fieldoid;
run;

proc sort data=SDTMLIB.fields_lib(rename=(formname=formname_lib fieldname=fieldname_lib controltype=controltype_lib dataformat=dataformat_lib codelist=codelist_lib)) out=fields_lib;
   by formoid fieldoid;
run;

data fields_out;
   format FormOID $10. FormName $200. FormOrder 8. FieldOID $10. FieldName $1000. FieldOrder 8. ControlType $200. DataFormat $200. Codelist $2000. In_Standard_Library  $1.
          Not_Submitted $1. Target_Domains $50. Target_Variables $50. Tool_Notes $5000. new_fieldoid 8. diff_fieldname 8. diff_controltype 8. diff_dataformat 8. diff_codelist 8.;
   informat FormOID $10. FormName $200. FormOrder 8. FieldOID $10. FieldName $1000. FieldOrder 8. ControlType $200. DataFormat $200. Codelist $2000. In_Standard_Library  $1.
          Not_Submitted $1. Target_Domains $50. Target_Variables $50. Tool_Notes $5000. new_fieldoid 8. diff_fieldname 8. diff_controltype 8. diff_dataformat 8. diff_codelist 8.;
   length FormOID $10 FormName $200 FieldOID $10 FieldName $1000 ControlType $200 DataFormat $200 Codelist $2000 In_Standard_Library $1
          Not_Submitted $1 Target_Domains $50 Target_Variables $50 Tool_Notes $5000;
   merge fields_lib(in=lib) fields_study(in=study);
   by formoid fieldoid;
   length Tool_Notes1 Tool_Notes2 Tool_Notes3 Tool_Notes4 $1000;
   if study;
   if lib then In_Standard_Library="Y";
   else do; new_fieldoid=1; In_Standard_Library="N"; Tool_Notes="标准库中没有与当前相同的FieldOID";end;
   if lib and fieldname ne fieldname_lib then do; 
      diff_fieldname=1; 
      Tool_Notes1="尽管标准库中有相同的FieldOID，但对应的Study Level Fieldname与标准库中的Fieldname不同，后者是`"||strip(fieldname_lib)||"`";
   end;
   if lib and controltype ne controltype_lib then do;
      diff_controltype=1; 
      Tool_Notes2="尽管标准库中有相同的FieldOID，但对应的Study Level Controltype与标准库中的Controltype不同，后者是`"||strip(controltype_lib)||"`";
   end;
   if lib and dataformat ne dataformat_lib then do;
      diff_dataformat=1; 
      Tool_Notes3="尽管标准库中有相同的FieldOID，但对应的Study Level Dataformat与标准库中的Dataformat不同，后者是`"||strip(dataformat_lib)||"`";
   end;
   if lib and codelist ne codelist_lib then do; 
      diff_codelist=1;
      Tool_Notes4="尽管标准库中有相同的FieldOID，但对应的Study Level Codelist与标准库中的Codelist不同，后者是`"||strip(codelist_lib)||"`";
   end;
   if missing(Tool_Notes) then Tool_Notes = catx(' / ',Tool_Notes1,Tool_Notes2,Tool_Notes3,Tool_Notes4);
   keep FormOID FormName FormOrder FieldOID FieldName FieldOrder ControlType DataFormat Codelist In_Standard_Library 
        Not_Submitted Target_Domains Target_Variables Tool_Notes new_fieldoid diff_fieldname diff_controltype diff_dataformat diff_codelist;
run;

proc sort data=fields_out;
   by FormOrder FieldOrder;
run;


proc sql;select count(distinct formoid) into: num_forms from forms_out;quit;
proc sql;select count(distinct formoid) into: new_forms from forms_out where new_formoid=1;quit;
proc sql;select count(distinct formoid) into: diff_forms from forms_out where diff_formname=1;quit;
proc sql;select count(distinct catx('_',formoid,fieldoid)) into: num_fields from fields_out;quit;
proc sql;select count(distinct catx('_',formoid,fieldoid)) into: new_fields from fields_out where new_fieldoid=1;quit;
proc sql;select count(distinct catx('_',formoid,fieldoid)) into: diff_fields from fields_out where new_fieldoid ne 1 and Tool_Notes ne '';quit;


data notes_for_users;
  length value $2000;
  label value="使用说明";
  value="本研究Forms共有%trim(&num_forms.)个，其中来自CRF标准库的Forms有%trim(%eval(&num_forms.-&new_forms.))个，占比%trim(%sysfunc(putn(%sysevalf((&num_forms.-&new_forms.)/&num_forms*100),8.1)))"||"%"; output;
  value="本研究中来自CRF标准库的%trim(%eval(&num_forms.-&new_forms.))个Forms中，FormName与标准库不同的有%trim(&diff_forms.)个，占比%trim(%sysfunc(putn(%sysevalf(&diff_forms./(&num_forms.-&new_forms.)*100),8.1)))"||"%"; output;
  value="本研究Fields共有%trim(&num_fields.)个，其中来自CRF标准库的Fields有%trim(%eval(&num_fields.-&new_fields.))个，占比%trim(%sysfunc(putn(%sysevalf((&num_fields.-&new_fields.)/&num_fields*100),8.1)))"||"%"; output;
  value="本研究中来自CRF标准库的%trim(%eval(&num_fields.-&new_fields.))个Fields中，FieldName/ControlType/DataFormat/Codelist与标准库不同的有%trim(&diff_fields.)个，占比%trim(%sysfunc(putn(%sysevalf(&diff_fields./(&num_fields.-&new_fields.)*100),8.1)))"||"%"; output;
  value=""; output;  
  value=""; output;
  value=""; output;
run;


/* output to Excel file*/
ods excel file="&_sdtmspecdir./&_studyid._SDTM_Mapping_Matrix_%sysfunc(putn(%sysfunc(today()),yymmdd10.)).xlsx" options
   ( embedded_titles      = 'yes'
     embed_titles_once    = 'yes'
     embedded_footnotes   = 'yes'
     autofilter           = "all"
     sheet_name           = "使用说明"
    );

proc report data=notes_for_users;
run;

ods excel options
   ( embedded_titles      = 'yes'
     embed_titles_once    = 'yes'
     embedded_footnotes   = 'yes'
     frozen_headers       = "on"
     autofilter           = "all"
     sheet_name           = "Forms"
    );

proc report data=forms_out out=other.forms(drop=_BREAK_ formname_lib);
  column FormOID FormName FormOrder In_Standard_Library Target_Domains Tool_Notes new_formoid diff_formname formname_lib;
  define FormOrder/ order display;
  define new_formoid/ noprint display;
  define diff_formname/ noprint display;
  define formname_lib/ noprint display;
  compute new_formoid;
	 if new_formoid=1 then call define(_ROW_,"style","style=[background=lightpurple]");
  endcomp;
  compute diff_formname;
	 if diff_formname=1 then call define("FormName","style","style=[background=lightblue]");
  endcomp;
run;


ods excel options
   ( embedded_titles      = 'yes'
     embed_titles_once    = 'yes'
     embedded_footnotes   = 'yes'
     frozen_headers       = "on"
     frozen_rowheaders    = "5"
     autofilter           = "all"
     sheet_name           = "Fields"
    );

proc report data=fields_out out=other.fields(drop=_BREAK_);
  column FormOID FormName FormOrder FieldOID FieldName FieldOrder ControlType DataFormat Codelist In_Standard_Library 
         Not_Submitted Target_Domains Target_Variables Tool_Notes new_fieldoid diff_fieldname diff_controltype diff_dataformat diff_codelist;
  define FormOrder/ order display;
  define FieldOrder/ order display;
  define new_fieldoid/ noprint display;
  define diff_fieldname/ noprint display;
  define diff_controltype/ noprint display;
  define diff_dataformat/ noprint display;
  define diff_codelist/ noprint display;
  compute new_fieldoid;
		if new_fieldoid=1 then call define(_ROW_,"style","style=[background=lightpurple]");
	endcomp;
  compute diff_fieldname;
		if diff_fieldname=1 then call define("FieldName","style","style=[background=lightblue]");
	endcomp;
  compute diff_controltype;
		if diff_controltype=1 then call define("ControlType","style","style=[background=lightblue]");
	endcomp;
  compute diff_dataformat;
		if diff_dataformat=1 then call define("DataFormat","style","style=[background=lightblue]");
	endcomp;
  compute diff_codelist;
		if diff_codelist=1 then call define("Codelist","style","style=[background=lightblue]");
	endcomp;
run;


ods excel close;

proc sql;
   create table pgms as 
   select distinct a.*, b.FormOID as form_als, c.FormOID as form_als2, c.fieldoid as field_als2
   from SDTMLIB.pgms_lib as a 
   left join other.forms as b
     on upcase(strip(a.check_form))=upcase(strip(b.FormOID))
   left join other.fields as c
     on upcase(strip(a.check_form))=upcase(strip(c.FormOID)) and upcase(strip(a.check_field))=upcase(strip(c.fieldoid))
   order by a.check_domain,a.order;
quit;

data other.pgms;
   set pgms;
   by check_domain order;
   if ( missing(check_form) and missing(check_field) ) or
      ( not missing(check_form) and missing(check_field) and not missing(form_als) ) or
      ( not missing(check_form) and not missing(check_field) and not missing(form_als2) and not missing(field_als2) )
    ;
   keep pgm check_domain order;
run;
