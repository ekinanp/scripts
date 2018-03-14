import os

# This is not good Python, but whatever. Just need something
# that is working.

script_dir = os.path.dirname(os.path.realpath('__file__'))
exec(open(os.path.join(script_dir, "setup_repos.py")).read())

AGENT_RELEASE_CANDIDATE = "0fe2706204cedcb275668c5f1c67d28b372b1238"

RUN_TICKETMATCH_PATH = os.path.join(script_dir, "run-ticketmatch.sh")
RUN_TICKETMATCH = os.path.basename(RUN_TICKETMATCH_PATH)

def run_ticketmatch_on(component, git_from_rev, git_to_rev, jira_project, jira_fix_version):
    setup_repos("5.5.x", AGENT_RELEASE_CANDIDATE)
    print("\n\n\n")

    component_repo = globals()[var_name(component)]
    component_repo.in_repo(cmd("cp -a %s %s" % (RUN_TICKETMATCH_PATH, RUN_TICKETMATCH)))

    print("RUNNING TICKETMATCH...")
    ticketmatch_cmd = "./%s %s %s %s \"%s\"" % (
        RUN_TICKETMATCH,
        git_from_rev,
        git_to_rev,
        jira_project,
        jira_fix_version
    )
    component_repo.in_repo(
        lambda : os.system(ticketmatch_cmd)
    )
