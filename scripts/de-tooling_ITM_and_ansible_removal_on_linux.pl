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
# version 2023-05-07
# Changelog
#
# de-tooling_ITM_and_ansible_removal_linux.pl  :   Fresh rewrite
#
# 2023-05-07  rewrite release ( Benny.Skov@kyndryl.com )
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
my(@foo,@bar,@baz,@out,@trimin,$argnum,$numArgs);
my($cmdexec,$text,$debug,$csv_data,%hash_rtems,@csv_rows,@csv_lines,@fields,$line,$row,$count,$status,$ccode,$nodename);
my($rtemsCi,$rtemsIP,$rtemsConnect,$rtemsPairs,$rtemsFunction,$rtemsPrimSec,$rtemsTier,$rtemsEnvir,$rtemsShore,$result,$itmuser_found,$is_user_found);
my($primary,$secondary,$pairsNumber,$CT_CMSLIST,$rtems_file,$handle,$agent,$shore,$envir);
my($silent_config_data,$silent_config_linux_git,$silent_config_linux,$pingonly);
my($env_file,$env_file_git,$env_data);
my($ini_file,$ini_file_git,$ini_data);
my($con_file,$con_file_git,$agent_con_data);
my($special_cfg,$special_cfg_git,$group,$userid,$logfile,@fsList,$FS,@allOut,$file,@cacfUsers,$removeAnsibleUsers);
my($exec_ansible_cleanup,$continue,$itm_isMounted,$ansible_isMounted,$uninstall_script);
$debug = 0;
$removeAnsibleUsers = 0;
$nodename = hostname;
$nodename = lc($nodename);
$numArgs = scalar(@ARGV);
if ($numArgs > 0) {
        if (defined($ARGV[0]) && $ARGV[0] =~ /^(-h|-\?|--help)/) {
                help_error();
        }
        foreach $argnum (0 .. $#ARGV) {
                if (defined($ARGV[$argnum])) {
                        if ( $ARGV[$argnum] =~ /^\-nodename$/)                  { $argnum++; $nodename = "$ARGV[$argnum]"; }
                        if ( $ARGV[$argnum] =~ /^\-removeAnsibleUsers$/)        { $removeAnsibleUsers = 1; }
                        if ( $ARGV[$argnum] =~ /^\-debugScript$/)               { $debug = 1; }
                }
        }
}
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# INIT
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

$scriptname         = $0;
$scriptname         =~ s/\\/\//g; # turn slash
@words              = split(/\//, $scriptname);
$scriptn            = $words[$#words];
$scriptn            =~ s/\.pl//g;
$continue           = 1; # ~true
# @fsList_orig = ("/var/opt/ansible",
#         "/var/opt/ansible_workdir",
#         "/etc/ansible",
#         "/root/.ansible_async",
#         "/tmp/gts-ansible",
#         "/etc/opt/bigfix",
#         "/var/tmp/ilmt",
#         "/var/tmp/aicbackup/ilmt",
#         "/var/db/sudo/lectured/ansible",
#         "/etc/opt/Bigfix",
#         "/etc/BESClient",
#         "/tmp/*BESClient*",
#         "/root/.ansible",
#         "/var/opt/ansible*",
#         "/var/log/ansible*",
#         "/_opt_IBM_ITM_i",
#         "/usr/bin/ansibl*"
#         );
@fsList = ("/etc/opt/bigfix",
        "/var/tmp/ilmt",
        "/var/tmp/aicbackup/ilmt",
        "/etc/opt/Bigfix",
        "/etc/BESClient",
        "/tmp/*BESClient*",
        "/_opt_IBM_ITM_i",
        );

# @cacfUsers = ("kmduxat1",
#         "kmduxat2",
#         "kmnuxat1",
#         "kmnuxat2",
#         "kmwuxat1",
#         "kmwuxat2",
#         "ug2uxat1",
#         "ug2uxat2",
#         "yl5uxat1",
#         "yl5uxat2");

@cacfUsers = ('itmuser');

$logfile = "de_tooling_removal_linux.log";
unlink("$logfile");
open LISTOUT, ">> $logfile" or die "cant open and write to $logfile";
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# read input
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
plog("\nnodename: $nodename");
plog("\ndebug:    $debug");
plog("\nscriptn:  $scriptn");
if ( $nodename =~ /\./i) {
        ($nodename,$bar) = split(/\./, $nodename, -1);
}
# ----------------------------------------------------------------------------------------------------------------------------
# help
# ----------------------------------------------------------------------------------------------------------------------------
sub help_error {
		print ("\n");
		print ("\n");
		print ("use: -?, for this message\n");
                print ("use: -n, for nodename \n");
                print ("use: -u, for remove ansible users like kmduxat1, kmduxat2.... \n");
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
        print("${text}");
        print(LISTOUT "${text}");
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
sub check_ansible_cleanup {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # check_ansible_cleanup
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

        ++$step;
        undef( @out );
        undef( @allOut );
        @out = ();$baz = '';
        $text = "check_ansible_cleanup";
        $exec_ansible_cleanup = 0 ;
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);
        @allOut = ();
        foreach $FS (@fsList) {
                if ($FS =~ /^$/) { next; }
                $cmdexec   = "find $FS 2>&1 || true";
                if ( $debug ) { plog("\n$cmdexec\n"); }
                @out = `$cmdexec`;
                trimout();
                if ( $debug ) { plog("\nout=>\n@out\n"); }
                @allOut = (@allOut, @out);
        }
        undef( @out );
        @out =  @allOut;
        $count = scalar @out;
        if ( $count < 6000 ) {
                $exec_ansible_cleanup = 1;
                plog("OK: ${count} file(s) can be deleted");
        } else {
                $exec_ansible_cleanup = 0 ;
                plog("warn: ${count} file(s) is over max 6000. usually under. Skipping exec_ansible_cleanup");
        }
}
sub exec_ansible_cleanup {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # exec_ansible_cleanup
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        if ( $exec_ansible_cleanup ) {
                ++$step;
                undef( @out );
                undef( @allOut );
                @out = ();$baz = '';
                $text = "exec_ansible_cleanup";
                plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);
                @allOut = ();
                foreach $FS (@fsList) {
                        if ($FS =~ /^$/) { next; }
                        $cmdexec   = "find $FS -not -path /tmp/KMD-AEVEN-TOOLS/scripts/* -delete 2>&1 || true";
                        if ( $debug ) { plog("\n$cmdexec\n"); }
                        @out = `$cmdexec`;
                        trimout();
                        if ( $debug ) { plog("\nout=>\n@out\n"); }
                        @allOut = (@allOut, @out);
                }
                undef( @out );
                @out =  @allOut;
                $count = scalar @out;
                if ( $count < 6000 ) {
                        plog("OK: ${count} file(s) can be deleted");
                } else {
                        plog("warn: ${count} file(s) is over max 6000. usually under. Skipping exec_ansible_cleanup");
                }
        }
}
sub check_fs_mounted {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # check_fs_mounted /opt/IBM/ITM
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "check if /opt/IBM/ITM is mounted";
        $itm_isMounted = 0 ;
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $cmdexec = "findmnt -n /opt/IBM/ITM > /dev/null 2>&1 && echo 'is_mount' || echo 'not_mount'";
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }
        trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);

        if ( $baz =~ /^is_mount/i ) {
                $itm_isMounted = 1;
                plog("OK: /opt/IBM/ITM is_mount. dir is a mounted filesystem, it cannot be deleted");
        } else {
                $itm_isMounted = 0 ;
                plog("OK: /opt/IBM/ITM is not mounted. Deleted");
        }
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # check_fs_mounted /var/opt/ansible
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "check if /var/opt/ansible is mounted";
        $ansible_isMounted = 0 ;
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $cmdexec = "findmnt -n /var/opt/ansible > /dev/null 2>&1 && echo 'is_mount' || echo 'not_mount'";
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }
        trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);

        if ( $baz =~ /^is_mount/i ) {
                $ansible_isMounted = 1;
                plog("OK: /var/opt/ansible is_mount. dir is a mounted filesystem, it cannot be deleted");
        } else {
                $ansible_isMounted = 0 ;
                plog("OK: /var/opt/ansible is not mounted - deleted.");
        }
}
sub check_leftovers {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # check_ansible_cleanup
        # --------------------}----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "check_leftovers";
        $exec_ansible_cleanup = 0 ;
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $cmdexec = 'find / \( -iname "*ILMT*" -o -iname "*ansible*" -o -iname "*bigfix*" -o -iname "*BESClient*" \) \
                -not -path "/proc/*" \
                -not -path "/sys/*" \
                -not -path "/dev/*" \
                -not -path "/run/*" \
                -not -path "*/cache/*" \
                -not -path "/var/lib/*" \
                -not -path "/usr/lib/*" \
                -not -path "/usr/share/*" \
                -not -path "/tmp/KMD-AEVEN-TOOLS/scripts/*" \
                2>/dev/null';
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }
        trimout();
        $count = scalar @out;
        if ( $count > 1 ) {
                plog("OK: ${count} file(s) is leftover at server, which was not matched and deleted.\n");
                foreach $line (@out) {
                        plog("${line}\n");
                }
        } else {
                plog("OK: ${count} file(s) is leftover. All is cleaned up.");
        }
}
sub list_opt_ansible {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # list /var/opt/ansible
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "list /var/opt/ansible";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $cmdexec = "ls -lrt /var/opt/ansible 2>&1 || true";
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        trimout();
        $count = scalar @out;
        if ( $count > 1 ) {
                plog("OK: ${count} file(s) is in /var/opt/ansible at server, which was not matched and deleted.\n");
                foreach $line (@out) {
                        plog("${line}\n");
                }
        } else {
                plog("OK: ${count} file(s) in /var/opt/ansible");
        }
}
sub check_itmuser_run_securemain() {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # check if itmuser exists
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        ${userid} = "itmuser";
        $itmuser_found = 0 ;

        $text = "check if ${userid} exists";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);
        $cmdexec = "id -g ${userid} > /dev/null 2>&1 && echo 'user_found' || echo 'no user_found'"; # check if user is found

        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }
        trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);
        if ( $baz =~ /no user_found/i ) {
                $itmuser_found = 0 ;
                plog("note: ${userid} NOT found: $baz");
        } else {
                $itmuser_found = 1;
                plog("OK: ${userid} found.");
        }
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # doublecheck to see if ITM is started under itmuser user
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        if ( $itmuser_found ) {

                ++$step;
                undef( @out );
                @out = ();$baz = '';
                $text = "get group name for itmuse";
                plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

                $cmdexec = "id -g ${userid} | xargs getent group | cut -d: -f1 2>&1 || true";
                if ( $debug ) { plog("\n$cmdexec\n"); }
                @out = `$cmdexec`;
                if ( $debug ) { plog("\nout=>\n@out\n"); }
                trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);
                if ( $baz =~ /no such user/i ) {
                        plog("OK: ${userid} NOT found: $baz");
                } else {
                        $group = $baz;
                        plog("OK: ${userid} found in group: $group");
                }

                ++$step;
                undef( @out );
                @out = ();$baz = '';
                $text = "check if ${userid} is used to start agents";
                plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);
                # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                # get grou name for itmuser
                # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
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
                        plog("OK: ITM is stated as root, no need for securemain");
                }
                # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                # secureMain for itmuser
                # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
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
sub check_ITM_running {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # list all ITM processes
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "list all ITM processes";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $cmdexec = "ps -ef | grep -i ITM |grep -v grep | wc -l || true 2>&1";
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }

        plog("OK: process listed");
}
sub check_uninstall_script {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # check if uninstall exists
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "check if unistall.sh exists";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        # Check if uninstall.sh exists before running uninstall
        $uninstall_script = "/opt/IBM/ITM/bin/uninstall.sh";
        if ( -e $uninstall_script ) {
                plog("OK: Found $uninstall_script");
        } else {
                plog("WARN: $uninstall_script not found. Skipping uninstall.");
                $continue = 0;
                return;
        }
}
sub start_agents {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # run start lz agents
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "start lz agents";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);        $cmdexec = "/opt/IBM/ITM/bin/itmcmd agent start lz 2>&1";

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
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);        $cmdexec = "/opt/IBM/ITM/bin/itmcmd agent start 08 2>&1";

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
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);        $cmdexec = "/opt/IBM/ITM/bin/itmcmd agent start all 2>&1";

        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }
        trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);

        plog("OK: gsma agent started: $baz");
}
sub stop_all_agents {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # First stop all agents gracefully
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "stop all agents gracefully";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        # Try graceful stop first
        $cmdexec = "/opt/IBM/ITM/bin/itmcmd agent -f stop all 2>&1";
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }

        # Wait for processes to stop
        sleep(5);

        plog("OK: all agents stop command issued");

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

        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # run kill k08agent
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "kill anything ITM";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        # Example: db2por    60615      1  0 Feb13 ?        00:32:00 /opt/IBM/ITM/lx8266/ud/bin/kuddb2 kmdlnxblc001_db2por
        # $cmdexec = "ps -ef | grep -i /opt/IBM/ITM | grep -v grep | awk '{print $8}' | xargs -n1 basename | pkill -9 xargs 2>&1";
        $cmdexec = "pkill -9 -f /opt/IBM/ITM 2>&1";
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }

        plog("OK: all /opt/IBM/ITM is stopped");
}
sub uninstall_agents {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # Check uninstall script exists
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "check if unistall.sh exists";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        # Check if uninstall.sh exists before running uninstall
        my $uninstall_script = "/opt/IBM/ITM/bin/uninstall.sh";
        if ( -e $uninstall_script ) {
                plog("OK: Found $uninstall_script");
        } else {
                plog("WARN: $uninstall_script not found. Skipping uninstall.");
                return;
        }

        # Double-check for any remaining ITM processes
        ++$step;
        $text = "verify no ITM processes running";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $cmdexec = "ps -ef | grep -i /opt/IBM/ITM | grep -v grep";
        @out = `$cmdexec`;
        trimout();
        if (scalar @out > 0) {
            plog("WARN: Found ITM processes still running. Forcing termination.");
            system("pkill -9 -f /opt/IBM/ITM");
            sleep(3);  # Give processes time to die
        }

        # Backup and clean config files that might prevent uninstall
        my @config_paths = (
            '/opt/IBM/ITM/config',
            '/opt/IBM/ITM/bin/*.ini',
            '/opt/IBM/ITM/bin/*.config'
        );
        foreach my $path (@config_paths) {
            system("rm -rf $path.old 2>/dev/null");
            system("mv $path $path.old 2>/dev/null");
        }

        # Run uninstall with force option
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "uninstall all agents";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $cmdexec = "/opt/IBM/ITM/bin/uninstall.sh -f REMOVE EVERYTHING";  # Add -f for force
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `ksh $cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }
        trimout();

        # Log output with proper formatting
        if (scalar @out > 0) {
            plog("OK: ITM agent uninstall details:\n");
            foreach my $line (@out) {
                chomp($line);
                if ($line =~ /\S/) {  # Only log non-empty lines
                    plog("    $line\n");
                }
            }
        }

        # Verify uninstall succeeded by checking if key directories still exist
        ++$step;
        $text = "verify uninstall completion";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        if (-d "/opt/IBM/ITM/bin") {
            plog("WARN: ITM binaries directory still exists. Manual cleanup may be needed.");
            # Force remove critical files to prevent agent from running
            system("rm -f /opt/IBM/ITM/bin/*agent 2>/dev/null");
            system("rm -f /opt/IBM/ITM/bin/itmcmd 2>/dev/null");
        }
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
sub list_opt_itm {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # list /opt/IBM/ITM/
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "list /opt/IBM/ITM/";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $cmdexec = "ls -lrt /opt/IBM/ITM/ 2>&1 || true";
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        trimout();
        $count = scalar @out;
        if ( $count > 1 ) {
                plog("OK: ${count} file(s) is in /opt/IBM/ITM/ at server, which was not matched and deleted.\n");
                foreach $line (@out) {
                        plog("${line}\n");
                }
        } else {
                plog("OK: ${count} file(s) in /opt/IBM/ITM/");
        }
}
sub remove_ux_uers() {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # remove itmuser and misc CACF users
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        if ( $removeAnsibleUsers )  {

                foreach ${userid} (@cacfUsers) {
                        ++$step;
                        my $cleanup_success = 1;  # Track if all cleanup operations succeeded
                        undef( @out );
                        @out = ();$baz = '';
                        $text = "checking if user ${userid} exists";
                        $is_user_found = 0;
                        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

                        # Check if user exists more reliably using getent
                        $cmdexec = "getent passwd ${userid} > /dev/null 2>&1 && echo 'user_found' || echo 'no_user_found'";
                        if ( $debug ) { plog("\n$cmdexec\n"); }
                        @out = `$cmdexec`;
                        trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);

                        if ( $baz =~ /user_found/i ) {
                                $is_user_found = 1;
                                plog("OK: user ${userid} found");

                                # Check and terminate user processes if any exist
                                ++$step;
                                undef( @out );
                                @out = ();$baz = '';
                                $text = "checking and terminating ${userid}'s processes";
                                plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

                                # First check if user has any processes
                                $cmdexec = "ps -u ${userid} -o pid= > /dev/null 2>&1 && echo 'has_processes' || echo 'no_processes'";
                                if ( $debug ) { plog("\n$cmdexec\n"); }
                                @out = `$cmdexec`;
                                trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);

                                if ( $baz =~ /has_processes/i ) {
                                # Try graceful termination first
                                $cmdexec = "pkill -TERM -u ${userid} 2>/dev/null || true";
                                if ( $debug ) { plog("\n$cmdexec\n"); }
                                `$cmdexec`;

                                # Wait briefly for processes to terminate
                                sleep(2);

                                # Force kill any remaining processes
                                $cmdexec = "pkill -9 -u ${userid} 2>/dev/null || true";
                                if ( $debug ) { plog("\n$cmdexec\n"); }
                                `$cmdexec`;

                                # Verify all processes are gone
                                $cmdexec = "ps -u ${userid} -o pid= > /dev/null 2>&1 && echo 'still_running' || echo 'all_terminated'";
                                @out = `$cmdexec`;
                                trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);

                                if ( $baz =~ /still_running/i ) {
                                        plog("WARN: Some processes for ${userid} could not be terminated");
                                        $cleanup_success = 0;
                                } else {
                                        plog("OK: All processes for ${userid} terminated successfully");
                                }
                                } else {
                                plog("Note: No processes found for ${userid}");
                                }

                                # Check and cleanup user files
                                ++$step;
                                undef( @out );
                                @out = ();$baz = '';
                                $text = "checking ${userid}'s files";
                                $exec_ansible_cleanup = 0;
                                plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

                                # Find user's files with error suppression for permission denied
                                $cmdexec = "find /tmp /var/spool/cron /etc/sudoers.d /home /var/spool/cron /var/mail /var/spool/cups -user ${userid} 2>/dev/null || true";
                                if ( $debug ) { plog("\n$cmdexec\n"); }
                                @out = `$cmdexec`;
                                trimout();
                                $count = scalar @out;

                                if ( $count > 0 && $count < 1000 ) {
                                        $exec_ansible_cleanup = 1;
                                        plog("OK: Found ${count} file(s) to be deleted");
                                        # Print found files in debug mode
                                        if ( $debug ) {
                                        foreach $file (@out) {
                                                plog("Found file: $file");
                                        }
                                        }
                                } elsif ( $count >= 1000 ) {
                                        $exec_ansible_cleanup = 0;
                                        plog("WARN: ${count} file(s) is over max 1000. Usually under. Skipping cleanup");
                                        $cleanup_success = 0;
                                } else {
                                        plog("Note: No files found for ${userid}");
                                }

                                # Remove the user account if cleaning up files was successful
                                if ( $cleanup_success ) {
                                ++$step;
                                $text = "removing user account ${userid}";
                                plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

                                $cmdexec = "userdel -r ${userid} 2>&1 || true";
                                if ( $debug ) { plog("\n$cmdexec\n"); }
                                @out = `$cmdexec`;
                                trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);

                                # Verify user was removed
                                $cmdexec = "getent passwd ${userid} > /dev/null 2>&1 && echo 'still_exists' || echo 'removed'";
                                @out = `$cmdexec`;
                                trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);

                                if ( $baz =~ /still_exists/i ) {
                                        plog("ERROR: Failed to remove user ${userid}");
                                } else {
                                        plog("OK: User ${userid} removed successfully");
                                }
                                } else {
                                plog("WARN: Skipping removal of user ${userid} due to cleanup issues");
                                }
                        } else {
                                plog("Note: User ${userid} not found on server - skipping cleanup operations");
                        }
                }
        }
}
sub check_prerequisites {
    my $prerequisites_ok = 1;

    # Check for required commands
    my @required_commands = ('pkill', 'find', 'id', 'getent', 'ps', 'ls', 'ksh');
    foreach my $cmd (@required_commands) {
        my $check = `which $cmd 2>/dev/null`;
        if ($? != 0) {
            plog("ERROR: Required command '$cmd' not found");
            $prerequisites_ok = 0;
        }
    }

    # Check for ITM installation path
    if (!-d "/opt/IBM/ITM") {
        plog("WARN: ITM installation directory /opt/IBM/ITM not found");
    }

    # Check ITM binary paths that we'll need
    my @itm_paths = (
        '/opt/IBM/ITM/bin/itmcmd',
        '/opt/IBM/ITM/bin/cinfo'
    );

    foreach my $path (@itm_paths) {
        if (!-x $path) {
            plog("WARN: ITM binary '$path' not found or not executable");
        }
    }

    # Check if any ITM processes are running
    my $itm_processes = `ps -ef | grep -i "/opt/IBM/ITM" | grep -v grep | wc -l`;
    chomp($itm_processes);
    if ($itm_processes > 0) {
        plog("NOTE: Found $itm_processes ITM processes running");
    }

    # Check disk space in critical locations
    my @paths_to_check = ('/', '/opt', '/var');
    foreach my $path (@paths_to_check) {
        my $df_output = `df -h $path 2>/dev/null`;
        if ($df_output =~ /(\d+)%/) {
            my $usage = $1;
            if ($usage > 90) {
                plog("WARN: Low disk space on $path ($usage% used)");
                $prerequisites_ok = 0;
            }
        }
    }

    return $prerequisites_ok;
}

# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# begin - main
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$agent = 'lz';
if ( $continue ) { cinfo(); }
$agent = '08';
if ( $continue ) { cinfo(); }
if ( $continue ) { check_ansible_cleanup(); }
if ( $continue ) { exec_ansible_cleanup(); }
if ( $continue ) { check_fs_mounted(); }
if ( $continue ) { check_leftovers(); }
if ( $continue ) { list_opt_ansible(); }

if ( $continue ) { check_itmuser_run_securemain(); }
if ( $continue ) { check_ITM_running(); }
if ( $continue ) { check_uninstall_script(); }

if ( $continue ) { stop_all_agents(); }
if ( $continue ) { uninstall_agents(); }
if ( $continue ) { list_opt_itm(); }
if ( $removeAnsibleUsers ) { remove_ux_uers(); }

plog("\nTheEnd\n");
close LISTOUT;