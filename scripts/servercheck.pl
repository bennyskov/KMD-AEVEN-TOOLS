#!C:/Perl64/bin/perl.exe -w
use strict;
use warnings;
use Sys::Hostname;
# Add Perl debugger module for VS Code integration
eval { require Devel::Debug::DBGp; Devel::Debug::DBGp->import(port => 9000); };

my($CI,$OSname,$OSversion,$OSservicePack,$IsVirtual,$Domain,$FQDN,$IPaddress,$SerialNumber,$ModelNumber,$DiskSpace,$RAM,$CPUtype,$CPUspeed,$CPUcount,$CPUcores,$CPUsockets);
my($output_file,$scriptname,$workdir,$cmdexec,$scriptn,$logfile,$text);
my($xml,@out,@tmp,@words,$foo,$bar);

# Set autoflush for better debug output
local $| = 1;

$scriptname         = $0;
$scriptname         =~ s/\\/\//g; # turn slash
@words              = split(/\//, $scriptname);
$scriptn            = $words[$#words];
$scriptn            =~ s/\.pl//g;
$workdir            = $0;
$workdir            =~ s/\/[^\/]*$//;  # Remove script filename from path
$logfile        	= $workdir.'/'.$scriptn.'.log';
unlink($logfile);
print("logfile=$logfile\n");

sub trim($) {
	my $string = shift;
	$string =~ s/\s+/ /g;	# remove all double whitespace
	$string =~ s/^\s+//g;   # remove beginning whitespaces
	$string =~ s/\s+$//g;	# remove trailing whitespaces
	$string =~ s/\r//g; 	# remove newlines
	$string =~ s/\n//g; 	# remove newlines
	$string =~ s/^"//g; 	# remove beginning double quotes
	$string =~ s/"$//g; 	# remove trailing double quotes
	return $string;
}
sub plog {
    $text = shift;
    open FILEOUT, ">> ${logfile}" or die "cant open and write to ${logfile}";
    print(FILEOUT $text);
    close FILEOUT;
    print("$text");
}
$foo = hostname;

@words = split(/\./, $foo);
$CI = $words[0];
$CI = trim($CI);
plog("CI=$CI\n");

$Domain = hostname;
$Domain =~ s/${CI}\.//g;
plog("Domain=$Domain\n");

$FQDN = hostname;
plog("FQDN=$FQDN\n");


$cmdexec = "hostname -I";
@out = `$cmdexec`;
plog("\n# IPaddress ------------------------------------------------------\n");
plog("\n@out\n");
foreach (@out) {
    chomp($_);$_ = trim($_);
    if ( grep(/^$/i,$_) ) { next; }
    $IPaddress = $_;
    plog("IPaddress=$IPaddress\n");
}

$cmdexec = "cat /sys/class/dmi/id/product_name";
@out = `$cmdexec`;
plog("\n# product_name ------------------------------------------------------\n");
plog("\n@out\n");
foreach (@out) {
    chomp($_);$_ = trim($_);
    if ( grep(/^$/i,$_) ) { next; }
    $ModelNumber = $_;
    plog("ModelNumber=$ModelNumber\n");
}

plog("\n# get diskspace ------------------------------------------------------\n");
$cmdexec = "df -B1 --output=size | awk 'NR>1 {sum += \$1} END {printf \"%.0f\", sum}' | numfmt --to=iec --suffix=B --format='%.0f'";
plog("\n$cmdexec\n");
@out = `$cmdexec`;
plog("\n@out\n");
foreach (@out) {
    chomp($_);$_ = trim($_);
    if ( grep(/^$/i,$_) ) { next; }
    $DiskSpace = $_;
    plog("DiskSpace=$DiskSpace\n");
}

plog("\n# get RAM physical memory ------------------------------------------------------\n");
$cmdexec = "free -b | grep Mem: | awk '{print \$2}' | numfmt --to=iec --suffix=B --format='%.0f'";
plog("\n$cmdexec\n");
@out = `$cmdexec`;
plog("\n@out\n");
foreach (@out) {
    chomp($_);$_ = trim($_);
    if ( grep(/^$/i,$_) ) { next; }
    $RAM = $_;
    plog("RAM=$RAM\n");
}

$cmdexec = "hostnamectl";
@out = `$cmdexec`;
plog("\n# hostnamectl ------------------------------------------------------\n");
plog("\n@out\n");
foreach (@out) {
    chomp($_);$_ = trim($_);
    if ( grep(/^$/i,$_) ) { next; }
    @words = split(/:/, $_);
    plog("line=$_\n");
    $foo = $words[-1];
    if ( grep(/^Operating System/i,$_) ) {
        $OSname = trim($foo);
        $OSname =~ s/Enterprise//g;
        $OSname =~ s/Standard//g;
        $OSname =~ s/\(\)//g;

        # remove build name
        @words = split(/\s/, $OSname);
        $foo = $words[-1];
        $OSname =~ s/${foo}//g;
        $OSname = trim($OSname);
        plog("OSname=$OSname\n");

        $OSversion = trim($_);
        plog("OSversion=$OSversion\n");

    }
    if ( grep(/^Machine ID/i,$_) ) {
        $SerialNumber = trim($foo);
        plog("SerialNumber=$SerialNumber\n");
    }
    if ( grep(/^Kernel/i,$_) ) {
        $OSservicePack = trim($foo);
        plog("OSservicePack=$OSservicePack\n");
    }
}

$cmdexec = "lscpu";
@out = `$cmdexec`;
plog("\n# lscpu ------------------------------------------------------\n");
plog("\n@out\n");
foreach (@out) {
    chomp($_);$_ = trim($_);
    if ( grep(/^$/i,$_) ) { next; }
    @words = split(/:/, $_);
    plog("line=$_\n");
    $foo = $words[-1];
    if ( grep(/^Hypervisor vendor/i,$_) ) {
        if ( grep(/VMware/i,$_) ) {
            $IsVirtual = "True";
            plog("IsVirtual=$IsVirtual\n");
        }
    }
    if ( grep(/^Model name/i,$_) ) {
        $CPUtype = trim($foo);
        plog("CPUtype=$CPUtype\n");
    }
    if ( grep(/^CPU\(s\): /i,$_) ) {
        $CPUcount = trim($foo);
        plog("CPUcount=$CPUcount\n");
    }
    if ( grep(/^Socket\(s\): /i,$_) ) {
        $CPUsockets = trim($foo);
        plog("CPUsockets=$CPUsockets\n");
        $CPUcores = $CPUcores * $CPUsockets; # Sockets is received after cores
        plog("CPUcores total=$CPUcores\n");

    }
    if ( grep(/^Core\(s\) /i,$_) ) {
        $CPUcores = trim($foo);
        plog("CPUcores pr sockets=$CPUcores\n");
    }

    if ( grep(/^CPU MHz: /i,$_) ) {
        $CPUspeed = trim($foo);
        # $CPUspeed = $CPUspeed / 1000;
        $CPUspeed = sprintf("%.0f", $CPUspeed);
        plog("CPUspeed=$CPUspeed\n");
    }
}


$cmdexec = "cat /etc/resolv.conf";
@out = `$cmdexec`;
plog("\n# cat /etc/resolv.conf ------------------------------------------------------\n");
plog("\n@out\n");

$cmdexec = "lsblk -io MODEL,KNAME,SIZE,TYPE";
@out = `$cmdexec`;
plog("\n# lsblk -io MODEL,KNAME,SIZE,TYPE ------------------------------------------------------\n");
plog("\n@out\n");

$cmdexec = "df -h --total";
@out = `$cmdexec`;
plog("\n# df -h --total ------------------------------------------------------\n");
plog("\n@out\n");

$cmdexec = "systemd-detect-virt";
@out = `$cmdexec`;
plog("\n# systemd-detect-virt ------------------------------------------------------\n");
plog("\n@out\n");


$xml = '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
$xml .= '<SystemInformation>' . "\n";
$xml .= "\t<CI>$CI</CI>\n";                                         # dmsvrCI
$xml .= "\t<OSname>$OSname</OSname>\n";                             # dmsvrOSname
$xml .= "\t<OSversion>$OSversion</OSversion>\n";                    # dmsvrOSversion     - kernal
$xml .= "\t<OSservicePack>$OSservicePack</OSservicePack>\n";        # dmsvrOSservicePack
$xml .= "\t<IsVirtual>$IsVirtual</IsVirtual>\n";                    # dmsvrIsVirtual
$xml .= "\t<Domain>$Domain</Domain>\n";                             # dmsvrDomain
$xml .= "\t<FQDN>$FQDN</FQDN>\n";                                   # dmsvrFQDN
$xml .= "\t<IPaddress>$IPaddress</IPaddress>\n";                    # dmsvrIPaddress
$xml .= "\t<SerialNumber>$SerialNumber</SerialNumber>\n";           # dmsvrSerialNumber
$xml .= "\t<ModelNumber>$ModelNumber</ModelNumber>\n";              # dmsvrModelNumber
$xml .= "\t<DiskSpace>$DiskSpace</DiskSpace>\n";                    # dmsvrDiskSpace
$xml .= "\t<RAM>$RAM</RAM>\n";                                      # dmsvrRAM
$xml .= "\t<CPUtype>$CPUtype</CPUtype>\n";                          # dmsvrCPUtype Model name:
$xml .= "\t<CPUspeed>$CPUspeed</CPUspeed>\n";                       # dmsvrCPUspeed
$xml .= "\t<CPUcount>$CPUcount</CPUcount>\n";                       # dmsvrCPUcount
$xml .= "\t<CPUcores>$CPUcores</CPUcores>\n";                       # dmsvrCPUcores
$xml .= "\t<CPUsockets>$CPUsockets</CPUsockets>\n";                 # dmsvrCPUsockets
$xml .= "</SystemInformation>\n";

# Save XML output to a file
$scriptname = $0;
$scriptname =~ s/\.pl$//;  # Remove .pl extension from script name
$output_file = "${scriptname}_os.xml";
unlink($output_file);
open(my $fh, '>', $output_file) or die "Cannot open file '$output_file' for writing: $!";
print $fh $xml;
plog("System information saved to '$output_file'.\n");
close($fh);