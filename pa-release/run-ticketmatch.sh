#!/usr/bin/expect -f

proc validate_arg {{arg}} {
  if {${arg} eq ""} {
    puts "Usage: ./run-ticketmatch.sh <git-from-rev> <git-to-rev> <jira-project> <jira-fix-version>"
    exit 1
  }
}

set TICKETMATCH "/Users/enis.inan/GitHub/ticketmatch/ticketmatch.rb"

set git_from_rev [lindex ${argv} 0]
set git_to_rev [lindex ${argv} 1]
set jira_project [lindex ${argv} 2]
set jira_fix_version [lindex ${argv} 3]

validate_arg ${git_from_rev}
validate_arg ${git_to_rev}
validate_arg ${jira_project}
validate_arg ${jira_fix_version}

spawn ruby ${TICKETMATCH} 
expect "Rev: "
send "${git_from_rev}\r"
expect "Rev: |master| "
send "${git_to_rev}\r"
expect "project: |PUP| "
send "${jira_project}\r"
expect "version: |${jira_project} ${git_to_rev}| "
send "${jira_fix_version}\r"
expect "$ "
