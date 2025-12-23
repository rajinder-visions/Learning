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
### How to setup a git directory
go to the path where you want to initialize git repository to track changes in project.
```
git init
```
To add file so that git can track run the following command
```
git add <filename>
```
if you want to add all the files present in current directory Run the command given below:-
```
git add .
```
