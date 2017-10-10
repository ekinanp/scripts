from sys import argv
from github import Github, GithubException, InputGitAuthor
from datetime import datetime
import os
import time
import re
import json

# for some reason, python's isoformat does not display the utc offset
# as a ":" separated value, and it does not have it as an option with
# the datetime module.
def current_date():
    date = datetime.now()
    utc_offset = time.strftime("%z")
    return date.strftime("%Y-%m-%dT%H:%M:%S") + utc_offset[:3] + ":" + utc_offset[3:]

ARGV_REGEX = re.compile("([^:]+):([^:]+):([^:]+)(?::([^:]+))?")

argc = len(argv)
match_obj = ARGV_REGEX.match(argv[1])
if (argc != 2 and match_obj is None):
    print("USAGE: python tag.py <repo>:<tag>:<sha>[:message]")
    exit(1)

repo_name, new_tag, sha = match_obj.groups()[:3] 
message = match_obj.groups()[-1]
if message is None : message = new_tag.join(['"', '"'])

repo = Github(login_or_token = os.environ("GITHUB_TOKEN")).get_user().get_repo(repo_name)
# TODO: What should go here as "Author" and "E-mail"?
author = InputGitAuthor("Jenkins CI", "blah@puppet.com", current_date())
tag = repo.create_git_tag(new_tag, message, sha, "foo", author) 
ref = "refs/tags/"+new_tag
repo.create_git_ref(ref, tag.sha)

print(json.dumps({"component" : repo_name, "ref" : ref}))
