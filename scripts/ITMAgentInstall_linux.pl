#!/usr/bin/perl -w
# ---------------------------------------------------------------------------------------------------------------------------------------
#
#
#                                                                             dddddddd
#   kkkkkkkk                                                                  d::::::d                                        lllllll
#   k::::::k                                                                  d::::::d                                        l:::::l
#   k::::::k                                                                  d::::::d                                        l:::::l
#   k::::::k                                                                  d:::::d                                         l:::::l
#   k:::::k    kkkkkkkyyyyyyy           yyyyyyynnnn  nnnnnnnn        ddddddddd:::::drrrrr   rrrrrrrrryyyyyyy           yyyyyyyl::::l
#   k:::::k   k:::::k  y:::::y         y:::::y n:::nn::::::::nn    dd::::::::::::::dr::::rrr:::::::::ry:::::y         y:::::y l::::l
#   k:::::k  k:::::k    y:::::y       y:::::y  n::::::::::::::nn  d::::::::::::::::dr:::::::::::::::::ry:::::y       y:::::y  l::::l
#   k:::::k k:::::k      y:::::y     y:::::y   nn:::::::::::::::nd:::::::ddddd:::::drr::::::rrrrr::::::ry:::::y     y:::::y   l::::l
#   k::::::k:::::k        y:::::y   y:::::y      n:::::nnnn:::::nd::::::d    d:::::d r:::::r     r:::::r y:::::y   y:::::y    l::::l
#   k:::::::::::k          y:::::y y:::::y       n::::n    n::::nd:::::d     d:::::d r:::::r     rrrrrrr  y:::::y y:::::y     l::::l
#   k:::::::::::k           y:::::y:::::y        n::::n    n::::nd:::::d     d:::::d r:::::r               y:::::y:::::y      l::::l
#   k::::::k:::::k           y:::::::::y         n::::n    n::::nd:::::d     d:::::d r:::::r                y:::::::::y       l::::l
#   k::::::k k:::::k           y:::::::y          n::::n    n::::nd::::::ddddd::::::ddr:::::r                 y:::::::y       l::::::l
#   k::::::k  k:::::k           y:::::y           n::::n    n::::n d:::::::::::::::::dr:::::r                  y:::::y        l::::::l
#   k::::::k   k:::::k         y:::::y            n::::n    n::::n  d:::::::::ddd::::dr:::::r                 y:::::y         l::::::l
#   kkkkkkkk    kkkkkkk       y:::::y             nnnnnn    nnnnnn   ddddddddd   dddddrrrrrrr                y:::::y          llllllll
#                            y:::::y                                                                        y:::::y
#                           y:::::y                                                                        y:::::y
#                          y:::::y                                                                        y:::::y
#                         y:::::y                                                                        y:::::y
#                        yyyyyyy                                                                        yyyyyyy
#
#
# ---------------------------------------------------------------------------------------------------------------------------------------
# version 2023-08-01
# Changelog
#
# ITMAgentRepair_linux.pl  :   repair ITM agents locally on server
#
# 2023-08-01  Initial release ( Benny.Skov@kyndryl.com )
# -----------------------------------------------------------------------------------------------------------------
#
use strict;
use File::Basename;
# use File::Path qw(make_path);
# use Cwd qw(abs_path);
use Sys::Hostname;
use File::Copy;
my($foo,$bar,$baz,$qux,$quux,$quuz,$corge,$grault,$garply,$waldo,$fred,$plugh,$xyzzy,$thud);
my($envirShore,$step,$scriptname,$scriptn,@words);
my(@foo,@bar,@baz,@out,@trimin,$argnum);
my($cmdexec,$text,$debug,$csv_data,%hash_rtems,@csv_rows,@csv_lines,@fields,$line,$row,$count,$status,$ccode,$hostname,$itm_nodename);
my($rtemsCi,$rtemsIP,$rtemsConnect,$rtemsPairs,$rtemsFunction,$rtemsPrimSec,$rtemsTier,$rtemsEnvir,$rtemsShore,$result,$itmuser_found);
my($primary,$secondary,$pairsNumber,$CT_CMSLIST,$rtems_file,$handle,$agent,$shore,$envir);
my($silent_config_data,$silent_config_linux_git,$silent_config_linux,$pingonly);
my($env_file,$env_file_git,$env_data);
my($ini_file,$ini_file_git,$ini_data);
my($con_file,$con_file_git,$agent_con_data);
my($special_cfg,$special_cfg_git,$group,$userid);
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# INIT
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$hostname           = hostname;
$hostname           = lc($hostname);
$scriptname         = $0;
$scriptname         =~ s/\\/\//g; # turn slash
@words              = split(/\//, $scriptname);
$scriptn            = $words[$#words];
$scriptn            =~ s/\.pl//g;
$debug              = 0;
$pingonly           = 0;
$ccode              = "";
$shore              = ".*";
$envir              = ".*";
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# read input
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# plog("@ARGV\n");
if  (scalar(@ARGV) != 0 ) {
	if 	( ($ARGV[0] =~ /^(-h|-\?|--help)/) ) { help_error(); }
	foreach $argnum (0 .. $#ARGV) {
		# plog("$ARGV[$argnum]\n");
    if ( $ARGV[$argnum] =~ /^\-ccode$/)         { $argnum++; $ccode = "$ARGV[$argnum]"; }
    if ( $ARGV[$argnum] =~ /^\-shore$/)         { $argnum++; $shore = "$ARGV[$argnum]"; }
    if ( $ARGV[$argnum] =~ /^\-envir$/)         { $argnum++; $envir = "$ARGV[$argnum]"; }
    if ( $ARGV[$argnum] =~ /^\-pingonly$/)      { $argnum++; $pingonly = "$ARGV[$argnum]"; }
    if ( $ARGV[$argnum] =~ /^\-d$/)             { $argnum++; $debug = 1; } # 1=yes
	}
} else {
	help_error();
}
if ( $ccode =~ /^$/i) {
  $ccode = "kmd";
}
if ( $pingonly =~ /^$/i) {
  $pingonly = 0;
}

if ( $pingonly ) {
        if ( $ccode =~ /^$/i) { $ccode = "kmd"; }
        if ( $shore =~ /^$/i) { $shore = "."; }
        if ( $envir =~ /^$/i) { $envir = "."; }
}
plog("\nhostname: $hostname");
plog("\nccode:    $ccode");
plog("\nshore:    $shore");
plog("\nenvir:    $envir");
plog("\npingonly: $pingonly");
plog("\ndebug:    $debug");
plog("\nscriptn:  $scriptn");
if ( $hostname =~ /\./i) {
        ($hostname,$bar) = split(/\./, $hostname, -1);
}
$itm_nodename = "${ccode}_${hostname}";
plog("itm_nodename: $itm_nodename");

# ----------------------------------------------------------------------------------------------------------------------------
# help
# ----------------------------------------------------------------------------------------------------------------------------
sub help_error {
		print ("\n");
		print ("\n");
		print ("use: -?, for this message\n");
		print ("use: -ccode, for custom Code\n");
		print ("use: -shore, for shore\n");
		print ("use: -envir, for envir\n");
                print ("use: -pingonly 1, for ping only\n");
                print ("use: -d, for debug\n");
		print ("\n");
		print ("\n");
		exit;
}
# -----------------------------------------------------------------------------------------------------------------
# functions
# -----------------------------------------------------------------------------------------------------------------
sub get_date {
	our $day = ("00".."31")[(localtime)[3]];
	our $month = ("01".."12")[(localtime)[4]];
	our $year = ((localtime)[5] + 1900);
	$year = sprintf("%02d", $year % 100);
	our $hour = ("00".."23")[(localtime)[2]];
	our $min = ("00".."59")[(localtime)[1]];
	our $sec = ("00".."59")[(localtime)[0]];
	our $date = "$year$month$day-$hour$min$sec";
	return($date);
}
sub trim($) {
	my $string = shift;
	$string =~ s/\s+/ /g;	# remove all double whitespace
	$string =~ s/^\s+//g; # remove beginning whitespaces
	$string =~ s/\s+$//g;	# remove trailing whitespaces
	$string =~ s/\r//g; 	# remove newlines
	$string =~ s/\n//g; 	# remove newlines
	$string =~ s/^"//g; 	# remove beginning double quotes
	$string =~ s/"$//g; 	# remove trailing double quotes
	return $string;
}
sub plog {
        $text = shift;
        print("$text");
}
sub trimout {
        @trimin = ();
        @trimin = @out;
        @out = ();
        TRIM: foreach (@trimin) {
                if ( grep(/^$/i,$_) ) { next TRIM; }
                $_ =~ s/^\s+//g;    # remove beginning whitespaces
                $_ =~ s/\s+$//g;	# remove trailing whitespaces
                push(@out, $_);
        }
}
sub check_itmuser_run_securemain() {
       # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # check if itmuser exists
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $userid = "itmuser";
        $itmuser_found = 0 ;

        $text = "check if ${userid} exists";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $cmdexec = "id -g ${userid} | xargs getent group | cut -d: -f1 2>&1";
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        # if ( $debug ) { plog("\nout=>\n@out\n"); }
        trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);
        if ( $baz =~ /no such user/i ) {
                $itmuser_found = 0 ;
                plog("OK: ${userid} NOT found: $baz");
        } else {
                $itmuser_found = 1;
                $group = $baz;
                plog("OK: ${userid} found in group: $group");
        }
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # doublecheck to see if ITM is started under itmuser user
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        if ( $itmuser_found ) {
                ++$step;
                undef( @out );
                @out = ();$baz = '';
                $text = "check if ${userid} is used to start agents";
                plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

                $userid = "itmuser";
                # $cmdexec = "ps -ef | grep -i klzagent | grep -v grep | awk '{print $1}' 2>&1";
                $cmdexec = "ps -ef | grep -i klzagent | grep -v grep 2>&1";
                if ( $debug ) { plog("\n$cmdexec\n"); }
                @out = `$cmdexec`;
                if ( $debug ) { plog("\nout=>\n@out\n"); }
                trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);
                if ( $debug ) { plog("\nresult=>${baz}<=\n"); }
                ($foo,$bar) = split(/ /, $baz, -1);

                if ( $baz =~ /^${userid}/i ) {
                        $itmuser_found = 1;
                        $group = $baz;
                        plog("OK: ITM is stated using ${userid}, so we must run securemain");
                } else {
                        $itmuser_found = 0 ;
                        plog("OK: ITM is stated using root, no need for securemain");
                }
        }
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # secureMain for itmuser
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        if ( $itmuser_found ) {

                ++$step;
                undef( @out );
                @out = ();$baz = '';
                $text = "secureMain for ${userid}";
                plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

                $cmdexec = "/opt/IBM/ITM/bin/secureMain -g ${group} lock 2>&1";
                if ( $debug ) { plog("\n$cmdexec\n"); }
                @out = `$cmdexec`;
                if ( $debug ) { plog("\nout=>\n@out\n"); }
                trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);
                plog("OK: secureMain runned for ${userid}: $baz");
        }
}
sub read_rtems_csv {

        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # Read RTEMS csv list
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';

        $rtems_file = "/tmp/scripttemp_dir/rtems.csv";

        $text = "Read rtems.csv from file $rtems_file";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        open $handle, '<', $rtems_file;
        chomp(@csv_rows = <$handle>);
        close $handle;

        $count = scalar(@csv_rows);
        plog("OK: read $count RTEMS rows");

}
sub pingip() {

        $cmdexec = "echo quit | timeout 2 telnet $rtemsIP 3660 2>&1";         # OK IF         Connected to
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }
        trimout();$baz='';$baz = join(";", @out);$baz = trim($baz); # if getting the all in one line
        if ( $baz =~ /(succeeded|Connected to $rtemsIP)/i) { $thud = "True" } else { $thud = "False" }

        if ( $thud =~ /False/i) {
                $cmdexec = "nc -zv $rtemsIP 3660 -w 3 2>&1";
                # $cmdexec = "nc -zvw3 $rtemsIP 3660 2>&1";
                if ( $debug ) { plog("\n$cmdexec\n"); }
                @out = `$cmdexec`;
                if ( $debug ) { plog("\nout=>\n@out\n"); }
                trimout();$baz='';$baz = join(";", @out);$baz = trim($baz); # if getting the all in one line
                if ( $baz =~ /(succeeded|Connected to $rtemsIP)/i) { $thud = "True" } else { $thud = "False" }
        }
        if ( $thud =~ /False/i) {
                $cmdexec = "echo q | openssl s_client -connect $rtemsIP:3660"; # OK IF         SSL handshake has read
                if ( $debug ) { plog("\n$cmdexec\n"); }
                @out = `$cmdexec`;
                #    if ( $debug ) { plog("\nout=>\n@out\n") }

                trimout();$baz='';$baz = join(";", @out);$baz = trim($baz); # if getting the all in one line
                if ( $baz =~ /Connected\(/i) { $thud = "True" } else { $thud = "False" }
        }

        if ( $thud =~ /False/i) {
                $result = "Ping failed for $rtemsIP ";
        } else {
                $result = "Ping success for $rtemsIP ";
        }
}
sub ping_get_apair_rtems {

        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # check ports open against RTEMS
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "check if ports are open against envir ${envir}";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);
        plog("OK:");
        # if ( $debug ) { plog("\ncsv_rows=>\n@csv_rows\n"); }
        LINE: foreach $row (@csv_rows) {
                if ( $row =~ /^#/i ) { next LINE; }
                ( $rtemsCi,$rtemsIP,$rtemsConnect,$rtemsPairs,$rtemsFunction,$rtemsPrimSec,$rtemsTier,$rtemsEnvir,$rtemsShore ) = split(/;/, $row);
                # kmdlnxrls016;84.255.124.219;kmdlnxitm001/kmdlnxitm003;7;itm rtems;secondary;tier-2;cmo classic;nearshore
                $rtemsEnvir =~ s/ /\_/g;
                # if ( $rtemsEnvir =~ /${envir}/i && $rtemsShore =~ /${shore}/i && $rtemsIP !~ /^$/i && $rtemsTier !~ /Emptying/i && $rtemsPairs =~ /21/i  ) {
                if ( $rtemsEnvir =~ /${envir}/i && $rtemsShore =~ /${shore}/i && $rtemsIP !~ /^$/i && $rtemsTier !~ /Emptying/i ) {

                        print "rtemsCi: $rtemsCi, rtemsIP: $rtemsIP, rtemsPairs: $rtemsPairs, rtemsPrimSec: $rtemsPrimSec, rtemsEnvir: $rtemsEnvir\n";
                        pingip();
                        if ( $result =~ /success/i ) {
                                $status = "OK";
                                $hash_rtems{$rtemsIP} = "$status;$rtemsCi;$rtemsIP;$rtemsConnect;$rtemsPairs;$rtemsFunction;$rtemsPrimSec;$rtemsTier;$rtemsEnvir;$rtemsShore";
                        }
                        plog("\n$result");
                }
        }
        $count = scalar keys %hash_rtems;
        if ( $count == 0 ) {
                ++$step;
                undef( @out );
                @out = ();$baz = '';
                $text = "check ports open against all. ( Either all were marked Emptying or could not ping them)";
                plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);
                plog("OK:");
                LINE: foreach $row (@csv_rows) {
                        if ( $row =~ /^#/i ) { next LINE; }
                        ( $rtemsCi,$rtemsIP,$rtemsConnect,$rtemsPairs,$rtemsFunction,$rtemsPrimSec,$rtemsTier,$rtemsEnvir,$rtemsShore ) = split(/;/, $row);
                        # kmdlnxrls016;84.255.124.219;kmdlnxitm001/kmdlnxitm003;7;itm rtems;secondary;tier-2;cmo classic;nearshore
                        $rtemsEnvir =~ s/ /\_/g;
                        if ( $rtemsEnvir =~ /${envir}/i && $rtemsShore =~ /${shore}/i && $rtemsIP !~ /^$/i  ) {

                                print "rtemsCi: $rtemsCi, rtemsIP: $rtemsIP, rtemsPairs: $rtemsPairs, rtemsPrimSec: $rtemsPrimSec, rtemsEnvir: $rtemsEnvir\n";
                                pingip();
                                if ( $result =~ /success/i ) {
                                        $status = "OK";
                                        $hash_rtems{$rtemsIP} = "$status;$rtemsCi;$rtemsIP;$rtemsConnect;$rtemsPairs;$rtemsFunction;$rtemsPrimSec;$rtemsTier;$rtemsEnvir;$rtemsShore";
                                }
                                plog("\n$result");
                        }
                }
        }
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # if no ports opened, then notify and exit 12
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "check and inform about port status";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $count = scalar keys %hash_rtems;
        if ( $count > 0 ) {
                plog("OK: there are $count ports opened to choose from\n");
                foreach $rtemsIP (sort keys %hash_rtems) {
                        $row = $hash_rtems{$rtemsIP};
                        ( $status,$rtemsCi,$rtemsIP,$rtemsConnect,$rtemsPairs,$rtemsFunction,$rtemsPrimSec,$rtemsTier,$rtemsEnvir,$rtemsShore ) = split(/;/, $row);
                        plog("\nstatus: $status, rtemsCi: $rtemsCi, rtemsIP: $rtemsIP, rtemsPairs: $rtemsPairs, rtemsPrimSec: $rtemsPrimSec, rtemsEnvir: $rtemsEnvir");
                }
        } else {
                plog("ERROR: there is $count ports opened.");
                plog("\nPlease open a SRQ to network, asking to have ITM PORT 3660, and TDW PORT 65100 opened from this server against appropiate RTEMS");
                # foreach $row (@csv_rows) {
                #         ( $status,$rtemsCi,$rtemsIP,$rtemsConnect,$rtemsPairs,$rtemsFunction,$rtemsPrimSec,$rtemsTier,$rtemsEnvir,$rtemsShore ) = split(/\;/, $row);
                #         plog("\nrtemsCi: $rtemsCi, rtemsIP: $rtemsIP, rtemsPairs: $rtemsPairs, rtemsPrimSec: $rtemsPrimSec, rtemsEnvir: $rtemsEnvir");
                # }
                exit 0;
        }
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # loop over opened ports to find a pair
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "loop over opened ports to find a pair";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);
        foreach $rtemsIP (sort keys %hash_rtems) {
                $row = $hash_rtems{$rtemsIP};
                ( $status,$rtemsCi,$rtemsIP,$rtemsConnect,$rtemsPairs,$rtemsFunction,$rtemsPrimSec,$rtemsTier,$rtemsEnvir,$rtemsShore ) = split(/;/, $row);
                if ( $status =~ /OK/i && $rtemsPrimSec =~ /primary/i ) {
                        $primary = $rtemsIP;
                        $pairsNumber = $rtemsPairs;
                }
                }
                foreach $rtemsIP (sort keys %hash_rtems) {
                        ( $status,$rtemsCi,$rtemsIP,$rtemsConnect,$rtemsPairs,$rtemsFunction,$rtemsPrimSec,$rtemsTier,$rtemsEnvir,$rtemsShore ) = split(/\;/, $hash_rtems{$rtemsIP});
                        if ( $status =~ /OK/i && $rtemsPrimSec =~ /secondary/i && $rtemsPairs =~ /$pairsNumber/i ) {
                $secondary = $rtemsIP;
                }
        }
        $CT_CMSLIST = "IP.SPIPE:#$primary;IP.SPIPE:#$secondary";
        plog("OK: a pair has been selected. Pair: $pairsNumber primary: $primary secondary: $secondary ");
}
sub update_silent_ini_env {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # update config files
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "update ${agent} config files";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);
        # -------------------------------------------------------------------------------------------------------------------
        # lz.config
        # -------------------------------------------------------------------------------------------------------------------
        $con_file              = "/opt/IBM/ITM/config/${agent}.config";unlink("$con_file");
        $con_file_git          = "/tmp/scripttemp_dir/${agent}.config.empty"; # empty
        copy("$con_file_git","$con_file");


        # -------------------------------------------------------------------------------------------------------------------
        # lz.environment
        # -------------------------------------------------------------------------------------------------------------------
        $env_file              = "/opt/IBM/ITM/config/${agent}.environment";unlink("$env_file");
        $env_file_git          = "/tmp/scripttemp_dir/${agent}.environment"; # only KDC_FAMILIES
        copy("$env_file_git","$env_file");

$env_data = <<EOT;

# ========================================================================
# Postinstall changes
# ========================================================================
CTIRA_SYSTEM_NAME=${itm_nodename}
CTIRA_HOSTNAME=${itm_nodename}
EOT
# CT_CMSLIST=${CT_CMSLIST}
# CTIRA_SUBSYSTEM_ID=''
# KDC_FAMILIES=ip.spipe EPHEMERAL:Y port:3660 ip.pipe use:n sna use:n ip use:n ip6.pipe use:n ip6.spipe use:n ip6 use:n HTTP_SERVER:N
# GSK_PROTOCOL_SSLV2=OFF
# GSK_PROTOCOL_SSLV3=OFF
# KDEBE_TLS10_ON=NO
# KDEBE_TLS11_ON=NO
# GSK_V3_CIPHER_SPECS=350A

        open FILEOUT, ">> ${env_file}" or die "cant open and write to ${env_file}";
        print(FILEOUT $env_data);
        close FILEOUT;

        $cmdexec = "cat $env_file 2>&1";
        @out = `$cmdexec`;
        # if ( $debug ) { plog("\n env_file =>\n@out\n"); }

        # -------------------------------------------------------------------------------------------------------------------
        # lz.ini
        # -------------------------------------------------------------------------------------------------------------------
        $ini_file              = "/opt/IBM/ITM/config/${agent}.ini";unlink("$ini_file");
        $ini_file_git          = "/tmp/scripttemp_dir/${agent}.ini";
        copy("$ini_file_git","$ini_file");

$ini_data = <<EOT;

# ========================================================================
# Postinstall changes
# ========================================================================
CTIRA_SYSTEM_NAME=${itm_nodename}
CTIRA_HOSTNAME=${itm_nodename}
EOT
# KDC_FAMILIES=ip.spipe EPHEMERAL:Y port:3660 ip.pipe use:n sna use:n ip use:n ip6.pipe use:n ip6.spipe use:n ip6 use:n HTTP_SERVER:N
# CT_CMSLIST=${CT_CMSLIST}
# CTIRA_SUBSYSTEM_ID=''
# GSK_PROTOCOL_SSLV2=OFF
# GSK_PROTOCOL_SSLV3=OFF
# KDEBE_TLS10_ON=NO
# KDEBE_TLS11_ON=NO
# GSK_V3_CIPHER_SPECS=350A

        open FILEOUT, ">> ${ini_file}" or die "cant open and write to ${ini_file}";
        print(FILEOUT $ini_data);
        close FILEOUT;

        $cmdexec = "cat $ini_file 2>&1";
        @out = `$cmdexec`;
        # if ( $debug ) { plog("\n ini_file =>\n@out\n"); }




        # -------------------------------------------------------------------------------------------------------------------
        # silent_config_linux
        # -------------------------------------------------------------------------------------------------------------------

        $silent_config_linux      = '/opt/IBM/ITM/silent_config_linux.txt';unlink("$silent_config_linux");
        $silent_config_linux_git  = '/tmp/scripttemp_dir/silent_config_linux.txt';
        copy("$silent_config_linux_git","$silent_config_linux");

        $cmdexec = "sed -i 's/HOSTNAME=primary/HOSTNAME=${primary}/g' $silent_config_linux 2>&1";@out = `$cmdexec`;
        $cmdexec = "sed -i 's/MIRROR=secondary/MIRROR=${secondary}/g' $silent_config_linux 2>&1";@out = `$cmdexec`;

$silent_config_data = <<EOT;

# ========================================================================
# Postinstall changes
# ========================================================================
CTIRA_HOSTNAME=${itm_nodename}
CTIRA_SYSTEM_NAME=${itm_nodename}
EOT
# KDC_FAMILIES=ip.spipe EPHEMERAL:Y port:3660 ip.pipe use:n sna use:n ip use:n ip6.pipe use:n ip6.spipe use:n ip6 use:n HTTP_SERVER:N
# CTIRA_SUBSYSTEM_ID=''
# CT_CMSLIST=${CT_CMSLIST}
# GSK_PROTOCOL_SSLV2=OFF
# GSK_PROTOCOL_SSLV3=OFF
# KDEBE_TLS10_ON=NO
# KDEBE_TLS11_ON=NO
# GSK_V3_CIPHER_SPECS=350A

        open FILEOUT, ">> ${silent_config_linux}" or die "cant open and write to ${silent_config_linux}";
        print(FILEOUT $silent_config_data);
        close FILEOUT;

        $cmdexec = "cat $silent_config_linux 2>&1";
        @out = `$cmdexec`;
        if ( $debug ) { plog("\n silent_config_linux =>\n@out\n"); }

        plog("OK: ${agent} config files updated");
}
sub special_cfg {

        $special_cfg        = "/opt/IBM/ITM/config/.ConfigData/k${agent}env";unlink("$special_cfg");
        $special_cfg_git    = "/tmp/scripttemp_dir/k${agent}env";
        copy("$special_cfg_git","$special_cfg");

        $foo = "|HOSTNAME|primary|";
        $bar = "|HOSTNAME|${primary}|";
        $cmdexec = "sed -i 's/$foo/${bar}/g' $special_cfg 2>&1";@out = `$cmdexec`;

        $foo = "|MIRROR|secondary|";
        $bar = "|MIRROR|${secondary}|";
        $cmdexec = "sed -i 's/$foo/${bar}/g' $special_cfg 2>&1";@out = `$cmdexec`;

        $foo = "|RUNNINGHOSTNAME|hostname|";
        $bar = "|RUNNINGHOSTNAME|${hostname}|";
        $cmdexec = "sed -i 's/$foo/${bar}/g' $special_cfg 2>&1";@out = `$cmdexec`;


        $cmdexec = "cat $special_cfg 2>&1";
        @out = `$cmdexec`;
        # if ( $debug ) { plog("\n special_cfg =>\n@out\n"); }

        $cmdexec = "chmod -R 775 /opt/IBM/ITM/config/ 2>&1";
        @out = `$cmdexec`;
        # if ( $debug ) { plog("\n special_cfg =>\n@out\n"); }

}
sub stop_lz_08_agents {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # run Stop LZ
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "stop LZ agent";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $cmdexec = "/opt/IBM/ITM/bin/itmcmd agent -f stop lz 2>&1";
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }

        plog("OK: agent lz stopped");

        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # run Stop 08
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "stop 08 agent";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $cmdexec = "/opt/IBM/ITM/bin/itmcmd agent -f stop 08 2>&1";
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }

        plog("OK: agent 08 stopped");

        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # run kill klzagent
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "kill klzagent";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $cmdexec = "pkill -9 klzagent 2>&1";
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }
        plog("OK: klzagent stopped");

        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # run kill k08agent
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "kill k08agent";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $cmdexec = "pkill -9 k08agent 2>&1";
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }

        plog("OK: k08agent stopped");

}
sub list_processes {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # list all ITM processes
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "list all ITM processes";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $cmdexec = "ps -ef | grep -i ITM 2>&1";
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }

        plog("OK: process listed");
}
sub install_agents {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # run start lz agents
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "install ITM agents";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        if ( $itmuser_found ) {
                $cmdexec = "sudo -u ${userid} /opt/IBM/ITM/bin/itmcmd agent start lz 2>&1";
        } else {
                $cmdexec = " /opt/IBM/ITM/bin/install.sh";
        }

        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }
        trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);

        plog("OK: ITM agent uninstalled: $baz");
}

sub configure_agent {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # run configure using silent_config_linux
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "run configure using silent_config_linux";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        if ( $itmuser_found ) {
                $cmdexec = "sudo -u ${userid} /opt/IBM/ITM/bin/itmcmd config -A -p $silent_config_linux ${agent} 2>&1";
        } else {
                $cmdexec = "/opt/IBM/ITM/bin/itmcmd config -A -p $silent_config_linux ${agent} 2>&1";
        }

        # $cmdexec = "/opt/IBM/ITM/bin/CandleConfig -A -p $silent_config_linux lz 2>&1";
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }
        trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);

        plog("OK: configure result: $baz");
}
sub start_agents {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # run start lz agents
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "start lz agents";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        if ( $itmuser_found ) {
                $cmdexec = "sudo -u ${userid} /opt/IBM/ITM/bin/itmcmd agent start lz 2>&1";
        } else {
                $cmdexec = "/opt/IBM/ITM/bin/itmcmd agent start lz 2>&1";
        }

        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }
        trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);

        plog("OK: lz agent started: $baz");

        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # run start 08 agents
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "start 08 agents";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        if ( $itmuser_found ) {
                $cmdexec = "sudo -u ${userid} /opt/IBM/ITM/bin/itmcmd agent start 08 2>&1";
        } else {
                $cmdexec = "/opt/IBM/ITM/bin/itmcmd agent start 08 2>&1";
        }

        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }
        trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);

        plog("OK: gsma agent started: $baz");

        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # run start all agents if any is missed
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "start all agents";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        if ( $itmuser_found ) {
                $cmdexec = "sudo -u ${userid} /opt/IBM/ITM/bin/itmcmd agent start all 2>&1";
        } else {
                $cmdexec = "/opt/IBM/ITM/bin/itmcmd agent start all 2>&1";
        }

        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }
        trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);

        plog("OK: gsma agent started: $baz");
}
sub cinfo {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # cinfo
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "cinfo  $agent agent";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $cmdexec = "/opt/IBM/ITM/bin/cinfo -c $agent 2>&1";
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }

        plog("OK: cinfo completed");
}
sub netstat {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # netstat
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "netstat port assignment";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $cmdexec = "netstat -anp | grep 3660 2>&1";
        # $cmdexec = "netstat -tup 2>&1";
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }

        plog("OK: netstat completed");
}
sub listLogs {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # list Logs
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # ++$step;
        # undef( @out );
        # @out = ();$baz = '';
        # $text = "list Logs";
        # plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        # $cmdexec = "ls -lrt /opt/IBM/ITM/logs 2>&1";
        # if ( $debug ) { plog("\n$cmdexec\n"); }
        # @out = `$cmdexec`;
        # if ( $debug ) { plog("\nout=>\n@out\n"); }

        # $cmdexec = "cat /opt/IBM/ITM/logs/KMDAPP2394_lz_1693841541.log 2>&1";
        # if ( $debug ) { plog("\n$cmdexec\n"); }
        # @out = `$cmdexec`;
        # if ( $debug ) { plog("\nout=>\n@out\n"); }

        # $cmdexec = "cat /opt/IBM/ITM/logs/KMDAPP2394_08_1693841548.log 2>&1";
        # if ( $debug ) { plog("\n$cmdexec\n"); }
        # @out = `$cmdexec`;
        # if ( $debug ) { plog("\nout=>\n@out\n"); }

        # $cmdexec = "cat /opt/IBM/ITM/logs/UpdateAutoRun.log 2>&1";
        # if ( $debug ) { plog("\n$cmdexec\n"); }
        # @out = `$cmdexec`;
        # if ( $debug ) { plog("\nout=>\n@out\n"); }

        # $cmdexec = "cat /opt/IBM/ITM/logs/lz.env 2>&1";
        # if ( $debug ) { plog("\n$cmdexec\n"); }
        # @out = `$cmdexec`;
        # if ( $debug ) { plog("\nout=>\n@out\n"); }

        # $cmdexec = "cat /opt/IBM/ITM/logs/08.env 2>&1";
        # if ( $debug ) { plog("\n$cmdexec\n"); }
        # @out = `$cmdexec`;
        # if ( $debug ) { plog("\nout=>\n@out\n"); }

        # $cmdexec = "cat /opt/IBM/ITM/logs/itm_config.trc 2>&1";
        # if ( $debug ) { plog("\n$cmdexec\n"); }
        # @out = `$cmdexec`;
        # if ( $debug ) { plog("\nout=>\n@out\n"); }

        # $cmdexec = "cat /opt/IBM/ITM/logs/candle_installation.log 2>&1";
        # if ( $debug ) { plog("\n$cmdexec\n"); }
        # @out = `$cmdexec`;
        # if ( $debug ) { plog("\nout=>\n@out\n"); }
        # " -rw-rw-r--. 1 root root    1389 Sep  4 17:32 UpdateAutoRun.log",
        # " -rwxrwxr--. 1 root root    5740 Sep  4 17:32 lz.env",
        # " -rw-rw-r--. 1 root root      79 Sep  4 17:32 KMDAPP2394_lz_1693841541.log",
        # " -rwxrwxr--. 1 root root  655814 Sep  4 17:32 candle_installation.log",
        # " -rwxrwxr--. 1 root root    5740 Sep  4 17:32 08.env",
        # " -rw-rw-r--. 1 root root      79 Sep  4 17:32 KMDAPP2394_08_1693841548.log",
        # " -rw-rw-r--. 1 root root 1297016 Sep  4 17:32 itm_synclock.trc",
        # " -rw-rw-r--. 1 root root 1154342 Sep  4 17:32 itm_config.trc",
        # " -rw-rw-r--. 1 root root   98106 Sep  4 17:32 itm_config.log",
        # plog("OK: list Logs");
}
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# begin - main
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
check_itmuser_run_securemain();
read_rtems_csv();

if ( $pingonly ) {
        ping_get_apair_rtems();
} else {
        ping_get_apair_rtems();
        stop_lz_08_agents();
        list_processes();

        install_agents();

        $agent = 'lz';
        update_silent_ini_env();
        special_cfg();
        configure_agent();

        $agent = '08';
        update_silent_ini_env();
        special_cfg();
        configure_agent();
        check_itmuser_run_securemain();
        start_agents();

        $agent = 'lz';
        cinfo();
        $agent = '08';
        cinfo();

        netstat();
        list_processes();
        listLogs();
}
