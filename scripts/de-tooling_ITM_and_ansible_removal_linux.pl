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
my($cmdexec,$text,$debug,$csv_data,%hash_rtems,@csv_rows,@csv_lines,@fields,$line,$row,$count,$status,$ccode,$hostname,$itm_nodename);
my($rtemsCi,$rtemsIP,$rtemsConnect,$rtemsPairs,$rtemsFunction,$rtemsPrimSec,$rtemsTier,$rtemsEnvir,$rtemsShore,$result,$itmuser_found,$is_user_found);
my($primary,$secondary,$pairsNumber,$CT_CMSLIST,$rtems_file,$handle,$agent,$shore,$envir);
my($silent_config_data,$silent_config_linux_git,$silent_config_linux,$pingonly);
my($env_file,$env_file_git,$env_data);
my($ini_file,$ini_file_git,$ini_data);
my($con_file,$con_file_git,$agent_con_data);
my($special_cfg,$special_cfg_git,$group,${userid});
my($exec_ansible_cleanup,$continue,$itm_isMounted,$ansible_isMounted,$uninstall_script,@usernames);
$debug = 0;
if  (scalar(@ARGV) >= 0 ) {
	$numArgs = $#ARGV + 1;
	# plog("thanks, you gave me $numArgs cmdexec-line arguments.\n");
	if 	( ($ARGV[0] =~ /^(-h|-\?|--help)/) ) { help_error(); }
	foreach $argnum (0 .. $#ARGV) {
		plog("$ARGV[$argnum]\n");
                if ( $ARGV[$argnum] =~ /^\-d$/) { $argnum++; $debug = 1; } # 1=yes
	}
} else {
	help_error();
}
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
$continue           = 1; # ~true
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# read input
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
plog("\nhostname: $hostname");
plog("\ndebug:    $debug");
plog("\nscriptn:  $scriptn");
if ( $hostname =~ /\./i) {
        ($hostname,$bar) = split(/\./, $hostname, -1);
}
# ----------------------------------------------------------------------------------------------------------------------------
# help
# ----------------------------------------------------------------------------------------------------------------------------
sub help_error {
		print ("\n");
		print ("\n");
		print ("use: -?, for this message\n");
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
sub check_ansible_cleanup {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # check_ansible_cleanup
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "check_ansible_cleanup";
        $exec_ansible_cleanup = 0 ;
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);
        $cmdexec   = 'find / \( -path "/var/opt/ansible" -o \
                                -path "/var/opt/ansible_workdir" -o \
                                -path "/etc/ansible" -o \
                                -path "/root/.ansible_async" -o \
                                -path "/tmp/gts-ansible" -o \
                                -path "/etc/opt/bigfix" -o \
                                -path "/var/tmp/ilmt" -o \
                                -path "/var/tmp/aicbackup/ilmt" -o \
                                -path "/var/db/sudo/lectured/ansible" -o \
                                -path "/etc/opt/Bigfix" -o \
                                -path "/etc/BESClient" -o \
                                -path "/root/.ansible" \) \
                                2>/dev/null | wc -l';

        if ( $debug ) { plog("\n$cmdexec\n"); }

        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }
        trimout();
        $count = scalar @out;
        if ( $count < 6000 ) {
                $exec_ansible_cleanup = 1;
                plog("OK: ${baz} file(s) can be deleted");
        } else {
                $exec_ansible_cleanup = 0 ;
                plog("warn: ${baz} file(s) is over max 6000. usually under. Skipping exec_ansible_cleanup");
        }
}
sub exec_ansible_cleanup {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # exec_ansible_cleanup
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "exec_ansible_cleanup";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        if ( $exec_ansible_cleanup ) {
                $cmdexec   = 'find / \( -path "/var/opt/ansible" -o \
                                        -path "/var/opt/ansible_workdir" -o \
                                        -path "/etc/ansible" -o \
                                        -path "/root/.ansible_async" -o \
                                        -path "/tmp/gts-ansible" -o \
                                        -path "/etc/opt/bigfix" -o \
                                        -path "/var/tmp/ilmt" -o \
                                        -path "/var/tmp/aicbackup/ilmt" -o \
                                        -path "/var/db/sudo/lectured/ansible" -o \
                                        -path "/etc/opt/Bigfix" -o \
                                        -path "/etc/BESClient" -o \
                                        -path "/root/.ansible" \) \
                                        -delete 2>/dev/null | wc -l';

                # $cmdexec = "find /var/opt/ansible /var/opt/ansible_workdir /etc/ansible /root/.ansible_async /tmp/gts-ansible /etc/opt/bigfix /var/tmp/ilmt -delete 2>/dev/null";
                if ( $debug ) { plog("\n$cmdexec\n"); }
                @out = `$cmdexec`;
                if ( $debug ) { plog("\nout=>\n@out\n"); }
                trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);

                if ( $exec_ansible_cleanup ) {
                        plog("OK: ${baz} file(s) can be deleted");
                } else {
                        $exec_ansible_cleanup = 0 ;
                        plog("OK: ${exec_ansible_cleanup} has been skipped.");
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
                2>/dev/null';
        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `$cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }
        trimout();
        $count = scalar @out;
        if ( $count > 1 ) {
                plog("OK: ${count} file(s) is leftover at server, which was not matched and deleted.");
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
                plog("OK: ${count} file(s) is in /var/opt/ansible at server, which was not matched and deleted.");
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
                plog("OK: Found $uninstall_script\n");
        } else {
                plog("WARN: $uninstall_script not found. Skipping uninstall.\n");
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
sub stop_all_agents {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # run Stop all
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "stop 08 agent";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        $cmdexec = "/opt/IBM/ITM/bin/itmcmd agent -f stop all 2>&1";
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
sub uninstall_agents {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # run start lz agents
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "check if unistall.sh exists";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        # Check if uninstall.sh exists before running uninstall
        my $uninstall_script = "/opt/IBM/ITM/bin/uninstall.sh";
        if ( -e $uninstall_script ) {
                plog("OK: Found $uninstall_script\n");
        } else {
                plog("WARN: $uninstall_script not found. Skipping uninstall.\n");
                return;
        }

        ++$step;
        undef( @out );
        @out = ();$baz = '';
        $text = "uninstall all agents";
        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

        if ( $itmuser_found ) {
                $cmdexec = "sudo -u ${userid} /opt/IBM/ITM/bin/itmcmd agent start all 2>&1";
        } else {
                $cmdexec = "/opt/IBM/ITM/bin/uninstall.sh REMOVE EVERYTHING";
        }

        if ( $debug ) { plog("\n$cmdexec\n"); }
        @out = `ksh $cmdexec`;
        if ( $debug ) { plog("\nout=>\n@out\n"); }
        trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);

        plog("OK: ITM agent uninstalled: $baz");
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
                plog("OK: ${count} file(s) is in /opt/IBM/ITM/ at server, which was not matched and deleted.");
                foreach $line (@out) {
                        plog("${line}\n");
                }
        } else {
                plog("OK: ${count} file(s) in /opt/IBM/ITM/");
        }
}
sub remove_users() {
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        # remove itmuser and misc CACF users
        # ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

        # $cmdexec = "id ${userid} > /dev/null 2>&1 && echo 'user_found' || echo 'no user_found'"; # check if user is found
        # $cmdexec = "id -g ${userid} | xargs getent group | cut -d: -f1 2>&1"; # show tenent for user
        # $cmdexec = "getent passwd ${userid} | cut -d':' -f5 2>&1"; # show tenent for user
        # $cmdexec = "kill -9 -u ${userid} || true 2>&1"; # kill any process running with user
        # $cmdexec = "find /tmp /var/spool/cron /etc/sudoers.d /home /var/spool/cron /var/mail /var/spool/cups -user ${userid} || true"; #check count of files to be removed. max 3000 lines
        # $cmdexec = "find /tmp /var/spool/cron /etc/sudoers.d /home /var/spool/cron /var/mail /var/spool/cups -user ${userid} -delete 2>/dev/null || true"; # remove all for user        $cmdexec = "find /tmp /var/spool/cron /etc/sudoers.d /home /var/spool/cron /var/mail /var/spool/cups -user ${userid} || true"; # is all gone?

        @usernames = ('itmuser','dk017862');

        foreach ${userid} (@usernames) {

                ++$step;
                undef( @out );
                @out = ();$baz = '';
                $text = "check if ${userid} exists";
                $is_user_found = 0;
                plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

                $cmdexec = "id ${userid} > /dev/null 2>&1 && echo 'user_found' || echo 'no user_found'"; # check if user is found
                if ( $debug ) { plog("\n$cmdexec\n"); }
                @out = `$cmdexec`;
                if ( $debug ) { plog("\nout=>\n@out\n"); }
                trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);

                if ( $baz =~ /user_found/i ) {
                        $is_user_found = 1 ;
                        plog("OK: ${userid} found $baz");
                } else {
                        $is_user_found = 0;
                        $group = $baz;
                        plog("note: ${userid} is not found on server.");
                }

                if ( $is_user_found ) {

                        ++$step;
                        undef( @out );
                        @out = ();$baz = '';
                        $text = "kill users processes";
                        $is_user_found = 0 ;
                        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

                        $cmdexec = "kill -9 -u ${userid} || true 2>&1"; # kill any process running with user
                        if ( $debug ) { plog("\n$cmdexec\n"); }
                        @out = `$cmdexec`;
                        if ( $debug ) { plog("\nout=>\n@out\n"); }
                        trimout();$baz='';$baz = join(";", @out);$baz = trim($baz);
                        plog("OK: ${userid}'s processes killed.");

                        ++$step;
                        undef( @out );
                        @out = ();$baz = '';
                        $text = "check if ${userid} exists";
                        $exec_ansible_cleanup = 0 ;
                        plog(sprintf "\n%-13s - step:%02d - %-55s",get_date(),$step,$text);

                        $cmdexec = "find /tmp /var/spool/cron /etc/sudoers.d /home /var/spool/cron /var/mail /var/spool/cups -user ${userid} || true"; #check count of files to be removed. max 3000 lines
                        if ( $debug ) { plog("\n$cmdexec\n"); }
                        @out = `$cmdexec`;
                        if ( $debug ) { plog("\nout=>\n@out\n"); }
                        trimout();
                        $count = scalar @out;

                        if ( $count < 1000 ) {
                                $exec_ansible_cleanup = 1;
                                plog("OK: ${count} file(s) can be deleted");
                        } else {
                                $exec_ansible_cleanup = 0;
                                plog("warn: ${count} file(s) is over max 1000. Usually under. Skipping exec_ansible_cleanup");
                        }
                }
        }
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
if ( $continue ) { remove_users(); }
plog("\nTheEnd\n");