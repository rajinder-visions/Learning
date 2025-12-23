# What is Git

Git is a **VCS** (Version Control System) which tracks our code and records history, changes when and by which these changes are made, or if if any file is deleted by mistake we can reflect back to it. 


## How to Configure git
### To configure username,email and default branch
```
git config --global user.name "Your Name"
git config --global user.email "abc@gmail.com"
git config --global int.defaultBranch main
```
### To Check the configuration
```
git config --list --show-origin
or
git config --global --list
```
### Working with git
#### To initialize.
```
git init
```
#### To add specific file 
```
git add <filename>
```
#### To add all the files.
```
git add .
```
#### To commit.
```
git commit -m "Your Commit Message"
```
#### To Clone a git Project From Remote
```
git clone <https://test-user/test.git>
```
#### To Check status 
```
git status
```
