from workflow.repos.constants import (REPOS, pa_components)
from workflow.repos.git_repository import GitRepository

from workflow.utils import (commit, to_action, identity, const, in_directory, sequence, git, exec_stdout)
from workflow.actions.repo_actions import bump_version
from workflow.repos.constants import (REPOS, pa_components)
from workflow.actions.file_actions import (new_file, modify_line, read_file)

from jira import JIRA
import subprocess
import os
import json

# Use the current working directory, appended with "WORKSPACE"
WORKSPACE = os.path.join(os.path.dirname(os.path.realpath('__file__')), "WORKSPACE")

# NOTE: This does not consider private components, which is OK b/c the 5.5.x release
# doesn't use them. Modify the script (or even the workflow tool) in the future to
# account for this.

# Buggy, doesn't account for Bash quoting but simple enough.
def cmd(cmd, **kwargs):
    return lambda : subprocess.check_output(cmd.split(" "), **kwargs).decode("utf-8").strip()

def var_name(component):
    return component.replace("-", "_")


# Takes in an agent branch (to reset the agent to) and an agent sha.
# Clones the agent repo, checks it out at the specified sha, then clones
# all of the agent components and checks them out there. Exports relevant
# global variables afterwards to use elsewhere.
def setup_repos(agent_branch, agent_sha, **kwargs):
    reset_branches = kwargs.get('reset_branches', False)
    globals()['puppet_agent'] = REPOS['puppet-agent'](workspace = WORKSPACE, stub_branch = identity)
    if reset_branches:
        puppet_agent.reset_branch(agent_branch)

    component_jsons = puppet_agent.in_branch(agent_branch, exec_stdout(
        "find", "configs/components", "-name", "*.json"
    )).split("\n")
    components = [os.path.basename(component_json)[:-5] for component_json in component_jsons]

    for component in components:
        if component not in pa_components():
            continue
        globals()[var_name(component)] = REPOS[component](
            workspace = WORKSPACE,
            stub_branch = identity,
            puppet_agent = puppet_agent
        )
        component_repo = globals()[var_name(component)]
        # Get the component SHA to check out from the component.json file
        component_json_contents = puppet_agent.in_branch(
            agent_branch,
            read_file("configs/components/%s.json" % component)
        )
        component_ref = json.loads(component_json_contents)["ref"]

        # Checkout the component reference
        component_repo.in_repo(cmd("git fetch upstream"))
        component_repo.in_repo(cmd("git checkout %s" % component_ref))
