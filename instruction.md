- work on fixing tests as long as there are issues 
- use pytest for testing
- Continue operations unless explicit stop command given
- Don't create fallback implementations
- If there's an error, raise it and don't hide it by switching to a fallback
- Fix the actual issue instead of relying on fallbacks
- When I send you just 'c' I mean 'continue'
Aliases:
'c': continue
'rc': reduce complexity without removing functionality
'hrc': how can we reduce complexity without removing functionality
's': same error again
'f': fix
'e': explain
't': add tests
'ta': try again to edit the files
'ait': add integration tests
'i': investigate
'ir': investigate and make a recommendation
'a': run all tests
'rc': review the code 
'rt': review the code and add tests where most important
'l': run linter 
'rr': review the project. do you have recommendations? Assign a priority to each suggestion
'acp': git add, git commit, git push
'acpm': git add, git commit, git push, git merge
'h': how should we continue? please tell me what you think we should do next
'wmi': what functionality is only mocked or not implemented at all? Please implement it
'rope': use rope to analyze the code organization and improve it
'con': consolidate
'ra': run radon (exclude venv;  --exclude "*/venv/*") to find where we need to improve code quality and fix it
'report': write an in depth report about the state of the project
'fic': fix the issues written to context.txt

- Please make suggestions of how we should continue
- Point out bugs or architecture issues
- Avoid complexity
- When you run streamlit, don't let it open a new browser window
- Question every requirement
- Simplify and optimize
- Accelerate cycle time
- In DSPy, you can do lm = dspy.LM('openrouter/google/gemini-2.0-flash-001') to load a model
- Don't set API keys or manage them for using LLMs with litellm or DSPy, they are automatically loaded by the libraries from the env
- Don't use docstrings, use comments instead if explanation is required
- Don't just disable linting to avoid the issue, fix it
- Postgres is set up with user tom and database twitter, accessible via
Unix domain socket

Use many asserts so we can recognize issues with our mental model early

LLMs I use with Aider/DSPy/LiteLLM:
deepseek/deepseek-reasoner
deepseek/deepseek-chat
openrouter/google/gemini-2.0-flash-001
openrouter/deepseek/deepseek-r1-distill-qwen-32b
gemini/gemini-2.0-flash-exp
from dspy.teleprompt import BootstrapFewShotWithRandomSearch

Don't use the OpenRouter models for Deepseek unless I tell you otherwise, Openrouter Deepseek is a lot more expensive 

# DSPy info
# BootstrapFewShotWithRandomSearch:
fewshot_optimizer = BootstrapFewShotWithRandomSearch(metric=your_defined_metric, max_bootstrapped_demos=2, num_candidate_programs=8, num_threads=NUM_THREADS)
your_dspy_program_compiled = fewshot_optimizer.compile(student = your_dspy_program, trainset=trainset, valset=devset)

# MIPROv2:
# Import the optimizer
from dspy.teleprompt import MIPROv2

# Initialize optimizer
teleprompter = MIPROv2(
    metric=gsm8k_metric,
    auto="light", # Can choose between light, medium, and heavy optimization runs
)

# Optimize program
print(f"Optimizing program with MIPRO...")
optimized_program = teleprompter.compile(
    program.deepcopy(),
    trainset=trainset,
    max_bootstrapped_demos=3,
    max_labeled_demos=4,
    requires_permission_to_run=False,
)

# Save optimize program for future use
optimized_program.save(f"mipro_optimized")

# Evaluate optimized program
print(f"Evaluate optimized program...")
evaluate(optimized_program, devset=devset[:])

# SIMBA
simba = dspy.SIMBA(metric=metric, max_steps=12, max_demos=10)
optimized_agent = simba.compile(agent, trainset=trainset, seed=6793115)


Please properly use git and use git branches
Please don't ask me to perform actions if you can perform them yourself
Please don't just edit data in the DB without my permission

Use python3.11
Don't keep starting new Streamlit instances, my already running Streamlit instance reloads the changes
Don't delete local branches
Make sure you created an appropriate branch before editing the project
Please keep retrying to edit files multiple times; For large files it can take multiple attempts
If you are inside a venv, you can mark commands as safe to autorun
When we keep encountering the same issue, step back and think about what really the underlying issue is; code complexity? architecture? the library we use?
Please run a linter from time to time to catch potential issues
Please tell me if you see bugs or architecture issues or other problems
Choose branch names and commit messages yourself
If editing a file fails, try to perform smaller edits
Before you ask me questions, think about if you can find the answer by yourself
Don't use fallbacks, they make it hard to understand what's going on
When you are finished, please present me with a list of options of what we could do next and add priorities to them; tell me what you think we should do next as well
Please do not delete data from the DB (or delete data anywhere else)without my approval
Use uv instead of pip
Don't swallow exceptions
Please don't ask me to provide information if you can get it yourself since you are just so much faster
Please use git rm instead of rm when possible
Only merge into main after we merge into develop and only merge into main when I explicitly tell you to do so
When merging, please merge the whole branch
Please do not stash changes unless I explicitly ask you to do so
Decide on commit messages yourself 
We already migrated the database
Follow TDD: Please add tests first if possible
Add many asserts to catch issues early
Use rope to improve code quality
Please point out if I prompt you to do something that is in conflict with the rules, I might need to update the rules 
Highest priority is to have a well organized project structure and avoid redundancy in order to keep complexity low 
Consolidate when possible and make sure to remove code that is no longer used
When running pylint, use --jobs=12 
When you use docker compose, please run it as non blocking since I can't easily interrupt it
Don't modify linter settings without my explicit instruction; they are very strict on purpose 
rumination will solve all your problems. if you still have problems you have to ruminate more
When removing files, please use git rm
When you create new files, only use the filename/path without additional text in paranthesis 
Important: Please show messages to me again after you've created all search replace blocks so I actually see your messages
