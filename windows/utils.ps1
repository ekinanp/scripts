[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

## UTILITIES

function Required([string] $ParamName) {
  throw "${ParamName} is required!"
}

function In-Dir([string] $Dir = (Required 'dir'), [scriptblock] $code = (Required 'code')) {
  try {
    Push-Location $dir

    Invoke-Command -ScriptBlock $code
  } finally {
    Pop-Location
  }
}

function Get-Assemblies {
  [AppDomain]::CurrentDomain.GetAssemblies()
}

function Get-Types ($Pattern=".") {
  Get-Assemblies | %{
    $ErrorActionPreference = 'SilentlyContinue';
    $_.GetExportedTypes()
  } | where {$_ -match $Pattern}
}

function ql {
  $args
}

function Force-Resolve-Path([string] $path) {
  try {
    $result = (resolve-path $path -ErrorAction 'stop').path
  } catch [System.Management.Automation.ItemNotFoundException] {
    $result = $_.TargetObject
  }
  
  $result
}

function Download-File([string] $url, [string] $path = $null) {
  if (-Not $path) {
    $path = [io.path]::GetFileName($url)
  }
  
  $path = Force-Resolve-Path $path
  
  $client = new-object net.webclient
  $client.DownloadFile($url, $path)
  
  $path
}

function Touch([string] $path) {
  $resolved_path = Force-Resolve-Path $path
  if (Test-Path $resolved_path) {
    return
  }
  
  [void] (new-item -itemtype file $resolved_path)
}

function Do-Request(
  [string] $url,
  [string] $method,
  [Object] $body,
  [string] $token
) {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $headers = @{
    'Accept' = 'application/json';
	'Authorization' = "token $token"
  }
  
  invoke-restmethod -uri $url -method $method -headers $headers -body $body
}

function Fqdn {
  "$(hostname).delivery.puppetlabs.net"
}

function To-Unix-Path([string] $path) {
  $path -replace '\\','/' -replace 'C:','/c'
}

function To-Win-Path([string] $path) {
  $path -replace '^/c', 'C:' -replace '/','\'
}

function Arch {
  if ([intptr]::size -eq 8) {
    'x64'
  } else {
    'x86'
  }
}

function Identity {
  { $args[0] }
}

# Probably not quite right, but good enough for my
# purposes. More readable too.
function Is-Null($value) {
  $value -eq $null
}

function Get-Env-Var([switch] $AllowNullValue, [string] $var) {
  $value = (dir "env:/$var" -ErrorAction 'silentlycontinue').value
  if ($AllowNullValue) {
    $value
  } else {
    [string] $value
  }
}

function Unset-Env-Var([switch] $permanent, [string] $var) {
  Remove-Item -Path "env:/$var"
  
  if ($permanent) {
    [System.Environment]::SetEnvironmentVariable(
      $var,
      $null,
      [System.EnvironmentVariableTarget]::User
    )
  }
}

function Set-Env-Var([switch] $permanent, [string] $var, [object] $block = (identity)) {
  if ($block -is [string]) {
    $new_value = $block
  } else {
    $cur_value = get-env-var $var
    $new_value = $block.invoke("$cur_value")
  }
  
  Set-Item -Path "env:/$var" -Value "$new_value"
  
  if ($permanent) {
    [System.Environment]::SetEnvironmentVariable(
      $var,
      $new_value,
      [System.EnvironmentVariableTarget]::User
    )
  }
}

# NOTE: Do not set an environment variable to empty here!
function With-Env {
  $ErrorActionPreference = 'Stop'
  
  # This lets us do something like
  #   with-env BUNDLE_PATH=.bundle/gems BUNDLE_BIN=.bundle/bin { <cmd> }
  [string[]] $env_vars, [scriptblock] $code =  $args[0..($args.length-2)], $args[-1]
  
  
  # Now set the environment to these new values.
  # We will go back to the previous state after the
  # code executes.
  $old_vals = @{}
  try {
    foreach ($env_var in $env_vars) {
      [string] $var, [string] $value = @($env_var.split('=', 2))
      $old_vals[$var] = get-env-var -AllowNullValue $var
      set-env-var $var $value
    }
	
	  Invoke-Command -ScriptBlock $code
  } finally {
    foreach ($var in $old_vals.keys) {
      if ( is-null $old_vals[$var] ) {
        unset-env-var $var
      } else {
        set-env-var $var $old_vals[$var]
      }
    }
  }
}

function BinDir() {
  $bindir = join-path $env:USERPROFILE 'bin'
  [void] (mkdir -Force $bindir)
  Add-To-Path -Permanent $bindir
  
  $bindir
}

function Add-To-Path([switch] $Permanent, [string] $dir) {
  set-env-var -Permanent:$permanent PATH {
    $old_value = $args[0]
  	if (-Not ($old_value -match [regex]::Escape($dir))) {
      $args[0] + ";${dir}"
    } else {
      $old_value
    }
  }
}


# DEV ENVIRONMENT SETUP: GIT

function Setup-Git-Config() {
  git config --global 'user.name' "Enis Inan"
  git config --global 'user.email' "enis.inan@puppet.com"
  git config --global 'user.username' "ekinanp"
  git config --global 'push.default' "simple"
  git config --global 'core.autocrlf' 'true'
  git config --global core.whitespace cr-at-eol
}

function Git-Bash {
  $git_bash_path = dir $env:programfiles -recurse -filter "*git-bash*" | %{$_.fullname}
  start-process $git_bash_path
  start-sleep -milliseconds 500
  $bash_ps = get-wmiobject win32_process | where { $_.name -eq 'bash.exe' }
   
  $wshell = new-object -com wscript.shell
  [void] $wshell.appactivate($bash_ps.parentprocessid)
  foreach ($cmd in $args) {
    $wshell.sendkeys("$cmd {ENTER}")
  }
}

function Add-Key-To-GitHub([string] $key_file, [string] $token) {
  $ErrorActionPreference = 'stop'
  
  $fqdn = fqdn
  $keys = do-request `
    -url "https://api.github.com/user/keys" `
  	-method "GET" `
  	-token $token `
  	-body $null
	
  foreach ($key in $keys) {
    if ($key.title -eq (fqdn)) {
      write-host "We already have an SSH key setup for ${fqdn}. Nothing more to do ..."
      return
    }
  }
  
  write-host "Setting up the SSH key for ${fqdn} ..."
  $body = @{
    'title' = $fqdn;
    'key' = (get-content $key_file | out-string)
  } | convertto-json

  [void] (do-request `
    -url "https://api.github.com/user/keys" `
  	-method "POST" `
  	-token $token `
  	-body $body)
	
  write-host "Successfully set-up the GitHub SSH key for $fqdn!"
}

function Setup-Git-SSH([string] $token) {
  $ssh_dir = "$($env:USERPROFILE -replace '\\','/' -replace 'C:','/c')/.ssh"
  $ssh_key_file = "${ssh_dir}/id_rsa"

  # Generate the ssh pub-private key pair
  Git-Bash `
    "ssh-keygen -t rsa -b 4096 -f ${ssh_key_file} -N '' -C enis.inan@puppet.com" `
  	'eval ${(}ssh-agent -s{)}'`
  	"ssh-add $ssh_key_file"
	
  # Wait a bit for Git Bash to generate our SSH keys
  sleep 1
	
  # Add the generated key to GitHub
  add-key-to-github (to-win-path "${ssh_key_file}.pub") $token
}

function Setup-Git([string] $token) {
  Setup-Git-Config
  Setup-Git-SSH $token
}

# Some parts here are manual, specifically the Installer's GUI.
function Install-Executable(
  [string] $Url = (Required 'Url'),
  [string] $ExeFile = (Required '.exe file wildcard'),
  [string] $Name = (Required '.exe name')
) {
  $ErrorActionPreference = 'Stop'
  
  write-host "Downloading ${Name} ..."
  $path = download-file $url
  write-host "Installing ${Name} ..."
  $exe_ps = start-process (Force-Resolve-Path $path) -passthru
  wait-process -id $exe_ps.id
  remove-item $path
  
  $actual_exe_file = @(dir $ExeFile)
  if ( $actual_exe_file.length -ne 1) {
    throw "${ExeFile} must specify only one .exe file. Right now, it specifies: ${actual_exe_file}"
  }
  write-host "Found .exe file at $($actual_exe_file.fullname). Pointing PATH to it ..."
  $exe_dir = split-path $actual_exe_file
  
  write-host "Setting the PATH to point to ${Name} ..."
  Add-To-Path $exe_dir
  write-host "Successfully installed ${Name} !"
}

function Install-Simple-Executable(
  [string] $Url = (Required 'Url'),
  [string] $Name = $null
) {
  if (-Not $Name) {
    $Name = join-path (BinDir) ([io.path]::GetFileName($Url))
  }
  download-file $Url $Name
}

function Install-Ruby() {
  $ErrorActionPreference = 'Stop'
  $url = 'https://github.com/oneclick/rubyinstaller2/releases/download/rubyinstaller-2.4.4-2/rubyinstaller-devkit-2.4.4-2-x64.exe'
  $arch = arch
  if ($arch -eq 'x86') {
    $url = $url -replace 'x64\.exe','x86.exe'
  }
  
  Install-Executable `
    -Url $url `
    -ExeFile 'C:\Ruby24*\bin\ruby.exe' `
    -Name 'Ruby'
}

function Install-Ag() {
  install-simple-executable 'https://kjkpub.s3.amazonaws.com/software/the_silver_searcher/rel/0.29.1-1641/ag.exe'
}

function Install-Vim() {
  Install-Executable `
    -Url 'ftp://ftp.vim.org/pub/vim/pc/gvim81.exe' `
    -ExeFile "${env:ProgramFiles(x86)}\Vim\*\vim.exe" `
    -Name 'Vim'
}

function Install-Vim-Plugin([string] $plugin) {
  $vim_dir = "${env:USERPROFILE}\vimfiles"
  $vim_bundle = join-path $vim_dir "bundle"
  
  Push-Location $vim_bundle
    git clone "git://github.com/${plugin}"
  Pop-Location
}

function Configure-Vim() {
  $vim_dir = "${env:USERPROFILE}\vimfiles"
  $vim_autoload = join-path $vim_dir "autoload"
  $vim_bundle = join-path $vim_dir "bundle"
  
  mkdir -Force "$vim_dir","$vim_autoload","$vim_bundle"
  
  download-file "https://tpo.pe/pathogen.vim" (join-path $vim_autoload "pathogen.vim")
  
  @"
execute pathogen#infect()
syntax on
filetype plugin indent on

set tabstop=2
set expandtab
set autoindent
set smartindent
set shiftwidth=2
"@ | set-content -Encoding UTF8 -Path (join-path "${env:USERPROFILE}" "_vimrc")

  $vim_plugins = 'rodjek/vim-puppet','kien/rainbow_parentheses.vim','PProvost/vim-ps1'
  foreach ($plugin in $vim_plugins) {
    install-vim-plugin $plugin
  }
}

function Setup-Vim() {
  install-vim
  configure-vim
}

# CONEMU:
#   * BROWSER: https://www.fosshub.com/ConEmu.html/ConEmuSetup.180626.exe
#   * Choose Powershell as default
#   * In settings, under General -> Appearance:
#         Uncheck "Show Search Field in Tab Bar" 
#   * In settings, enable the following macros:
#         Ctrl + N => Create(2, 0)
#         Ctrl + T => Shell("new_console:a", "powershell.exe", "", "%CD%")
#         Ctrl + Q => Close("active", "tab")

## FUNCTION TO SET-UP BASIC DEV. ENVIRONMENT ON WINDOWS

function Pause() {
  [void] (Read-Host "Press any key to continue ... ")
}

# TODO: Add the SSH public key to talk to other VMs! (Jenkins
#       acceptance key).
#
#       Use Git Bash for this.
function Setup-Dev-Environment([string] $github_token) {
  setup-git $github_token
  pause
  install-ruby
  pause
  install-ag
  pause
  setup-vim
  pause
}

#######################################################
# Useful Commands (dup of pe-utils, basically)
#######################################################

function Make-Host-Hash([string] $HostType = (Required 'HostType')) {
  $ErrorActionPreference = 'Continue'

  foreach ($hostEngine in "vmpooler","nspooler") {
    if ( $hostEngine -eq "vmpooler" ) {
      $vm = floaty get "${hostType}" --url 'https://vmpooler.delivery.puppetlabs.net/api/v1' | out-string
    } else {
      $vm = floaty get "${hostType}" --service ns --url 'https://nspooler-service-prod-1.delivery.puppetlabs.net' | out-string
    }
    if (-Not $?) {
      continue
    }

    $_, $hostName, $_ = $vm.split(' ', [StringSplitOptions] 'RemoveEmptyEntries') 
    @{
      'hostname' = $hostName;
      'type' = $hostType;
      'engine' = $hostEngine
    }
    return
  }

  throw "Could not find a VM for ${hostType}! Seems to be an invalid platform name."
}

# This is useful for executing e.g. ruby scripts that use
# the Puppet we build from Vanagon. It makes it so we can
# iterate on the repo pretty quickly/experiment with how stuff
# works.
function With-PuppetEnv([scriptblock] $code) {
  $PL_BASEDIR = 'C:\ProgramFiles64Folder\PuppetLabs\Puppet'

  $FACTER_env_windows_installdir = $PL_BASEDIR 

  $PUPPET_DIR = "$PL_BASEDIR\puppet"
  $FACTERDIR = "$PL_BASEDIR\facter"
  $HIERA_DIR = "$PL_BASEDIR\hiera"
  $MCOLLECTIVE_DIR = "$PL_BASEDIR\mcollective"
  $RUBY_DIR = "$PL_BASEDIR\sys\ruby"

  # Delete our system ruby so that we use Puppet's
  $CUR_PATH = (get-env-var PATH) -replace ([regex]::Escape('C:\Ruby24-x64\bin'))
  $PATH = "$PUPPET_DIR\bin;$FACTERDIR\bin;$HIERA_DIR\bin;$MCOLLECTIVE_DIR\bin;$PL_BASEDIR\bin;$RUBY_DIR\bin;$PL_BASEDIR\sys\tools\bin;$CUR_PATH"

  # Set the RUBY LOAD_PATH using the RUBYLIB environment variable
  $RUBYLIB = "$PUPPET_DIR\lib;$FACTERDIR\lib;$HIERA_DIR\lib;$MCOLLECTIVE_DIR\lib;"

  # Translate all slashes to / style to avoid issue #11930
  $RUBYLIB = $RUBYLIB -replace [regex]::Escape('\'),'/'

  # Enable rubygems support
  $RUBYOPT = 'rubygems'

  # Set SSL variables to ensure trusted locations are used
  $SSL_CERT_FILE = "$PUPPET_DIR\ssl\cert.pem"
  $SSL_CERT_DIR = "$PUPPET_DIR\ssl\certs"
  $OPENSSL_CONF = "$PUPPET_DIR\ssl\openssl.conf"

  # Now run our command
  with-env `
    PL_BASEDIR=$PL_BASEDIR `
    FACTER_env_windows_installdir=$FACTER_env_windows_installdir `
    PUPPET_DIR=$PUPPET_DIR `
    FACTERDIR=$FACTERDIR `
    HIERA_DIR=$HIERA_DIR `
    MCOLLECTIVE_DIR=$MCOLLECTIVE_DIR `
    RUBY_DIR=$RUBY_DIR `
    PATH=$PATH `
    RUBYLIB=$RUBYLIB `
    RUBYOPT=$RUBYOPT `
    SSL_CERT_FILE=$SSL_CERT_FILE `
    SSL_CERT_DIR=$SSL_CERT_DIR `
    OPENSSL_CONF=$OPENSSL_CONF `
    $code
}

function Get-AdsiObject {
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Name,

    [Parameter(Mandatory=$true)]
    [ValidateSet('user', 'group')]
    [string]
    $Type
  )

  [ADSI]"WinNT://./${Name},${Type}"
}

function Get-UserFlags {
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Name
  )

  $ALL_FLAGS = @{
    'SCRIPT' = 0x0001;
    'ACCOUNTDISABLE' = 0x0002;
    'HOMEDIR_REQUIRED' = 0x0008;
    'LOCKOUT' = 0x0010;
    'PASSWD_NOTREQD' = 0x0020;
    'PASSWD_CANT_CHANGE' = 0x0040;
    'ENCRYPTED_TEXT_PWD_ALLOWED' = 0x0080;
    'TEMP_DUPLICATE_ACCOUNT' = 0x0100;
    'NORMAL_ACCOUNT' = 0x0200;
    'INTERDOMAIN_TRUST_ACCOUNT' = 0x0800;
    'WORKSTATION_TRUST_ACCOUNT' = 0x1000;
    'SERVER_TRUST_ACCOUNT' = 0x2000;
    'DONT_EXPIRE_PASSWORD' = 0x10000;
    'MNS_LOGON_ACCOUNT' = 0x20000;
    'SMARTCARD_REQUIRED' = 0x40000;
    'TRUSTED_FOR_DELEGATION' = 0x80000;
    'NOT_DELEGATED' = 0x100000;
    'USE_DES_KEY_ONLY' = 0x200000;
    'DONT_REQ_PREAUTH' = 0x400000;
    'PASSWORD_EXPIRED' = 0x800000;
    'TRUSTED_TO_AUTH_FOR_DELEGATION' = 0x1000000;
    'PARTIAL_SECRETS_ACCOUNT' = 0x04000000;
  }

  $userflags = (Get-AdsiObject -Name $Name -Type 'user').Get('UserFlags')
  $flags = @()
  foreach ($flag in $ALL_FLAGS.keys) {
    if (($userflags -band $ALL_FLAGS[$flag]) -ne 0) {
      $flags += $flag
    }
  }

  $flags
}

# TODO: Make symlink from Vanagon dir. of Puppet to the real, expected
# location of Puppet. This is something for later though. Maybe could add
# to the Makefile, actually. Might be better to do it there.
#
# TODO: Add the option to run presuite and postsuite steps, pref. taking in
# the right steps as input (so a non-switch set of parameters)
function Run-AcceptanceTests {
  Param(
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [hashtable[]]
    $absHosts,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $bhgString,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $tests,

    [Switch]
    $init,

    [Switch]
    $provision
  )

  $ErrorActionPreference = 'Stop'

  $absHostsJson = $absHosts | ConvertTo-Json -Compress

  In-Dir 'acceptance' {
    with-env BUNDLE_PATH=.bundle/gems BUNDLE_BIN=.bundle/bin ABS_RESOURCE_HOSTS="$absHostsJson" {
      bundle install

      $hostsFile = "hosts.yaml"
      $hostsFileContents = bundle exec beaker-hostgenerator "${bhgString}" --hypervisor abs --disable-default-role --osinfo-version 1 | out-string
      set-content -Path "${hostsFile}" -Value "$hostsFileContents" -Encoding "ASCII"

      if ($init) {
        bundle exec beaker init --hosts $hostsFile --options-file 'config/aio/options.rb'
      }

      if ($provision) {
        bundle exec beaker provision
      }

      bundle exec beaker exec "$tests"
    }
  }
}

<#
TODO:
  * Add code for getting a VM, deleting a VM.
  * Add code for setting up a build host for Vanagon
  * Add code for copying over a Git repo (specifically Windows platforms) + rebuilding stuff
      * In Vanagon makefile
#>

