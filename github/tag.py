from github import Github
from github import GithubException
from github import InputGitAuthor
from sys import argv
from datetime import datetime

# TODO: Change this to the puppetlabs token after testing!
TOKEN = "7c7e6001ce96cf1325f17c381119c888ac3b250e"

# TODO: Is this necessary? Can remove it.
TIMEOUT = 60

argc = len(argv)
if (argc < 4 or argc > 5):
    print("USAGE: python tag.py <repo> <tag> <sha> [message]")
    exit(1)

repo_name, new_tag, sha = argv[1], argv[2], argv[3] 
message = argv[4] if argc == 5 else "Tagged to " + new_tag 
repo = Github(login_or_token = TOKEN, timeout = TIMEOUT).get_user().get_repo(repo_name)

author = InputGitAuthor("Jenkins", "blah@puppet.com", datetime.now().__str__())
repo.create_git_tag(new_tag, message, sha, "commit", author) 
ref = "refs/tags/"+new_tag
repo.create_git_ref(ref, sha)
print(ref)
