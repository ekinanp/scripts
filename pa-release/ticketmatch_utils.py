import os

# This is not good Python, but whatever. Just need something
# that is working.

script_dir = os.path.dirname(os.path.realpath('__file__'))
exec(open(os.path.join(script_dir, "setup_repos.py")).read())

AGENT_RELEASE_CANDIDATE = "c47a97544f7126e20d63e857350f1d8f71d4823c"

RUN_TICKETMATCH_PATH = os.path.join(script_dir, "run-ticketmatch.sh")
RUN_TICKETMATCH = os.path.basename(RUN_TICKETMATCH_PATH)

TICKETMATCH_MAP = {
    "puppet-agent"          : ("5.5.0", "PA", "puppet-agent 5.5.1"),
    "facter"                : ("3.11.0", "FACT", "FACT 3.11.1"),
#    "hiera"                 : ("3.4.2", "HI", "HI 3.4.3"),
    "pxp-agent"             : ("1.9.0", "PCP", "pxp-agent 1.9.1"),
    "puppet"                : ("5.5.0", "PUP", "PUP 5.5.1"),
    "marionette-collective" : ("2.12.0", "MCO", "MCO 2.12.1"),
    "libwhereami" : ("0.2.0", "FACT", "FACT 3.11.1"),
    "leatherman" : ("1.4.0", "LTH", "LTH 1.4.0"),
}

def run_ticketmatch_on(repo_name, **kwargs):
    setup_repos("5.5.1_release", AGENT_RELEASE_CANDIDATE, **kwargs)
    print("\n\n\n")

    repo = globals()[var_name(repo_name)]
    repo.in_repo(cmd("cp -a %s %s" % (RUN_TICKETMATCH_PATH, RUN_TICKETMATCH)))

    (git_from_rev, jira_project, jira_fix_version) = TICKETMATCH_MAP[repo_name]
    git_to_rev = repo.in_repo(cmd("git rev-parse HEAD"))
    
    print("RUNNING TICKETMATCH...")
    ticketmatch_cmd = "./%s %s %s %s \"%s\"" % (
        RUN_TICKETMATCH,
        git_from_rev,
        git_to_rev,
        jira_project,
        jira_fix_version
    )
    repo.in_repo(
        lambda : os.system(ticketmatch_cmd)
    )
