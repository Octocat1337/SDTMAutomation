/* please run mapping matrix first. */
/* outputs template sas programs to selected folders.
Generates template programs according to Form and Filed sections in ALS (crf metadata)
*/

Options notes nomprint nosymbolgen nomlogic nofmterr nosource nosource2 missing=' ' noquotelenmax linesize=max noBYLINE SPOOL validvarname=v7 msglevel=i device=emf;
title ; footnote ;
proc datasets lib=work nolist  memtype=DATA kill; quit;
 
%*-------------------------------------------------------------------------------*;
%* Step 01: Config;
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

%macro Output_SDTM_Template_PGM(trakcer_path=
                              , tracker_name=
                              , PGM_OutPath=
                              , debug=Y);

    %if %length(&trakcer_path.) = 0 %then %let trakcer_path = &_doc.&_sbar.tracker;
    %if %length(&tracker_name.) = 0 %then %let tracker_name = &_studyid.-&_trunk.-tracker.xlsm; 
    %if %length(&PGM_OutPath.)  = 0 %then %let PGM_OutPath  = &_program_sdtm.; 

    proc import datafile="&trakcer_path.&_sbar.&tracker_name"
        out     =trakcer_file
        dbms    =xlsx
        replace;
        sheet   ="SDTM Dataset";
        getnames=yes;
    run;

    data sdtm_pgms;
	    set other.pgms;
    run;

    proc sql noprint;
        create table tracker as
          select distinct domain, Production_Programmer
              from trakcer_file
                  where domain ne ''
        ;
        select count(*) into: domain_num 
            from tracker
        ;
    quit;

    %if &domain_num.=0 %then %do;
    	%put ****宏Output_SDTM_Template_PGM信息: tracker里面没有分配Domain, 模板程序不会产生;
		%goto CEP_EXIT;
	%end;

    %do i=1 %to &domain_num.;

        data _null_;
            set tracker;
            if _n_=&i then do;
                call symput("domain",strip(lowcase(domain)));
                call symput("Programmer",strip(lowcase(Production_Programmer)));
            end;
        run;

        %let pgm_path=&PGM_OutPath.&_sbar.&domain..sas;

        %if %sysfunc(fileexist(&pgm_path.)) %then %do;
        	%put ****宏Output_SDTM_Template_PGM信息: &pgm_path.已存在, &domain.模板程序不会产生;
    	%end;

        %else %do;/*防止覆盖已存在的sdtm 程序*/

            filename pgm_path "&pgm_path" encoding='utf-8';

            data domain_pgm;
			    format check_domain $100.;
				informat check_domain $100.;
                length check_domain $100;
                set sdtm_pgms 
                    tracker(rename=(domain=check_domain) drop=Production_Programmer);/*tracker中的domain不在模板程序里时，仍可以输出空白的模板程序*/
                    where upcase(Check_Domain) = upcase("&domain");
            run;

            data _null_;
                file pgm_path notitles lrecl=5000 linesize=5000 termstr=LF; 
                set domain_pgm nobs=total_obs end=eof;
                
                if  _n_ = 1 then do;
                    put "/**********************************************************************************";
                    put " Project          : &_studyid.";
                    put " Program name     : %lowcase(&domain.).sas";
                    put " Description      : Create %upcase(&domain.) Dataset"/;
                    put " Programmer       : &Programmer."/;
                    put " Change Version:";
                    put " Date          Name            Description";
                    put " ----------    ------------    -----------------------------------------------";
                    put " %sysfunc(putn(%sysfunc(today()),yymmdd10.))      &Programmer.          Create."/;
                    put " ******************* CSPC Inc. All Rights Reserved. *******************************/ "/;
                    put "Options notes nomprint nosymbolgen nomlogic nofmterr nosource nosource2 missing=' ' noquotelenmax linesize=max noBYLINE SPOOL validvarname=v7 msglevel=i device=emf;";
                    put "title ; footnote ;";
                    put "proc datasets lib=work nolist  memtype=DATA kill; quit;"/;
                    put "*-------------------------------------------------------------------------------*;";
                    put "* Step 01: Config;";
                    put "*-------------------------------------------------------------------------------*;"/;
                    put %nrstr('%global _currentroot _currentfile _sbar;');
                    put %nrstr('%let _currentroot=&SYSINCLUDEFILEDIR.; %let _currentfile=&SYSINCLUDEFILENAME.;');
                    put %nrstr('%macro currentroot_sasserver;');
                    put %nrstr('%local _pathfile;');
                    put %nrstr('%if "&SYSSCPL."="Linux" %then %let _sbar=/; %else  %let _sbar=\;');
                    put %nrstr('%if %length(&_currentroot.)=0 %then %do;');
                    put %nrstr('%if %symexist(_SASPROGRAMFILE) and "&SYSSCPL."="Linux" %then %do;');
                    put %nrstr("%let _pathfile=%sysfunc(translate(%sysfunc(tranwrd(%sysfunc(tranwrd(&_SASPROGRAMFILE.,Z:,/data1)),\\172.16.10.70\,/)),%str( /),%str(%%'\)));");
                    put %nrstr('%end;');
                    put %nrstr('%else %do;');
                    put %nrstr('%let _pathfile= %sysfunc(getoption(sysin))%sysget(SAS_EXECFILEPATH);');
                    put %nrstr('%end;');
                    put %nrstr('%let _currentroot=%substr(&_pathfile.,1,%eval(%sysfunc(find(&_pathfile., &_sbar., -400))-1));');
                    put %nrstr('%let _currentfile=%scan(&_pathfile.,-1,&_sbar.);');
                    put %nrstr('%end;');
                    put %nrstr('%mend;');
                    put %nrstr('%currentroot_sasserver;')/;
                    put %nrstr('%include "&_currentroot.&_sbar.init.sas";')/;
                    put "%*-------------------------------------------------------------------------------*;";
                    put "%* Step 02: User-defined formats and macros;";
                    put "%*-------------------------------------------------------------------------------*;"////;
                end;

                if total_obs = 1 then do;/*tracker中的domain不在模板程序里，输出*/
                    put "%*-------------------------------------------------------------------------------*;";
                    put "%* Step 03: Create variables from RAW data;";
                    put "%*-------------------------------------------------------------------------------*;"////;

                    put "%*-------------------------------------------------------------------------------*;";
                    put "%* Step 04: Create final validation dataset;";
                    put "%*-------------------------------------------------------------------------------*;";
                    put %nrstr('%m_attrib(attrv=sdtm,dataset=pc,vlabel=label_CN,outlib=sdtm,popv=);')/;
                end; 
                else if total_obs > 1 then do;/*输出SDTM matrix里面的模板程序*/
                    n_spaces=length(PGM) - length(cats(PGM));                   
                    put @n_spaces PGM;
                end;

            run;

            filename pgm_path clear;

            data current_output;
                length sdtm_pgm $20;
                sdtm_pgm="&domain..sas";
            run;
            %if &i=1 %then %do;
                data already_output;
                    set current_output;
                    if 0;
                run;
            %end;

            data already_output;
                set already_output current_output;
            run;

        %end;
    %end;

    %if %sysfunc(exist(already_output)) %then %do;
        data _null_;
            set already_output;
        	put "****宏Output_SDTM_Template_PGM信息: " sdtm_pgm "已经输出";
        run;
    %end;

    %CEP_EXIT:
    %if %upcase(&debug) = N %then %do;
        proc datasets lib=work nolist  memtype=DATA kill; quit;
    %end;

%mend;

%Output_SDTM_Template_PGM;
