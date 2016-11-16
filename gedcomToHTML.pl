#!/usr/bin/perl

# gedcomToHTML.pl 1.5.6 -- Dan Pidcock 22 Feb 2007
$version = "1.5.6"; # version number
# Danio@bigfoot.com - www.pidcock.co.uk/gth

# Copyright (c) Dan Pidcock, 1997-2007.

# This program is freely distributable without licensing fees 
# and is provided without guarantee or warrantee expressed or 
# implied. This program is NOT in the public domain.

# translate gedcom files to html
# based on the gedcom 5.5 standard and a sample gedcom 5.3 file
# doesn't handle all gedcom elements

# Feel free to use this program, but please keep the authorship the
# same.  If you have any changes you have made, I would be happy to
# incorporate them and put your name on the credits.  - Dan

# Credits for contributions:
# Baptism, sealing, repository info added - Jay North
# Group by letter in surnames file - Jay North
# Trailing slash removed from surnames for sorting - Jay North
# Make a statistics file - Jay North
# HTML made 4.0 standard - Jay North
# Christening (1.5.3) -  John ffitch
# Children > 8 bug (1.5.1) - Richard Ball, WebbedGed author (Dick Purnell??)
# Source and titles, better comma code in v1.5 by David Moore
# Surnames beginning with same letter on same line in v1.5 by jpb
# Photo thumbnails (1.5) - anonymouse contributor
# Multiple marriage code of 1.22b based on that by Dale DePriest
# Improvements proposed by Graham Lawrence 18 Nov 1997 changes and
# incorporated in v1.2.

# The preferences file name
$prefsFile = "gedcomToHTML.prefs";

# The strings that are printed into files - change for different
# languages

$str_birth="Birth:";
$str_chr="Christened:";
$str_baptism="LDS Baptism:";
$str_endowment="LDS Endowment:";
$str_sealing_children="LDS Sealing to Children:";
$str_sealing_spouse="LDS Sealing to Spouse:";
$str_death="Death:";
$str_burial="Burial:";
$str_occupation="Occupation:";
$str_private="(Private)";
$str_father="Father:";
$str_mother="Mother:";
$str_child="Child";
$str_notes="Notes:";
$str_title="Title:";
$str_author="Author:";
$str_pub_info="Publication Info:";
$str_abbr="Abbreviation:";
$str_call_num="Call Number:";
$str_comments="Comments:";
$str_text="Text:";
$str_source="Source";
$str_all_surnames="All surnames in the tree";
$str_people="People";
$str_surnames="Surnames";
$str_married="Married";
$str_divorced="Divorced";
$str_on="on ";
$str_at="at ";
$str_list_of="List of";
$str_lpeople="List of people";
$str_lsurnames="List of surnames";
$str_people_and="people and";
$str_unique_names="unique names";
$str_m="m.";

# Characters to ignore when sorting surnames
$ignoreSurnameSort = " '";

# Leave the rest alone unless you know what's happenin'

$in = 0; # What is being read.  
            # 0=nothing, 1=header, 2=family record, 
            # 3=individual record, 4=note record.
            # 5=source record.
$in1 = 0; # What is at level 1 at the mo.
            # 0=nothing, 1=birth(indiv), 2=death(indiv),
            # 3=burial(indiv), 4=notes(i), 7=christening(indiv)
            # 50=marriage(fam),
            # 60=note(source),
            # 61=comment(source).

print "gedcomToHtml $version (c) Dan Pidcock 1997-2006\n";

if ($#ARGV != 0) {
    die "usage: gedcomToHTML.pl <gedcom file>\n";
}
print "Gedcom file @ARGV\n";

#######################################################################
# Get the preferences
# Set defaults
$family_table = 1;  # print family tree type table
$print_family = 0;  # print detailed family info
$print_notes = 1;   # Print an individual's notes
$print_sources = 1; # Print an individual's source references
$make_stats = 0;    # Make a statistics file
$add_titles = 1;    # Add titles to names
$group_letters = 1; # Group by letter
$check_images = 1;  # Check for images in the $out_dir/$photo_dir directory
$extension = "html"; # extension for created files
$private = 1;       # Make birth information private
$out_dir = "Html";  # Directory where the HTML files will be stored
$photo_dir = "../Photo"; # Directory where the individual's picture files are
                        # (relative to $out_dir)
$photoThumbnails = 0;
$treepic_path = "../Pics";
$updateStatus = 1;
if (open(IN_FILE, "<$prefsFile")) {
    while (<IN_FILE>) {
        # match anything except space or = then space = space anything except  or # anything
        # e.g. variable = value # comment
      if (/([^\s=]*)\s*=\s([^#\s]*).*\n/) {
                            # There must be a better way of doing this...
                            if ($1 eq "family_table") {
                                $family_table = $2; }
                            elsif ($1 eq "print_family") {
                                $print_family = $2; }
                            elsif ($1 eq "print_notes") {
                                $print_notes = $2; }
                            elsif ($1 eq "print_sources") {
                                $print_sources = $2; }
                            elsif ($1 eq "make_stats") {
                                $make_stats = $2; }
                            elsif ($1 eq "add_titles") {
                                $add_titles = $2; }
                            elsif ($1 eq "group_letters") {
                                $group_letters = $2;  }                         
                            elsif ($1 eq "check_images") {
                                $check_images = $2;  }
                            elsif ($1 eq "extension") {
                                $extension = $2;  }
                            elsif ($1 eq "private") {
                                $private = $2;  }
                            elsif ($1 eq "out_dir") {
                                $out_dir = $2;  }
                            elsif ($1 eq "photo_dir") {
                                $photo_dir = $2; }
                            elsif ($1 eq "photo_thumbnails") {
                                $photoThumbnails = $2; }
                            elsif ($1 eq "treepic_path") {
                                $treepic_path = $2;  }
                            elsif ($1 eq "update_status") {
                                $updateStatus = $2; }
                        }
                       }
}
else {
    print "Cannot find preferences file $prefsFile - using defaults\n";
}

# Get this year in 4 figure format
$curr_year = 1900 + (localtime(time))[5];

#######################################################################
# Make the directory and chdir to it

if (!-e $out_dir) {
    unless (mkdir($out_dir,0755)) {
        die "Couldn't create $out_dir directory\n";
    }
}

#################################################################
# Read the gedcom file in and created the individual and family 
# data structures.
print "Reading information\n";
$| = 1; # flushing for progress report.
$num_indivs = 0;
$num_families = 0;
$num_source = 0;
$num_repository = 0;
while (<>) {
    if (/^\s*0.*/) { # a 0 line
        if ($in1 != 0) # reset in1
            {$in1 = 0;}
        if (/^\s*0\s*HEAD/) { # header
            $in = 1;
            #print "Header $_";
        }
        elsif (/^\s*0\s@(.*)@\sFAM/) { # family record
            $in = 2;
            $fam_id = $1;
            $fams{$fam_id}++;
            $famc_cnt = 1;
            $num_families++;
            &show_reading_status;
            #print "Family $_";
        }
        elsif (/^\s*0\s@(.*)@\sINDI/) { # individual record
            $in = 3;
            $indiv_id = $1;
            $indivs{$indiv_id}++;
            $num_indivs++;
            $num_fams = 0; # number of spouses
            &show_reading_status;
            #print "Individual $_";
        }
        elsif (/^\s*0\sTRLR/) { # end of file
            $in = 0;
        }
        elsif (/^\s*0\s@(.*)@\sSUBM/) { # submission record - just ignore
            $in = 0;
        }
        elsif (/^\s*0\s@(.*)@\sNOTE/) { # note record - linked to an indi
            $note_id = $1;
            # Separate notes in separate lines with line break.
            $note{$note_id} = $note{$note_id}."<br/>";
            $in = 4;
        }
        elsif (/^\s*0\s@(.*)@\sSOUR/) { # source record - linked to an indi
            $sour_id = $1;
            $sours{$sour_id}++;
            $in = 5;
                $num_source++;
            &show_reading_status;

        }
          elsif (/^\s*0\s@(.*)@\sREPO/) { # repository record - linked to a source record
            $repo_id = $1;
            $repos{$repo_id}++;
            $in = 6;
                $num_repository++;
            &show_reading_status;
        }
        else {
            $in = 0;
            print "Don't understand this 0 line: $_";
        }
    }
    elsif (/^\s*1\s(.*)/) { # a 1 line
        $rol = $1;
        if ($in1 != 0) # reset in1
            {$in1 = 0;}
        if ($in == 1) {
            ; # ignore the header
        }
        elsif ($in == 2) { #family record
            #print "\tfamily $fam_id $rol\n";
            if ($rol =~ /HUSB\s@(.*)@/) {
                $fam_husb{$fam_id} = $1;
            }
            if ($rol =~ /WIFE\s@(.*)@/) {
                $fam_wife{$fam_id} = $1;
            }
            if ($rol =~ /CHIL\s@(.*)@/) {
                #$key = $fam_id."@".$famc_cnt."@".$1;
                #$fam_chil{$key} = $1;
                if ($famc_cnt == 1) { # First one
                    $fam_chil{$fam_id} = $1;}
                else {
                    $fam_chil{$fam_id} = $fam_chil{$fam_id}."@".$1;}
                $key = $fam_id;
                $famc_cnt++;
            }
            elsif ($rol =~ /MARR.*/) {
                $in1 = 50;
            }
            elsif ($rol =~ /DIV.*/) {
                $in1 = 51;
            }
        }
        elsif ($in == 3) { # individual record
            #print "\tindividual $indiv_id $rol\n";
            if ($rol =~ /NAME\s(.*)/) {
                # convert the surname to italics
                $name = $1;
                $name =~ /(.*)\/(.*)\/(.*)/;
                $temp_surname = $2;
                $temp_surname =~s/\s$//;
                $indiv_surname{$indiv_id} = $temp_surname;
                $indiv_forname{$indiv_id} = $1." ".$3;          
                $_ = $name;
                s/\// <i>/;
                s/\//<\/i>/;
                $indiv_name{$indiv_id} = $_;
                $_ = $name;
                s/\// /g;
                $indiv_name_unformatted{$indiv_id} = $_;                
            }
            elsif ($rol =~ /SEX\s(.)/) {
                $indiv_sex{$indiv_id} = $1;
            }
            elsif ($rol =~ /TITL\s(.*)/) {
                $indiv_titl{$indiv_id} = $1;
            }
            elsif ($rol =~ /BIRT.*/) {
                $in1 = 1;
            }
            elsif ($rol =~ /CHR.*/) {
                $in1 = 7;
            }
            elsif ($rol =~ /DEAT.*/) {
                $in1 = 2;
            }
            elsif ($rol =~ /BURI.*/) {
                $in1 = 3;
            }
            elsif ($rol =~ /OCCU\s(.*)/) {
                $indiv_occu{$indiv_id} = $1;
            }
            #elsif ($rol =~ /NOTE\s@(.*)@/) {
                # note with link to level 0 note record
            #    $indiv_note_link{$indiv_id} = $1;
            #    $note_indiv_link{$1} = $indiv_id;
            #    $in1 = 4;
            #}
            elsif ($rol =~ /NOTE\s(.*)/) {
                $indiv_note{$indiv_id} = $1;
                $in1 = 4;
            }
            elsif ($rol =~ /BAPL.*/) {
                $in1 = 8;
            }
            elsif ($rol =~ /ENDL.*/) {
                $in1 = 9;
            }
            elsif ($rol =~ /SLGC.*/) {
                $in1 = 10;
            }
            elsif ($rol =~ /SLGS.*/) {
                $in1 = 11;
            }
            elsif ($rol =~ /SOUR\s@(.*)@/) { # general source for individual
                $indiv_sour{$indiv_id} = $1;
            }
            elsif ($rol =~ /FAMC\s@(.*)@/) { # child to family link
                $indiv_famc{$indiv_id} = $1;
            }
            elsif ($rol =~ /FAMS\s@(.*)@/) { # spouse to family link
                if ($num_fams > 0) {
                    $indiv_fams{$indiv_id} = $indiv_fams{$indiv_id}."@".$1;
                }
                else {
                    $indiv_fams{$indiv_id} = $1;                    
                }
                $num_fams++;
            }
        }
        elsif ($in == 4) { # note record
            # $note_id has the note link code
            if ($rol =~ /CONC\s?(.*)/) {
                $note{$note_id} = $note{$note_id}." $1";
            }
            elsif ($rol =~ /CONT\s?(.*)/) {
                $note{$note_id} = $note{$note_id} . "<br/>\n$1" ;
            }
        }
        elsif ($in == 5) { # sour record
            # Convert any http references so a user jump from the source
            # file directly to the source link.
            # This assumes the reference is space delimited, could be better.
            $rol =~ s/(http:\/\/\S+)/<a href=\"$1\">$1<\/a>/;

            if ($rol =~ /TITL\s?(.*)/) {
                $sour_titl{$sour_id} = $1;
            }
            elsif ($rol =~ /AUTH\s?(.*)/) {
                $sour_auth{$sour_id} = $1;
            }
            elsif ($rol =~ /REPO\s@(.*)@/) {
                $sour_repo{$sour_id} = $1;
            }
            elsif ($rol =~ /PUBL\s?(.*)/) {
                $sour_publ{$sour_id} = $1;
            }
            elsif ($rol =~ /ABBR\s?(.*)/) {
                $sour_abbr{$sour_id} = $1;
            }
            elsif ($rol =~ /CALN\s?(.*)/) {
                $sour_caln{$sour_id} = $1;
            }
            elsif ($rol =~ /NOTE\s?(.*)/) {
                $sour_note{$sour_id} = $1;
                $in1 = 60;
            }
            elsif ($rol =~ /TEXT\s?(.*)/) {
                $sour_text{$sour_id} = $1;
                $in1 = 61;
            }
        }
        elsif ($in == 6) { # sour record
            # Convert any http references so a user jump from the source
            # file directly to the source link.
            # This assumes the reference is space delimited, could be better.
            $rol =~ s/(http:\/\/\S+)/<a href=\"$1\">$1<\/a>/;

            if ($rol =~ /NAME\s?(.*)/) {
                $repo_name{$repo_id} = $1;
            }
            elsif ($rol =~ /ADDR\s?(.*)/) {
                $repo_addr{$repo_id} = $1;
                $in1 = 601;
            }
            elsif ($rol =~ /NOTE\s?(.*)/) {
                $repo_note{$repo_id} = $1;
                $in1 = 602;
            }
            elsif ($in1 == 1) { # TEXT in source
                if ($rol =~ /CONC\s?(.*)/) {          
                    $repo_addr{$repo_id} = $repo_addr{$repo_id}." $1";
                }
                elsif ($rol =~ /CONT\s?(.*)/) {          
                    $repo_addr{$repo_id} = $repo_addr{$repo_id}."<br/>\n$1";
                }
            }
        }
    } # end if a 1 line
    elsif (/^\s*2\s(.*)/) { # a 2 line
        $rol = $1;
        if ($in1 == 1) { # BIRT in individual
            if ($rol =~ /DATE\s(.*)/) {
                $indiv_birt_date{$indiv_id} = $1;
                $indiv_birt{$indiv_id} = 1;
            }
            elsif ($rol =~ /PLAC\s(.*)/) {
                $indiv_birt_plac{$indiv_id} = $1;
                $indiv_birt{$indiv_id} = 1;
            }
            elsif ($rol =~ /SOUR\s@(.*)@/) { # source of birth record
                $indiv_birt_sour{$indiv_id} = $1;
                $indiv_birt{$indiv_id} = 1;
            }
        }
        elsif ($in1 == 2) { # DEAT in individual
            if ($rol =~ /DATE\s(.*)/) {
                $indiv_deat_date{$indiv_id} = $1;
                $indiv_deat{$indiv_id} = 1;
            }
            elsif ($rol =~ /PLAC\s(.*)/) {
                $indiv_deat_plac{$indiv_id} = $1;
                $indiv_deat{$indiv_id} = 1;
            }
            elsif ($rol =~ /SOUR\s@(.*)@/) { # source of death record
                $indiv_deat_sour{$indiv_id} = $1;
                $indiv_deat{$indiv_id} = 1;
            }
        }
        elsif ($in1 == 3) { # BURI in individual
            if ($rol =~ /DATE\s(.*)/) {
                $indiv_buri_date{$indiv_id} = $1;
                $indiv_buri{$indiv_id} = 1;
            }
            elsif ($rol =~ /PLAC\s(.*)/) {
                $indiv_buri_plac{$indiv_id} = $1;
                $indiv_buri{$indiv_id} = 1;
            }
        }
        elsif ($in1 == 4) { # NOTE in individual
            if ($rol =~ /CONC\s?(.*)/) {          
                $indiv_note{$indiv_id} = $indiv_note{$indiv_id}." $1";
            }
            elsif ($rol =~ /CONT\s?(.*)/) {
                $indiv_note{$indiv_id} = $indiv_note{$indiv_id}."<p/>\n$1" ;
            }
        }
        if ($in1 == 7) { # CHR in individual
            if ($rol =~ /DATE\s(.*)/) {
                $indiv_chr_date{$indiv_id} = $1;
                $indiv_chr{$indiv_id} = 1;
            }
            elsif ($rol =~ /PLAC\s(.*)/) {
                $indiv_chr_plac{$indiv_id} = $1;
                $indiv_che{$indiv_id} = 1;
            }
            elsif ($rol =~ /SOUR\s@(.*)@/) { # source of christening record
                $indiv_chr_sour{$indiv_id} = $1;
                $indiv_chr{$indiv_id} = 1;
            }
        }
        elsif ($in1 == 8) { # BAPL in individual
            if ($rol =~ /DATE\s(.*)/) {
                $indiv_bapl_date{$indiv_id} = $1;
                $indiv_bapl{$indiv_id} = 1;
            }
            elsif ($rol =~ /PLAC\s(.*)/) {
                $indiv_bapl_plac{$indiv_id} = $1;
                $indiv_bapl{$indiv_id} = 1;
            }
            elsif ($rol =~ /TEMP\s(.*)/) {
                $indiv_bapl_temp{$indiv_id} = $1;
                $indiv_bapl{$indiv_id} = 1;
            }
            elsif ($rol =~ /STAT\s(.*)/) {
                $indiv_bapl_stat{$indiv_id} = $1;
                $indiv_bapl{$indiv_id} = 1;
            }
        }
        elsif ($in1 == 9) { # ENDL in individual
            if ($rol =~ /DATE\s(.*)/) {
                $indiv_endl_date{$indiv_id} = $1;
                $indiv_endl{$indiv_id} = 1;
            }
            elsif ($rol =~ /PLAC\s(.*)/) {
                $indiv_endl_plac{$indiv_id} = $1;
                $indiv_endl{$indiv_id} = 1;
            }
            elsif ($rol =~ /TEMP\s(.*)/) {
                $indiv_endl_temp{$indiv_id} = $1;
                $indiv_endl{$indiv_id} = 1;
            }
            elsif ($rol =~ /STAT\s(.*)/) {
                $indiv_endl_stat{$indiv_id} = $1;
                $indiv_endl{$indiv_id} = 1;
            }
        }
        elsif ($in1 == 10) { # SLGC in individual
            if ($rol =~ /DATE\s(.*)/) {
                $indiv_slgc_date{$indiv_id} = $1;
                $indiv_slgc{$indiv_id} = 1;
            }
            elsif ($rol =~ /PLAC\s(.*)/) {
                $indiv_slgc_plac{$indiv_id} = $1;
                $indiv_slgc{$indiv_id} = 1;
            }
            elsif ($rol =~ /TEMP\s(.*)/) {
                $indiv_slgc_temp{$indiv_id} = $1;
                $indiv_slgc{$indiv_id} = 1;
            }
            elsif ($rol =~ /STAT\s(.*)/) {
                $indiv_slgc_stat{$indiv_id} = $1;
                $indiv_slgc{$indiv_id} = 1;
            }
        }
        elsif ($in1 == 11) { # SLGS in individual
            if ($rol =~ /DATE\s(.*)/) {
                $indiv_slgs_date{$indiv_id} = $1;
                $indiv_slgs{$indiv_id} = 1;
            }
            elsif ($rol =~ /PLAC\s(.*)/) {
                $indiv_slgs_plac{$indiv_id} = $1;
                $indiv_slgs{$indiv_id} = 1;
            }
            elsif ($rol =~ /TEMP\s(.*)/) {
                $indiv_slgs_temp{$indiv_id} = $1;
                $indiv_slgs{$indiv_id} = 1;
            }
            elsif ($rol =~ /STAT\s(.*)/) {
                $indiv_slgs_stat{$indiv_id} = $1;
                $indiv_slgs{$indiv_id} = 1;
            }
        }
        elsif ($in1 == 50) { # MARR in family
            if ($rol =~ /DATE\s(.*)/) {
                $fam_marr_date{$fam_id} = $1;
                $fam_marr{$fam_id} = 1;
            }
            elsif ($rol =~ /PLAC\s(.*)/) {
                $fam_marr_plac{$fam_id} = $1;
                $fam_marr{$fam_id} = 1;
            }
            elsif ($rol =~ /SOUR\s@(.*)@/) { # source of marriage record
                $fam_marr_sour{$fam_id} = $1;
                $fam_marr{$fam_id} = 1;
            }
        }
        elsif ($in1 == 51) { # DIV in family
            if ($rol =~ /DATE\s(.*)/) {
                $fam_div_date{$fam_id} = $1;
                $fam_div{$fam_id} = 1;
            }
            elsif ($rol =~ /PLAC\s(.*)/) {
                $fam_div_plac{$fam_id} = $1;
                $fam_div{$fam_id} = 1;
            }
            elsif ($rol =~ /SOUR\s@(.*)@/) { # source of divorce record
                $fam_div_sour{$fam_id} = $1;
                $fam_div{$fam_id} = 1;
            }
        }
       elsif ($in1 == 60) { # NOTE in source
            if ($rol =~ /CONC\s?(.*)/) {          
                $sour_note{$sour_id} = $sour_note{$sour_id}." $1";
            }
            elsif ($rol =~ /CONT\s?(.*)/) {
                $sour_note{$sour_id} = $sour_note{$sour_id}."<br/>\n$1";
            }
        }
        elsif ($in1 == 61) { # TEXT in source
            if ($rol =~ /CONC\s?(.*)/) {          
                $sour_text{$sour_id} = $sour_text{$sour_id}." $1";
            }
            elsif ($rol =~ /CONT\s?(.*)/) {
                $sour_text{$sour_id} = $sour_text{$sour_id}."<br/>\n$1";
            }
        }
        elsif ($in1 == 601) { # TEXT in source
            if ($rol =~ /CONC\s?(.*)/) {          
                $repo_addr{$repo_id} = $repo_addr{$repo_id}." $1";
            }
            elsif ($rol =~ /CONT\s?(.*)/) {          
                $repo_addr{$repo_id} = $repo_addr{$repo_id}."<br />\n$1";
            }
        }
        elsif ($in1 == 602) { # TEXT in source
            if ($rol =~ /CONC\s?(.*)/) {          
                $repo_note{$repo_id} = $repo_note{$repo_id}." $1";
            }
            elsif ($rol =~ /CONT\s?(.*)/) {          
                $repo_note{$repo_id} = $repo_note{$repo_id}."<br />\n$1";
            }
        }
    } # end if a 2 line
}

#################################################################
# Link note data to individual records
foreach $note_id (keys %note) {
    $indiv_note{$note_indiv_link{$note_id}} = $indiv_note{$note_indiv_link{$note_id}}.$indiv_note{$note_id};
}    

#################################################################
# Set up the HTML for the top and bottom of individual's files
if (open(IN_FILE, "tpl_ind_top.html")) {
    $i = 0;
    while (<IN_FILE>) {
        $html_ind_top[$i] = $_;
        $i++;
    }
}
else { # use defaults
    $html_ind_top[0] = "<body>\n";
    $html_ind_top[1] = "<h1>#ind_name</h1>\n";    
}
close(IN_FILE);

if (open(IN_FILE, "tpl_ind_bot.html")) {
    $i = 0;
    while (<IN_FILE>) {
        $html_ind_bot[$i] = $_;
        $i++;
    }
}
else { # use defaults
    $html_ind_bot[0] = "<hr width=50%>\n";
    $html_ind_bot[1] = "<br/><a href=\"people.$extension\">$str_lpeople</a> ";    
    $html_ind_bot[2] = "| <a href=\"surnames.$extension\">$str_lsurnames</a><p/>\n";
}
close(IN_FILE);

#################################################################
# show results
print "\nCreating individual files\n";
$ind_cnt = 0;
# make a file for each individual
foreach $indiv_id (keys %indivs) {
    $ind_cnt++;
    if ((($ind_cnt % $updateStatus) == 0)) {
        print "$ind_cnt\r"; }
    
    # open an output file
    unless (open(OUT_FILE, ">$out_dir/$indiv_id.$extension")) {
        die "\nCouldn't open output file $out_dir/$indiv_id.$extension\n";
    }
    
    # Split the list of spouse families into @fams.
    # Need to clear the array for some versions of perl.
    @fams = ();
    @fams = split(/@/, $indiv_fams{$indiv_id});
    #print "Fams:@fams\n";
    $famc = $indiv_famc{$indiv_id};

    # Add the title to the name if required and exists
    if ($add_titles && $indiv_titl{$indiv_id})
    {
        $indiv_name{$indiv_id} = $indiv_name{$indiv_id}." ".$indiv_titl{$indiv_id};
        $indiv_name_unformatted{$indiv_id} = $indiv_name_unformatted{$indiv_id}." ".$indiv_titl{$indiv_id};
    }

    ##############################################################
    # print the information to file
    # Make birth info private if required and person alive
    if ($private && $indiv_deat{$indiv_id} == 0) {
        # No death record - check if born too long ago
        if ($indiv_birt_date{$indiv_id} =~ /([0-9][0-9][0-9][0-9])/) {
            $year = $1;
            if ($year > $curr_year) {
                print "Individual $indiv_id has birth date ($1) after this year ($curr_year)\n";
            }
            elsif ($year+120 > $curr_year) { # May be alive
                &make_birt_private($indiv_id);
            }
        }
        elsif ($indiv_chr_date{$indiv_id} =~ /([0-9][0-9][0-9][0-9])/) {
            $year = $1;
            if ($year > $curr_year) {
                print "Individual $indiv_id has christening date ($1) after this year ($curr_year)\n";
            }
            elsif ($year+120 > $curr_year) { # May be alive
                &make_birt_private($indiv_id);
            }
        }
        else { # Couldn't find a birth year - make private
            &make_birt_private($indiv_id);
        }
    }
        
    # Check if there is a photo for the individual
    # Thanks to Bob Minteer for the code this is based on
    if ($check_images) {
        if (-r "$out_dir/$photo_dir/$indiv_id.jpg") {
            $imgpath{$indiv_id}="$photo_dir/$indiv_id.jpg";
        }
        elsif (-r "$out_dir/$photo_dir/$indiv_id.gif") {
            $imgpath{$indiv_id}="$photo_dir/$indiv_id.gif";
        }
        else {
            $imgpath{$indiv_id}="";
        }
    }

    print OUT_FILE "<html><head><title>$indiv_name_unformatted{$indiv_id} ($indiv_birt_date{$indiv_id} - $indiv_deat_date{$indiv_id})</title></head>\n\n";
    # print HTML at top of page
    $html_ind_top_l = @html_ind_top;
    for ($i = 0; $i < $html_ind_top_l; $i++) {
        $_ = $html_ind_top[$i];
        s/\#ind_name/$indiv_name{$indiv_id}/ei;
        print OUT_FILE $_;
        if (($check_images) && ($imgpath{$indiv_id} ne "") && (/<body/)) {
            if ($photoThumbnails) {
                print OUT_FILE "<A HREF=\"$imgpath{$indiv_id}\">"; }
            print OUT_FILE "<IMG SRC=\"$imgpath{$indiv_id}\" ALIGN=\"right\"";
            if ($photoThumbnails) {
                print OUT_FILE " WIDTH=150 ALT=\"click to enlarge\"></a>\n"; }
            else {
                print OUT_FILE ">\n"; }
        }
    }

    if ($print_sources && $indiv_sour{$indiv_id})
    {
        print OUT_FILE "<a href=\"$indiv_sour{$indiv_id}.$extension\">$str_source</a><br/><br/>\n";
    }

    # birth date and place
    if ($indiv_birt{$indiv_id}) {
        $printComma = 0;
        print OUT_FILE "$str_birth ";

        if ($indiv_birt_date{$indiv_id}) {
            print OUT_FILE "$indiv_birt_date{$indiv_id}";
            $printComma = 1;
        }
        if ($indiv_birt_plac{$indiv_id}) {
            if ($printComma)
              {print OUT_FILE ", ";}
            print OUT_FILE "$indiv_birt_plac{$indiv_id}";
            $printComma = 1;
        }
        if ($print_sources && $indiv_birt_sour{$indiv_id}) {
            if ($printComma)
                {print OUT_FILE "  ";}
            print OUT_FILE "<a href=\"$indiv_birt_sour{$indiv_id}.$extension\">$str_source</a>";    
        }
        print OUT_FILE "<br/>\n";
    }

    # Christening
    if ($indiv_chr{$indiv_id}) {
        $printComma = 0;
        print OUT_FILE "$str_chr ";
        if ($indiv_chr_date{$indiv_id}) {
            print OUT_FILE "$indiv_chr_date{$indiv_id}";
            $printComma = 1;
        }
        if ($indiv_chr_plac{$indiv_id}) {
            if ($printComma)
              {print OUT_FILE ", ";}
            print OUT_FILE "$indiv_chr_plac{$indiv_id}";
            $printComma = 1;
        }
        if ($print_sources && $indiv_chr_sour{$indiv_id}) {
            if ($printComma)
                {print OUT_FILE "  ";}
            print OUT_FILE "<a href=\"$indiv_chr_sour{$indiv_id}.$extension\">$str_source</a>";
        }
        print OUT_FILE "<br/>\n";
    }

    # death date and place
    if ($indiv_deat{$indiv_id}) {
        $printComma = 0;
        print OUT_FILE "$str_death ";
        if ($indiv_deat_date{$indiv_id}) {
            print OUT_FILE "$indiv_deat_date{$indiv_id}";
            $printComma = 1;
        }
        if ($indiv_deat_plac{$indiv_id}) {
            if ($printComma)
              {print OUT_FILE ", ";}
            print OUT_FILE "$indiv_deat_plac{$indiv_id}";
            $printComma = 1;
        }
        if ($print_sources && $indiv_deat_sour{$indiv_id}) {
            if ($printComma)
              {print OUT_FILE "  ";}
            print OUT_FILE "<a href=\"$indiv_deat_sour{$indiv_id}.$extension\">$str_source</a>";    
        }
        print OUT_FILE "<br/>\n";
    }

    # burial date and place
    if ($indiv_buri{$indiv_id}) {
        print OUT_FILE "$str_burial ";
        if ($indiv_buri_date{$indiv_id}) {
            print OUT_FILE "$indiv_buri_date{$indiv_id}";
            if ($indiv_buri_plac{$indiv_id})
                {print OUT_FILE ", ";}
        }
        if ($indiv_buri_plac{$indiv_id}) {
            print OUT_FILE "$indiv_buri_plac{$indiv_id}";
        }
        print OUT_FILE "<br/>\n";
    }
    # BAPL date and place
    if ($indiv_bapl{$indiv_id}) {
        print OUT_FILE "$str_baptism ";
        if ($indiv_bapl_date{$indiv_id}) {
            print OUT_FILE "$indiv_bapl_date{$indiv_id}";
            if ($indiv_bapl_plac{$indiv_id} || $indiv_bapl_temp{$indiv_id})
                {print OUT_FILE ", ";}
        }
        if ($indiv_bapl_plac{$indiv_id}) {
            print OUT_FILE "$indiv_bapl_plac{$indiv_id}";
            if ($indiv_bapl_temp{$indiv_id})
                {print OUT_FILE ", ";}
        }
        if ($indiv_bapl_temp{$indiv_id}) {
            print OUT_FILE "$indiv_bapl_temp{$indiv_id}";
        }
        print OUT_FILE "<br/>\n";
    }
    # ENDL date and place
    if ($indiv_endl{$indiv_id}) {
        print OUT_FILE "$str_endowment ";
        if ($indiv_endl_date{$indiv_id}) {
            print OUT_FILE "$indiv_endl_date{$indiv_id}";
            if ($indiv_endl_plac{$indiv_id} || $indiv_endl_temp{$indiv_id})
                {print OUT_FILE ", ";}
        }
        if ($indiv_endl_plac{$indiv_id}) {
            print OUT_FILE "$indiv_endl_plac{$indiv_id}";
            if ($indiv_endl_temp{$indiv_id})
                {print OUT_FILE ", ";}
        }
        if ($indiv_endl_temp{$indiv_id}) {
            print OUT_FILE "$indiv_endl_temp{$indiv_id}";
        }
        print OUT_FILE "<br/>\n";
    }
    # SLGC date and place
    if ($indiv_slgc{$indiv_id}) {
        print OUT_FILE "$str_sealing_children ";
        if ($indiv_slgc_date{$indiv_id}) {
            print OUT_FILE "$indiv_slgc_date{$indiv_id}";
            if ($indiv_slgc_plac{$indiv_id} || $indiv_slgc_temp{$indiv_id})
                {print OUT_FILE ", ";}
        }
        if ($indiv_slgc_plac{$indiv_id}) {
            print OUT_FILE "$indiv_slgc_plac{$indiv_id}";
            if ($indiv_slgc_temp{$indiv_id})
                {print OUT_FILE ", ";}
        }
        if ($indiv_slgc_temp{$indiv_id}) {
            print OUT_FILE "$indiv_slgc_temp{$indiv_id}";
        }
        print OUT_FILE "<br/>\n";
    }
    # SLGS date and place
    if ($indiv_slgs{$indiv_id}) {
        print OUT_FILE "$str_sealing_spouse ";
        if ($indiv_slgs_date{$indiv_id}) {
            print OUT_FILE "$indiv_slgs_date{$indiv_id}";
            if ($indiv_slgs_plac{$indiv_id} || $indiv_slgs_temp{$indiv_id})
                {print OUT_FILE ", ";}
        }
        if ($indiv_slgs_plac{$indiv_id}) {
            print OUT_FILE "$indiv_slgs_plac{$indiv_id}";
            if ($indiv_slgs_temp{$indiv_id})
                {print OUT_FILE ", ";}
        }
        if ($indiv_slgs_temp{$indiv_id}) {
            print OUT_FILE "$indiv_slgs_temp{$indiv_id}";
        }
        print OUT_FILE "<br/>\n";
    }
    print OUT_FILE "<p/>\n";
    
    # occupation
    if ($indiv_occu{$indiv_id}) {
        print OUT_FILE "$str_occupation $indiv_occu{$indiv_id}<p/>\n";
    }
    print OUT_FILE "<p>\n";
    
    # print marriage info if more than just spouse name is known
    if (!$print_family) {
        &print_marriages;
    }

    if ($family_table || $print_family) {
        &get_parent_data;
        &get_child_data;
    }
   
    # If $family_table then print the ancestors chart (needs $father,
    # $mother, $pgfather etc., $famc.
    if ($family_table) {
        &get_gparent_data;
        
        # family chart
        print OUT_FILE "<p>\n<table border=1 cellspacing=0 cellpadding=0>\n";
        if (($father ne "") || ($mother ne "")) {
            print OUT_FILE &tableAncestors();
        } # end if has a parent
        $fams_len = @fams;

        if ($fams_len != 0) {
            # Spouse(s) and their children
            for ($fams_num=0; $fams_num < $fams_len; $fams_num++) {
                &get_spouse_data($fams[$fams_num]);
                &get_child_data($fams[$fams_num]);
                print OUT_FILE &tableSpouseChildren();
            } # end for each family
        } # end if has spouses
        print OUT_FILE "</table>\n<p>\n";

    } # end if family_table
    
    # If $print_family then print parents, marriage(s), children.
    # Uses $father, $mother, @child, $famc, $fams.
    
    if ($print_family) {
    
        # parents
        if ($father ne "") {
            print OUT_FILE "$str_father <a href=\"$father_id.$extension\">$father</a><br/>\n"; 
        }
        if ($mother ne "") {
            print OUT_FILE "$str_mother <a href=\"$mother_id.$extension\">$mother</a><p>\n"; 
        }    
        print OUT_FILE "<p/>\n";
        
        # spouse, marriage date and place and children
        &print_marriages(1);
        
    } # end if print_family
    
    print OUT_FILE "<p/>\n";
    
    # notes
    if ($print_notes && $indiv_note{$indiv_id}) {
        print OUT_FILE "$str_notes $indiv_note{$indiv_id}\n";
        print OUT_FILE "<p/>\n";
    }

    # print HTML at bottom of page
    print OUT_FILE @html_ind_bot;
    &print_footer;
    close(OUT_FILE);
} # end foreach $indiv_id (keys %indivs)

if ($print_sources)
{
    print "\rCreating source files\n";

    foreach $sour_id (keys %sours) {
        # open an output file
        unless (open(OUT_FILE, ">$out_dir/$sour_id.$extension")) {
            die "\nCouldn't open output file $out_dir/$sour_id.$extension\n";
        }
        
        print OUT_FILE "<html><head><title>$str_source $sour_id</title></head>\n\n<body>\n";
        if ($sour_titl{$sour_id}) {
            print OUT_FILE "$str_title $sour_titl{$sour_id}<br/>\n";
        }

        if ($sour_auth{$sour_id}) {
            print OUT_FILE "$str_author $sour_auth{$sour_id}<br/>\n";
        }

        if ($sour_publ{$sour_id}) {
            print OUT_FILE "$str_pub_info $sour_publ{$sour_id}<br/>\n";
        }

        if ($sour_abbr{$sour_id}) {
            print OUT_FILE "$str_abbr $sour_abbr{$sour_id}<br/>\n";
        }

        if ($sour_caln{$sour_id}) {
            print OUT_FILE "$str_call_num $sour_caln{$sour_id}<br/>\n";
        }

        if ($sour_note{$sour_id}) {
            print OUT_FILE "<p>$str_comments<br/>\n$sour_note{$sour_id}<br/>\n";
        }

        if ($sour_text{$sour_id}) {
            print OUT_FILE "<p>$str_text<br/>\n$sour_text{$sour_id}<br/>\n";
        }
        
        print OUT_FILE "<p>\n</body></html>";

        close(OUT_FILE);
    } # end foreach $sour_id (keys %sours)
}


#############################################
# make a list of people file
# open an output file
print "\rCreating people file\n";
unless (open(OUT_FILE, ">$out_dir/people.$extension")) {
    die "Couldn't open output file $out_dir/people.$extension\n";
}
# Set the fline array to the contents of the template file (if it exists) or a default template
if (open(TPL_FILE, "tpl_people.html")) {
    print "Using people template file\n";
    $i = 0;
    while (<TPL_FILE>) {
        $fline[$i] = $_;
        $i++;
    } # while <TPL_FILE>
    close(TPL_FILE);
}
else {
    # use defaults
    @fline = (
        "<html><head><title>$str_people</title></head>\n\n<body>\n",
        "<h1>$str_lpeople</h1> ($num_indivs $str_people_and $num_families $str_unique_names)<p/>\n",
        "#main",
        "#ns <a name=\"#ind_surname\">\n",
        "<a href=\"#ind_id.$extension\">#ind_surname, #ind_forname</a> (#ind_birt_date - #ind_deat_date) #photo<br/>",
        "#end",
        "\n<p>\n<br/><a href=\"surnames.$extension\">$str_lsurnames</a><p/>\n",
        "#footer"
         );
}
    # Go through every line in the fline array
    #  if it is #main then insert every individual
    #  if it is #footer print the footer
    #  else just print the line
    $fline = @fline;
    for ($j = 0; $j < $fline; $j++) {
        $_ = $fline[$j];
        if (/#main/) { # do the main loop of all people
            # read the format into out_fmt array from the fline array lines between #main and #end
            $i = 0; $nsi = 0;
            until ($line =~ /#end/) {
                   $j++;
                   $line = $fline[$j];
                   $ns[$i] = 0;
                   if ($line =~ /#ns(.*\n)/) {
               $line = $1; # strip the #ns from $line
               $ns[$i] = 1; # flag this line of out_fmt as a new surname line
                   }
                   $out_fmt[$i] = $line;
                   $i++;
            }
            $out_fmt[$i-1]=""; # get rid of #end
            $len = @out_fmt;
            $old_surname = "-o-o-";
            foreach $indiv_id (sort by_surname keys %indivs) {
                # is the surname different to the previous individual's surname?
                $ns_this = (($indiv_surname{$indiv_id} ne $old_surname) && ($indiv_surname{$indiv_id} ne ""));
                if ($ns_this) 
                    {$old_surname = $indiv_surname{$indiv_id};}
                # for every line in out_fmt
                for ($i = 0; $i < $len; $i++) {
                    # if this surname is different to previous or this line of out_fmt is not a new surname line
                    # then print this line from out_fmt
                    if ($ns_this || !$ns[$i]) {
                        $line = $out_fmt[$i];
                        $line =~ s/#ind_id/$indiv_id/gei;
                        $line =~ s/#ind_forname/$indiv_forname{$indiv_id}/gei;
                        $line =~ s/#ind_surname/$indiv_surname{$indiv_id}/gei;
                        $line =~ s/#ind_titl/$indiv_titl{$indiv_id}/gei;
                        if ($indiv_birt_date{$indiv_id} ne "") {
                            $line =~ s/#ind_birt_date/$indiv_birt_date{$indiv_id}/gei;
                        }
                        elsif ($indiv_chr_date{$indiv_id} ne "") {
                            $line =~ s/#ind_birt_date/"chr. $indiv_chr_date{$indiv_id}"/gei;
                        }
                        else {
                            $line =~ s/#ind_birt_date//gei;
                        }
                        $line =~ s/#ind_deat_date/$indiv_deat_date{$indiv_id}/gei;
                        if (($check_images) && ($imgpath{$indiv_id} ne "")) {
                            $line =~ s/#photo/\<em\>\(photo available\)\<\/em\>/gi;
                        }
                        else {
                            $line =~ s/#photo//gei;
                        }
                        # get rid of private birth date
                        $line =~ s/\(\($str_private\) - \)/$str_private/;
                        print OUT_FILE $line;
                    }
                }
            } # end for each individual
            @out_fmt = ();
        }
        elsif (/#footer/) {
            &print_footer;
        }
        else {
            print OUT_FILE $_;
        }
    } # for i=0 to $fline
close(OUT_FILE);


#############################################
# make a surname file
unless (open(OUT_FILE, ">$out_dir/surnames.$extension")) {
    die "Couldn't open output file $out_dir/surnames.$extension\n";
}

print "Creating surnames file\n";
if (open(TPL_FILE, "tpl_surnames.html")) {
    print "Using surnames template file\n";
    while (<TPL_FILE>) {
        if (/#main/) { # do the main loop of all surnames
            # read in the format
            $i = 0;
            until ($line =~ /#end/) {
                $line = <TPL_FILE>;
                $out_fmt[$i] = $line;
                $i++;
            }
            $out_fmt[$i-1]=""; # get rid of #end
            &printSurnames(@out_fmt);
            @out_fmt = ();
        }
        elsif (/#footer/) {
            &print_footer;
        }
        else {
            print OUT_FILE $_;
        }
    } # while <TPL_FILE>
    close(TPL_FILE);
}
else { # use the default layout
    print OUT_FILE "<html><head><title>Surnames</title></head>\n\n";
    print OUT_FILE "<body>\n";
    print OUT_FILE "<h1>$str_all_surnames</h1>\n";
    print OUT_FILE "$str_list_of $num_indivs $str_people_and $num_families $str_unique_names<p>\n";
    $out_fmt[0] = "<a href=\"people.$extension##ind_surname\">#ind_surname</a>\n";
    &printSurnames(@out_fmt);
    
    print OUT_FILE "<p/><hr width=50%>\n";
    print OUT_FILE "<br/><a href=\"people.$extension\">$str_lpeople</a><p/>\n";
    &print_footer;
}
close(OUT_FILE);

#############################################
# make a stats file
if ($make_stats)
{
    print "Creating Stats File\n";
    unless (open(OUT_FILE, ">$out_dir/stats.html")) 
    {
        die "Couldn't open output file $out_dir/stats.html\n";
    }

    print OUT_FILE "<table class=stats>
     <tr>
      <td>Individuals</td>
      <td>Families</td>
      <td>Sources</td>
      <td>Repositories</td>
     </tr>
     <tr>
      <td>$num_indivs</td>
      <td>$num_families</td>
      <td>$num_source</td>
      <td>$num_repository</td>
     </tr>
    </table>";

    close(OUT_FILE);
}

#############################################
# sort by surname 
sub by_surname {
    $lca = lc($indiv_surname{$a});
    $lcb = lc($indiv_surname{$b});
    # ignore specified characters for surname sort
    $l = length $ignoreSurnameSort;
    for ($i = 0; $i < $l; $i++)
    {
        $char = substr $ignoreSurnameSort,$i,1;
        $lca =~ s/$char//;
        $lcb =~ s/$char//;
    }
    $lca cmp $lcb
        ||
    $indiv_forname{$a} cmp $indiv_forname{$b}
        ||
    $indiv_birt_date{$a} cmp $indiv_birt_date{$b}
        ||
    $a cmp $b;
}

#############################################
# Show the status of reading the file
# In: $num_indivs,  $num_families
sub show_reading_status {
    if ((($num_indivs % $updateStatus) == 0)) {
    print "$num_indivs individuals, $num_families families, $num_source sources, $num_repository repository\r";
    }
}

#############################################
# Uses OUT_FILE.
sub print_footer {
    print OUT_FILE "Created by Dan Pidcock's <a href=\"http://www.pidcock.co.uk/gth/\">GedcomToHTML</a> v$version.<p/>\n";
    print OUT_FILE "</body></html>\n";
}

#############################################
# Uses OUT_FILE, $spouse, $spouse_id, $fams.
sub print_marriages {
    $long = $_[0]; # if set then print children too
    $fams_len = @fams;
    for ($fams_num=0; $fams_num < $fams_len; $fams_num++) {
        &get_spouse_data($fams[$fams_num]);
        if (($spouse ne "") || $fam_marr{$fams[$fams_num]}) {
            print OUT_FILE "<dl><dt>$str_married ";
            if ($fams_len > 1) {
                $i = $fams_num+1;
                print OUT_FILE "($i) ";
            }
        }
        if ($spouse ne "") {
            print OUT_FILE " <a href=\"$spouse_id.$extension\">$spouse</a>";
        }
        if ($fam_marr{$fams[$fams_num]}) {
            if ($fam_marr_date{$fams[$fams_num]}) {
                print OUT_FILE " $str_on$fam_marr_date{$fams[$fams_num]}";
            }
            if ($fam_marr_plac{$fams[$fams_num]}) {
                print OUT_FILE " $str_at$fam_marr_plac{$fams[$fams_num]}";
            }
        }
        if ($print_sources && $fam_marr_sour{$fam_id})
        {
            print OUT_FILE "  <a href=\"$fam_marr_sour{$fam_id}.$extension\">$str_source</a>";    
        }
        if ($fam_div{$fams[$fams_num]}) {
	    print OUT_FILE ", $str_divorced";
            if ($fam_div_date{$fams[$fams_num]}) {
                print OUT_FILE " $str_on$fam_div_date{$fams[$fams_num]}";
            }
            if ($fam_div_plac{$fams[$fams_num]}) {
                print OUT_FILE " $str_at$fam_div_plac{$fams[$fams_num]}";
            }
        }
        if ($print_sources && $fam_div_sour{$fam_id})
        {
            print OUT_FILE "  <a href=\"$fam_div_sour{$fam_id}.$extension\">$str_source</a>";    
        }
        print OUT_FILE "\n";
        if ($long) {
            &get_child_data($fams[$fams_num]);
            # children (in order of fam entry)
            for ($i = 0; $i < $num_children; $i++) {
                $child_num = $i+1;
                print OUT_FILE "<dd>$str_child $child_num: <a href=\"$child[$i].$extension\">$indiv_name{$child[$i]}</a><br/>\n";
            }
        }
        print OUT_FILE "</dl><p/>\n";
    }
}

#############################################
# Sets $father_id, $father, $mother_id, $mother.
# Uses $famc.
sub get_parent_data {
    # get parents
    $father = "";
    $mother = "";
    $father_id = $fam_husb{$famc};
    $mother_id = $fam_wife{$famc};
    $father = $indiv_name{$father_id};
    $mother = $indiv_name{$mother_id};
}

#############################################
# Sets $pgfather_id, $pgfather, $pgmother_id, $pgmother etc.
# Uses $father_id, $mother_id.
sub get_gparent_data {
    $pgfather = "";
    $pgmother = "";
    $mgfather = "";
    $mgmother = "";
    if ($father ne "") {
        $pgfather_id = $fam_husb{$indiv_famc{$father_id}};
        $pgfather = $indiv_name{$pgfather_id};
        $pgmother_id = $fam_wife{$indiv_famc{$father_id}};
        $pgmother = $indiv_name{$pgmother_id};
    }
    if ($mother ne "") {
        $mgfather_id = $fam_husb{$indiv_famc{$mother_id}};
        $mgfather = $indiv_name{$mgfather_id};
        $mgmother_id = $fam_wife{$indiv_famc{$mother_id}};
        $mgmother = $indiv_name{$mgmother_id};
    }
}

#############################################
# Put in subroutine by Dale dePriest
# Sets $spouse_id, $spouse.
# Uses $indiv_id..
# Parameter family that spouse is in.
sub get_spouse_data {
    $this_fam = $_[0];
    # get spouse (assume opposite sex)
    if ($indiv_sex{$indiv_id} eq "M") {
        $spouse_id = $fam_wife{$this_fam};
    }
    elsif ($indiv_sex{$indiv_id} eq "F") {
        $spouse_id = $fam_husb{$this_fam};
    }
    $spouse = $indiv_name{$spouse_id};
}

#############################################
# Put in subroutine by Dale dePriest
# Sets @child.
# Uses %fam_chil.
# Parameter family that children are in.
sub get_child_data {
    $this_fam = $_[0];
    # get children (in order of fam entry)
    if ($this_fam) {
        # Split the children list into @child
        @child = split(/@/, $fam_chil{$this_fam});
        $num_children = @child;
    }
}

#############################################
# Make birth information of an individual private
# Parameter individual ID number
sub make_birt_private {
    $indiv_birt_date{$_[0]} = "$str_private";
    $indiv_birt_plac{$_[0]} = "";
}

#############################################
# Make a string lower case
sub lc {
    $s = pop(@_);
    tr/A-Z/a-z/;
}

#############################################
# Return the ancestor table
sub tableAncestors {
    my $tableAncestors = "";
    
    # Ancestors
    $tableAncestors .= "<tr><td align=center>\n<table border=0>\n"; # begin the ancestors table
    $tableAncestors .= "<tr>\n";
    $tableAncestors .= "<td width=150 align=center><a href=\"$pgfather_id.$extension\">$pgfather</a></td>\n";
    $tableAncestors .= "<td width=150 align=center><a href=\"$pgmother_id.$extension\">$pgmother</a></td>\n";
    $tableAncestors .= "<td width=150 align=center><a href=\"$mgfather_id.$extension\">$mgfather</a></td>\n";
    $tableAncestors .= "<td width=150 align=center><a href=\"$mgmother_id.$extension\">$mgmother</a></td>\n";
    $tableAncestors .= "</tr>\n<tr>\n";
    if (($pgfather ne "") || ($pgmother ne ""))
        {$tableAncestors .= "<td colspan=2><img src=\"$treepic_path/tree300.gif\" width=\"300\" height=\"30\"></td>\n";}
    else
        {$tableAncestors .= "<td colspan=2></td>\n";}
    if (($mgfather ne "") || ($mgmother ne ""))
        {$tableAncestors .= "<td colspan=2><img src=\"$treepic_path/tree300.gif\" width=\"300\" height=\"30\"></td>\n";}
    else
        {$tableAncestors .= "<td colspan=2></td>\n";}
    $tableAncestors .= "</tr>\n";
    $tableAncestors .= "<tr>\n";
    $tableAncestors .= "<td colspan=2 align=center><a href=\"$father_id.$extension\">$father</a></td>\n";
    $tableAncestors .= "<td colspan=2 align=center><a href=\"$mother_id.$extension\">$mother</a></td>\n";
    $tableAncestors .= "</tr>\n";
    $tableAncestors .= "<tr>\n";
    if (($father ne "") || ($mother ne "")) 
        {$tableAncestors .= "<td colspan=4><img src=\"$treepic_path/tree600.gif\" width=\"600\" height=\"30\"></td>\n";}
    else
        {$tableAncestors .= "<td colspan=4></td>\n";}
    $tableAncestors .= "<tr>\n";
    $tableAncestors .= "<th colspan=4 align=center>$indiv_name{$indiv_id}</th>\n";
    $tableAncestors .= "</tr>\n";
    $tableAncestors .= "</table>\n</tr>\n</p>\n"; # end the ancestors table
    
    return $tableAncestors;
}

#############################################
# Return the spouse and children table
sub tableSpouseChildren {
    my $tableSpouseChildren = "";

    if ($num_children > 0) {
        $tableSpouseChildren .= "\n<tr><td align=center>\n<table border=0 cellspacing=0 cellpadding=0>\n"; # begin the spouse table
        $tableSpouseChildren .= "<tr>\n";
        if ($num_children > 8) {
            $cwidth=9;
        }
        else {
            $cwidth = $num_children;
        }
        $tableSpouseChildren .= "<td colspan=$cwidth align=center>";
        $tableSpouseChildren .= $str_m;
        if ($fams_len > 1) {
            $i = $fams_num+1;
            $tableSpouseChildren .= "($i) ";
        }
        $tableSpouseChildren .= "<a href=\"$spouse_id.$extension\">$spouse</a></td></tr>\n";
        # the children
        $start_child = 0;
        # If there are more than 9 children then use a multi line display
        while (($num_children - $start_child) > 9) {
            # print the 8 child tree with extra leg coming down
            $tableSpouseChildren .= "<tr><td colspan=9><img src=\"$treepic_path/tree_c8l.gif\" width=600 height=30></tr>\n";
            # print the first 8 children
            $tableSpouseChildren .= "<tr>";
            for ($i = $start_child; $i < $start_child+4; $i++) {
                $tableSpouseChildren .= "<td align=center width=67>";
                $tableSpouseChildren .= "<img src=\"$treepic_path/dot-trans.gif\" width=67 height=1><br/>";
                $tableSpouseChildren .= "<a href=\"$child[$i].$extension\"><font size=-1>$indiv_name{$child[$i]}</font></a></td>\n";
            }
            $tableSpouseChildren .= "<td align=center width=65><img src=\"$treepic_path/tree_l.gif\" width=65 height=60></td>\n";
            for ($i = $start_child+4; $i < $start_child+8; $i++) {
                $tableSpouseChildren .= "<td align=center width=67>";
                $tableSpouseChildren .= "<img src=\"$treepic_path/dot-trans.gif\" width=67 height=1><br/>";
                $tableSpouseChildren .= "<a href=\"$child[$i].$extension\"><font size=-1>$indiv_name{$child[$i]}</font></a></td>\n";
            }
            $tableSpouseChildren .= "</tr>\n";
            $start_child += 8;
        }
        # print the rest of the children
        $num_left = $num_children-$start_child;
        $tableSpouseChildren .= "<tr><td align=center colspan=9>\n";
        # The rest of the children must go into a table as the number of columns will not necessarily be 9 or a divider of 9
        $tableSpouseChildren .= "<table border=0 cellspacing=0 cellpadding=0>"; # begin the children table
        $tableSpouseChildren .= "<tr><td colspan=$num_left><img src=\"$treepic_path/tree_c$num_left.gif\" width=600 height=30></td></tr>\n";
        $cell_width = int(600/$num_left);
        $tableSpouseChildren .= "<tr>";
        for ($i = $start_child; $i < $num_children; $i++) {
            $tableSpouseChildren .= "<td align=center width=$cell_width>";
            $tableSpouseChildren .= "<img src=\"$treepic_path/dot-trans.gif\" width=$cell_width height=1><br/>";
            $tableSpouseChildren .= "<a href=\"$child[$i].$extension\"><font size=-1>$indiv_name{$child[$i]}</font></a></td>\n";
        }
        $tableSpouseChildren .= "</tr></table></td></tr>\n"; # end the children table

        $tableSpouseChildren .= "</table>\n</td></tr>\n"; # end the spouse table
    } # end if has children
    else { #no children so just put marriage for consistency
        $tableSpouseChildren .= "<tr>\n";
        $tableSpouseChildren .= "<td align=center>";
        $tableSpouseChildren .= $str_m;
        if ($fams_len > 1) {
            $i = $fams_num+1;
            $tableSpouseChildren .= "($i) ";
        }
        $tableSpouseChildren .= "<a href=\"$spouse_id.$extension\">$spouse</a><p></td></tr>\n";   
    }

    return $tableSpouseChildren;
}

sub printSurnames {
    my(@out_fmt) = @_;
    my $len = @out_fmt;
    if ($group_letters)
    {
        print OUT_FILE "<a href=#A>A</a> | <a href=#B>B</a> | <a href=#C>C</a> | <a href=#D>D</a> | <a href=#E>E</a> | <a href=#F>F</a> | <a href=#G>G</a> | <a href=#H>H</a> | <a href=#I>I</a> | <a href=#J>J</a> | <a href=#K>K</a> | <a href=#L>L</a> | <a href=#M>M</a> | <a href=#N>N</a> | <a href=#O>O</a> | <a href=#P>P</a> | <a href=#Q>Q</a> | <a href=#R>R</a> | <a href=#S>S</a> | <a href=#T>T</a> | <a href=#U>U</a> | <a href=#V>V</a> | <a href=#W>W</a> | <a href=#X>X</a> | <a href=#Y>Y</a> | <a href=#Z>Z</a>";
        print OUT_FILE "<p/>";
    }
    my $old_surname="-o-o-"; # so that empty surnames show up
    my $cur_letter = 'a';
    foreach $indiv_id (sort by_surname keys %indiv_surname) 
    {
        my $new_surname = lc($indiv_surname{$indiv_id});
        if ($new_surname ne $old_surname) 
        {
            if (lc(substr($indiv_surname{$indiv_id},$[,1)) ne $cur_letter) 
            {
                $cur_letter = lc(substr($indiv_surname{$indiv_id},$[,1));
                if ($group_letters)
                {
                    $cur_letter_uc = uc($cur_letter);
                    if (($old_surname ne "-o-o-") && ($old_surname ne ""))
                    {
                        print OUT_FILE "<p/>\n<a href=\"surnames.$extension\">Back to Top</a><p/>";
                    }
                    print OUT_FILE "\n<a name=$cur_letter_uc /><surname_index>$cur_letter_uc</surname_index><br/>\n";
                }
                else
                {
                    print OUT_FILE "<br/>";
                }
            }
            for (my $i = 0; $i < $len; $i++) 
            {
                my $line = $out_fmt[$i];
                $line =~ s/#ind_surname/$indiv_surname{$indiv_id}/gei;
                print OUT_FILE $line;
            }
            $old_surname = lc($indiv_surname{$indiv_id});
        }
    }
}