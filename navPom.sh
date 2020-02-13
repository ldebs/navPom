#!/bin/bash

defDir=~/
defPomListName=pom_list_name.txt
defPomList=$defDir/$defPomListName

N="\\033[0m";_B="\\033[1m";_U="\\033[4m";_K="\\033[5m";_I="\\033[7m"
DG="\\033[30m";R="\\033[31m";G="\\033[32m";Y="\\033[33m";B="\\033[34m";P="\\033[35m";C="\\033[36m";LG="\\033[37m";K="\\033[38m"
DG_="\\033[40m";R_="\\033[41m";G_="\\033[42m";Y_="\\033[43m";B_="\\033[44m";P_="\\033[45m";C_="\\033[46m";LG_="\\033[47m"

echo -e "\
$_U$Y                                            $N$Y
||                                        ||
||  $C ▐ ▄  ▄▄▄·  ▌ ▐·$B ▄▄▄·      • ▌ ▄ ·.   $Y||
||  $C•█▌▐█▐█ ▀█ ▪█·█▌$B▐█ ▄█▪     ·██ ▐███▪  $Y||
||  $C▐█▐▐▌▄█▀▀█ ▐█▐█•$B ██▀· ▄█▀▄ ▐█ ▌▐▌▐█·  $Y||
||  $C██▐█▌▐█ ▪▐▌ ███ $B▐█▪·•▐█▌.▐▌██ ██▌▐█▌  $Y||
||  $C▀▀ █▪ ▀  ▀ . ▀  $B.▀    ▀█▄▀▪▀▀  █▪▀▀▀  $Y||
$_U||                                        ||$N
"

in=$1
shift
[[ "$in" == "" ]] && in=./$defPomListName && echo -e "${R}No input file argument,$Y use $in$N" 1>&2
[ ! -e $in ] && echo -n -e "${R}$in does not exist," 1>&2 && in=$defPomList && echo -e "$Y use $in$N" 1>&2
[ ! -e $in ] && echo -e "${R}$in does not exist,$Y create it with :m$N" 1>&2

myHist=$(dirname $0)/.$(basename $0)_history
history -r $myHist

writeHist(){
  local cmd="$1"; shift
  [[ "$cmd" != "" ]] && history -s -- "$cmd"
  local tmpHist=/tmp/$(basename $0)_$$_history
  history -w $myHist
  cat -n $myHist | sort -rk2 | sort -uk2 | sort -nk1 | cut -f2- > $tmpHist
  cp $tmpHist $myHist
  rm $tmpHist
  [[ "$cmd" != "" ]] && history -c && history -r $myHist
}

saveHistoryAndExit(){
  writeHist
  exit
}
trap saveHistoryAndExit SIGINT SIGTERM SIGTSTP

trim(){
  local var=$1
  local val=${!var}
  val="$(sed -e "s/^ *\(.*\) *$/\1/" -e "s/\\$/\\\\$/g" <<< "$val")"
  eval "$var=\"$val\""
}

searchIn(){
  local filter=$1; shift
  printSearch "$filter" "$($grepArg "$in" | grep "$filter")"
}

printSearch(){
  local filter="$1"; shift
  local resSearch="$1"; shift
  while IFS=';' read -ra res; do
    [[ "$printDep" == "no" ]] && deps="${LG}deps=...$(awk "/$filter/ {print(\"\\$R$filter\\$LG...\")}" <<< "${res[4]}")$N"
    [[ "$printDep" == "yes" ]] && deps="$LG$(sed -e "s/$filter/\\$R$filter\\$LG/" <<< "${res[4]}")$N"
    echo -e "\
$G$(sed -e "s/$filter/\\$R$filter\\$G/" <<< "${res[0]}")$N \
$_B$LG$(sed -e "s/$filter/\\$_I\\$R$filter\\$N\\$_B\\$LG/" <<< "\n  ${res[1]}")$N \
$P$(sed -e "s/$filter/\\$_B\\$R$filter\\$N\\$P/" <<< "\n    ${res[2]}")$N \
$B$(sed -e "s/$filter/\\$R$filter\\$B/" <<< "${res[3]}")$N \
$deps"
  done <<< "$(sed -e "s/ /;/" -e "s/ /;/" -e "s/ /;/" -e "s/ /;/" <<< "$resSearch")"
}

getChild(){
  local parent=$1; shift
  line="$($grepArg "$in"  | grep "parent=$parent")"
  sed "s/.*pom=\([^ ]*\).*/\1/" <<< "$line" | sort -u
}

getDep(){
  local parent=$1; shift
  line="$($grepArg "$in" | grep -P "deps(=|.* )$parent( |$)")"
  sed "s/.*pom=\([^ ]*\).*/\1\\$N\\$DG dependency\\$N/" <<< "$line" | sort -u
}

getField(){
  local field=$1; shift
  local line=$1; shift
  sed "s/.*$field=\([^:]*:[^:]*\):.*/\1/" <<< "$line"
}

getPomLine(){
  local pom=$1; shift
  grep "$pom" "$out" | head -n 1
}

makePomHier(){
  dir=$1
  [[ "$dir" == "" ]] && dir=$defDir && echo "No dir argument, set to $dir" 1>&2
  shift
  out=$1
  [[ "$out" == "" ]] && out=$defPomList && echo "No output file argument, set to $out" 1>&2
  shift
  echo -e dir=$B$dir$N out=$B$out$N
  in=$out

  cd $dir

  echo Find repos 1>&2
  repos=$(find -type d |sort -u | grep -v -e "/target" -e "/bin" | grep  "\.git$" | sed -e "s:^\./::" -e "s:/.git::" -e 's:$:/:')
  echo Find poms 1>&2
  poms=$(find -name "pom.xml" | grep -v -e "/target/" -e "/bin/" | sort -u | sed "s:^\./::")
  nbp=$(wc -l <<< "$poms")
  echo $nbp 1>&2

  i=1
  for p in $poms; do
    echo -en "$G$i/$nbp$B $p$N " 1>&2
    line=""

    # parent GAV
    echo -n "gp " 1>&2
    gp=$(xmllint --xpath "/*[local-name()='project']/*[local-name()='parent']/*[local-name()='groupId']/text()" $p 2>/dev/null)
    echo -n "ap " 1>&2
    ap=$(xmllint --xpath "/*[local-name()='project']/*[local-name()='parent']/*[local-name()='artifactId']/text()" $p 2>/dev/null)
    echo -n "vp " 1>&2
    vp=$(xmllint --xpath "/*[local-name()='project']/*[local-name()='parent']/*[local-name()='version']/text()" $p 2>/dev/null)

    # pom GAV
    echo -n "g " 1>&2
    g=$(xmllint --xpath "/*[local-name()='project']/*[local-name()='groupId']/text()" $p 2>/dev/null)
    [[ "$g" == "" ]] && g=$gp
    echo -n "a " 1>&2
    a=$(xmllint --xpath "/*[local-name()='project']/*[local-name()='artifactId']/text()" $p 2>/dev/null)
    echo -n "v " 1>&2
    v=$(xmllint --xpath "/*[local-name()='project']/*[local-name()='version']/text()" $p 2>/dev/null)
    [[ "$v" == "" ]] && v=$vp

    gav="$g:$a:$v"
    gavp="$gp:$ap:$vp"
    line="$line$p pom=$gav parent=$gavp "

    # project
    echo -n "prj " 1>&2
    prj=""
    ep=${p/pom.xml/.project}
    [ -e $ep ] && prj=$(xmllint --xpath "/*[local-name()='projectDescription']/*[local-name()='name']/text()" $ep 2>/dev/null)
    [[ "$prj" == "" ]] && prj="-no-prj-"
    line="${line}project=$prj "

    # dependencies
    echo -n "dep " 1>&2
    deps=$(xmllint --noblanks --xpath "//*[local-name()='dependency']" $p  2>/dev/null)
    [[ "$deps" == "" ]] && deps="-no-dep-" || deps=$(sed -e "s:</dependency>:% :g" -e "s:</\?groupId>::g" -e "s:<dependency>::g" -e "s/<artifactId>/:/g" -e "s%</artifactId>\(<version>\)\?%:%g" -e 's/<!--[^-]*-->//g' -e "s:\(</artifactId>\|</version>\)[^%]*%::g" <<< "$deps")
    line="${line}deps=$deps "

    lines="$lines$(dirname $p)/\n$line\n"
    ((i++))
    echo 1>&2
  done

  echo "$dir" > "$out"
  echo -e "$lines$repos" | LC_ALL=C sort >> "$out"


  i=1
  echo Resolve dependencies versions 1>&2
  while read -u 10 line
  do
    if grep -q "pom.xml" <<< "$line" > /dev/null 2>&1; then 
      pom=$(getField pom "$line")
      echo -e -n "$G$i/$nbp $B$pom$N " 1>&2
      if grep -q "deps=.*\\$" <<< "$line" > /dev/null 2>&1; then
        sedExp=""
        versToSearch=$(sed 's/ /\n/g' <<< "$line" | grep "\\$" | sed 's/.*\${\([^}]*\)}/\1/')
        for v in $versToSearch; do
          if grep -q "%\${$v}%" <<< "$sedExp" > /dev/null 2>&1; then continue; fi
          parent="pom=$(getField pom "$line")"
          echo -n "$v " 1>&2
          val=""
          j=1
          while [[ j -le 10 && "$val" == "" && "$parent" != "pom=:" ]]; do
            pomLine=$(getPomLine $parent)
            curFile=$(cut -d" " -f1 <<< "$pomLine")
            [[ "$curFile" == "" ]] && break
            val=$(grep "<$v>" $curFile | sed "s%.*<$v>\(.*\)</$v>.*%\1%g")
            [[ "$val" == "" ]] && parent="pom=$(getField parent "$pomLine")"
            ((j++))
          done
          [[ j == 11 ]] && echo "$R>$N " 1>&2
          [[ "$val" == "" ]] && val="\${$v}" || val="$v=$val"
          sedExp="$sedExp -e 's%\${$v}%$val%g'"
        done
        line=$(eval sed $sedExp <<< "$line")
      fi
      echo 1>&2
      ((i++))
    fi
    echo "$line" >> /tmp/dep_ver_$$_out
  done 10< "$out"
  \cp -f /tmp/dep_ver_$$_out "$out"
  \rm -f /tmp/dep_ver_$$_out
}

tree(){
  level=0
  maxLevel=20
  donesPom=""
  if [[ "$search" == -l* ]]; then
    maxLevel=$(sed "s/-l *\([0-9]*\) .*/\1/" <<< "$search")
    search=$(sed "s/-l *[0-9]* \(.*\)/\1/" <<< "$search")
  fi
  lastSearch=$search
  line="$($grepArg "$in" | grep -P "pom=[^ ]*$search")"
  pom="$(sed -e "s/.*pom=\([^:]*\):\([^:]*\):.*/\1:\2/" <<< "$line")"
  poms="$(sed -e "s/.*pom=\([^:]*\):\([^:]*\):\([^ ]*\).*/\1:\\$R\2\\$N:\3/" <<< "$line")"
  parent=$(sed "s/.*parent=\([^ ]*\):[^:]* .*/\1/" <<< "$line")
  while [[ "$parent" != :* && "$parent" != "" ]]; do
    grepParent=$(sed "s/^/-e pom=/" <<< "$parent")
    line="$($grepArg "$in" | grep $grepParent)"
    if [[ "$line" != "" ]]; then
      curPom="$(sed "s/.*pom=\([^ ]*\).*/\1/" <<< "$line")"
      parent=$(sed "s/.*parent=\([^ ]*\):[^:]* .*/\1/" <<< "$line" | sort -u)
      poms="$curPom
$(sed "s/^/  /" <<< "$poms")"
    else
      parent=""
    fi
  done

  echo -e "\nPARENTS:\n$poms"

  echo -e "\nCHILDS:"

  childs=""
  grepPom=$(sed "s/^/-e pom=/" <<< "$pom")
  line="$($grepArg "$in" | grep $grepPom)"
  newDeps=$(getDep $pom | sed "s/^/0 /")
  newChilds=$(getChild $pom | sed "s/^/0 /")
  toBrowse=$(grep -v "^$" <<< "$newChilds
$newDeps")
  while [[ "$toBrowse" != "" ]]; do
    browsed=$(head -n 1 <<< "$toBrowse")
    trim browsed
    toBrowse=$(tail -n +2 <<< "$toBrowse")
    if [[ "$browsed" != "" ]]; then
      level=$(cut -d" " -f1 <<< "$browsed")
      cur=$(cut -d" " -f2- <<< "$browsed")
      child="$(for((i=0; i<level; i++));do echo -n "  "; done)$cur"
      if [[ $level -lt $maxLevel ]]; then
        curPom="$(sed -e "s/^\([^:]*\):\([^:]*\):.*/\1:\2/" <<< "$cur")"
        if ! grep -q "$curPom" <<< "$donesPom" > /dev/null 2>&1; then
          newDeps=$(getDep $curPom | grep -v -E "^$" | sed "s/^/$((level + 1)) /")
          newChilds=$(getChild $curPom | grep -v -E "^$" | sed "s/^/$((level + 1)) /")
          toBrowse=$(grep -v "^$" <<< "$newChilds
$newDeps
$toBrowse")
        else
          child="$G$child$G-->$N"
        fi
      else
        child="$Y$child$Y...$N"
      fi
      echo -e "$child"
    fi
    donesPom="$donesPom
$curPom"
  done
}

grepArg="cat"
printDep=no
while true
do
  echo -e "${Y}---- search / !cmd / -g grep options / -d / :vi file / :t [-l limit] artifact / :m [pom list file] [search dir] / :q $N "
  read -e -p "> " search
  if [[ "$search" != "" ]]; then
    writeHist "$search"
    if [[ "$search" == -g* ]]; then
      search=$(cut -c3- <<< "$search")
      if [[ "$search" == "" ]]; then
        grepArg="cat"
      else
        grepArg="grep $search"
      fi
      echo $grepArg
    elif [[ "$search" == "-d" ]]; then
      [[ "$printDep" == "no" ]] && printDep=yes || printDep=no
      echo Print dependencies = $printDep
    elif [[ "$search" == !* ]]; then
      cmd="$(cut -c2- <<< "$search")"
      echo "$cmd"
      eval "$cmd"
    elif [[ "$search" == :vi* ]]; then
      eval "vim \"+/$lastSearch\" $(cut -c4- <<< "$search")"
    elif [[ "$search" == :m* ]]; then
      search=$(cut -c3- <<< "$search")
      trim search
      pomFile="$in"
      [[ "$search" != "" ]] && pomFile="$(awk '{print $1}' <<< "$search")" \
                            && makePomDir="$(awk '{print $2}' <<< "$search")"
      [[ "$makePomDir" == "" ]] && makePomDir=$(head -1 "$pomFile" 2>/dev/null)
      [[ "$makePomDir" == "" ]] && makePomDir=$(head -1 "$in" 2>/dev/null)
      makePomHier "$makePomDir" "$pomFile"
    elif [[ "$search" == :t* ]]; then
      search=$(cut -c3- <<< "$search")
      trim search
      [[ "$search" == "" ]] && search=$lastSearch
      if [[ "$search" != "" ]]; then
        tree
      fi
    elif [[ "$search" == :q* ]]; then
      saveHistoryAndExit
    else
      lastSearch=$search
      searchIn "$search"
    fi
  fi
done
