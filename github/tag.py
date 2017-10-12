from sys import argv
from github import Github, GithubException, InputGitAuthor
from datetime import datetime
import os
import time
import json

# for some reason, python's isoformat does not display the utc offset
# as a ":" separated value, and it does not have it as an option with
# the datetime module.
def current_date():
    date = datetime.now()
    utc_offset = time.strftime("%z")
    return date.strftime("%Y-%m-%dT%H:%M:%S") + utc_offset[:3] + ":" + utc_offset[3:]

argc = len(argv)
if (argc < 4 or argc > 5):
    print("USAGE: python tag.py <repo> <tag> <sha> [message]")
    exit(1)

repo_name, new_tag, sha = argv[1:4] 
message = new_tag.join(['"', '"']) if argc == 4 else argv[4]

repo = Github(login_or_token = os.environ["GITHUB_TOKEN"]).get_user().get_repo(repo_name)
# TODO: What should go here as "Author" and "E-mail"?
author = InputGitAuthor("Jenkins CI", "ci@puppetlabs.com", current_date())
tag = repo.create_git_tag(new_tag, message, sha, "foo", author) 
ref = "refs/tags/"+new_tag

try:
    repo.create_git_ref(ref, tag.sha)
except GithubException as e:
    if "Reference already exists" not in e.data['message']:
        raise e
    print("The reference " + ref + " already exists. Passing through ...")

print(ref)
