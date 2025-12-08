when you finish working, give me a numbered list of options of how you think we should continue so i can just send you a number to prompt you to continue with that; order them by the priority that you think they should have with the most important one the furthest up
do not use fallbacks since they hide issues
do not use broad excepts which hide issues
don't copy service files into the systemd folder, create symlinks instead
when you run SELECT commands with psql please do it all in a single line so my allow rule matches 
do many tiny edits instead of a large one 
when you hit the write limit, do even smaller inserts 

# abbreviations
rr: review and recommend - review the complete project code and make recommendations 
c: continue
acp: add commit push
h: how should we continue
t: add tests
a: run all tests
l: run linter
'rt': review the code and add tests where most important
i: investigate
ucm: remember what you just learned by updating CLAUDE.md
ucm: update CLAUDE.md

# git best practices
- when possible, use git rm/mv instead of rm, mv 

# python package management
- use uv when installing python packages 

# code review guidelines
- please keep it as simple as possible, write few lines of code so it is easier for me to review 
- write as little code as possible to get tasks done; for every bit of code it is a lot of effort to review and to work with later
- when hooks limit edit size to 400 bytes, use many tiny edits instead of large ones

# system interaction guidelines
- avoid using sudo commands, I can't enter the password in this interface and it interrupts your work
- please only use docker compose to run commands when possible - if you don't i might have to confirm execution of the command which slows things down and causes extra work for me 
- please avoid command substitution since those break the automated command execution approval and i need to review and allow execution of your command manually 
- use docker compose directly instead of creating shell files that use docker compose to avoid having to confirm script execution and prevent code messiness

# work ethic
- keep working until all todos are done

# development best practices
- make sure not to duplicate existing code or functionality 
- don't create a new file for every change/feature
- please make sure to put new files in the proper locations and don't just write every new file into the repository root

# docker best practices
- do not use the standard application ports when exposing docker compose service ports to the host since those ports are often already in use or need to be available so it's easy for me to start services on the host

# CLAUDE.md
- keep the notes in CLAUDE.md very detailed and write down everything you learned in it 
- update it frequently
- instead of just removing outdated knowledge, note down why it is no longer true
- update it each time before you finish working

# HUMANS.md
- i often send multiple requests and let you work async on them, which means i might not see your messages
- write questions you have, answer to my questions, and other information to HUMANS.md file
