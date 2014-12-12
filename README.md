# dpxmlsh

The "dpxmlsh" tool is a BASH script / collection of bash functions that
interacts with DataPower's xml-management interface.  It is well-suited
to both interactive use and scripted use.

It is known to work in Linux, OSX, and Windows.

## Prequisites

    bash https://www.gnu.org/software/bash/
    curl http://curl.haxx.se
    xmlstarlet http://xmlstar.sourceforge.net/
    openssl https://www.openssl.org/
    And other standard *nix tools

## Features:

    Access to all status providers and config objects
    Choice of output formats
    Choice of import-to-enviornment-variable
    Tab completion on status providers, file names, and config objects

## Online help:

```

dpxmlsh -- working with a DataPower appliance via XML management from the
bash command line or shell script.

There are 3 steps to profit:

1) Run the script.  This will place you in a subshell.  Alternatively, you can
Source or import the script library.  This is  done once for the lifetime of the
interactive shell or shell script.  Note the leading dot+space!  That is *not* a typo!
    i.e.:

       DPXMLSH_SCRIPT=true
       . /path/to/dpxmlsh_library.sh 

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

    --help)
    -h | --host | --dp-host)
    -u | --user | --dp-user)
    -p | --pass | --passwd | --password | --dp-pass | --dp-passwd | --dp-password)
    -d | --domain | --dp-domain)
    -P | --port | --dp-port | --dp-xml-mgmt-port)
    --debug)
    --no-debug)
    --verbose)
    --no-verbose)
    --debug-dir)

Note that the user defaults to "admin", the domain to "default", the port to 5550,
and the password inherited from ~/.netrc (see man netrc), so the only thing that
must be specified is the host.

The high-level functions, which are usable but user/script alone, without
need for additional xml processing:
    dpxmlsh_action_changepassword 
    dpxmlsh_action_deletefile 
    dpxmlsh_action_exec_config 
    dpxmlsh_action_execconfig 
    dpxmlsh_action_saveconfig 
    dpxmlsh_action_testhardware 
    dpxmlsh_complete_helper_dpfile 
    dpxmlsh_deletefile 
    dpxmlsh_edit 
    dpxmlsh_get_config_import 
    dpxmlsh_get_config_importprint 
    dpxmlsh_get_config_list 
    dpxmlsh_get_file 
    dpxmlsh_get_status_evalfetch 
    dpxmlsh_get_status_evalfilter 
    dpxmlsh_get_status_evalprint 
    dpxmlsh_get_status_import 
    dpxmlsh_get_status_list 
    dpxmlsh_get_status_table 
    dpxmlsh_get_status_vtable 
    dpxmlsh_help 
    dpxmlsh_lls 
    dpxmlsh_ls 
    dpxmlsh_selftest 
    dpxmlsh_set_file 
    dpxmlsh_set_firmware_and_accept_license 
    dpxmlsh_switch 
    dpxmlsh_version 

The low-level, xml-result-emitting functions are:
    dpxmlsh_amp_set_firmware_request 
    dpxmlsh_soma_action_changepassword 
    dpxmlsh_soma_action_deletefile 
    dpxmlsh_soma_action_exec_config 
    dpxmlsh_soma_action_execconfig 
    dpxmlsh_soma_action_saveconfig 
    dpxmlsh_soma_action_testhardware 
    dpxmlsh_soma_deletefile 
    dpxmlsh_soma_get_config 
    dpxmlsh_soma_get_file 
    dpxmlsh_soma_get_filestore 
    dpxmlsh_soma_get_status 
    dpxmlsh_soma_set_file 

```
