import os

# This is not good Python, but whatever. Just need something
# that is working.

script_dir = os.path.dirname(os.path.realpath('__file__'))
exec(open(os.path.join(script_dir, "setup_repos.py")).read())

AGENT_RELEASE_CANDIDATE = "0fe2706204cedcb275668c5f1c67d28b372b1238"

RUN_TICKETMATCH_PATH = os.path.join(script_dir, "run-ticketmatch.sh")
RUN_TICKETMATCH = os.path.basename(RUN_TICKETMATCH_PATH)

TICKETMATCH_MAP = {
    "puppet-agent"          : ("5.4.0", "PA", "puppet-agent 5.5.0"),
    "facter"                : ("3.10.0", "FACT", "FACT 3.11.0"),
    "pxp-agent"             : ("1.8.2", "PCP", "pxp-agent 1.9.0"),
    "puppet"                : ("5.4.0", "PUP", "PUP 5.5.0"),
    "marionette-collective" : ("2.11.4", "MCO", "MCO 2.12.0"),
}

def run_ticketmatch_on(repo_name, **kwargs):
    setup_repos("5.5.x", AGENT_RELEASE_CANDIDATE, **kwargs)
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
