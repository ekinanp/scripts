from sys import argv
from github import Github, GithubException, InputGitAuthor
from datetime import datetime
import os
import time
import json

argc = len(argv)
if (argc != 2):
    print("USAGE: python delete.py <repo>")
    exit(1)

repo_name = argv[1] 

repo = Github(login_or_token = os.environ["GITHUB_TOKEN"]).get_user().get_repo(repo_name)
repo.delete()
