import os

# This is not good Python, but whatever. Just need something
# that is working.

script_dir = os.path.dirname(os.path.realpath('__file__'))
exec(open(os.path.join(script_dir, "setup_repos.py")).read())

AGENT_RELEASE_CANDIDATE = "03320b7ccc502ba1b880a0f382ddcd3864bdfd88"

RUN_TICKETMATCH_PATH = os.path.join(script_dir, "run-ticketmatch.sh")
RUN_TICKETMATCH = os.path.basename(RUN_TICKETMATCH_PATH)

TICKETMATCH_MAP = {
    "puppet-agent"          : ("5.3.5", "PA", "puppet-agent 5.3.6"),
    "facter"                : ("3.9.5", "FACT", "FACT 3.9.6"),
    "hiera"                 : ("3.4.2", "HI", "HI 3.4.3"),
    "pxp-agent"             : ("1.8.2", "PCP", "pxp-agent 1.8.3"),
    "puppet"                : ("5.3.5", "PUP", "PUP 5.3.6"),
    "marionette-collective" : ("2.11.4", "MCO", "MCO 2.11.5"),
}

def run_ticketmatch_on(repo_name, **kwargs):
    setup_repos("5.3.x", AGENT_RELEASE_CANDIDATE, **kwargs)
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
