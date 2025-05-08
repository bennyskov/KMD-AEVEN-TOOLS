#!/bin/ksh
#
# ****************************************************************************
# * Licensed Materials - Property of IBM
# *
# * 5724-C04
# *
# * Copyright IBM Corporation 2007-2015 All Rights Reserved
# ****************************************************************************
#
# Script removes installed products
# Return codes:
#   0 = OK
#   1 = no products to delete
#   2 = failed
#   3 = failed due to running processes found
#

function Err_report {
  #-------------------------------------------------------------------#IV76877
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV76877
                                                                      #IV76877
  case $1 in
    #$NLS-E$ "$PROGNAME warning: $2,continuing ..."
    warn) print -u2 "$(nls_replace 'KCI0200I' $PROGNAME \"$2\")"
          sleep 2
          return
          ;;
    #$NLS-E$ "$PROGNAME failure: $2."
    fail) print -u2 "$PROGNAME $(nls_replace 'KCI0201I'): $2";         #214546
          clean_up 2
          ;;
    info) print -u2 "$PROGNAME        : $2";                           #214546
          return
          ;;
  esac
}

function Use_report {
  #-------------------------------------------------------------------#IV76877
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV76877
                                                                      #IV76877
  print -u2 "$PROGNAME"
  print -u2 "$PROGNAME [-f] [-i] [-h install_dir] product platformCode"
  print -u2 "$PROGNAME [-h install_dir] REMOVE EVERYTHING"
  #$NLS-E$ "\t-f Force delete, suppress confirmation messages and prompts."
  print -u2 "\t-f $(nls_replace 'KCI0202I')"
  #$NLS-E$ "\t-i Ignore all running processes."
  print -u2 "\t-i $(nls_replace 'KCI0203I')"
  #$NLS-E$ "\t'product' A two-letter code for the product to be uninstalled."
  print -u2 "\t'product' $(nls_replace 'KCI0204I')"
  #$NLS-E$ "\t'platformCode' Platform code (such as aix513, sol286, hp11,
  #         etc.) for the product."
  print -u2 "\t'platformCode' $(nls_replace 'KCI0205I')"
  #$NLS-E$ "\tREMOVE EVERYTHING are special keywords."
  print -u2 "\tREMOVE EVERYTHING $(nls_replace 'KCI1266I')"
  #$NLS-E$ "\t WARNING, specifying these keywords will remove the entire
  #         contents of the ITM home directory without further prompting
  #         or confirmation."
  print -u2 "\t\t$(nls_replace 'KCI1267I')"
  exit 2
}

function get_desc {
  #-------------------------------------------------------------------#IV76877
  # Get product description                                           #IV76877
  #-------------------------------------------------------------------#IV76877
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV76877
                                                                      #IV76877
  pc=$1
  verFiles=$(ls ${CANDLEHOME}/registry/${pc}+(ai|hp|so|l)*.ver);      #IV27849
  desc=$(grep "^desc" $(print $verFiles | head -1) |
         cut -d"=" -f2 | sed 's/^ //g');                              #IV27849
  [[ -z "$desc" ]] && desc=$(grep "^$pc" $CANDLEHOME/registry/proddsc.tbl |
                             head -1 | cut -f2 -d"|")
  [[ -z "$desc" ]] && desc=$pc
  print $desc
}

function uninstall_product {
  (
  #-------------------------------------------------------------------#IV76877
  # Uninstall a product and its prereqs                               #IV76877
  #                                                                   #IV76877
  # This function is called recursively and we have to be sure the    #IV76877
  # variables are used locally, but for SLES10 the variables 'pc',    #IV76877
  # 'platform' are not local and are rewritten when the function is   #IV76877
  # called recursively.                                               #IV76877
  # The function is executed in its own shell by placing parenthesis  #IV76877
  # within the function brackets.                                     #IV76877
  # The function gets its own copy of the environment when it is      #IV76877
  # called and any changes are not reflected in the calling script    #IV76877
  # which is its own function.                                        #IV76877
  #-------------------------------------------------------------------#IV76877
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV76877
                                                                      #IV76877
  typeset pc=$1
  typeset platform=$2
  # skip these components when checking for shared prereq
  typeset skipComp=$3
  typeset sharedPrereq=""

  [[ -z "$skipComp" ]] && skipComp=$pc$platform

  # Nuke CandleHome!
  if [[ "$pc" = "REMOVE" && "$platform" = "EVERYTHING" ]]; then
    #$NLS-E$ "Removing ITM home: $CANDLEHOME\n"
    print "$(nls_replace 'KCI0206I'): $CANDLEHOME\n"
    cd $originalDir
    cmdHome=$(cd $(dirname $0) ; dirname $(pwd) )
    if [[ $(pwd) = "$CANDLEHOME/bin" || "$CANDLEHOME" = "$cmdHome" ]]; then
      #$NLS-E$ "$CANDLEHOME/bin may have to be removed manually after this
      #         script completes"
      Err_report warn "$(nls_replace 'KCI0207I' $CANDLEHOME/bin )"
    fi
    #$NLS-E$ Err_report warn "Purging $CANDLEHOME"
    Err_report warn "$(nls_replace 'KCI0208I' $CANDLEHOME)"

    [[ -f $CANDLEHOME/registry/AutoStart ]] && remove_autostart

    hp_forcewait
    hp_dld_sl_conf;                                                   #IV76877

    rm -rf $CANDLEHOME
    [[ -n "${CANDLEDATA}" ]] && rm -rf "${CANDLEDATA}";               #IV67523

    remove_links
    clean_up
  fi

  # Not installed if there's no VER file
  cd $regDir
  vFile=$pc$platform.ver
  #$NLS-E$ "product \"$pc\" for platform \"$platform\" not installed in
  #         $CANDLEHOME"
  if [[ ! -f $vFile ]]; then
    Err_report warn "$(nls_replace 'KCI0209I' "$pc" "$platform" "$CANDLEHOME")"
    return
  fi

  # Remove Watchdog default configuration files and pas.dat
  if [[ "$pc" = @(ux|lz) ]]; then
    rm -f $CANDLEHOME/config/CAP/k"$pc"_default.xml 2> /dev/null
    rm -f $CANDLEHOME/config/CAP/kca_default.xml 2> /dev/null
    rm -f $CANDLEHOME/config/CAP/pas.dat 2> /dev/null
    rm -f $CANDLEHOME/config/CAP/kwgcap.xsd 2> /dev/null
  else
    rm -f $CANDLEHOME/config/CAP/k"$pc"_default.xml 2> /dev/null
  fi
                                                                      #IV67523
  #-------------------------------------------------------------------#IV67523
  # Clean up CANDLEDATA-specific stuff.                               #IV67523
  #-------------------------------------------------------------------#IV67523
  if [[ -n "${CANDLEDATA}" ]]; then                                   #IV67523
    if [[ "$pc" = @(ux|lz) ]]; then                                   #IV67523
      unlink "${CANDLEHOME}/kca" 2> /dev/null;                        #IV67523
      rm -rf "${CANDLEDATA}/kca" 2> /dev/null;                        #IV67523
    fi                                                                #IV67523
    rm -rf "${CANDLEDATA}/ATTRLIB/${pc}" 2> /dev/null;                #213940
    rm -rf "${CANDLEDATA}/EIFLIB/${pc}" 2> /dev/null;                 #213940
    rm -rf "${CANDLEDATA}/hist/${pc}" 2> /dev/null;                   #IV67523
    rm -rf "${CANDLEDATA}/psit/${pc}" 2> /dev/null;                   #IV67523
  fi                                                                  #IV67523
                                                                      #IV67523
  #-------------------------------------------------------------------#IV67523
  # Clean up agent application exits in CANDLEHOME/bin.               #IV67523
  #-------------------------------------------------------------------#IV67523
  rm -rf "${CANDLEHOME}/bin/"*"_${pc}.sh" 2> /dev/null;               #IV67523

  # Get each prereq for the product (except ci and jr)
  prereqs=$(grep "^preReq" $vFile | egrep -ve " ci| gs| jr| ui| none" |
            cut -f1 -d"|"|cut -f3 -d " ")

  # remove as with TEMS
  if [[ "$pc" = "ms" && -f "$CANDLEHOME/registry/as$platform.ver" ]]; then
    asdesc=$(get_desc as)
    msdesc=$(get_desc ms)
    #$NLS-E$ $asdesc will be removed with $msdesc
    nls_replace 'KCI1361I' "$asdesc" "$msdesc"
    prereqs="as$platform $prereqs"
  fi

  # Delete prereqs
  for pre in $(print $prereqs) ; do
    prePC=$(print $pre|cut -c1-2)
    preArch=${pre#$prePC}
    # check if this prereq component are shared as prereq by other component
    sharedPrereq=""
    for comp in $(ls *.ver | egrep -ve "^ci|^jr|^ui|^gs" ) ; do
      comp=${comp%.ver}
      skip=$(print $skipComp | grep "$comp")
      if [[ -n "$skip" ]]; then
        # this component should be skipped,
        # because it is going to be removed
        continue
      fi
      tmpSharedPrereq=$(grep " = $pre" ${comp}.ver)
      [[ -n "$tmpSharedPrereq" ]] && sharedPrereq="$sharedPrereq $comp"
    done
    if [[ -z "$sharedPrereq" ]]; then
      # add this prereq component to the skip list,
      # for it is going to be removed
      have=$(print $skipComp | grep  "^$prePC$preArch")
      [[ -z "$have" ]] && skipComp="$skipComp $prePC$preArch"
      uninstall_product $prePC $preArch "$skipComp"
    fi
  done

  # Remove the product
  # OS agent is slow to down go, wait for it
  if [[ "$pc" = "ux" ]]; then
    hp_forcewait
  fi

  remove_product $pc $platform
  update_autostart $pc

  # Synchronize/remove 'localconfig' directories for product(s) just removed.
  # Keep stderr printing to the screen to catch possible cricital errors
  $CANDLEHOME/bin/syncLocalConfDirs.sh >/dev/null
  )
}

function set_bootMode {
  #-------------------------------------------------------------------#IV97694
  # Determine whether this system will be booted as systemd or initd  #IV97694
  #-------------------------------------------------------------------#IV97694
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV97694
                                                                      #IV97694
  # Determine the Linux distribution                                  #IV97694
  OS_dist=$(grep '^ID=' /etc/os-release 2> /dev/null | cut -d= -f2 |
            cut -d\" -f2);                                            #IV97694
  # OS_dist from /etc/os-release must be fixed to be the same as      #IV97694
  # linux_dist existing strings in use                                #IV97694
  # os-release: redhat sles ubuntu                                    #IV97694
  # linux_dist: RedHat SUSE Ubuntu                                    #IV97694
  case $OS_dist in                                                    #IV97694
    ubuntu) linux_dist="Ubuntu";                                      #IV97694
            ;;                                                        #IV97694
    rhel)   linux_dist="RedHat";                                      #IV97694
            ;;                                                        #IV97694
    sles)   linux_dist="SUSE";                                        #IV97694
            ;;                                                        #IV97694
    "")     linux_dist="";                                            #IV97694
            ;;                                                        #IV97694
    *)      linux_dist="RedHat";     # Pretend unknown is RedHat      #IV97694
            ;;                                                        #IV97694
  esac                                                                #IV97694
  # pkg-config may not be installed on Ubuntu even when systemd used  #IV97694
  pkg-config systemd --exists > /dev/null 2>&1;                       #IV97694
  if [[ $? -eq 0 ]]; then                                             #IV97694
    boot_mode=systemd;                                                #IV97694
    pkgConfigOPT="systemd --variable=systemdsystemunitdir"            #IV97694
    sdBaseDir="$(pkg-config $pkgConfigOPT 2> /dev/null)";             #IV97694
  else                                                                #IV97694
    boot_mode=initd;                                                  #IV97694
    if [[ "$linux_dist" = Ubuntu ]]; then                             #IV97694
      # Need the systemctl command in the test for Ubuntu             #IV97694
      systemctl --now > /dev/null 2>&1;                               #IV97694
      if [[ $? -eq 0 ]]; then                                         #IV97694
        boot_mode=systemd;                                            #IV97694
        sdBaseDir="/lib/systemd/system";                              #IV97694
      fi                                                              #IV97694
    fi                                                                #IV97694
  fi                                                                  #IV97694
  if [[ "$boot_mode" != systemd ]]; then                              #IV97694
    sdBaseDir="";                                                     #IV97694
    sdBaseName="";                                                    #IV97694
    sdUnits="";                                                       #IV97694
  fi                                                                  #IV97694
}

function update_autostart {
  #-------------------------------------------------------------------#IV76877
  # Delete of agent start/stop records from boot script.              #IV76877
  #-------------------------------------------------------------------#IV76877
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV76877
                                                                      #IV76877
  if [[ "$(whoami)" = "root" ]]; then
    if [[ -f $CANDLEHOME/registry/AutoStart ]]; then
      editString1="start $pc"
      editString2="stop $pc"
      filenum=$(cat $CANDLEHOME/registry/AutoStart)

      case "$os" in
        li|lx|lp|ls)
          rcFile="/etc/init.d/ITMAgents$filenum"
          ;;
        so)
          rcFile="/etc/init.d/ITMAgents$filenum"
          ;;
        hp)
          rcFile="/sbin/init.d/ITMAgents$filenum"
          ;;
        ai)
          rcFile="/etc/rc.itm$filenum"
          ;;
      esac

      # construct a sed script for deleting lines                     #214546
      editString="";                                                  #214546
      if [[ -n "$(grep "$editString1" $rcFile 2>/dev/null)" ]]; then  #214546
        editString="/${editString1}/d;";                              #214546
      fi                                                              #214546
      if [[ -n "$(grep "$editString2" $rcFile 2>/dev/null)" ]]; then  #214546
        editString="${editString}/${editString2}/d";                  #214546
      fi                                                              #214546
      if [[ -n "${editString}" ]]; then                               #214546
        update_rcFile
        if [[ $checkit -ne 0 ]]; then
          #$NLS-E$ Delete of agent start/stop records failed.
          Err_report fail "$(nls_replace 'KCI1168E')"
        else
          #$NLS-E$ Delete of agent start/stop records successful.
          Err_report info "$(nls_replace 'KCI1169I')"
        fi
      fi

      # Update systemd target unit and remove systemd service units   #IV97694
      if [[ "$boot_mode" = systemd ]]; then                           #IV97694
        sdBaseName=ITMAgents$filenum;                                 #IV97694
        sdUnits=$(print $(cd $sdBaseDir;ls $sdBaseName.* 2>/dev/null));#IV97694
        sdTargetBase=$sdBaseName.target;                              #IV97694
        sdTargetFile=$sdBaseDir/$sdTargetBase;                        #IV97694
        sdEditString1="RequiredBy=";                                  #IV97694
        for sdUnit in $sdUnits ; do                                   #IV97694
          if [[ "$sdUnit" = @($sdBaseName.$pc.*service) ]]; then      #IV97694
            # Disable unit                                            #IV97694
            systemctl disable $sdUnit;                                #IV97694
            # Delete product [instance] service file                  #IV97694
            rm -rf $sdBaseDir/${sdUnit};                              #IV97694
            # Delete product [instance] entry from target file        #IV97694
            editString="/${sdEditString1}${sdUnit}/d;";               #IV97694
            update_sdTargetFile;                                      #IV97694
            if [[ $checkit -ne 0 ]]; then                             #IV97694
              #$NLS-E$ Delete of agent RequiredBy record failed.      #IV97694
              Err_report fail "$(nls_replace 'KCI1180E')";            #IV97694
            else                                                      #IV97694
              #$NLS-E$ Delete of agent RequiredBy record successful.  #IV97694
              Err_report info "$(nls_replace 'KCI1181I')";            #IV97694
            fi                                                        #IV97694
          fi                                                          #IV97694
        done                                                          #IV97694
      fi                                                              #IV97694
    fi
  fi
}

function update_rcFile {
  # Update the boot script.                                           #IV76877
  #-------------------------------------------------------------------#IV76877
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV76877
                                                                      #IV76877
  SEDscript=$CANDLETMP/SEDscript
  print "$editString" > $SEDscript
  checkit=0
  tmpRcFile=$CANDLETMP/rcFile.new.$$
  cp -f $rcFile $tmpRcFile
  checkit=$?
  if [[ $checkit -eq 0 ]]; then
    sed -f $SEDscript $tmpRcFile > $rcFile
    checkit=$?
    if [[ $checkit -ne 0 ]]; then
      cp -f $tmpRcFile $rcFile
    fi
  fi
  rm -f $tmpRcFile
  rm -f $SEDscript
}

function update_sdTargetFile {
  #-------------------------------------------------------------------#IV97694
  # Update the systemd target file.                                   #IV97694
  #-------------------------------------------------------------------#IV97694
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV97694
                                                                      #IV97694
  SEDscript=$CANDLETMP/SEDscript;                                     #IV97694
  print "$editString" > $SEDscript;                                   #IV97694
  checkit=0;                                                          #IV97694
  tmpSdFile=$CANDLETMP/sdTargetFile.new.$$;                           #IV97694
  cp -f $sdTargetFile $tmpSdFile;                                     #IV97694
  checkit=$?;                                                         #IV97694
  if [[ $checkit -eq 0 ]]; then                                       #IV97694
    sed -f $SEDscript $tmpSdFile > $sdTargetFile;                     #IV97694
    checkit=$?;                                                       #IV97694
    if [[ $checkit -ne 0 ]]; then                                     #IV97694
      # Disable target unit                                           #IV97694
      systemctl disable $sdTargetBase;                                #IV97694
      # Update target unit file                                       #IV97694
      cp -f $tmpSdFile $sdTargetFile;                                 #IV97694
      # Enable target unit                                            #IV97694
      systemctl enable $sdTargetBase;                                 #IV97694
    fi                                                                #IV97694
  fi                                                                  #IV97694
  rm -f $tmpSdFile;                                                   #IV97694
  rm -f $SEDscript;                                                   #IV97694
}

function remove_product {
  #-------------------------------------------------------------------#IV76877
  # Remove a product or a prereq (component)                          #IV76877
  #-------------------------------------------------------------------#IV76877
  eval $(itmsh_trace_func "${0}" "${@}");  # enable function tracing  #IV76877
                                                                      #IV76877
  product=$1
  binarch=$2
  name=$(get_desc $product)
  typeset regdir="${CANDLEHOME}/registry";                            #IZ92223
  typeset configdir="${CANDLEHOME}/config";
  typeset propdir="$CANDLEHOME/properties/version";
  typeset vfile="${regdir}/${product}${binarch}.ver";                 #IZ92223
  typeset varch;                           # arch from ver file       #IZ92223
  typeset varchdir;                        # CANDLEHOME/varch/product #IZ92223
  typeset rm_varch;                        # 1=rm needed,0=skip       #IZ92223
  typeset rm_binarch;                      # 1=rm needed,0=skip       #IZ92223
                                                                      #IZ92223
  #-------------------------------------------------------------------#IZ92223
  # If there's a ver file, do two things:                             #IZ92223
  #                                                                   #IZ92223
  # a) Remove the directory that corresponds to each runArch that is  #IZ92223
  #    defined in the ver file. But ONLY do that if that runArch is   #IZ92223
  #    not represented by its own ver file.                           #IZ92223
  # b) Remove the ver file itself.                                    #IZ92223
  #-------------------------------------------------------------------#IZ92223
  # For the general case, xx<arch>.ver has a one-to-one relationship  #IZ92223
  # with its directory CANDLEHOME/<arch>/xx.                          #IZ92223
  # However, for at least one case (kf=Eclipse Help Server), this is  #IZ92223
  # not true. The kf component can have multiple directories for a    #IZ92223
  # given kf<arch>.ver file.                                          #IZ92223
  #                                                                   #IZ92223
  # For example, when package kfaix533 is installed, files are        #IZ92223
  # created in CANDLEHOME/aix533/kf.                                  #IZ92223
  # But, other components like the TEPS plus any TEPS application     #IZ92223
  # support create files in CANDLEHOME/aix536/kf. The runArch scan    #IZ92223
  # is designed to address this case.                                 #IZ92223
  # Our example kfaix533.ver has the following runArch entries:       #IZ92223
  #                                                                   #IZ92223
  #    a) runArch = aix533                                            #IZ92223
  #    b) runArch = aix536                                            #IZ92223
  #    c) runArch = open                                              #IZ92223
  #                                                                   #IZ92223
  # As we pass through these entries, we do the following:            #IZ92223
  #                                                                   #IZ92223
  #    a) CANDLEHOME/aix533/kf exists because it was created when the #IZ92223
  #       kfaix533 component was installed. It is the same  #IZ92223  #IZ92223
  #       architecture requested to be uninstalled, so we remove it.  #IZ92223
  #    b) On a 32-bit system, CANDLEHOME/aix536/kf does not exist, so #IZ92223
  #       we ignore the entry. On a 64-bit system, this directory is  #IZ92223
  #       populated by the TEPS and by any TEPS application support.  #IZ92223
  #       If there is no ver file that corresponds to (owns) this     #IZ92223
  #       architecture, we remove it as part of the request.          #IZ92223
  #    c) There is never any CANDLEHOME/open/kf, so we ignore this    #IZ92223
  #       entry.                                                      #IZ92223
  #                                                                   #IZ92223
  # While the kf product is the only one known to be affect in this   #IZ92223
  # manner, the code below is written to be generic.                  #IZ92223
  #-------------------------------------------------------------------#IZ92223
  rm_binarch=1;                         # assume rm needed later      #IZ92223
  if [[ -f ${vfile} ]]; then            # if we have a ver file...    #IZ92223
    grep "^runArch =" ${vfile} | cut -f3 -d" " | while read varch; do #IZ92223
      varchdir=${CANDLEHOME}/${varch}/${product};                     #IZ92223
      if [[ -d ${varchdir} ]]; then     # runArch directory exist?    #IZ92223
        rm_varch=1;                     # yes, assume rm is needed    #IZ92223
        if [[ "${varch}" = "${binarch}" ]]; then                      #IZ92223
          rm_binarch=0;                 # rm'ing now, skip later      #IZ92223
        elif [[ -f ${regdir}/${product}${varch}.ver ]]; then          #IZ92223
          rm_varch=0;                   # not ours to rm              #IZ92223
        fi                              # (elif(-e...))               #IZ92223
        if [[ ${rm_varch} -eq 1 ]]; then                              #IZ92223
          rm -rf ${varchdir} 2> /dev/null;                            #IZ92223
          if [[ $? -ne 0 ]]; then                                     #IZ92223
            #$NLS-E$ "unable to remove directory for $product"        #IZ92223
            Err_report warn "$(nls_replace 'KCI0211I' $product)";     #IZ92223
          fi                            # (if($?!=0))                 #IZ92223
          rm -rf ${varchdir}_IM 2> /dev/null;
        fi                               # (if($rm_varch==1)          #IZ92223
      fi                                  # (if(-e $varchdir)         #IZ92223
    done;                                  # (while(read varch))      #IZ92223
                                                                      #IZ92223
    rm ${regdir}/${product}${binarch}.ver 2> /dev/null;               #IZ92223
    if [[ $? -ne 0 ]]; then                                           #IZ92223
      #$NLS-E$ "unable to remove version file for $product"           #IZ92223
      Err_report warn "$(nls_replace 'KCI0212I' $product)";           #IZ92223
    fi                                     # (if($?!=0))              #IZ92223
  fi                                        # (if(-f $vfile))         #IZ92223
                                                                      #IZ92223
  #-------------------------------------------------------------------#IZ92223
  # If we didn't remove the binarch directory as part of ver file     #IZ92223
  # processing above, then make sure it is gone here. This code comes #IZ92223
  # into play if we were asked to remove something that didn't have a #IZ92223
  # ver file to start with or if the ver file did not reference the   #IZ92223
  # requested platform.                                               #IZ92223
  #-------------------------------------------------------------------#IZ92223
  if [[ ${rm_binarch} -eq 1 ]]; then                                  #IZ92223
    rm -rf ${CANDLEHOME}/${binarch}/${product} 2> /dev/null;          #IZ92223
    if [[ $? -ne 0 ]]; then                                           #IZ92223
      #$NLS-E$ "unable to remove directory for $product"              #IZ92223
      Err_report warn "$(nls_replace 'KCI0211I' $product)";           #IZ92223
    fi                                     # (if($?!=0))              #IZ92223
    rm -rf ${CANDLEHOME}/${binarch}/${product}_IM 2> /dev/null;
  fi                                        # (if($rm_binarch==1))    #IZ92223
                                                                      #IZ92223
  #-------------------------------------------------------------------#IZ92223
  # TEP/TEPS support files reside in the corresponding TEP/TEPS       #IZ92223
  # directory. So, if we just removed a TEP/TEPS component, we also   #IZ92223
  # removed those support files. So, we need to remove the ver files  #IZ92223
  # that go with them.                                                #IZ92223
  #                                                                   #IZ92223
  # This logic does not apply to TEMS support files. Those reside in  #IZ92223
  # CANDLEHOME/tables/cicatrsq, which means they are not removed when #IZ92223
  # the TEMS component is removed. Since the TEMS support files exist #IZ92223
  # after the TEMS is removed, we don't want to remove the ver files  #IZ92223
  # that go with them.                                                #IZ92223
  #-------------------------------------------------------------------#IZ92223
  case ${product} in                                                  #IZ92223
    cj)                                    # TEP desktop client       #IZ92223
      find ${regdir} -name "??tpd.ver" -exec rm {} 2> /dev/null \; ;  #IZ92223
    ;;                                     # (cj)                     #IZ92223
    cq)                                    # TEPS                     #IZ92223
      find ${regdir} -name "??tps.ver" -exec rm {} 2> /dev/null \; ;  #IZ92223
    ;;                                     # (cq)                     #IZ92223
    cw)                                    # TEP browser client       #IZ92223
      find ${regdir} -name "??tpw.ver" -exec rm {} 2> /dev/null \; ;  #IZ92223
    ;;                                     # (cw)                     #IZ92223
    pa)                                    # TEP perf extensions      #IZ92223
      find ${regdir} -name "??tpa.ver" -exec rm {} 2> /dev/null \; ;  #IZ92223
    ;;                                     # (pa)                     #IZ92223
  esac;                                     # (case($product))        #IZ92223

  #-------------------------------------------------------------------#IZ85668
  # If the product is completely removed, then also remove all of its #IZ85668
  # configuration files:                                              #IZ85668
  #    CANDLEHOME/config/xx.*    (ini, ini.bak, config, etc.)         #IZ85668
  #    CANDLEHOME/config/xx_*.config                                  #IZ85668
  #    CANDLEHOME/config/xx_dd*  (xml, properties, etc.)              #IZ85668
  #    CANDLEHOME/config/kxx_config.ini                               #IZ85668
  #    CANDLEHOME/config/.ConfigData/kxxenv                           #IZ85668
  #    CANDLEHOME/config/CAP/kxx_default.ini                          #IZ85668
  #    CANDLEHOME/config/<hostname>_xx.cfg     (instance)             #IZ85668
  #    CANDLEHOME/config/<hostname>_xx_*.cfg   (instance)             #IZ85668
  #    CANDLEHOME/config/<hostname>.*_xx_*.cfg (instance)             #IZ85668
  #                                                                   #IZ85668
  # Note: Without removing these, a reinstall of the same product can #IZ85668
  # pick up old configuration values.                                 #IZ85668
  #-------------------------------------------------------------------#IZ85668
  ls ${regdir}/${product}+(ai|hp|so|l)*.ver > /dev/null 2>&1          #IV27849
  rc=$?
  if [[ $rc -ne 0 && -d ${configdir} ]]; then
    rm -f ${configdir}/${product}.* 2> /dev/null
    rm -f ${configdir}/${product}_*.config 2> /dev/null               #IZ85668
    rm -f ${configdir}/${product}_dd* 2> /dev/null
    rm -f ${configdir}/k${product}_config.ini 2> /dev/null
    rm -f ${configdir}/.ConfigData/k${product}env 2> /dev/null
    rm -f ${configdir}/CAP/k${product}_default.xml 2> /dev/null
                                                                      #IZ85668
    MChost=$(hostname | cut -d. -f1);      # mixed case host name     #IZ85668
    typeset -l LChost="${MChost}";         # lower case host name     #IZ85668
    typeset -u UChost="${MChost}";         # upper case host name     #IZ85668
    for host in "${MChost}" "${LChost}" "${UChost}"; do               #IZ85668
      rm -f ${configdir}/${host}_${product}.cfg 2> /dev/null;         #IZ85668
      rm -f ${configdir}/${host}_${product}_*.cfg 2> /dev/null;       #IZ85668
      rm -f ${configdir}/${host}.*_${product}_*.cfg 2> /dev/null;     #IZ85668
    done;                                                             #IZ85668
  fi

  # remove swg tagging files
  if [[ -d "${propdir}/" ]]; then
    if [[ $rc -ne 0 ]]; then
      # product removed, just remove all related swg tagging files
      rm -f ${propdir}/k${product}.* > /dev/null 2>&1
    else
      # get base architecture code ex. li from li6263 binarch
      baseArch=${binarch%%[0-9]*}
      ls ${regdir}/$product$baseArch*.ver 2> /dev/null |
        egrep "$product$baseArch[0-0]+\.ver" > /dev/null 2>&1
      if [[ $? -ne 0 ]]; then
        for file in $(ls ${propdir}/k${product}.${baseArch}* 2>/dev/null |
            egrep "k$product\.$baseArch[0-9]+\..*"); do
          rm -rf $file > /dev/null 2>&1
        done
      else
        rm -f ${propdir}/k${product}.${binarch}* > /dev/null 2>&1
      fi
    fi
  fi

  # append "|" with $binarch to avoid hp11 & hp116 return together.   #55109
  platformDesc=$(grep "^$binarch|" $regDir/archdsc.tbl|cut -f2 -d"|")

  #$NLS-E$ "$name for platform $platformDesc removed from $CANDLEHOME.
  nls_replace 'KCI0213I' "$name" "$platformDesc" "$CANDLEHOME"

  # Log the deletion also
  logfile=$CANDLEHOME/logs/candle_installation.log
  print "$PROGNAME  : $(date)" >> $logfile
  longMsg="$name for platform $platformDesc removed from $CANDLEHOME"
  print "$PROGNAME  : $longMsg" >> $logfile
}

function procTokFiles {
  #-------------------------------------------------------------------#IV76877
  # Delete old token files and warn if there is another install       #IV76877
  # running in this <candlehome>.                                     #IV76877
  #-------------------------------------------------------------------#IV76877
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV76877
                                                                      #IV76877
  typeset -i maxAge=5  # Remove "remote" token files older than 5 days.
  typeset -i age=0 dot=0 doy=0
  typeset PID name

  ls ${baseTok}* | grep -v $thisTok > /dev/null 2>&1  # Other installs?
  [[ $? -eq 0 ]] || return

  doy=$(date +"%j")  # Day of the year (001 - 366)

  # Remove token files:
  # 1) created on this machine that are no longer connected to any process.
  # 2) created on other machines that are older than maxAge.

  for name in $(ls ${baseTok}* | grep -v $thisTok) ; do
    cat $name | grep "$thisMach" > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then # The token file was created on this machine.
      PID=${name##*_}
      ps -p $PID | grep $PID > /dev/null 2>&1
      [[ $? -ne 0 ]] && rm -f $name
    else
      # Ensure the day of year field exists.
      cat $name | grep "|" > /dev/null 2>&1
      [[ $? -eq 0 ]] || continue

      # Day the token file was created (001 - 366).
      dot=$(cat $name | cut -d"|" -f2 | cut -d"|" -f1)

      if [[ doy -ge dot ]]; then
        age=doy-dot
      else
        # This could happen towards the end of a year,
        # so "normalize" the day of the year.
        doy=366+doy
        age=doy-dot
      fi

      [[ age -gt maxAge ]] && rm -f $name
    fi
  done

  # Warn the user about possible simultaneous installs.

  # Check for other installs.
  ls ${baseTok}* | grep -v $thisTok > /dev/null 2>&1
  if [[ $? -eq 0 && "${orphan}" = "no" ]]; then
    #$NLS-E$ "\nAn install may currently be running in \"$CANDLEHOME\"
    #$NLS-E$  from the following machine(s): \n"
    print " "
    nls_replace 'KCI0215I' \"$CANDLEHOME\"
    print " "
    for name in $(ls ${baseTok}* | grep -v $thisTok) ; do
      print "  \c"; cat $name
    done

    #$NLS-E$ "Continue with this uninstallation"
    continue="$(nls_replace 'KCI0217I')"
    #$NLS-E$ "1-yes"
    yes="1-$(nls_replace 'KCI0197I')"
    #$NLS-E$ "2-no"
    no="2-$(nls_replace 'KCI0198I')"
    #$NLS-E$ "is default"
    default="\"2\" $(nls_replace 'KCI0199I')"
    #$NLS-E$ "\nContinue with this uninstallation [ 1-yes, 2-no;
    #         "2" is default ]?  \c"
    print "\n${continue} [ ${yes}, ${no}; ${default} ]? \c"
    read
    case $REPLY in
      y*|Y*|1) ;;
            *) clean_up
               ;;
      esac
  fi
}

function cinfoRunning {
  #-------------------------------------------------------------------#IV76877
  # Get the running process list for this host                        #IV76877
  #-------------------------------------------------------------------#IV76877
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV76877
                                                                      #IV76877
  $CANDLEHOME/bin/cinfo -r |
     $AWK '/\.\.\.running/ { A=NF-1; print $1"|"$2"|"$3"|"$A"|"$4 }'
}

function checkProcesses {
  #-------------------------------------------------------------------#IV76877
  # Check for running processes before uninstall                      #IV76877
  #-------------------------------------------------------------------#IV76877
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV76877
                                                                      #IV76877
  typeset rFile=$CANDLEHOME/config/.ConfigData/RunInfo
  typeset PID desc fieldSep fld23 msg pc proc
  typeset thisMachShort

  # No RunInfo means nothing's running
  [[ ! -f $rFile ]] && return

  # Determine whether it's BigK or dinkySQL.
  fieldSep=$(grep "FIELDSEP" $rFile | cut -d "=" -f2 2> /dev/null)

  # Check for components running from this <candlehome> on this machine.
  fld123=$(cinfoRunning)  # fld123 -> HOST|ms|35594|TEMS|itmuser
  # fld23 -> ms|35594|TEMS|itmuser
  fld23=$(print "$fld123" | cut -d "$fieldSep" -f2-5)

  # Check to see if the processes are actually running.
  [[ -n "$fld23" ]] || return

  #$NLS-E$ "\\nThe following processes must be stopped before attempting
  #         uninstall: \\n"
  msg="\\n$(nls_replace 'KCI0218I') \\n"

  print "$msg"
  for proc in $fld23 ; do
    pc=$(print "$proc" | cut -d "$fieldSep" -f1)
    desc=$(get_desc $pc)
    PID=$(print "$proc" | cut -d "$fieldSep" -f2)
    #$NLS-E$ Product
    print "  $(nls_replace 'KCI1170I') = $desc  PID = $PID"
  done
  print
  exit 3
}

function hp_forcewait {
  #-------------------------------------------------------------------#IV76877
  #  OS agent is not cleaning up its children on HP, so we have to    #IV76877
  #  wait for them to die.                                            #IV76877
  #-------------------------------------------------------------------#IV76877
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV76877
                                                                      #IV76877
  if [[ "$os" = hp && $(ps -ef|grep -c /ux/bin/|grep -v grep) -gt 1 ]]; then
    #$NLS-E$ Waiting for agent to shutdown
    print "$(nls_replace 'KCI1171I')"
    sleep 70
    if [[ -d "$CANDLEHOME/../" ]]; then
      cd $CANDLEHOME/../
    fi
  fi
  return
}

function hp_dld_sl_conf {
  #-------------------------------------------------------------------#IV76877
  # Delete GSKit library directory from /etc/dld.sl.conf if present   #IV76877
  #-------------------------------------------------------------------#IV76877
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV76877
                                                                      #IV76877
  if [[ "$os" = hp ]]; then                                           #IV76877
    PPFile="$CANDLEHOME/config/gsKit.config";                         #IV76877
    dldFile="/etc/dld.sl.conf";                                       #IV76877
                                                                      #IV76877
    if [[ -f "$PPFile" ]]; then
      # Generate grep search string based on the gsKit.conf file      #IV76877
      # If both 32 and 64 bit entries are in gsKit.conf, we have to   #IV76877
      # generate a hard-quted pipe delimited string.                  #IV76877
      # gsKit.config:                                                 #IV76877
      # GskitInstallDir=/opt/IBM/ITM/hpi11/gs                         #IV76877
      # GskitInstallDir_64=/opt/IBM/ITM/hpi116/gs                     #IV76877
      # grep Search string:                                           #IV76877
      # '/opt/IBM/ITM/hpi11/gs|/opt/IBM/ITM/hpi116/gs'                #IV76877
      # gsKit.config:                                                 #IV76877
      gskPaths="'"$(print -- $(grep "^Gskit.*=" $PPFile 2>/dev/null |
        cut -d= -f2) | tr " " "|" )"'";                               #IV76877
      # Check to see if either string is found in /etc/dld.sl.conf    #IV76877
      fnd=$(egrep -qve "${gskPaths}" $dldFile 2>/dev/null;echo $?);   #IV76877
      if [[ $fnd -eq 0 ]]; then                                       #IV76877
        cmd="tmp=\$(egrep -ve ${gskPaths} $dldFile)";                 #IV76877
        cmd="$cmd;echo \"\${tmp}\" > ${dldFile}";                     #IV76877
                                                                      #IV76877
        #-------------------------------------------------------------#IV76877
        # If we're already root, run the command and return.          #IV76877
        # Otherwise, we try to run the command interactively and let  #IV76877
        # the user control how we proceed.                            #IV76877
        #-------------------------------------------------------------#IV76877
        if [[ "$(whoami)" = "root" ]]; then                           #IV76877
          eval "$cmd"                                                 #IV76877
        else                                                          #IV76877
          #$NLS-E$ "\nroot user access is required to update
          #         /etc/dld.sl.conf"
          print "\n$(nls_replace 'KCI0216I')";                        #IV76877
          # If we're not root and we're in force mode, bail out       #IV76877
          if [[ "$force" = "yes" ]]; then                             #IV76877
            loop="no";                                                #IV76877
          else                                                        #IV76877
            loop="yes";                                               #IV76877
          fi                                                          #IV76877
                                                                      #IV76877
          while [[ $loop = "yes" ]] ; do                              #IV76877
            su root -c "$cmd";                                        #IV76877
            rc=$?;                                                    #IV76877
            if [[ $rc -ne 0 ]]; then                                  #IV76877
              #$NLS-E$ "Ignore [ 1 ] or Try again"                    #IV76877
              ignore1="$(nls_replace 'KCI0220I')"                     #IV76877
              #$NLS-E$ "2-yes"                                        #IV76877
              yes="2-$(nls_replace 'KCI0197I')"                       #IV76877
              #$NLS-E$ "3-no"                                         #IV76877
              no="3-$(nls_replace 'KCI0198I')"                        #IV76877
              #$NLS-E$ "\"3\" is default"                             #IV76877
              default="\"3\" $(nls_replace 'KCI0199I')"               #IV76877
              #$NLS-E$ "\nIgnore [ 1 ] or Try again [ 2-yes, 3-no;
              #               "3" is default ]?  \c"
              print "\n${ignore1} [${yes}, ${no}; ${default}]? \c";
              read;                                                   #IV76877
              case $REPLY in                                          #IV76877
                y*|Y*|2)                                              #IV76877
                  continue;                                           #IV76877
                ;;                                                    #IV76877
                i*|I*|1)                                              #IV76877
                  loop="no";                                          #IV76877
                ;;                                                    #IV76877
                *)                                                    #IV76877
                  #$NLS-E$ "Failing, Commands to be executed were:"
                  nls_replace 'KCI0221E';                             #IV76877
                  print "$cmd";                                       #IV76877
                  loop="no";                                          #IV76877
                ;;                                                    #IV76877
              esac                                                    #IV76877
            else                                                      #IV76877
              loop="no";                                              #IV76877
            fi                                                        #IV76877
          done                                                        #IV76877
        fi                                                            #IV76877
      fi                                                              #IV76877
    fi                                                                #IV76877
  fi                                                                  #IV76877
}

function remove_autostart {
  #-------------------------------------------------------------------#IV76877
  # Remove the entire boot script and links to it.                    #IV76877
  #-------------------------------------------------------------------#IV76877
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV76877
                                                                      #IV76877
  typeset -i filenum=;                                                #IZ58055
  if [[ -f $CANDLEHOME/registry/AutoStart ]]; then                    #IZ58055
    filenum=$(cat $CANDLEHOME/registry/AutoStart 2> /dev/null);       #IZ58055
  fi                                                                  #IZ58055
                                                                      #IZ58055
  #-------------------------------------------------------------------#IZ58055
  # Define the commands to undo autostart for our platform.           #IZ58055
  #-------------------------------------------------------------------#IZ58055
  case "$os" in                                                       #IZ58055
    li|lx|lp|ls)                                                      #IZ58055
      # Delete initd files and links                                  #IV97694
      cmd="chkconfig --del ITMAgents$filenum > /dev/null 2>&1";       #IZ58055
      cmd="$cmd;rm -f /etc/init.d/ITMAgents$filenum";                 #IZ58055
      cmd="$cmd;rm -f /etc/rc.d/rc[0-6].d/K10ITMAgents$filenum";      #IZ58055
      cmd="$cmd;rm -f /etc/rc.d/rc[0-6].d/S99ITMAgents$filenum";      #IZ58055
      cmd="$cmd;rm -f /etc/init.d/rc[0-6].d/K10ITMAgents$filenum";    #IZ58055
      cmd="$cmd;rm -f /etc/init.d/rc[0-6].d/S99ITMAgents$filenum";    #IZ58055
      cmd="$cmd;rm -f /var/lock/subsys/ITMAgents$filenum";            #IZ58055
      if [[ "$boot_mode" = systemd ]]; then                           #IV97694
        # Delete systemd target and service units                     #IV97694
        sdBaseName=ITMAgents$filenum;                                 #IV97694
        sdUnits=$(print $(cd $sdBaseDir;ls $sdBaseName.* 2>/dev/null));#IV97694
        for sdUnit in $sdUnits ; do                                   #IV97694
          # Disable unit                                              #IV97694
          cmd="$cmd;systemctl disable $sdUnit";                       #IV97694
          # Delete unit file                                          #IV97694
          cmd="$cmd;rm -f $sdBaseDir/${sdUnit}";                      #IV97694
        done                                                          #IV97694
      fi                                                              #IV97694
      ;;                                                              #IZ58055
    hp)                                                               #IZ58055
      cmd="rm -f /sbin/rc0.d/K100ITMAgents$filenum";                  #IZ58055
      cmd="$cmd;rm -f /sbin/rc1.d/K100ITMAgents$filenum";             #IZ58055
      cmd="$cmd;rm -f /sbin/rc2.d/S500ITMAgents$filenum";             #IZ58055
      cmd="$cmd;rm -f /sbin/init.d/ITMAgents$filenum";                #IZ58055
      ;;                                                              #IZ58055
    so)                                                               #IZ58055
      cmd="rm -f /etc/rc0.d/K10ITMAgents$filenum";                    #IZ58055
      cmd="$cmd;rm -f /etc/rc1.d/K10ITMAgents$filenum";               #IZ58055
      cmd="$cmd;rm -f /etc/rc2.d/S99ITMAgents$filenum";               #IZ58055
      cmd="$cmd;rm -f /etc/init.d/ITMAgents$filenum";                 #IZ58055
      ;;                                                              #IZ58055
    ai)                                                               #IZ58055
      rcFile="/etc/rc.itm${filenum}";                                 #IV23322
      cmd="rmitab rcitm$filenum";                                     #IZ58055
      cmd="$cmd;rm -f ${rcFile}";                                     #IV23322
      ;;                                                              #IZ58055
    *)                                         # should never happen..#IZ58055
      cmd="print -u2 'internal error: os=$os is not valid'";          #IZ58055
      ;;                                                              #IZ58055
  esac                                           # (case(os))         #IZ58055
                                                                      #IZ58055
  #-------------------------------------------------------------------#IZ58055
  # If we're already root, run the command and return. Otherwise, we  #IZ58055
  # try to run the command interactively and let the user control how #IZ58055
  # we proceed.                                                       #IZ58055
  #-------------------------------------------------------------------#IZ58055
  if [[ "$(whoami)" = "root" ]]; then                                 #IZ58055
    eval "$cmd"                                                       #IZ58055
  else
    #$NLS-E$ "\nroot user access is required to remove
    #               automatic restart files"
    print "\n$(nls_replace 'KCI0219I')";                              #IV23322
    # If we're not root and we're in force mode, bail out
    if [[ "$force" = "yes" ]]; then                                   #IV23322
      loop="no";                                                      #IV23322
    else                                                              #IV23322
      loop="yes";                                                     #IV23322
    fi                                                                #IV23322

    while [[ $loop = "yes" ]] ; do
      su root -c "$cmd"
      rc=$?
      if [[ $rc -ne 0 ]]; then  # su failed
        #$NLS-E$ "Ignore [ 1 ] or Try again"
        ignore1="$(nls_replace 'KCI0220I')"
        #$NLS-E$ "2-yes"
        yes="2-$(nls_replace 'KCI0197I')"
        #$NLS-E$ "3-no"
        no="3-$(nls_replace 'KCI0198I')"
        #$NLS-E$ "\"3\" is default"
        default="\"3\" $(nls_replace 'KCI0199I')"
        #$NLS-E$ "\nIgnore [ 1 ] or Try again [ 2-yes, 3-no;
        #               "3" is default ]?  \c"
        print "\n${ignore1} [${yes}, ${no}; ${default}]? \c";#IV23322
        read
        case $REPLY in
          y*|Y*|2)
            continue
          ;;
          i*|I*|1)
            loop="no";                                                #IV23322
          ;;
          *)
            #$NLS-E$ "Failing, Commands to be executed were:"
            nls_replace 'KCI0221E'
            print "$cmd"
            loop="no";                                                #IV23322
          ;;
        esac
      else                                                            #IV23322
        loop="no";                                                    #IV23322
      fi                                                              #IV23322
    done
  fi
                                                                      #IV23322
  if [[ "${os}" = "ai" ]]; then                                       #IV23322
    #$NLS-E$ "You must manually disable automatic stop at system      #IV23322
    #$NLS-E$ shutdown. Modify /etc/rc.shutdown so it no longer        #IV23322
    #$NLS-E$ invokes the command '$1 stop'.                           #IV23322
    print "";                                                         #IV23322
    nls_replace 'KCI0120I' "${rcFile}";                               #IV23322
  fi                                                                  #IV23322
}

function uninstall_process {
  #-------------------------------------------------------------------#IV76877
  # Run uninstall-process.sh if it exists.                            #IV76877
  #-------------------------------------------------------------------#IV76877
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV76877
                                                                      #IV76877
  TEMP_pc=$1
  TEMP_platform=$2

  # If exists, then we can run this script if JAVA is also installed.
  # This script was added as a special case for a specific agent.
  # Generally, it is not installed and it is not used by the SMA style agents.
  unProcessFile="$CANDLEHOME/bin/uninstall-process.sh"
  if [[ -f $unProcessFile ]]; then
    # and is executable
    if [[ ! -x $unProcessFile ]]; then
      # Try to fix the problem
      chmod a+x $unProcessFile 2>/dev/null
    fi

    # Now check again
    if [[ -x $unProcessFile ]]; then
      # We fixed the problem, good
      print ""
      #$NLS-E$ "Processing pre-uninstall operations for component:"
      print "$(nls_replace 'KCI0248I') $TEMP_pc"

      p1="$JAVA_HOME"
      p2="$CANDLEHOME"
      p3="$TEMP_pc"
      p4="preuninstall"
      p5="$TEMP_platform"
      p6="uninstall"
      p7="$force"
      p8="$CANDLEHOME/logs/uninstall-process.err"
      $unProcessFile "$p1" "$p2" "$p3" "$p4" "$p5" "$p6" "$p7" 2> $p8
      typeset -i result=$?
      if [[ $result -eq 0 ]]; then
        #$NLS-E$ "Processing pre-uninstall complete."
        print "$(nls_replace 'KCI0249I')"
        print ""
      fi
      return $result

    else
      # OK, we tried once, now we tell the user for more advanced steps
      print ""
      #$NLS-E$ "The file [$CANDLEHOME/bin/uninstall-process.sh] exists,
      #         but is not executable by this user."
      print "$(nls_replace 'KCI1260I' "$unProcessFile")"
      #$NLS-E$ "Please change the permission of this file to be executable
      #         by this user."
      print "$(nls_replace 'KCI1261I')"
      print ""

      # This is a bold step to exit the entire uninstaller, but warranted
      # since they need to try and fix this, and it's easy enough to
      # re-enter the tool. Plus, the user might not see the message.
      clean_up 1
    fi

  else
    # The file does not exist, which will often happen - we silently skip this
    print ""
  fi
}

function remove_links {
  #-------------------------------------------------------------------#IV76877
  # Remove /opt/IBM/ITM/tmaitm6/links/<PLAT>/lib if this ITM is not   #IV76877
  # installed in /opt/IBM/ITM and the "lib" directory link points to  #IV76877
  # to this ITM.                                                      #IV76877
  # If there are no files under /opt/IBM/ITM, remove /opt/IBM/ITM.    #IV76877
  #-------------------------------------------------------------------#IV76877
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV76877
                                                                      #IV76877
  typeset defaultCH="/opt/IBM/ITM"
  typeset link_target=""
  typeset tmp=""

  if [[ "$CANDLEHOME" != "$defaultCH" && -d $defaultCH ]]; then
    # search for symblink files under /opt/IBM/ITM
    for linkF in $(find ${defaultCH}/tmaitm6/links -type l 2>/dev/null) ; do
      link_target=$(ls -l $linkF)
      link_target=${link_target##*-\> }

      # link_target=/opt/IBM/ITMxyz/tmaitm6/... -> tmp=xyz/tmaitm6/...
      # link_target=/opt/IBM/xyz/tmaitm6/... -> tmp=/opt/IBM/xyz/tmaitm6/...
      tmp=${link_target##$CANDLEHOME}
      # this link doesn't point to this ITM
      [[ "$tmp" = "$link_target" ]] && continue

      # tmp=xyz/tmaitm6/... -> tmp=xyz
      tmp=${tmp%%/*}
      # this link doesn't point to this ITM
      [[ -n "$tmp" ]] && continue

      # this symblink file links to this ITM, it should be removed
      rm -f $linkF 1>/dev/null 2>&1
    done

    # remove /opt/IBM/ITM if it's empty (if it doesn't contain any files)
    typeset -i file_num=$(find $defaultCH ! -type d 2>&1 | wc -l)
    if [[ $file_num -eq 0 ]]; then
      rm -rf $defaultCH 1>/dev/null 2>&1
    fi
  fi
}

function uninstall_callpoint {
  #-------------------------------------------------------------------#IV76877
  # Run Java ITMinstall.InstallComponentPluginCall                    #IV76877
  #-------------------------------------------------------------------#IV76877
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV76877
                                                                      #IV76877
  productCode=$1
  export saveLang=$LANG
  baseArch=${cArch%%[0-9]*}
  regdir=$CANDLEHOME/registry
  pcInstalled=$(ls ${regdir}/$productCode$baseArch*.ver 2>/dev/null)
  [[ -z "$pcInstalled" ]] && return

  useJreArch=$cArch

  # if we are running platform lx we need to modify java arch prerequisite
  if [[ "$baseArch" = "lx" ]]; then
    export LANG=C
    cArchJava=$(grep "^preReqALL = jr" $pcInstalled 2>/dev/null |
                cut -d"=" -f2 | cut -d "|" -f1 | cut -c 4-)
    export LANG=$saveLang
    #use cArchJava only if component has jre prereq
    [[ -n "$cArchJava" ]] && useJreArch=$cArchJava
  fi

  setJavaEnv $useJreArch

  setBinLibArchs $cArch $productCode
  # echo "Product arch = $binArch"
  baseArch=${cArch%%[0-9]*}
  export LANG=C
  pcVRMF=$(grep "^VRMF =" ${regdir}/$productCode$baseArch*.ver 2>/dev/null |
           cut -d"=" -f2)
  export LANG=$saveLang
  plugin_type=install
  plugin_action=uninstall

  # if there is no VRMF in registry/<pc><arch>.ver file - create VRMF based
  # on "vel" and "ver"
  # VRMF = 0+ver+rel+0
  if [[ -z "$pcVRMF" ]]; then
    export LANG=C
    pcVER=$(grep "^ver =" ${regdir}/$productCode$baseArch*.ver 2>/dev/null |
            cut -d"=" -f2)
    pcREL=$(grep "^rel =" ${regdir}/$productCode$baseArch*.ver 2>/dev/null |
            cut -d"=" -f2)
    export LANG=$saveLang
    # Check if ver and rel can be read from ver file
    if [[ -z "$pcVER" || -z "$pcREL" ]]; then
      # Unable to determine product version
      return
    fi
    pcVRMF="0""$pcVER""$pcREL""0"
  fi

  j1="-classpath"
  j2="$CLASSPATH"
  j3="$SAFE_MODE"
  j4="-DGlobalDbgLevel=DEBUG_MAX"
  j5="-DInstallRASConfig=$CANDLEHOME/config/ITMConfigRAS.properties"
  j6="ITMinstall.InstallComponentPluginCall"
  j7="$plugin_type"
  j8="$plugin_action"
  j9="$CANDLEHOME"
  ja="$cArch"
  jb="$productCode"
  jc="$binArch"
  jd="$pcVRMF"
  $JREEXE $j1 $j2 $j3 $j4 $j5 $j6 $j7 $j8 $j9 $ja $jb $jc $jd
  rc=$?

  # echo "Return code is $rc"
}

function clean_up {
  #-------------------------------------------------------------------#IV76877
  # Remove the token file and the plugin_tmp directory.               #IV76877
  #-------------------------------------------------------------------#IV76877
  eval $(itmsh_trace_func "${0}" "${@}");   # enable function tracing #IV76877
                                                                      #IV76877
  typeset -i rc=0
  [[ "$1" = +([0-9]) ]] && rc=$1
  rm -f "$thisTok" > /dev/null 2>&1
  # Our plugin work dir
  rm -rf /tmp/plugin_tmp > /dev/null 2>&1
  # on HP-IA, the temporary directory is /var/tmp
  if [[ -d /var/tmp/plugin_tmp ]]; then
    rm -rf /var/tmp/plugin_tmp > /dev/null 2>&1
  fi
  exit $rc
}

###################################################################
#                         Main Routine                            #
###################################################################

PROGNAME=$(basename $0);                                              #IV76877
UsrCmd="$0 $*";                                                       #IV76877

typeset AWK="awk";                                                    #IV76877
# need to use nawk if it's available                                  #IV76877
type nawk >/dev/null 2>&1;                                            #IV76877
[[ $? -eq 0 ]] && AWK=nawk;                                           #IV76877

if [[ -f /usr/xpg4/bin/grep ]]; then                                  #IV27849
  grepCmd="/usr/xpg4/bin/grep";            # Solaris 10 & earlier     #IV27849
else                                                                  #IV27849
  grepCmd="grep";                          # Solaris 11+ & Linux/Unix #IV27849
fi                                                                    #IV27849
                                                                      #IV27849
bindir=$(pwd)/$(dirname $0)
[[ -z "$(print $0 | grep '\./')" && -z "$(print $0 | grep '^/.*')" &&
   $(pwd) = '/' ]] && bindir=$(pwd)$(dirname $0)
[[ -n "$(print $0 | grep '^/.*')" ]] && bindir=$(dirname $0)

. ${bindir}/itmsh_trace_main;               # embed/start tracing     #IV76877
                                                                      #IV76877
export TEXTDOMAINDIR=$bindir/../config/nls/msg
export PATH=/bin:/usr/bin:/usr/sbin:/usr/ucb:$bindir:$PATH            #IZ97998
Mode=""
Menu="yes"
force="no"
ignore="no"
orphan="no"
[[ -z "$(whoami 2>/dev/null)" ]] &&
  alias whoami='id | cut -d"(" -f2 | cut -d")" -f1'

typeset -i ver=0 vr=0

# Variables used for the token file.
typeset baseTok thisMach thisOS thisRec thisTok thisUser

while getopts ":h:fio" OPTS ; do
  case $OPTS in
    h) CANDLEHOME=$OPTARG
       ;;
    f) force="yes"
       ;;
    i) ignore="yes"
       ;;
    o) orphan="yes"
       ;;
    ?) Use_report
       ;;
  esac
done

shift $((OPTIND-1))

# Allow only product/platform combo or nothing
if [[ $# -ge 2 ]]; then
  pc="$1"; shift; platform="$1"
  Menu="no"
elif [[ $# -eq 1 ]]; then
  Use_report
else
  Menu="yes"
fi

[[ -n "$CANDLEHOME" ]] ||
  CANDLEHOME=$(cd $(dirname $0) ; dirname $(pwd) )
#$NLS-E$ "specified ITM home is not a valid directory: $CANDLEHOME"
[[ -d "$CANDLEHOME" ]] ||
  Err_report fail "$(nls_replace 'KCI0222E') $CANDLEHOME"
#$NLS-E$ "You have to be a root user or have the write access to directory
#         $CANDLEHOME if you want to uninstall ITM."
[[ -w "$CANDLEHOME" ]] ||
  Err_report fail "$(nls_replace 'KCI1205E' $CANDLEHOME)"
export CANDLEHOME
originalDir=$(pwd)

if [[ $(print "$CANDLEHOME" | wc -w) -ne 1 ]]; then
  #$NLS-E$ "Blanks are not permitted in CANDLEHOME"
  Err_report fail "$(nls_replace 'KCI0223E')"
fi

export CANDLETMP=$CANDLEHOME/tmp

CANDLEDATA="";                              # assume no CANDLEDATA    #IV67523
CH2CDlink="${CANDLEHOME}/registry/CANDLEDATA"; # get the link marker  #IV67523
if [[ -L "${CH2CDlink}" ]]; then               # is link set?         #IV67523
  CH2CDlink=$(ls -l "${CH2CDlink}" 2> /dev/null);                     #IV67523
  if [[ "${CH2CDlink}" = *" -> "* ]]; then    # is it valid?          #IV67523
    CANDLEDATA="${CH2CDlink##* -> }";          # yes, use it          #IV67523
  fi                                          # (if(CH2CDlink=* -> *))#IV67523
fi                                             # (if(-L...))          #IV67523

# Call dynarch only one time. Removed from all functions.             #IV76877
CurRegPath=$CANDLEHOME/registry;                                      #IV76877
ArchTbl=$CurRegPath/archdsc.tbl;                                      #IV76877
DynShl=$CANDLEHOME/bin/dynarch.shl;                                   #IV76877
. $DynShl $ArchTbl 2>/dev/null;                                       #IV76877
os=$(print $cArch|cut -c1-2);                                         #IV76877

if [[ "$os" = @(li|lx|lp|ls) ]]; then                                 #IV97694
  set_bootMode;                                                       #IV97694
fi                                                                    #IV97694

# LL - start token file stuff.
baseTok=$CANDLETMP/candle_install_

thisOS=$(uname -s)  # thisOS -> AIX
thisUser=$(whoami)


# Create the token file.
thisMach=$(hostname)  # thisMach -> vulcan
thisTok=$baseTok${thisMach}_$$
touch $thisTok > /dev/null 2>&1
#$NLS-E$ "could not create token file"
[[ $? -eq 0 ]] || Err_report fail "$(nls_replace 'KCI0224E')"

trap "clean_up" 1 2 3 15

# Build the description record, and add it to the token file.
# This record will look like:
# "AIX vulcan billy 17440 Friday Jun 08 14:21 2001 |159|".
# The number between pipes (|) is the day of the year the file was created.

thisRec="$thisOS $thisMach $thisUser $$ $(date +"%A %B %d %H:%M %Y |%j|")"
print "$thisRec" > $thisTok

# Delete old token files, and warn if there is another install running in
# this <candlehome>.

procTokFiles

if [[ "$ignore" = "no" ]]; then
  # Make sure nothing's running in this CandleHome
  checkProcesses
fi

# Get installer version and release number
ciVFile=cienv.ver
typeset curRel="" curVer="" regFile=""

regFile=$CANDLEHOME/registry/$ciVFile
#$NLS-E$ "could not read file: $regFile"
[[ -r $regFile ]] || Err_report fail "$(nls_replace 'KCI0225E' $regFile)"

curVrmf=$(grep "^VRMF =" $regFile | cut -d"=" -f2)
if [[ -z "$curVrmf" ]]; then
  curVer=$(grep "^ver =" $regFile | cut -d"=" -f2)
  #$NLS-E$ "could not determine the version number from $regFile"
  [[ -n "$curVer" ]] || Err_report fail "$(nls_replace 'KCI0226E' $regFile)"
  curRel=$(grep "^rel =" $regFile | cut -d"=" -f2)
  #$NLS-E$ "could not determine the release number from $regFile"
  [[ -n "$curRel" ]] || Err_report fail "$(nls_replace 'KCI0227E' $regFile)"
else
  curVer1=$(print $curVrmf| cut -c 1,2)
  curVer2=$(print $curVrmf| cut -c 3,4)
  curVer3=$(print $curVrmf| cut -c 5,6)
  curVer4=$(print $curVrmf| cut -c 7,8)
fi

# Show banner
print " "
print "*********** $(date) ******************"
if [[ -z "$curVrmf" ]]; then
  curLvl="$curVer /$curRel"
else
  curLvl="$curVer1.$curVer2.$curVer3.$curVer4"
fi
if [[ "$(uname -s)" != "NONSTOP_KERNEL" ]]; then
  print "User      : $(whoami)\t Group: $(groups)"
  #$NLS-E$ "Host name : $(hostname)"
  HostName="$(nls_replace 'KCI0228I') : $(hostname)"
  #$NLS-E$ "Installer Lvl:$curLvl"
  InstallerLvl="$(nls_replace 'KCI0229I') Lvl:$curLvl"
  #$NLS-E$ "Host name : $(hostname)\t Installer Lvl:$curLvl"
  print "${HostName}\t ${InstallerLvl}"
else
  #$NLS-E$ "User      : $(whoami)\t "
  print "$(nls_replace 'KCI0230I')      : $(whoami)\t "
  #$NLS-E$ "Installer Lvl:$curLvl"
  print "$(nls_replace 'KCI0229I') Lvl:$curLvl"
fi                          # end uname -s

print "ITM home  : $CANDLEHOME"
if [[ -n "${CANDLEDATA}" ]]; then                                     #IV67523
  print "ITM data  : ${CANDLEDATA}";                                  #IV67523
fi                                                                    #IV67523
print "***********************************************************"

infoTmp=$CANDLEHOME/tmp/info.tmp_$$
infoTmp2=$CANDLEHOME/tmp/info.tmp2_$$
regDir=$CANDLEHOME/registry

# This returns JAVA_HOME to us on the command line - set to variable and use
if [[ -f $CANDLEHOME/bin/CandleGetJavaHome ]]; then
  export JAVA_HOME=$($CANDLEHOME/bin/CandleGetJavaHome)
else
  export JAVA_HOME=
fi

# User entered a product code / platform combo in the args
if [[ "$Menu" = "no" ]]; then

  cd $regDir
  typeset sharedPrereq=""
  for comp in $(ls *.ver | egrep -ve "^ci|^gs") ; do
    comp=${comp%.ver}
    sharedPrereq=$(grep " = $pc$platform" ${comp}.ver)
    [[ -n "$sharedPrereq" ]] && break
  done
  if [[ -n "$sharedPrereq" ]]; then
    Err_report fail "$(nls_replace 'KCI1231E' \"$pc$platform\" \"$comp\")"
  fi

  typeset -i result=0

  cd $regDir
  tmpVerFile=$pc$platform.ver
  if [[ -f $tmpVerFile ]]; then
    isProdInstalled="yes"
  fi

  if [[ "$isProdInstalled" = "yes" ]]; then
    if [[ -n "$JAVA_HOME" ]]; then
      # Call the uninstall-process handler
      uninstall_process $pc $platform
      result=$?
      # Call the uninstall callpoint funtion
      if [[ $result -eq 0 ]]; then
        uninstall_callpoint $pc
        result=$?
      fi
    fi
  elif [[ "$pc" = "REMOVE" && "$platform" = "EVERYTHING" ]]; then
    if [[ -n "$JAVA_HOME" ]]; then
      cd $regDir
      codes="$(ls *.ver 2>/dev/null | grep -v "^ci")"

      for verfile in $(ls ??+(ai|hp|so|l)*.ver 2> /dev/null) ; do     #IV27849
        pc=$(print $verfile | cut -c 1-2)

        if [[ ! ("$pc" = @(gs|t1|jr|ui)) ]]; then
          platform="$(print $verfile | cut -c 3-)"
          platform=${platform%.ver}

          for prereq in $codes; do
            prereq=${prereq%.ver}
            sharedPrereq=$(grep " = $pc$platform" ${prereq}.ver)
            [[ -n "$sharedPrereq" ]] && break
          done

          if [[ -z "$sharedPrereq" ]]; then
            # Call the uninstall-process handler
            uninstall_process $pc $platform
            result=$?
            # Call the uninstall callpoint funtion
            if [[ $result -eq 0 ]]; then
              uninstall_callpoint $pc
              result=$?
            fi
          fi
        fi
      done

      pc="REMOVE"
      platform="EVERYTHING"
    fi
  fi

  if [[ $result -eq 1 ]]; then
    #$NLS-E$ "Cancel Uninstall..."
    print "$(nls_replace 'KCI1290I')"
  elif [[ $result -eq 0 ]]; then
    # The uninstall_product function will check if the package is installed
    # and display a message if not found.
    uninstall_product $pc $platform
    # if installed product was successfully uninstalled with all prerequisites
    # and was executed by non-root, show additional message to the user
    if [[ "$isProdInstalled" = "yes" ]]; then
      if [[ "$(whoami)" != "root" ]]; then
        #$NLS-E$ You have to be a root user to update auto restart script
        Err_report warn "$(nls_replace 'KCI1167I')"
      fi
    fi
  elif [[ $result -eq 2 ]]; then
    # uninstall.sh failed.
    clean_up 2
  fi

  # cm12160 - for silent install, need to remove top level directory
  # if no more products are installed and the force flag (-f) is specified
  remaining=$(cd $regDir ; find * -name '*.ver' ! -exec\
    $grepCmd -q 'preReqALL = none' {} \; -print 2>/dev/null | grep -v '/')

  if [[ -z "$remaining" && "$force" = "yes" ]]; then
    #$NLS-E$ "Removing ITM home: $CANDLEHOME\n"
    print "$(nls_replace 'KCI0231I'): $CANDLEHOME\n"
    # remove the agent autostart files
    if [[ -f $CANDLEHOME/registry/AutoStart ]]; then
      remove_autostart
    fi
    cd $originalDir
    hp_forcewait
    hp_dld_sl_conf;                                                   #IV76877
    rm -rf $CANDLEHOME
    remove_links
  fi

# User entered nothing on command-line so we show the list of installed prods
else
  rm -f $infoTmp2
  Response=""
  delPC=""

  while true ; do
    cd $regDir
    # Get a list of installed product version files.
    # Show only version files that have prereqs.
    for pc in $(ls ??+(ai|hp|so|l)*.ver 2> /dev/null) ; do            #IV27849
      pc=$(print $pc|cut -c 1-2)
      # GSKit should not be printed on the list of components available for
      # uninstall and should not be uninstalled until everything is removed,
      # it must get removed along with CANDLEHOME directory
      # T1 should not be listed as an option on the menu since it is not a
      # true component, but now integrated into the TEMS package.
      # JR should not be listed as an option on the uninstall menu since it
      # is not a true ITM component.
      if [[ ! ("$pc" = @(gs|t1|jr|ui)) ]]; then
        print $pc >> $infoTmp2
      fi
    done

    if [[ -z "$Response" && -f $infoTmp2 ]]; then
      #$NLS-E$ "\n...Products available to uninstall\n"
      print "\n...$(nls_replace 'KCI0232I')\n"
      #$NLS-E$ "Num\tProduct [ Code  Platform Version:Release Description ]"
      print "$(nls_replace 'KCI0233I')"
    fi

    # No products to list ... ask about removing CANDLEHOME
    if [[ ! -f $infoTmp2 ]]; then
      print
      #$NLS-E$ "No products found to uninstall. Preparing to remove ITM
      #         home ..."
      nls_replace 'KCI0234I'
      if [[ "$force" = "no" ]]; then
        #$NLS-E$ "Confirm: CANDLEHOME=$CANDLEHOME"
        confirm="$(nls_replace 'KCI0235I'): CANDLEHOME=$CANDLEHOME"
        #$NLS-E$ " ... OK to delete?"
        okDelete=" ... $(nls_replace 'KCI0236I')"
        #$NLS-E$ "1-yes"
        yes="1-$(nls_replace 'KCI0197I')"
        #$NLS-E$ "2-no"
        no="2-$(nls_replace 'KCI0198I')"
        #$NLS-E$ "\"2\" is default"
        default="\"2\" $(nls_replace 'KCI0199I')"
        #$NLS-E$ "Confirm: CANDLEHOME=$CANDLEHOME  ... OK to delete? [ 1-yes,
        #         2-no; "2" is default ]: "
        print -n "$confirm $okDelete [ $yes, $no; $default ]: "
        read answer
      else
        answer="y"
      fi
      case "$answer" in
        y|Y|yes|YES|1)
          #$NLS-E$ "Removing ITM home: $CANDLEHOME\n"
          print "$(nls_replace 'KCI0237I'): $CANDLEHOME\n"
          cd $originalDir
          cmdHome=$(cd $(dirname $0) ; dirname $(pwd) )
          #$NLS-E$ "$CANDLEHOME/bin may have to be removed manually after
          #         this script completes"
          [[ $(pwd) = "$CANDLEHOME/bin" || "$CANDLEHOME" = "$cmdHome" ]] &&
            Err_report warn "$CANDLEHOME/bin $(nls_replace 'KCI0238I')"
          #$NLS-E$ "Purging $CANDLEHOME"
          Err_report warn "$(nls_replace 'KCI0239I') $CANDLEHOME"
          if [[ -f $CANDLEHOME/registry/AutoStart ]]; then
            remove_autostart
          fi

          hp_forcewait
          hp_dld_sl_conf;                                             #IV76877

          rm -rf $CANDLEHOME
          if [[ -n "${CANDLEDATA}" ]]; then                           #214587
            rm -rf "${CANDLEDATA}";                                   #214587
          fi                                                          #214587

          remove_links
          ;;
      esac
      clean_up 1
    fi

    sort -u -o $infoTmp $infoTmp2
    typeset -i index=0
    while read pc ; do
      name=$(get_desc $pc)
      for vFile in $(ls ${pc}+(ai|hp|so|l)*.ver 2> /dev/null) ; do    #IV27849
        comp=${vFile%.ver}
        ${grepCmd} -q "preReqALL = ${comp}" ??+(ai|hp|so|l)*.ver;     #IV27849
        if [[ $? -eq 0 ]]; then                                       #IV27849
          # this component is a prereq of other component,
          # it shouldn't be selected to uninstall, just skip it
          continue
        fi

        index=$index+1
        if [[ -z "$Response" ]]; then
          platform=${vFile#$pc}
          platform=${platform%.ver}
          vrmf=$(grep "^VRMF =" $vFile|cut -f3 -d" ")
          if [[ -z "$vrmf" ]]; then
            version=$(grep "^ver =" $vFile|cut -f3 -d" ")
            release=$(grep "^rel =" $vFile|cut -f3 -d" ")
            print "$index\t$pc  $platform\t v$version:r$release  $name"
          else
            vrmf1=$(print $vrmf| cut -c 1,2)
            vrmf2=$(print $vrmf| cut -c 3,4)
            vrmf3=$(print $vrmf| cut -c 5,6)
            vrmf4=$(print $vrmf| cut -c 7,8)
            print "$index\t$pc  $platform\t v$vrmf1.$vrmf2.$vrmf3.$vrmf4 $name"
          fi
        elif [[ "$Response" = $index ]]; then
          platform=${vFile#$pc}
          platform=${platform%.ver}
          vrmf=$(grep "^VRMF =" $vFile|cut -f3 -d" ")
          if [[ -z "$vrmf" ]]; then
            version=$(grep "^ver =" $vFile|cut -f3 -d" ")
            release=$(grep "^rel =" $vFile|cut -f3 -d" ")
            delVersion=$version
            delRelease=$release
          else
            vrmf1=$(print $vrmf| cut -c 1,2)
            vrmf2=$(print $vrmf| cut -c 3,4)
            vrmf3=$(print $vrmf| cut -c 5,6)
            vrmf4=$(print $vrmf| cut -c 7,8)
            delVersion=$vrmf1.$vrmf2.$vrmf3.$vrmf4
            delRelease=""
          fi
          delPC=$pc
          delPlatform=$platform
          delName=$name
          break
        fi
      done
    done < $infoTmp
    rm -f $infoTmp $infoTmp2

    # List displayed and user responded ... now process response

    # User entered something
    if [[ -n "$Response" ]]; then
      # User picked a valid product to uninstall
      if [[ -n "$delPC" ]]; then
        if [[ "$force" = "no" ]]; then
          if [[ -n "$delRelease" ]]; then
            #$NLS-E$ "Confirm:"
            confirm="$(nls_replace 'KCI0240I'):"
            confirm2="$delPC  $delPlatform  v$delVersion:r$delRelease $delName"
            #$NLS-E$ " ... OK to delete?"
            okDelete="... $(nls_replace 'KCI0241I')"
            #$NLS-E$ "1-yes"
            yes="1-$(nls_replace 'KCI0197I')"
            #$NLS-E$ "2-no"
            no="2-$(nls_replace 'KCI0198I')"
            #$NLS-E$ "\"2\" is default"
            default="\"2\" $(nls_replace 'KCI0199I')"
            #$NLS-E$ "Confirm: $delPC  $delPlatform  v$delVersion:r$delRelease
            #         $delName ... OK to delete? [ 1-yes, 2-no;
            #         "2" is default ]: "
            print -n "$confirm $confirm2 $okDelete [ $yes, $no; $default ]: "
          else
            #$NLS-E$ "Confirm:"
            confirm="$(nls_replace 'KCI0240I'):"
            confirm2="$delPC  $delPlatform  v$delVersion $delName"
            #$NLS-E$ " ... OK to delete?"
            okDelete="... $(nls_replace 'KCI0241I')"
            #$NLS-E$ "1-yes"
            yes="1-$(nls_replace 'KCI0197I')"
            #$NLS-E$ "2-no"
            no="2-$(nls_replace 'KCI0198I')"
            #$NLS-E$ "\"2\" is default"
            default="\"2\" $(nls_replace 'KCI0199I')"
            #$NLS-E$ "Confirm: $delPC  $delPlatform  v$delVersion $delName
            #         ... OK to delete? [ 1-yes, 2-no; "2" is default ]: "
            print -n "$confirm $confirm2 $okDelete [ $yes, $no; $default ]: "
          fi
          read answer
        else
          answer="y"
        fi
        case "$answer" in
          #$NLS-E$ "Uninstall product $delPC $delPlatform"
          y|Y|yes|YES|1)
            print "$(nls_replace 'KCI0247I' "$delPC" "$delPlatform")"

            # check if product is installed based on product ver file
            # and set isProdInstalled variable appropriately
            isProdInstalled="no"
            cd $regDir
            tmpVerFile=$delPC$delPlatform.ver
            if [[ -f $tmpVerFile ]]; then
              isProdInstalled="yes"
            fi

            # This returns JAVA_HOME to us on the command line
            # - set to variable and use
            if [[ -f $CANDLEHOME/bin/CandleGetJavaHome ]]; then
              export JAVA_HOME=$($CANDLEHOME/bin/CandleGetJavaHome)
            else
              export JAVA_HOME=
            fi

            if [[ "$isProdInstalled" = "yes" ]]; then
              if [[ -n "$JAVA_HOME" ]]; then
                # Call the uninstall-process handler
                uninstall_process $delPC $delPlatform
                result=$?
                # Call the uninstall callpoint funtion
                if [[ $result -eq 0 ]]; then
                  uninstall_callpoint $delPC
                  result=$?
                fi
              fi
            fi

            if [[ $result -eq 1 ]]; then
              #$NLS-E$ "Cancel Uninstall..."
              print "$(nls_replace 'KCI1290I')"
            elif [[ $result -eq 0 ]]; then
              # The uninstall_product function will check if the package
              # is installed and display a message if not found.
              uninstall_product $delPC $delPlatform
              # if installed product was successfully uninstalled with
              # all prerequisites and was executed by non-root,
              # show additional message to the user
              if [[ "$isProdInstalled" = "yes" ]]; then
                if [[ "$(whoami)" != "root" ]]; then
                  #$NLS-E$ You have to be a root user to update auto
                  #        restart script
                  Err_report warn "$(nls_replace 'KCI1167I')"
                fi
              fi
            elif [[ $result -eq 2 ]]; then
              # uninstall.sh failed.
              clean_up 2
            fi
            delPC=""
            ;;
        esac
      else
        #$NLS-E$ "$Response was not a valid selection, please try again"
        nls_replace 'KCI0242I' $Response
      fi
      Response=""

    # User entered nothing, or first time thru ..
    # just prompt for a selection (or exit)
    else
      #$NLS-E$ "\nEnter number for a product to uninstall or \"99\" to exit: "
      print -n "\n$(nls_replace 'KCI0243I' \"99\") "
      read Response
      case "$Response" in
        x|X|exit|EXIT|99) clean_up
          ;;
      esac
    fi
  done
fi

clean_up
