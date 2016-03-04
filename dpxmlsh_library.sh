#!/bin/bash
#
# Author:  Harley Stenzel <hstenzel@us.ibm.com>
# Description: A shell library for working with the DataPower XML Management
# Interface.
#
# These functions are designed to be sourced into either a running shell or
# into another shell script.  
#
# Functions beginning with "_" are internal, and not for general use
# dpxmlsh_init does all the normal startup, common arg parsing, etc
# dpxmlsh_[amp|soma]_* functions take appropriate input (usually files
#   or args) and return an xml result on stdout.  The functions are
#   named after the underlying xml management methods.
# dpxmlsh_* generally use their amp or soma counterparts directly or
#   indirectly to deliver some easily usable function.  For instance,
#   get_status_* methods all call get status and return the result
#   in a different but useful form.  ls and lls are named after the
#   common command and alias for listing files. The functions get_file
#   and set_file do just what one would expect.  Tab completion helps.
#

DPXMLSH_VERSION=0.64

# Changes
# 0.64 2016-03-04:
#  * Disable the password selftest, runs afowl the repeated pw check
#  * Disable the testhardware selftest, not applicable on all platforms
# 0.63 2016-01-04:
#  * Add missing domain on set-file and get-file
#  * Add createdir and removedir
#  * selftest works on non-default domains
# 0.62 2014-12-08:
#  * Fix dpxmlsh_help so init args are displayed.
# 0.61 2014-09-24:
#  * Add action_testhardware
# 0.61 2014-09-23:
#  * Better checks for the xmlstarlet command
# 0.59 2014-05-01:
#  * Prompt in interactive mode now uses the whole ip address
#    if the host is specified numerically.
#  * Add netrc sanity checking and error message
# 0.58 2014-03-18:
#  * Better handle missing command completion dependencies
#  * Remove flags for command completion
# 0.57 2014-03-15:
#  * Minor tweak to user setting when netrc auth is used
# 0.56 2014-02-15:
#  * Bash completion for config objects
# 0.55 2014-01-10:
#  * Bash completion for files and status providers is function complete
#  * removed the colon-removing "normalization"
# 0.54 2013-12-11:
#  * Begin using bash command line completion for files on DataPower
# 0.53 2013-12-11:
#  * Use bash command line completion for status instead of warnings
# 0.52 2013-12-02:
#  * Add to git
#  * Few help cleanups
# 0.51 2013-10-30:
#  * Begin work on a better exit code, see dpxmlsh_soma_get_status.
#    Consider others in future versions.  It's a pattern that could
#    work for all but the get_file, which may return too much data.
#  * rename dpxmlsh_soma_deletefile to dpxmlsh_soma_action_deletefile
#  * add dpxmlsh_[soma_]action_changepassword
#  * add dpxmlsh_[soma_]action_saveconfig
#  * rename dpxmlsh_*action_exec_config -> dpxmlsh_action_execconfig
#  * rename dpxmlsh_*deletefile -> dpxmlsh*_action_deletefile
#  * Better boilerplate for standard handling of new soma actions
# 0.50 2013-10-28:
#  * Add subshell mode.  Can now simply exec the script library
#    to get a subshell.  Prompt includes [dphost:dpuser:dpdomain]
#    prefixed to the existing prompt.
#  * Add --interactive / --script.  This suppresses downloading
#    the list of status commands that are used for command completion.
#    This is good for building scripts that call _init.
# 0.49 2013-08-23:
#  * Fix bug with second init leading to xmlstarlet/xml not found
#  * Add dpxmlsh_version to see metainfo about this script
#  * Add dpxmlsh_unload to remove all functions and internal variables
#    used in this shell library.  Does not clean up things created
#    by the user using the library.
#  * Better cleanup on source
# 0.48 2013-08-01:
#  * Pretty print xml results that are not set file
#  * Detect if "xmlstarlet" is called "xml"
# 0.47 2013-07-18:
#  * Fix bug where error was reported incorrectly on an empty status
#    provider result
#  * Pretty up the selftest output
#  * Rename dpxmlsh_get_status_evaldump to dpxmlsh_get_status_evalprint
# 0.46 2013-07-02:
#  * Add --verbose for putting orig xml on stderr
#  * add soma_get_config,  get_config_list, and get_config_import
# 0.45 2013-06-19:
#  * Add label support to get_status_vtable and get_status_list
#  * Add get_status_eval*, the full-featured cousin to _import
#  * Make init fast and cheap for subsequent calls
# 0.44 2013-06-14:
#  * clean up the selftest so examples are more obvious
# 0.43 2013-06-13:
#  * Add get_status_import, which sucks an entire status provider into
#    arrays in memory. Check self_test for examples, and the comments
#    for the caveats.
# 0.42 2013-06-13:
#  * Add get_status_vtable, which makes it very easy to work with
#    multi-row tables.  See the comments for examples, and also
#    the example in selftest
# 0.41 2013-06-12:
#  * Fix bug in table status provider where unpopulated columns are
#    mishandled.  Now put a "-" in any empty field as a placeholder.
#  * Get status providers from init so it is only done once.
# 0.4 2013-06-11:
#  * Improve the status provider table layout -- use columns for pretty
#    formatting and turn spaces into underlines so the result is cut and
#    awk friendly.
#  * Improve status provider list output -- include status provider name
#    as part of the name
#  * Add "edit".
#  * Rename file so that it includes the word "library"
# 0.3 2013-06-11: 
#  * Add general purpose status provider handling in 3 formats:
#    XML, Table, and List
#  * Remove dependency on xmllint -- xmlstarlet can fulfil its function
# 0.2 2013-04-14: start using xmlstarlet -- an easy command line xslt tool
# 0.1 2013-03-27: framework takes shape
#  * working functions and unit test harness
# 0.0 2013-03-26: a few functions thrown in a file
#
# ToDo
# * Test domain support
# * figure out better way to get return codes
# * Fill out action and config set
# * Move to current xmlmgmt, not 2004

if [ "$_DPXMLSH_BASHRCFILE" != "" -a "$DPXMLSH_SCRIPT" != "true" ]
then
  if [ -e "/etc/bash.bashrc" ]; then
    . "/etc/bash.bashrc"
  fi
  if [ -e "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
  fi
  PS1="[\$_DPXMLSH_DPHOST_PROMPT:\$_DPXMLSH_DPUSER:\$_DPXMLSH_DPDOMAIN]$PS1"
fi

export _DPXMLSH_BASHRCFILE=""
if [ "$0" != "bash" -a "$DPXMLSH_SCRIPT" != "true" ]
then
  case "$0" in
  .*)
    _DPXMLSH_BASHRCFILE="${PWD}/$0"
    ;;
  /*)
    _DPXMLSH_BASHRCFILE="$0"
    ;;
  *)
    _DPXMLSH_BASHRCFILE="$(which $0)"
    ;;
  esac
  echo >&2
  echo "ATTENTION: Entering dpxmlsh subshell." >&2
  echo "Use \"dpxmlsh_init\" to get started or \"dpxmlsh_help\" for more info.  Tab-completion makes it easy!" >&2
  echo "Enjoy!" >&2
  echo >&2
  bash --rcfile "$_DPXMLSH_BASHRCFILE" -i
  echo "ATTENTION: Leaving dpxmlsh subshell" >&2
fi

function dpxmlsh_unload ()
{
  eval $(set | grep -e ^_DPXMLSH_ -e '^_*dpxmlsh_.* \(\)$' | sed -e 's/=.*//g' -e 's/ .*$//g' -e 's/^/unset /g')
}

# the dpxmlsh globals and functions, ensure they're unset at load
dpxmlsh_unload

function dpxmlsh_help ()
{

  cat <<-EOF

	dpxmlsh -- working with a DataPower appliance via XML management from the
	bash command line or shell script.

	There are 3 steps to profit:

	1) Run the script.  This will place you in a subshell.  Alternatively, you can
	Source or import the script library.  This is  done once for the lifetime of the
	interactive shell or shell script.  Note the leading dot+space!  That is *not* a typo!
	    i.e.: . /path/to/dpxmlsh.sh 
	2) Initialize the script library by calling the dpxmlsh_init function
	    i.e.: dpxmlsh_init -u admin -p supersercredpassword -h mydpappliance
	3) Call the functions in the library for fun and profit.
	    i.e.: dpxmlsh_ls
	          dpxmlsh_edit local:/myfile.xsl
	          dpxmlsh_get_file temporary:/internal-state.txt
	          dpxmlsh_get_status_list Version
	          dpxmlsh_get_status_table TCPTable
	          dpxmlsh_set_firmware_and_accept_license myfirmware.scrypt3

	Note that if you want to ensure that the script library is working properly, use the
	dpxmlsh_selftest function that exercises a significant portion of the library in a
	non-destructive fashion.  Additionally, _selftest prints examples of how many of the
	functions should be called.

	dpxmlsh_init takes the following args:
	$(set | sed -n '/^dpxmlsh_switch/,/^}/p' | grep "^ *-.*)" | sed 's/^ */    /g')

	Note that the user defaults to "admin", the domain to "default", the port to 5550,
	and the password inherited from ~/.netrc (see man netrc), so the only thing that
	must be specified is the host.

	The high-level functions, which are usable but user/script alone, without
	need for additional xml processing:
	$(set | grep "^dpxmlsh_[^ ]* ()" \
              | grep -v -e '_init' -e '_amp_' -e '_soma_' \
              | sort | sed -e 's/^/    /g' -e 's/ ()//g' )

	The low-level, xml-result-emitting functions are:
	$(set | grep "^dpxmlsh_[^ ]* ()" \
              | grep -e '_amp_' -e '_soma_' \
              | sort | sed -e 's/^/    /g' -e 's/ ()//g' )

	EOF
}

# Let the exit code of a series of pipes reflect the first failing command.
# Add the following command *immediately* after the series of pipes.
#  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
_dpxmlsh_pipestatus ()
{
  local rc
  local caller="$1"
  shift
  for rc in $*
  do
    if [ "$rc" != 0 ]
    then
      echo "ERROR: $caller pipestatus $*, returning $rc" >&2
      return $rc
    fi
  done
  return 0
}

# globals used by dpxmlsh
function _dpxmlsh_globals_init ()
{
  export _DPXMLSH_CURLSOMACMD=""
  export _DPXMLSH_CURLAMPCMD=""
  export _DPXMLSH_STATUSPROVIDERS=""
  export _DPXMLSH_DEBUGDIR="$HOME/dpxmlsh-debug"
  export _DPXMLSH_DPDOMAIN="default"
  export _DPXMLSH_DEBUG="false"
  export _DPXMLSH_VERBOSE=false
  export _DPXMLSH_DPHOST=""
  export _DPXMLSH_DPHOST_PROMPT=""
  export _DPXMLSH_DPUSER=admin
  export _DPXMLSH_DPPASS=""
  export _DPXMLSH_DPXMLPORT=5550
}
_dpxmlsh_globals_init

# Called at the onset, and whenever the user, hostname, password, auth
# method, domain, etc changes.
function dpxmlsh_init ()
{
  if [ -z "$_DPXMLSH_CURLSOMACMD" ]
  then
    # check prereqs
    test "$BASH" \
      || { echo "ERROR: $FUNCNAME only the bash shell is supported" >&2 ; return 1; }
    curl -V | grep -q -i ssl \
      || { echo "ERROR: $FUNCNAME curl missing or does not support ssl" >&2 ; return 1; }

    export _DPXMLSH_XMLSTARLET=""
    local WOOHOO_XMLSTARLET=$( echo "<top><node>woohoo</node></top>" | xmlstarlet sel --template --match '//node' --value-of '.' 2>/dev/null )
    local WOOHOO_XML=$( echo "<top><node>woohoo</node></top>" | xml sel --template --match '//node' --value-of '.' 2>/dev/null )
    if [ "$WOOHOO_XMLSTARLET" = "woohoo" ]
    then
      _DPXMLSH_XMLSTARLET="xmlstarlet"
    elif [ "$WOOHOO_XML" = "woohoo" ]
    then
      _DPXMLSH_XMLSTARLET="xml"
    else
      echo "ERROR: $FUNCNAME xmlstarlet/xml missing" >&2 
      return 1
    fi

    local opensshtest="$(echo 2bornot2b | openssl enc -base64 -a -A | openssl enc -base64 -A -d)"
    test "2bornot2b" = "$opensshtest"  \
      || { echo "ERROR: $FUNCNAME openssl missing or not functional" >&2 ; return 1; }
    { echo "a b c"; echo "def  g hij" ; } | column -t > /dev/null \
      || { echo "ERROR: $FUNCNAME 'column' command missing or not functional" >&2 ; return 1; }
      
  fi

  _dpxmlsh_globals_init
  dpxmlsh_switch "$@"
}

# Like init, except that it leaves current settings in place
function dpxmlsh_switch ()
{
  while [[ $# -gt 0 ]]
  do
    case $1 in

    --help)
      dpxmlsh_help
      return 0
      ;;

    -h|--host|--dp-host)
      shift
      _DPXMLSH_DPHOST="$1"
      # it's an ip address if it's all digits and dots or if it contains a ":" (ipv6).
      if [ "$(echo $_DPXMLSH_DPHOST | tr -d '0-9.')" = "" ] || echo "$_DPXMLSH_DPHOST" | grep -q ":" 
      then
        _DPXMLSH_DPHOST_PROMPT="$_DPXMLSH_DPHOST"
      else
        _DPXMLSH_DPHOST_PROMPT="$(echo $1 | cut -d. -f1)"
      fi
      ;;
  
    -u|--user|--dp-user)
      shift
      _DPXMLSH_DPUSER="$1"
      ;;
  
    -p|--pass|--passwd|--password|--dp-pass|--dp-passwd|--dp-password)
      shift
      _DPXMLSH_DPPASS="$1"
      ;;
  
    -d|--domain|--dp-domain)
      shift
      _DPXMLSH_DPDOMAIN="$1"
      ;;
  
    -P|--port|--dp-port|--dp-xml-mgmt-port)
      shift
      _DPXMLSH_DPXMLPORT="$1"
      ;;
  
    --debug)
      set -x
      _DPXMLSH_DEBUG="true"
      mkdir -p "$_DPXMLSH_DEBUGDIR" || { echo ERROR: could not make "$1" >&2 ; return 1 ; }
      ;;
    --no-debug)
      set +x
      _DPXMLSH_DEBUG="false"
      ;;

    --verbose)
      _DPXMLSH_VERBOSE=true
      ;;
    --no-verbose)
      _DPXMLSH_VERBOSE=false
      ;;

    --debug-dir)
      shift
      _DPXMLSH_DEBUGDIR="$1"
      mkdir -p "$_DPXMLSH_DEBUGDIR" || { echo ERROR: could not make "$1" >&2 ; return 1 ; }
      ;;
  
    *)
      echo Warning: invalid arg $1 >&2
      ;;
  
    esac
    shift
  done
  
  if [ -z "$_DPXMLSH_DPHOST" ] ; then
    echo "ERROR:  Must specify -h <dphostname>" >&2 
    _DPXMLSH_DPDOMAIN=""
    _DPXMLSH_DPUSER=""
    return 1
  fi

  local _DPXMLSH_CURLAUTH=""
  if [ -z "$_DPXMLSH_DPPASS" ] 
  then
    if [ -r $HOME/.netrc ] && \
        cat "$HOME/.netrc" \
          | grep "machine $_DPXMLSH_DPHOST " \
          | grep "login .*" \
          | grep "password .*" >/dev/null 2>&1
    then
      _DPXMLSH_CURLAUTH="--netrc"
      _DPXMLSH_DPUSER="<netrc>"
    else
      dpxmlsh_help
      echo "ERROR:  Must specify -p <dppassword> or create ~/.netrc with line \"machine $_DPXMLSH_DPHOST login <myDPUser> password <myDPPassword>\"" >&2
      _DPXMLSH_DPDOMAIN=""
      _DPXMLSH_DPUSER=""
      return 1
    fi
  else
    _DPXMLSH_CURLAUTH="--user $_DPXMLSH_DPUSER:$_DPXMLSH_DPPASS"
  fi

  local _DPXMLSH_CURLSOMAURL="https://$_DPXMLSH_DPHOST:$_DPXMLSH_DPXMLPORT/service/mgmt/current"
  local _DPXMLSH_CURLAMPURL="https://$_DPXMLSH_DPHOST:$_DPXMLSH_DPXMLPORT/service/mgmt/amp/1.0"

  # this is the curl command we will use everywhere.
  _DPXMLSH_CURLSOMACMD="curl $_DPXMLSH_CURLAUTH --silent --insecure --data @- $_DPXMLSH_CURLSOMAURL"
  _DPXMLSH_CURLAMPCMD="curl $_DPXMLSH_CURLAUTH --silent --insecure --data @- $_DPXMLSH_CURLAMPURL"
}

# return true if we have a dp:result OK
function _dpxmlsh_soma_isresultok ()
{
  $_DPXMLSH_XMLSTARLET sel --noblanks --text -N dp="http://www.datapower.com/schemas/management" \
    --template --match '//dp:result' --value-of '.' --nl \
  | tr -d " " \
  | grep -q "^OK$"
  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

# the contents the document are passed as $1
function _dpxmlsh_soma_isok ()
{
  local DOCUMENT="$1"

  # return 1 if there is no dp:response in the document
  echo "$DOCUMENT" | grep -q "<dp:response " || return 1

  # return 1 if we have <env:Fault>
  echo "$DOCUMENT" | grep -q "<env:Fault>" && return 1

  # return 1 if we have a dp:result and it is not <dp:result>OK</dp:result>
  if echo "$DOCUMENT" | grep -q "<dp:result>"
  then
    echo "$DOCUMENT" \
      | $_DPXMLSH_XMLSTARLET sel --noblanks --text -N dp="http://www.datapower.com/schemas/management" \
        --template --match '//dp:result' --value-of '.' --nl \
      | tr -d " " \
      | grep -q "^OK$" \
      || return 1
  fi

  # otherwise, return 0 because there wasn't a fault and f there was a result, it wasn't OK
  return 0
}


# return true if we have a amp:tatus ok
function _dpxmlsh_amp_isresultok ()
{
  $_DPXMLSH_XMLSTARLET sel --noblanks --text -N amp="http://www.datapower.com/schemas/appliance/management/1.0" \
    --template --match '//amp:Status' --value-of '.' --nl \
  | grep -q "^ok$"
  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

# Used as a debug/monitor point to save off copies of the contents
# of the pipe at various points in the cycle.  Names files with
# a date stamp and a description of the monitor point.
# Takes args:  
#  1) The calling function name, 
#  2) the directionality (request, response, internal),
#  3) The suffix (usually xml, sometimes .base64.txt)
#
function _dpxmlsh_tee ()
{
  local callingfunction="$1"
  local direction="$2"
  local suffix="$3"
  # save a copy of strategic transforms in debug mode
  if [ "$_DPXMLSH_DEBUG" = "true" ]
  then
    tee "$_DPXMLSH_DEBUGDIR"/$( date +%Y%m%d_%H%M%S_%N ).$callingfunction-$direction.$suffix
  elif [ "$_DPXMLSH_VERBOSE" = "true" ]
  then
    case $direction in
    request|response)
      printf "\nvvvvvvvv verbose $direction vvvvvvvv\n" >&2
      tee /dev/fd/2
      printf "\n^^^^^^^^ verbose $direction ^^^^^^^^\n" >&2
      ;;
    *)
      cat
      ;;
    esac
  else
    cat
  fi
}

# Generic function to convert from the user version of a command to the xml version
# Generally called thusly:
# function dpxmlsh_action_<actionname> () { _dpxmlsh_shell2xml 2 2 "$FUNCNAME" "$@"; }
# where args are minimum-args, maximum-args, and the rest is boilerplate.  FUNCNAME
# is a BASH builtin that evaluates to the name of the current function, and
# transparently pass all the rest of the args along.
function _dpxmlsh_shell2xml ()
{
  local MINARGS="$1"
  local MAXARGS="$2"
  local SOMACMD="$(echo $3 | sed 's/^dpxmlsh_/dpxmlsh_soma_/g')"
  shift
  shift
  shift

  # check args
  [ $# -lt "$MINARGS" ] && { echo ERROR: $SOMACMD invalid number of args >&2 ; return 1; }
  [ $# -gt "$MAXARGS" ] && { echo ERROR: $SOMACMD invalid number of args >&2 ; return 1; }

  local RESULT=$($SOMACMD "$@")

  if _dpxmlsh_soma_isok "$RESULT"
  then
    return 0
  fi

  echo "$RESULT" | $_DPXMLSH_XMLSTARLET fo >&2
  echo "ERROR" >&2
  return 1
}


# transfer a single file from local $1 to datapower and call it $2
# $1 may be - for stdin or a real file
# $2 is represented in DataPower notation, i.e. store:///myfile.xml
function dpxmlsh_soma_set_file ()
{
  local FROM="$1"       # either a file or - for input on stdin
  local DPFILENAME="$2" # what the file is called in DP, such as temporary:myfile.xml

  {
    cat <<-EOF
	<?xml version="1.0" encoding="UTF-8"?>
	<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
	  <soapenv:Body>
	    <dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="$_DPXMLSH_DPDOMAIN">
	      <dp:set-file name="$DPFILENAME">
	EOF
    # cat is happy to take "-" as well, and cleverly we are happy to take
    # stdin to this function and let this instance of cat consume it
    cat $FROM \
      | openssl enc -base64 -a -A \
      | _dpxmlsh_tee $FUNCNAME internal base64.txt
    cat <<-EOF
	      </dp:set-file>
	    </dp:request>
	  </soapenv:Body>
	</soapenv:Envelope>
	EOF
  } | _dpxmlsh_tee $FUNCNAME request xml \
    | $_DPXMLSH_CURLSOMACMD \
    | _dpxmlsh_tee $FUNCNAME response xml \
    | $_DPXMLSH_XMLSTARLET fo
  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

# transfer a single file from local $1 to datapower and call it $2
# $1 may be - for stdin or a real file
# $2 is represented in DataPower notation, i.e. store:///myfile.xml
function dpxmlsh_set_file ()
{
  local FROM="$1"       # either a file or - for input on stdin
  local DPFILENAME="$2" # what the file will be called in DP, such as temporary:myfile.xml

  # check args
  [ $# = 2 ] || { echo dpxmlsh_soma_set_file ERROR, invalid number of args to dpxmlsh_soma_set_file >&2 ; return 1; }
  [ "$FROM" = "-" -o -r "$FROM" ] || { echo dpxmlsh_soma_set_file ERROR: $FROM not readable or stdin >&2 ; return 1; }

  local RESULT=$(dpxmlsh_soma_set_file "$FROM" "$DPFILENAME")

  if _dpxmlsh_soma_isok "$RESULT"
  then
    return 0
  fi

  echo "$RESULT" | $_DPXMLSH_XMLSTARLET fo >&2
  echo "ERROR" >&2
  return 1
}

# Get the file specified as an arg and give the soma xml result back on stdout
# Can't pretty-print it because get we'll run out of memory on big files
function dpxmlsh_soma_get_file ()
{
  local DPFILENAME="$1" # what the file is called in DP, such as temporary:myfile.xml
  { cat <<-EOF
	<?xml version="1.0" encoding="UTF-8"?>
	<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
	 <soapenv:Body>
	  <dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="$_DPXMLSH_DPDOMAIN">
	   <dp:get-file name="$DPFILENAME"/>
	  </dp:request>
	 </soapenv:Body>
	</soapenv:Envelope>
	EOF
  } | _dpxmlsh_tee $FUNCNAME request xml \
    | $_DPXMLSH_CURLSOMACMD \
    | _dpxmlsh_tee $FUNCNAME response xml
  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

# Get the file specified as an arg and give it back on stdout
function _dpxmlsh_get_file ()
{
  local DPFILENAME="$1" # what the file is called in DP, such as temporary:myfile.xml
  dpxmlsh_soma_get_file "$DPFILENAME" \
  | tr -d '\n' \
  | sed -e 's;^.*<dp:file name=[^>]*>;;g' -e 's;</dp:file>.*;;g'  \
  | _dpxmlsh_tee $FUNCNAME internal base64.txt \
  | openssl enc -base64 -A -d

  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}

# this is "better" than tr and sed, but it doesn't work because it runs out of memory
#    | $_DPXMLSH_XMLSTARLET sel --noblanks --text -N dp="http://www.datapower.com/schemas/management" \
#	--template --match '//dp:file' --value-of '.' --nl \
# gives: -:2: error: xmlSAX2Characters: huge text node: out of memory
}

# transfer a single file on DataPower called $1 to the local machine where
# it is called $2
# $1 is represented in DataPower notation, i.e. store:///myfile.xml
# $2 may be - for stdin or a real file
function dpxmlsh_get_file ()
{
  local DPFILENAME="$1" # what the file is called in DP, such as temporary:myfile.xml
  local TO="$2"	 # either a file or - for stdout

  if [ "$TO" = "-" -o -z "$TO" ]
  then
    _dpxmlsh_get_file "$DPFILENAME" 
  else
    _dpxmlsh_get_file "$DPFILENAME" > "$TO"
  fi
}

function dpxmlsh_action_changepassword () { _dpxmlsh_shell2xml 2 2 "$FUNCNAME" "$@"; }
function dpxmlsh_soma_action_changepassword ()
{
  local OLDPASSWORD="$1"
  local NEWPASSWORD="$2"
  { cat <<-EOF
	<?xml version="1.0" encoding="UTF-8"?>
	<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
	  <env:Body>
	    <dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="$_DPXMLSH_DPDOMAIN">
	      <dp:do-action>
	        <ChangePassword>
	          <OldPassword>$OLDPASSWORD</OldPassword>
	          <Password>$NEWPASSWORD</Password>
	        </ChangePassword>
	      </dp:do-action>
	    </dp:request>
	  </env:Body>
	</env:Envelope>
	EOF
  } | _dpxmlsh_tee $FUNCNAME request xml \
    | $_DPXMLSH_CURLSOMACMD \
    | _dpxmlsh_tee $FUNCNAME response xml \
    | $_DPXMLSH_XMLSTARLET fo

  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

function dpxmlsh_action_saveconfig () { _dpxmlsh_shell2xml 0 0 "$FUNCNAME" "$@"; }
function dpxmlsh_soma_action_saveconfig ()
{
  { cat <<-EOF
	<?xml version="1.0" encoding="UTF-8"?>
	<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
	  <env:Body>
	    <dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="$_DPXMLSH_DPDOMAIN">
	      <dp:do-action>
	        <SaveConfig/>
	      </dp:do-action>
	    </dp:request>
	  </env:Body>
	</env:Envelope>
	EOF
  } | _dpxmlsh_tee $FUNCNAME request xml \
    | $_DPXMLSH_CURLSOMACMD \
    | _dpxmlsh_tee $FUNCNAME response xml \
    | $_DPXMLSH_XMLSTARLET fo

  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

function dpxmlsh_deletefile () { echo "WARNING: $FUNCNAME deprecated, use dpxmlsh_action_deletefile instead" >&2 ; dpxmlsh_action_deletefile "$@"; }
function dpxmlsh_soma_deletefile () { echo "WARNING: $FUNCNAME deprecated, use dpxmlsh_soma_action_deletefile instead" >&2 ; dpxmlsh_soma_action_deletefile "$@"; }
# should have action in the name
function dpxmlsh_action_deletefile () { _dpxmlsh_shell2xml 1 1 "$FUNCNAME" "$@"; }
function dpxmlsh_soma_action_deletefile ()
{
  local DPFILENAME="$1" # what the file is called in DP, such as temporary:myfile.xml
  { cat <<-EOF
	<?xml version="1.0" encoding="UTF-8"?>
	<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
	  <env:Body>
	    <dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="$_DPXMLSH_DPDOMAIN">
	      <dp:do-action>
	        <DeleteFile>
	          <File>$DPFILENAME</File>
	        </DeleteFile>
	      </dp:do-action>
	    </dp:request>
	  </env:Body>
	</env:Envelope>
	EOF
  } | _dpxmlsh_tee $FUNCNAME request xml \
    | $_DPXMLSH_CURLSOMACMD \
    | _dpxmlsh_tee $FUNCNAME response xml \
    | $_DPXMLSH_XMLSTARLET fo

  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

function dpxmlsh_action_removedir () { _dpxmlsh_shell2xml 1 1 "$FUNCNAME" "$@"; }
function dpxmlsh_soma_action_removedir ()
{
  local DPDIRNAME="$1"
  { cat <<-EOF
	<?xml version="1.0" encoding="UTF-8"?>
	<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
	  <env:Body>
	    <dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="$_DPXMLSH_DPDOMAIN">
	      <dp:do-action>
	        <RemoveDir>
	          <Dir>$DPDIRNAME</Dir>
	        </RemoveDir>
	      </dp:do-action>
	    </dp:request>
	  </env:Body>
	</env:Envelope>
	EOF
  } | _dpxmlsh_tee $FUNCNAME request xml \
    | $_DPXMLSH_CURLSOMACMD \
    | _dpxmlsh_tee $FUNCNAME response xml \
    | $_DPXMLSH_XMLSTARLET fo

  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

function dpxmlsh_action_createdir () { _dpxmlsh_shell2xml 1 1 "$FUNCNAME" "$@"; }
function dpxmlsh_soma_action_createdir ()
{
  local DPDIRNAME="$1"
  { cat <<-EOF
	<?xml version="1.0" encoding="UTF-8"?>
	<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
	  <env:Body>
	    <dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="$_DPXMLSH_DPDOMAIN">
	      <dp:do-action>
	        <CreateDir>
	          <Dir>$DPDIRNAME</Dir>
	        </CreateDir>
	      </dp:do-action>
	    </dp:request>
	  </env:Body>
	</env:Envelope>
	EOF
  } | _dpxmlsh_tee $FUNCNAME request xml \
    | $_DPXMLSH_CURLSOMACMD \
    | _dpxmlsh_tee $FUNCNAME response xml \
    | $_DPXMLSH_XMLSTARLET fo

  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}
# get a list of all files on the appliance
function dpxmlsh_soma_get_filestore ()
{
  { cat <<- EOF
	<?xml version="1.0" encoding="UTF-8"?>
	<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
	<env:Body>
	<dp:request xmlns:dp="http://www.datapower.com/schemas/management"  domain="$_DPXMLSH_DPDOMAIN">
		<dp:get-filestore/>
	</dp:request>		
	</env:Body>
	</env:Envelope>
	EOF
  } | _dpxmlsh_tee $FUNCNAME request xml \
    | $_DPXMLSH_CURLSOMACMD \
    | _dpxmlsh_tee $FUNCNAME response xml \
    | $_DPXMLSH_XMLSTARLET fo

  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

function dpxmlsh_ls ()
{
  dpxmlsh_soma_get_filestore \
  | $_DPXMLSH_XMLSTARLET sel --template --match '//file' --value-of '../@name' --output '/' --value-of '@name' --nl \
  | grep -v '^$' 
  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}
function dpxmlsh_lls ()
{
  local file
  local size
  local date
  local time
  dpxmlsh_soma_get_filestore \
  | $_DPXMLSH_XMLSTARLET sel --template --match '//file' \
      --value-of 'size' \
      -o ' ' --value-of 'modified' \
      -o ' ' --value-of '../@name' --output '/' --value-of '@name' \
    --nl \
  | grep -v '^$' \
  | while read size date time file
    do
      printf "%9d %10s %8s %s\n" "$size" "$date" "$time" "$file"
    done
  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

function dpxmlsh_soma_get_config ()
{
  local DPOBJECTCLASS=""
  local DPOBJECTNAME=""
  local ARG1="$1"
  local ARG2="$2"

  # figure out a normalized object name to dp name mapping
  # this is only needed when both class name and object
  # name are specified.
  if [ ! -z "$ARG1" -a ! -z "$ARG2" ] ; then
    local NEWARG2
    NEWARG2=$(dpxmlsh_get_status_table ObjectStatus \
      | grep "^LinkAggregation" | awk '{print $4 " " $4}' \
      | sed 's/[- ]// ' | grep "^$ARG2 " | cut -d" " -f2)

    # If we don't get an answer (0 words) or we get more than
    # one answer (2 or more words) then stick with what was 
    # provided exactly.  Otherwise, the status provider
    # successfully mapped an object name!
    if [ $(echo "$NEWARG2" | wc -w) = 1 ] ; then
      ARG2="$NEWARG2"
    fi
  fi

  if [ ! -z "$1" ]; then
    DPOBJECTCLASS="class=\"$ARG1\""
  fi

  if [ ! -z "$2" ]; then
    DPOBJECTNAME="name=\"$ARG2\""
  fi

  { cat <<-EOF
	<?xml version="1.0"?>
	<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
	  <soapenv:Body>
	    <dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="$_DPXMLSH_DPDOMAIN">
	      <dp:get-config $DPOBJECTCLASS $DPOBJECTNAME/>
	    </dp:request>
	  </soapenv:Body>
	</soapenv:Envelope>
	EOF
  } \
    | _dpxmlsh_tee $FUNCNAME request xml \
    | $_DPXMLSH_CURLSOMACMD \
    | _dpxmlsh_tee $FUNCNAME response xml \
    | $_DPXMLSH_XMLSTARLET fo

  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

# Config in the form of a list of name-value pairs, separated by '=",
# with the value quoted.  As such, the result should be in form where it
# could be sourced into a script and used directly
# Note that each variable's name is transformed.  All spaces, dashes, dots
# and underlines in the orig name are removed for compliance with shell variable
# names or readability.  Underscores are used as separators.  Unnamed multi-
# instance variables are assigned an ordinal 0..n.  Variables are named in
# the form <PrefixName>_config_<<ObjectType_[objectname|instancenumber]>...>="value"
#
# Takes 3 args:
# 1: ObjectType (or "")
# 2: ObjectName (or "")
# 3: Prefix name (or "")
function dpxmlsh_get_config_list ()
{
  cat >/tmp/dpxmlsh_getconfig.$$.xsl <<-"EOF"
	<?xml version="1.0"?>
	<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	 xmlns:exslt="http://exslt.org/common"
	 xmlns:math="http://exslt.org/math"
	 xmlns:date="http://exslt.org/dates-and-times"
	 xmlns:func="http://exslt.org/functions"
	 xmlns:set="http://exslt.org/sets"
	 xmlns:str="http://exslt.org/strings"
	 xmlns:dyn="http://exslt.org/dynamic"
	 xmlns:saxon="http://icl.com/saxon"
	 xmlns:xalanredirect="org.apache.xalan.xslt.extensions.Redirect"
	 xmlns:xt="http://www.jclark.com/xt"
	 xmlns:libxslt="http://xmlsoft.org/XSLT/namespace"
	 xmlns:test="http://xmlsoft.org/XSLT/"
	 xmlns:dp="http://www.datapower.com/schemas/management"
	 extension-element-prefixes="exslt math date func set str dyn saxon xalanredirect xt libxslt test"
	 exclude-result-prefixes="math str">
	<xsl:output omit-xml-declaration="yes" indent="no" method="text"/>
	<xsl:param name="inputFile">-</xsl:param>
	<xsl:template match="/">
	  <xsl:call-template name="t1"/>
	</xsl:template>
	<xsl:template name="t1">
	  <xsl:for-each select="//*">
	    <xsl:for-each select="ancestor-or-self::*">
	      <xsl:if test="string-length(../@name)=0">
		<xsl:variable name="sample2" select="."/>
	        <xsl:if test="( count($sample2/../preceding-sibling::*[name()=name($sample2/..)]) + count($sample2/../following-sibling::*[name()=name($sample2/..)]) ) > 0" >
	          <xsl:value-of select="count($sample2/../preceding-sibling::*[name()=name($sample2/..)])"/>
	          <xsl:value-of select="'_'"/>
	        </xsl:if>
	      </xsl:if>
	      <xsl:value-of select="translate(name(),'_.- ','')"/>
	      <xsl:if test="string-length(@name)!=0">
	        <xsl:value-of select="'_'"/>
	        <xsl:value-of select="translate(@name,'_.- ','')"/>
	      </xsl:if>
	      <xsl:if test="not(position()=last())">
	        <xsl:value-of select="'_'"/>
	      </xsl:if>
	      <xsl:if test="count(./*)=0">
	        <xsl:value-of select="'=__QUOTE__'"/>
	        <xsl:value-of select="."/>
	        <xsl:value-of select="'__QUOTE__'"/>
	      </xsl:if>
	    </xsl:for-each>
	    <xsl:value-of select="'&#10;'"/>
	  </xsl:for-each>
	</xsl:template>
	</xsl:stylesheet>
	EOF

  dpxmlsh_soma_get_config "$1" "$2" \
  | $_DPXMLSH_XMLSTARLET tr /tmp/dpxmlsh_getconfig.$$.xsl - \
  | grep "dp:config" \
  | grep "=" \
  | sed -e 's/^.*_dp:config_//g' -e 's/__QUOTE__/"/g' -e "s/^/$3_config_/g"

  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
  local rc=$?

  rm -f /tmp/dpxmlsh_getconfig.$$.xsl
  return $rc

  # This approach didn't work because I could not index multiple
  # anonymous inner objects without direct access to xslt.
  # dpxmlsh_soma_get_config $1 \
  # | $_DPXMLSH_XMLSTARLET sel -N dp="http://www.datapower.com/schemas/management" \
  #   -T -t \
  #   -m '//*' -m 'ancestor-or-self::*' \
  #     -v 'name()' \
  #     -i 'string-length(@name)!=0' \
  #       -o _ -v '@name' \
  #     -b \
  #     -i 'not(position()=last())' \
  #       -o _ \
  #     -b \
  #     -i 'count(./*)=0' \
  #       -o '[' -v 'count(../preceding-sibling::*)' -o "]=__QUOTE__" -v . -o "__QUOTE__" \
  #     -b \
  #   -b \
  #   -n \
  # | grep "dp:config" | grep = | sed -e 's/^.*_dp:config_//g' -e 's/__QUOTE__/"/g'
}

# Import config into shell variables.
# Takes 3 args:
# 1: ObjectType (or "")
# 2: ObjectName (or "")
# 3: Prefix name (or "")
function dpxmlsh_get_config_import ()
{
  # First clear out old stuff
  eval $(set | grep "^$3_config_" | sed -e 's/^/unset /g' -e 's/=.*$//g')
  # Then pull in the new
  eval $(dpxmlsh_get_config_list "$1" "$2" "$3" | sed 's/^/export /g')
}

# Print imported config.  Note that this can also be used to filter
# the config after it is already imported, provided the import was less
# specific than the print.
# Takes 3 args:
# 1: ObjectType (or "")
# 2: ObjectName (or "")
# 3: Prefix name (or "")
function dpxmlsh_get_config_importprint ()
{
  local pattern="$3_config"
  if [ ! -z "$1" ] ; then
    pattern="${pattern}_$1"
  else
    pattern="${pattern}_[a-zA-Z0-9]*"
  fi
  if [ ! -z "$2" ] ; then
    pattern="${pattern}_$2"
  else
    pattern="${pattern}_[a-zA-Z0-9]*"
  fi
  set | grep "^${pattern}_"
}

# Status from any legal provider, or propmt with a list of valid status inquiries
function _dpxmlsh_soma_get_status ()
{
  local DPSTATUSPROVIDER="$1"

  { cat <<-EOF
	<?xml version="1.0" encoding="UTF-8"?>
	<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
	  <env:Body>
	    <dp:request domain="$_DPXMLSH_DPDOMAIN" xmlns:dp="http://www.datapower.com/schemas/management">
	      <dp:get-status class="$DPSTATUSPROVIDER"/>
	    </dp:request>
	  </env:Body>
	</env:Envelope>
	EOF
  } \
    | _dpxmlsh_tee $FUNCNAME request xml \
    | $_DPXMLSH_CURLSOMACMD \
    | _dpxmlsh_tee $FUNCNAME response xml \
    | $_DPXMLSH_XMLSTARLET fo

  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

# On success, give the XML on stdout.  On failure, give the failure message on stderr
function dpxmlsh_soma_get_status ()
{
  local RESULT=$(_dpxmlsh_soma_get_status "$@")

  if _dpxmlsh_soma_isok "$RESULT"
  then
    echo "$RESULT"
    return 0
  fi

  echo "$RESULT" | $_DPXMLSH_XMLSTARLET fo >&2
  echo "ERROR: $FUNCNAME $@" >&2
  return 1
}

# Status in the form of a space-deliminated table.
# In this form, the results of this function can be reliably piped into
# a "while read col1 col2 col3" shell loop.  What exactly the columns mean
# is left as an exercise to the user.  Note that spaces in the orig input
# are turned into underscores and empty fields are replaced with a dash
# so shell parsing is easy.
function dpxmlsh_get_status_table ()
{
  dpxmlsh_soma_get_status $1 \
  | $_DPXMLSH_XMLSTARLET sel -N dp="http://www.datapower.com/schemas/management" \
    --template \
      -m '//dp:status//*' \
        --nl \
      -m './*' \
        -o '__BEGIN__' --value-of "translate(.,' ','_')" --output '__END__ ' \
  | { grep -v "^$"; true ; } \
  | sed -e 's/__BEGIN____END__/-/g' -e 's/__BEGIN__//g' -e 's/__END__//g' \
  | column -t

  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

# Status in the form of a list of name-value pairs, separated by '=",
# with the value quoted.  As such, the result should be in form where it
# could be sourced into a script and used directly
function dpxmlsh_get_status_list ()
{
  local label=$2
  if [ "$label" != "" ]
  then
    label="$2_"
  fi

  dpxmlsh_soma_get_status $1 \
  | $_DPXMLSH_XMLSTARLET sel -N dp="http://www.datapower.com/schemas/management" \
    --template \
      -m '//dp:status//*' \
        --output "#---------------------" -n \
      -m './*' \
        --output "$label" --value-of 'name(..)' -o '_' --value-of 'name(.)' --output '=__QUOTE__' --value-of '.' --output '__QUOTE__' --nl \
  | uniq \
  | sed -n -e 's/__QUOTE__/"/gp' -e '/^#/p' 

  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

# Status in verbose table form, with of name-value pairs, separated by '=",
# with the value quoted, and fields separated by a space and a semicolon.
# As such, the result should be in form where it is both grepable (for selecting
# the appropriate row of the status provider) and eval-able, so that the result
# of the grep can be eval'd, giving immediate, name-based variables. 
# For instance: 
# $ eval $(dpxmlsh_get_status_vtable TCPTable | grep "TCPTable_localIP=\"0.0.0.0\"" | grep "TCPTable_localPort=\"22\"")
# $ echo $TCPTable_state echo $TCPTable_localPort TCPTable_state
# listen 22 0.0.0.0
#
# Or for even more fun:
# dpxmlsh_get_status_vtable TCPTable \
# | while read line
#   do
#    eval "$line"
#    echo $TCPTable_state $TCPTable_localPort $TCPTable_localIP
#   done
function dpxmlsh_get_status_vtable ()
{
  local label=$2
  if [ "$label" != "" ]
  then
    label="$2_"
  fi

  dpxmlsh_soma_get_status $1 \
  | $_DPXMLSH_XMLSTARLET sel -N dp="http://www.datapower.com/schemas/management" \
    --template \
      -m '//dp:status//*' \
        --nl \
      -m './*' \
        --output "$label" --value-of 'name(..)' -o '_' --value-of 'name(.)' --output '=__QUOTE__' --value-of '.' --output '__QUOTE__; ' \
  | sed -n -e 's/__QUOTE__/"/gp' -e '/^#/p'

  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

# the get_status_eval* functions (fetch and filter) allow the caller to
# take control of his own destiny.  With fetch, the status provider
# queried and the fields identified.  Everything that needs to be 
# initialized is initialized.  Subsequently, when filter is called,
# the output is in the form of one line per row in an eval()able
# format that can be grepped, filtered, or manupulated prior to
# eval.  For instance:
# dpxmlsh_get_status_evalfetch TCPTable mylabel \
#  && eval "$(dpxmlsh_get_status_evalfilter TCPTable mylabel | grep established)" \
#  && eval "$(dpxmlsh_get_status_evalfilter TCPTable mylabel | grep listen)" \
#  && dpxmlsh_get_status_evalprint TCPTable mylabel
# returns a list of all tcp ports that are in either established or listen, with
# established being before listen.
# Note that dpxmlsh_get_status_evalprint is provided for diagnostic and example
# purposes -- it will print the entire status provider
function dpxmlsh_get_status_evalfetch ()
{
  local field
  for field in $(set | grep "^$2_$1_[^=]*=" | cut -d= -f1)
  do
    unset $field
  done

  local vtable="$(dpxmlsh_get_status_vtable $1 $2 )"
  local fields="$( echo "$vtable" | sed -n '1,1s/="[^;]*;//gp')"

  for field in $fields
  do
    declare -a $field
    export $field
  done
  eval "$2_$1_ROWS='0'"
  eval "$2_$1_FIELDS='$fields'"
  eval "$2_$1_VTABLE='$vtable'"
  export $2_$1_ROWS
  export $2_$1_FIELDS
  export $2_$1_VTABLE
}

# Print out rows of the status provider in a form that can be both
# grepped and eval'd.  The expected workflow is to evalfetch to get
# the result, then eval "$(dpxmlsh_get_status_evalfilter StatusProvider label)"
# to put just the rows selected into a set of environment variable arrays.
function dpxmlsh_get_status_evalfilter ()
{
  local row
  local value
  local fields
  local vtable
  eval "fields=\"\$$2_$1_FIELDS\""
  eval "vtable=\"\$$2_$1_VTABLE\""

  while read row
  do
    [ "$row" = "" ] && break

    eval "$row"
    
    for field in $fields
    do
      eval "value=\"\$$field\""
      echo -n "${field}[\$$2_$1_ROWS]=\"$value\"; "
    done
    echo "$2_$1_ROWS=\$(( \$$2_$1_ROWS + 1 ));"
    
  done <<-EOF
	$vtable
	EOF
}

# Mostly for diagnostic purposes, evalprint simply prints the result of
# an evalfetch+evalfiltered set of environment variables in the same form
# as get_status_table. 
function dpxmlsh_get_status_evalprint ()
{
  local rows
  eval "rows=\"\$$2_$1_ROWS\""
  local fields
  eval "fields=\"\$$2_$1_FIELDS\""
  local i
  local value

  for (( i=0 ; i < $rows ; i++ ))
  do
    for field in $fields
    do
      eval "value=\${$field[$i]}"
      echo -n "$(echo "$value" | sed -e 's/ /-/g' -e 's/^$/-/g') "
    done
    echo
  done \
  | column -t
}

# Here's where we get mind-bendy trippy.  We're going to suck in all the status
# provider data into arrays of environment variables.
# The status provider name is specified in $1
# The variable name prefix is specified in $2
# Rows are numbered 0 through <PREFIX>_<PROVIDER>_ROWS
# A list of the fields found in the status provider is avilable in the variable
# called <PREFIX>_<PROVIDER>_FIELDS.  For instance, if the prefix is "MY" and
# the status provider is TCPTable, then $MY_TCPTable_ROWS will contain the
# number of rows in the table and $MY_TCPTABLE_FIELDS will contain the names of
# the fields in the provider.  See selftest for an example of how to use.
#
# While this is useful, I predict it will be horribly overused.  It comes into
# its own only when selecting more than one element and then only for non-
# interactive use and then only when more than one field are required.  So keep
# that in mind.
function dpxmlsh_get_status_import ()
{
  dpxmlsh_get_status_evalfetch $1 $2
  eval "$(dpxmlsh_get_status_evalfilter $1 $2)"
}

# This function does command line completion for all status commands.
# Note that the first time it is called, we get a list of all possible status providers
# If that list changes, command completion could be incorrect.
function _dpxmlsh_status_complete ()
{
  if [ "${_DPXMLSH_STATUSPROVIDERS}" = "" ] 
  then
    export _DPXMLSH_STATUSPROVIDERS="$( \
      dpxmlsh_get_file store:/xml-mgmt-2004-objects.xsd - | \
        $_DPXMLSH_XMLSTARLET sel -N xsd="http://www.w3.org/2001/XMLSchema" \
        --template --match '//xsd:enumeration' --if "../../@name='status-class'" --value-of '@value' --nl \
    )"
  fi
  COMPREPLY=( $(compgen -W "$_DPXMLSH_STATUSPROVIDERS" $2) )
  #printf "\nDEBUG ARGS=$* COMP_LINE=$COMP_LINE COMP_POINT=$COMP_POINT COMP_KEY=$COMP_KEY COMP_TYPE=$COMP_TYPE COMP_WORDS=$COMP_WORDS COMP_CWORD=$COMP_CWORD COMPREPLY=${COMPREPLY[@]}\n" >&2
}
complete -F _dpxmlsh_status_complete dpxmlsh_get_status_list
complete -F _dpxmlsh_status_complete dpxmlsh_get_status_table
complete -F _dpxmlsh_status_complete dpxmlsh_get_status_evalfetch
complete -F _dpxmlsh_status_complete dpxmlsh_get_status_evalfilter
complete -F _dpxmlsh_status_complete dpxmlsh_get_status_evalprint
complete -F _dpxmlsh_status_complete dpxmlsh_get_status_import
complete -F _dpxmlsh_status_complete dpxmlsh_get_status_vtable
complete -F _dpxmlsh_status_complete dpxmlsh_soma_get_status

# helper function that generates the completion list for dpxmlsh_complete_*dpfile*
function dpxmlsh_complete_helper_dpfile ()
{
  local cur
  cur="$1"

  # If cur already has a colon, then completion must not include the portion before the colon.  If cur
  # does not already contain the colon, then there is no need to filter.  This is all because bash
  # autocompletion handles colons as a deliminator.
  # Also, ignore any errors from dpxmlsh_ls.  If it didn't work the result will be empty and that's just fine.
  if echo "$cur" | grep ":" >/dev/null 2>&1
  then
    dpxmlsh_ls 2>/dev/null | grep "^$cur" | sed -e "s;^\(${cur}[^/]*/\).*;\1;g" | sort | uniq | cut -d: -f2-
  else
    dpxmlsh_ls 2>/dev/null | grep "^$cur" | sed -e "s;^\(${cur}[^/]*/\).*;\1;g" | sort | uniq 
  fi

}

# The bash autocomplete function for dpxmlsh commands that take a single arg (hence the "1")
# and that arg is a file on DP.
function _dpxmlsh_complete_dpfile ()
{
  declare -f -F _get_comp_words_by_ref >/dev/null || return
  _get_comp_words_by_ref -n =: cur words cword prev || return
  #echo -e "\nDEBUG $FUNCNAME argc=$# argv=$@ cur=$cur nwords=${#words[@]} words=${words[@]} cword=$cword prev=$prev" >&2 ; sleep 1

  case ${#words[@]} in
  2)
    COMPREPLY+=( $(dpxmlsh_complete_helper_dpfile "$cur") )
    ;;
  *)
    ;;
  esac
}
function _dpxmlsh_complete_dpfile_localfile ()
{
  declare -f -F _get_comp_words_by_ref >/dev/null || return
  _get_comp_words_by_ref -n =: cur words cword prev || return
  #echo -e "\nDEBUG $FUNCNAME argc=$# argv=$@ cur=$cur nwords=${#words[@]} words=${words[@]} cword=$cword prev=$prev" >&2 ; sleep 1

  case ${#words[@]} in
  2)
    COMPREPLY+=( $(dpxmlsh_complete_helper_dpfile "$cur") )
    ;;
  3)
    COMPREPLY=( $(compgen -f "$2") )
    ;;
  *)
    ;;
  esac
}
# completion for commands that take <localfile> <dpfile>
function _dpxmlsh_complete_localfile_dpfile ()
{
  declare -f -F _get_comp_words_by_ref >/dev/null || return
  _get_comp_words_by_ref -n =: cur words cword prev || return
  #echo -e "\nDEBUG $FUNCNAME argc=$# argv=$@ cur=$cur nwords=${#words[@]} words=${words[@]} cword=$cword prev=$prev" >&2 ; sleep 1

  case ${#words[@]} in
  2)
    COMPREPLY=( $(compgen -f "$2") )
    ;;
  3)
    COMPREPLY+=( $(dpxmlsh_complete_helper_dpfile "$cur") )
    ;;
  *)
    ;;
  esac
}
complete -o nospace -F _dpxmlsh_complete_dpfile_localfile dpxmlsh_get_file
complete -o nospace -F _dpxmlsh_complete_dpfile_localfile dpxmlsh_soma_get_file
complete -o nospace -F _dpxmlsh_complete_dpfile dpxmlsh_deletefile
complete -o nospace -F _dpxmlsh_complete_dpfile dpxmlsh_soma_action_deletefile
complete -o nospace -F _dpxmlsh_complete_dpfile dpxmlsh_edit
complete -o nospace -F _dpxmlsh_complete_localfile_dpfile dpxmlsh_set_file
complete -o nospace -F _dpxmlsh_complete_localfile_dpfile dpxmlsh_soma_set_file

# works well, but object names with characters that are not valid in script variable names
# are broken and cannot autocomplete.  We could potentially use dpxmlsh_get_status_list ObjectStatus
# as the source of our object class and name information, but that would break on
# firmware that does not include that relatively recent status provider.
function _dpxmlsh_complete_config ()
{
  declare -f -F _get_comp_words_by_ref >/dev/null || return
  _get_comp_words_by_ref -n =: cur words cword prev || return
  #echo -e "\nDEBUG $FUNCNAME argc=$# argv=$@ cur=$cur nwords=${#words[@]} words=${words[@]} cword=$cword prev=$prev" >&2 ; sleep 1

  case ${#words[@]} in
  2)
    COMPREPLY=( $( dpxmlsh_get_config_list "" "" completion | cut -d_ -f3 | sort | uniq | grep "^$cur" ) )
    ;;
  3)
    COMPREPLY+=( $( dpxmlsh_get_config_list "$prev" "" completion | grep "^completion_config_${prev}_" | cut -d_ -f4 | sort | uniq | grep "^$cur" ) )
    ;;
  *)
    ;;
  esac
}
complete -o nospace -F _dpxmlsh_complete_config dpxmlsh_get_config_import
complete -o nospace -F _dpxmlsh_complete_config dpxmlsh_get_config_importprint
complete -o nospace -F _dpxmlsh_complete_config dpxmlsh_get_config_list         
complete -o nospace -F _dpxmlsh_complete_config dpxmlsh_soma_get_config
 
# Execute a DataPower CLI script called $1
# Warning: MUST NOT have "top" "configure terminal" in this!  If you do,
# you will get success -- but nothing will have executed.
function dpxmlsh_action_exec_config () { echo "WARNING: $FUNCNAME deprecated, use dpxmlsh_action_execconfig instead" >&2 ; _dpxmlsh_shell2xml 1 1 "$FUNCNAME" "$@"; }
function dpxmlsh_soma_action_exec_config () { echo "WARNING: $FUNCNAME deprecated, use dpxmlsh_soma_action_execconfig instead" >&2 ; dpxmlsh_soma_action_execconfig "$@"; }
function dpxmlsh_action_execconfig () { _dpxmlsh_shell2xml 1 1 "$FUNCNAME" "$@"; }
function dpxmlsh_soma_action_execconfig ()
{
  local DPCONFIGFILE="$1"
  { cat <<-EOF
	<?xml version="1.0" encoding="utf-8"?>
	<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
	  <env:Body>
	    <dp:request domain="$_DPXMLSH_DPDOMAIN" xmlns:dp="http://www.datapower.com/schemas/management">
	      <dp:do-action>
	        <ExecConfig>
	          <URL>$DPCONFIGFILE</URL>
	        </ExecConfig>
	      </dp:do-action>
	    </dp:request>
	  </env:Body>
	</env:Envelope>
	EOF
  } \
    | _dpxmlsh_tee $FUNCNAME request xml \
    | $_DPXMLSH_CURLSOMACMD \
    | _dpxmlsh_tee $FUNCNAME response xml \
    | $_DPXMLSH_XMLSTARLET fo

  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

function dpxmlsh_action_testhardware () { _dpxmlsh_shell2xml 0 0 "$FUNCNAME" "$@"; }
function dpxmlsh_soma_action_testhardware ()
{
  { cat <<-EOF
	<?xml version="1.0" encoding="utf-8"?>
	<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
	  <env:Body>
	    <dp:request domain="$_DPXMLSH_DPDOMAIN" xmlns:dp="http://www.datapower.com/schemas/management">
	      <dp:do-action>
	        <TestHardware>
	        </TestHardware>
	      </dp:do-action>
	    </dp:request>
	  </env:Body>
	</env:Envelope>
	EOF
  } | _dpxmlsh_tee $FUNCNAME request xml \
    | $_DPXMLSH_CURLSOMACMD \
    | _dpxmlsh_tee $FUNCNAME response xml \
    | $_DPXMLSH_XMLSTARLET fo

  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

function dpxmlsh_amp_set_firmware_request ()
{
  local FROM="$1"       # either a file or - for input on stdin

  { cat <<-EOF
	<?xml version="1.0" encoding="UTF-8"?>
	<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
	  <soapenv:Body>
	    <dp:SetFirmwareRequest xmlns:dp="http://www.datapower.com/schemas/appliance/management/1.0">
	      <dp:Firmware>
	EOF
    # cat is happy to take "-" as well, and cleverly we are happy to take
    # stdin to this function and let this instance of cat consume it
    cat $FROM \
      | openssl enc -base64 -a -A \
      | _dpxmlsh_tee $FUNCNAME internal base64.txt
    cat <<-EOF
	      </dp:Firmware>
	    </dp:SetFirmwareRequest>
	  </soapenv:Body>
	</soapenv:Envelope>
	EOF
  } | _dpxmlsh_tee $FUNCNAME request xml \
    | $_DPXMLSH_CURLAMPCMD \
    | _dpxmlsh_tee $FUNCNAME response xml \
    | $_DPXMLSH_XMLSTARLET fo

  _dpxmlsh_pipestatus $FUNCNAME ${PIPESTATUS[@]}
}

# Upgrade the firmware to the scrypt in $1
# $1 may be either a file or - for stdin
# Also stick the license accepted file in so the upgrade can succeed
function dpxmlsh_set_firmware_and_accept_license ()
{
  local FROM="$1"       # either a file or - for input on stdin

  # check args
  [ "$FROM" = "-" -o -z "$FROM" -o -r "$FROM" ] \
    || { echo dpxmlsh_amp_set_firmware_request ERROR: $FROM not readable or stdin >&2 ; return 1; }

  # stick the magic file in its place, otherwise the next command fails silently
  echo -n "" | dpxmlsh_set_file - temporary:license.accepted

  local RESULT=$(dpxmlsh_amp_set_firmware_request "$FROM")
  if echo "$RESULT"  | _dpxmlsh_amp_isresultok
  then
    return 0
  fi

  echo "$RESULT" | $_DPXMLSH_XMLSTARLET fo >&2
  echo "ERROR" >&2
  return 1
}

# Edit files on the appliance
# Just download the file, edit in something reasonable, and re-upload if changed
function dpxmlsh_edit ()
{
  local EDITOR="vi"
  if [ "$VISUAL" ]; then
    EDITOR="$VISUAL"
  elif [ -x /etc/alternatives/editor ]; then
    EDITOR="/etc/alternatives/editor"
  fi
  local TMPFILE=/tmp/dpxmlsh$$.tmp

  local DPFILE
  local MD5SUM
  for DPFILE in $*
  do
    dpxmlsh_get_file "$DPFILE" "$TMPFILE" || { echo "ERROR: could not get $DPFILE"; return 1; }
    MD5SUM="$(md5sum $TMPFILE)"
    "$EDITOR" "$TMPFILE"
    if echo "$MD5SUM" | md5sum -c >/dev/null 2>&1
    then
      echo "WARNING: $DPFILE not changed, skipping" >&2
    else
      dpxmlsh_set_file "$TMPFILE" "$DPFILE" || { echo "ERROR: could not set $DPFILE"; return 1; }
    fi
    rm "$TMPFILE"
  done
}

function dpxmlsh_version ()
{
  echo VERSION=\'$DPXMLSH_VERSION\'
  echo DPHOST=\'$_DPXMLSH_DPHOST\'
  echo DPUSER=\'$_DPXMLSH_DPUSER\'
  echo DPPASS=\'$( echo $_DPXMLSH_DPPASS | sed 's/././g')\'
  echo DPDOMAIN=\'$_DPXMLSH_DPDOMAIN\'
  echo DPXMLPORT=\'$_DPXMLSH_DPXMLPORT\'

  echo VERBOSE=\'$_DPXMLSH_VERBOSE\'
  echo DEBUG=\'$_DPXMLSH_DEBUG\'
  echo DEBUGDIR=\'$_DPXMLSH_DEBUGDIR\'
  echo CURLSOMACMD=\'$_DPXMLSH_CURLSOMACMD\' | sed "s/:${_DPXMLSH_DPPASS} /:<redacted> /g"
  echo CURLAMPCMD=\'$_DPXMLSH_CURLAMPCMD\' | sed "s/:${_DPXMLSH_DPPASS} /:<redacted> /g"
  echo XMLSTARLET=\'$_DPXMLSH_XMLSTARLET\'
}

function _dpxmlsh_selftest ()
{
  # This is an example of an exact result received on a successful soma set file
  echo -e "\n#### _dpxmlsh_soma_isresultok soma_set_file-response"
  local SOMASETFILEOK='<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"><env:Body><dp:response xmlns:dp="http://www.datapower.com/schemas/management"><dp:timestamp>2013-05-03T21:45:34-04:00</dp:timestamp><dp:result>OK</dp:result></dp:response></env:Body></env:Envelope>'

  echo "$SOMASETFILEOK" \
    | _dpxmlsh_soma_isresultok \
    || { echo "_dpxmlsh_soma_isresultok soma_set_file-response failed $?" >&2 ; return 1 ; }

  _dpxmlsh_soma_isok "$SOMASETFILEOK" \
    || { echo "_dpxmlsh_soma_isok SOMASETFILEOK failed $?" >&2 ; return 1 ; }

  # This is an example of an exact result received on a successful soma exec config
  echo -e "\n#### _dpxmlsh_soma_isresultok soma_action_exec_config-response"
  local SOMAEXECCONFIGOK='<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"><env:Body><dp:response xmlns:dp="http://www.datapower.com/schemas/management"><dp:timestamp>2013-05-03T21:45:34-04:00</dp:timestamp><dp:result>
                        OK
                    </dp:result></dp:response></env:Body></env:Envelope>'

  echo "$SOMAEXECCONFIGOK" \
    | _dpxmlsh_soma_isresultok \
    || { echo "_dpxmlsh_soma_isresultok soma_action_exec_config-response failed $?" >&2 ; return 1 ; }

  _dpxmlsh_soma_isok "$SOMAEXECCONFIGOK" \
    || { echo "_dpxmlsh_soma_isok SOMAEXECCONFIGOK failed $?" >&2 ; return 1 ; }

  echo -e "\n#### _dpxmlsh_amp_isresultok amp_set_firmware_request-response"
  local AMPSETFIRMWAREOK='<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"><env:Body><amp:SetFirmwareResponse xmlns:amp="http://www.datapower.com/schemas/appliance/management/1.0"><amp:Status>ok</amp:Status></amp:SetFirmwareResponse></env:Body></env:Envelope>'
  echo "$AMPSETFIRMWAREOK" | _dpxmlsh_amp_isresultok \
    || { echo "_dpxmlsh_amp_isresultok amp_set_firmware_request-response failed $?" >&2 ; return 1 ; }

  local SOMASTATUSGOOD='<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
  <env:Body>
    <dp:response xmlns:dp="http://www.datapower.com/schemas/management">
      <dp:timestamp>2013-10-30T22:46:40-04:00</dp:timestamp>
      <dp:status>
        <Version xmlns:env="http://www.w3.org/2003/05/soap-envelope">
          <Version>XI52.6.0.1.0</Version>
        </Version>
      </dp:status>
    </dp:response>
  </env:Body>
</env:Envelope>'
  _dpxmlsh_soma_isok "$SOMASTATUSGOOD" \
    || { echo "_dpxmlsh_soma_isok SOMASTATUSGOOD failed $?" >&2 ; return 1 ; }

  local SOMADELETEFILEOK='<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
  <env:Body>
    <dp:response xmlns:dp="http://www.datapower.com/schemas/management">
      <dp:timestamp>2013-10-30T22:53:48-04:00</dp:timestamp>
      <dp:result>
                        OK
                    </dp:result>
    </dp:response>
  </env:Body>
</env:Envelope>' 
  _dpxmlsh_soma_isok "$SOMADELETEFILEOK" \
    || { echo "_dpxmlsh_soma_isok SOMADELETEFILEOK failed $?" >&2 ; return 1 ; }

  local SOMADELETEFILENOTFOUND='<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"><env:Body><dp:response xmlns:dp="http://www.datapower.com/schemas/management"><dp:timestamp>2013-10-30T23:13:29-04:00</dp:timestamp><dp:result><error-log><log-event level="error">No such file or directory named store:dpxmlsh.tmp exists</log-event><log-event level="error">(admin:default:saml-artifact:9.42.102.252): (config)# delete "store:dpxmlsh.tmp"</log-event></error-log></dp:result></dp:response></env:Body></env:Envelope>'
  _dpxmlsh_soma_isok "$SOMADELETEFILENOTFOUND" \
    && { echo "_dpxmlsh_soma_isok SOMADELETEFILENOTFOUND failed $?" >&2 ; return 1 ; }

  return 0
}

function dpxmlsh_selftest ()
{
  dpxmlsh_version

  # first check that the internals work
  _dpxmlsh_selftest || return 1

  local payload="$USER $(hostname) $(date)"

  echo -e "\n#### dpxmlsh_set_file"
  echo '$ echo "$payload" | dpxmlsh_set_file - "local:dpxmlsh.tmp"'
  echo "$payload" \
    | dpxmlsh_set_file - "local:dpxmlsh.tmp" \
    || { echo "dpxmlsh_set_file failed $?" >&2 ; return 1 ; }

  echo -e "\n#### dpxmlsh_get_file"
  echo '$ dpxmlsh_get_file "local:dpxmlsh.tmp" -'
  dpxmlsh_get_file "local:dpxmlsh.tmp" - > /dev/null \
    || { echo "dpxmlsh_get_file failed $?" >&2 ; return 1 ; }

  echo -e "\n#### dpxmlsh_get_file check payload"
  echo '$ RESULT=$(dpxmlsh_get_file "local:dpxmlsh.tmp" -)'
  local RESULT=$(dpxmlsh_get_file "local:dpxmlsh.tmp" -)
  [ "$payload" = "$RESULT" ] \
    || { echo "dpxmlsh_get_file contents failed $?" >&2 ; return 1 ; }

  echo -e "\n#### dpxmlsh_deletefile"
  echo '$ dpxmlsh_deletefile "local:dpxmlsh.tmp"'
  dpxmlsh_deletefile "local:dpxmlsh.tmp" \
    || { echo "dpxmlsh_deletefile should have succeeded but failed $?" >&2 ; return 1 ; }

  echo -e "\n#### dpxmlsh_deletefile negative test, soma error expected"
  echo '$ dpxmlsh_deletefile "local:dpxmlsh.tmp"'
  dpxmlsh_deletefile "local:dpxmlsh.tmp" \
    && { echo "dpxmlsh_deletefile should have failed but succeeded $?" >&2 ; return 1 ; }

##
  echo -e "\n#### dpxmlsh_set_file big"
  echo '$ openssl rand 10000000 > rand-big'
  openssl rand 10000000 > rand-big
  echo '$ dpxmlsh_set_file rand-big temporary:rand-big'
  dpxmlsh_set_file rand-big temporary:rand-big \
    || { echo "dpxmlsh_set_file big failed $?" >&2 ; return 1 ; }

  echo -e "\n#### dpxmlsh_get_file big"
  echo '$ dpxmlsh_get_file "temporary:rand-big" rand-big.out' 
  dpxmlsh_get_file "temporary:rand-big" rand-big.out \
    || { echo "dpxmlsh_get_file big failed $?" >&2 ; return 1 ; }

  echo '$ cmp rand-big rand-big.out'
  cmp rand-big rand-big.out \
    || { echo "compare big failed $?" >&2 ; return 1 ; }
  echo '$ rm rand-big rand-big.out'
  rm rand-big rand-big.out

  echo -e "\n#### dpxmlsh_deletefile big"
  echo '$ dpxmlsh_deletefile "temporary:rand-big"'
  dpxmlsh_deletefile "temporary:rand-big" \
    || { echo "dpxmlsh_deletefile should have succeeded but failed $?" >&2 ; return 1 ; }
##
  echo -e "\n#### dpxmlsh_set_file big stdin"
  echo '$ openssl rand 10000000 > rand-big'
  openssl rand 10000000 > rand-big
  echo '$ cat rand-big | dpxmlsh_set_file - temporary:rand-big'
  cat rand-big | dpxmlsh_set_file - temporary:rand-big \
    || { echo "dpxmlsh_set_file big failed $?" >&2 ; return 1 ; }

  echo -e "\n#### dpxmlsh_get_file big stdin"
  echo '$ dpxmlsh_get_file "temporary:rand-big" rand-big.out' 
  dpxmlsh_get_file "temporary:rand-big" rand-big.out \
    || { echo "dpxmlsh_get_file big failed $?" >&2 ; return 1 ; }

  echo '$ cmp rand-big rand-big.out'
  cmp rand-big rand-big.out \
    || { echo "compare big failed $?" >&2 ; return 1 ; }
  echo '$ rm rand-big rand-big.out'
  rm rand-big rand-big.out

  echo -e "\n#### dpxmlsh_deletefile big stdin"
  echo '$ dpxmlsh_deletefile "temporary:rand-big"'
  dpxmlsh_deletefile "temporary:rand-big" \
    || { echo "dpxmlsh_deletefile should have succeeded but failed $?" >&2 ; return 1 ; }

  echo -e "\n#### dpxmlsh_ls (truncated, error 141 OK)"
  echo '$ dpxmlsh_ls | head -10'
  dpxmlsh_ls | head -10
  echo -e "\n#### dpxmlsh_lls (truncated, error 141 OK)"
  echo '$ dpxmlsh_lls | head -10'
  dpxmlsh_lls | head -10

  echo -e "\n#### dpxmlsh_action_exec_config"
  echo '$ printf "system\n  contact "John Doe $(date)"\nexit\n" | dpxmlsh_set_file - "temporary:contact.cfg'
  { cat <<-EOF 
	system
	  contact "John Doe $(date)"
	exit
	EOF
  } | dpxmlsh_set_file - "temporary:contact.cfg" \
    || { echo "dpxmlsh_set_file temporary:contact.cfg failed $?" >&2 ; return 1 ; }
  echo '$ dpxmlsh_action_exec_config "temporary:///contact.cfg"'
  dpxmlsh_action_exec_config "temporary:///contact.cfg"

  echo -e "\n#### dpxmlsh_action_exec_config cleanup"
  echo '$ echo "system; no contact; exit" | dpxmlsh_set_file - "temporary:contact.cfg"'
  echo "system; no contact; exit" | dpxmlsh_set_file - "temporary:contact.cfg"
  echo '$ dpxmlsh_action_exec_config "temporary:///contact.cfg"'
  dpxmlsh_action_exec_config "temporary:///contact.cfg"

  echo -e "\n#### dpxmlsh_get_status_list Version is a good candidate for list form"
  echo '$ dpxmlsh_get_status_list Version'
  dpxmlsh_get_status_list Version

  echo -e "\n#### dpxmlsh_get_status_table TCPPort good candidate table form because it's sparse (truncated, error 141 OK)"
  echo '$ dpxmlsh_get_status_table TCPTable | head -10'
  dpxmlsh_get_status_table TCPTable | head -10

  echo -e "\n#### dpxmlsh_get_status_vtable eval + grep example"
  echo '$ eval $(dpxmlsh_get_status_vtable ObjectStatus mylabel | grep SSHService)'
  eval $(dpxmlsh_get_status_vtable ObjectStatus mylabel | grep SSHService)
  echo '$ echo $mylabel_ObjectStatus_Class is opstate $mylabel_ObjectStatus_OpState adminstate $mylabel_ObjectStatus_AdminState'
  echo $mylabel_ObjectStatus_Class is opstate $mylabel_ObjectStatus_OpState adminstate $mylabel_ObjectStatus_AdminState

  echo -e "\n#### dpxmlsh_get_status_vtable TCPPort good candidate table form because it's sparse (truncated, error 141 OK), see src for example"
  local row
  dpxmlsh_get_status_vtable TCPTable \
    | while read row
      do
        # since the output from vtable is itself valid shell, we can eval to get all
        # the Provider_field names and values at once.
        eval "$row"
        echo Read a row of TCPTable with state=$TCPTable_state localport=$TCPTable_localPort localip=$TCPTable_localIP
      done \
    | head -10

  
  echo -e "\n#### dpxmlsh_get_status_import iterative TCPPort (truncated, error 141 OK), see src for example"
  dpxmlsh_get_status_import TCPTable selftest
  { 
    echo $selftest_TCPTable_FIELDS | sed -e 's/selftest_TCPTable_//g'
    dpxmlsh_get_status_evalprint TCPTable selftest
  } | head -10 | column -t

  # Something iterative; print the localport when the domain is default
  for (( i=0 ; i < $selftest_TCPTable_ROWS ; i++ ))
  do
    if [[ "${selftest_TCPTable_serviceDomain[$i]}" = "default" ]]
    then
      echo ${selftest_TCPTable_serviceName[$i]} is on port ${selftest_TCPTable_localPort[$i]} in the default domain
    fi
  done

  echo -e "\n#### dpxmlsh_get_status_eval* TCPPort example"
  echo '$ dpxmlsh_get_status_evalfetch TCPTable selftest2'
  dpxmlsh_get_status_evalfetch TCPTable selftest2 
  echo '$ eval "$(dpxmlsh_get_status_evalfilter TCPTable selftest2 | grep default)"'
  eval "$(dpxmlsh_get_status_evalfilter TCPTable selftest2 | grep default)"
  echo '$ echo There are $selftest2_TCPTable_ROWS ports listening in the default domain'
  echo There are $selftest2_TCPTable_ROWS ports listening in the default domain
  echo '$ echo They are on ports ${selftest2_TCPTable_localPort[@]}'
  echo They are on ports ${selftest2_TCPTable_localPort[@]}
  echo '$ echo They are of types ${selftest2_TCPTable_serviceClass[@]}'
  echo They are of types ${selftest2_TCPTable_serviceClass[@]}

  echo -e "\n#### dpxmlsh_get_config_list DNSNameService example"
  echo '$ dpxmlsh_get_config_list DNSNameService "" selftest1'
  dpxmlsh_get_config_list DNSNameService "" selftest1

  echo -e "\n#### dpxmlsh_get_config_import DNSNameService example"
  echo '$ dpxmlsh_get_config_import DNSNameService "" selftest2'
  dpxmlsh_get_config_import DNSNameService "" selftest2
  echo '$ echo dns is using algorithm $selftest2_config_DNSNameService_MainNameService_LoadBalanceAlgorithm'
  echo dns is using algorithm $selftest2_config_DNSNameService_MainNameService_LoadBalanceAlgorithm

  echo -e "\n#### dpxmlsh_action_saveconfig"
  echo '$ dpxmlsh_action_saveconfig'
  dpxmlsh_action_saveconfig \
    || { echo "dpxmlsh_action_saveconfig failed $?" >&2 ; return 1 ; }

  # Disable the password test, it needs to be reworked so it does not run afowl
  # the repeated-password test
  if true || [ "$_DPXMLSH_DPPASS" = "" ]; then
    echo "WARNING: Cannot test password change"
  else
    echo -e "\n#### dpxmlsh_action_changepassword, change the password then change it back again.  Note the two calls to _init!"
    OLDPASS="$_DPXMLSH_DPPASS"
    echo "\$ dpxmlsh_action_changepassword $_DPXMLSH_DPPASS dpxmlsh-$_DPXMLSH_DPPASS"
    dpxmlsh_action_changepassword "$_DPXMLSH_DPPASS" "dpxmlsh-$_DPXMLSH_DPPASS" \
      || { echo "dpxmlsh_action_changepassword 1 failed $?" >&2 ; return 1 ; }

    echo "\$ dpxmlsh_init -h $_DPXMLSH_DPHOST -p dpxmlsh-$OLDPASS -u $_DPXMLSH_DPUSER"
    dpxmlsh_init -h "$_DPXMLSH_DPHOST" -p "dpxmlsh-$OLDPASS" -u "$_DPXMLSH_DPUSER" \
      || { echo "dpxmlsh_init with new password failed $?" >&2 ; return 1 ; }

    echo "\$ dpxmlsh_action_changepassword dpxmlsh-$OLDPASS $OLDPASS"
    dpxmlsh_action_changepassword "dpxmlsh-$OLDPASS" "$OLDPASS" \
      || { echo "dpxmlsh_action_changepassword 2 failed $?" >&2 ; return 1 ; }

    echo "\$ dpxmlsh_init -h $_DPXMLSH_DPHOST -p $OLDPASS -u $_DPXMLSH_DPUSER"
    dpxmlsh_init -h "$_DPXMLSH_DPHOST" -p "$OLDPASS" -u "$_DPXMLSH_DPUSER" \
      || { echo "dpxmlsh_init with old password failed $?" >&2 ; return 1 ; }
  fi

  if true
  then
    echo -e "\n#### dpxmlsh_action_testhardware skipped, not applicable on all platforms"
  else
    echo -e "\n#### dpxmlsh_action_testhardware"
    echo '$ dpxmlsh_action_testhardware'
    dpxmlsh_action_testhardware \
      || { echo "dpxmlsh_action_testhardware failed $?" >&2 ; return 1 ; }
  fi

  echo -e "\n#### dpxmlsh_action_createdir"
  echo '$ dpxmlsh_action_createdir local:///dpxmlshtest'
  dpxmlsh_action_createdir local:///dpxmlshtest \
    || { echo "dpxmlsh_action_createdir failed $?" >&2 ; return 1 ; }
  echo "asdf" | dpxmlsh_set_file - local:///dpxmlshtest/asdf \
    || { echo "dpxmlsh_action_createdir failed $?" >&2 ; return 1 ; }
  dpxmlsh_ls | grep dpxmlshtest | grep -q asdf \
    || { echo "looking for created file in created dir failed $?" >&2 ; return 1 ; }
  echo '$ dpxmlsh_action_removedir local:///dpxmlshtest'
  dpxmlsh_action_removedir local:///dpxmlshtest \
    || { echo "dpxmlsh_action_removedir failed $?" >&2 ; return 1 ; }
  dpxmlsh_ls | grep dpxmlshtest | grep asdf \
    && { echo "looking for created file in created dir succeeded $?" >&2 ; return 1 ; }
    
  echo -e "\n#### WOOHOO dpxmlsh_selftest success"
}

