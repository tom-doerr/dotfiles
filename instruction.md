Instructions for Aider and other LLM tools:
Keep it simple!

1. Embrace Simplicity Over Cleverness
- Write code that's immediately understandable to others
- If a solution feels complex, it probably needs simplification
- Optimize for readability first, performance second unless proven otherwise
- Avoid premature optimization

2. Focus on Core Functionality
- Start with the minimum viable solution
- Question every feature: "Is this really necessary?"
- Build incrementally based on actual needs, not hypothetical ones
- Delete unnecessary code and features

3. Leverage Existing Solutions
- Use standard libraries whenever possible
- Don't reinvent the wheel
- Choose well-maintained, popular libraries for common tasks
- Keep dependencies minimal but practical

4. Function Design
- Each function should have a single responsibility
- Keep functions short (typically under 20 lines)
- Use descriptive names that indicate purpose
- Limit number of parameters (3 or fewer is ideal)

5. Project Structure
- Keep related code together
- Use consistent file organization
- Maintain a flat structure where possible
- Group by feature rather than type

```plaintext
# Good project structure
project/
├── main.py
├── config.py
├── users/
│   ├── models.py
│   ├── services.py
│   └── tests/
└── utils/
    └── helpers.py
```

6. Code Review Guidelines
- Review for simplicity first
- Question complexity and overengineering
- Look for duplicate code and abstraction opportunities
- Ensure consistent style and naming conventions

7. Maintenance Practices
- Regularly remove unused code
- Keep dependencies updated
- Refactor when code becomes unclear
- Document only what's necessary and likely to change

Remember:
- Simple code is easier to maintain and debug
- Write code for humans first, computers second
- Add complexity only when justified by requirements
- If you can't explain your code simply, it's probably too complex


Complexity is what kills you
When you finish editing, present me with a list of options of how we could continue. Indicate what you think should be the next step
When I just send you the letter c, I mean continue
Make scripts executable when first creating them
Add docstrings or comments only to explain the why 
When you see comments or docstrings that are not necessary remove them.
Use type hints when possible.

Use descriptive, meaningful names for variables, functions, and classes

Group related code together
Validate input data
Avoid deep nesting of conditionals

Only provide the filename/filepath above a code block when performing an edit.
Do NOT include 'New file: ' or (apply to main.py) or similar.

Try to do as many edits at once as possible. 
You can edit many files and also add tests and also remove old code or delete old tests in a single completion.


When working, think about:
how should we continue? what are issues? do you see bugs? should we add more tests? would more tests help narrow down the issues? if so add as many tests as you think help. do we need to refactor? should we switch approaches? how can we simplify? is there code or tests we should delete? are there tests we need to update? continue with what you think is most important. please do many edits, it's good if you fix many issues at the same time. try to fix all issues at the same time  

To run shell commands, just print them in markdown `code` quotes then i can run them. 

In DSPy, you can do lm = dspy.LM('openrouter/google/gemini-2.0-flash-001') to load a model
Don't use docstrings, use comments instead if explanation is required
Don't just disable linting to avoid the issue, fix it

Don't try to create workarounds, fix the actual issues
Use pytest for writing python tests 
To add files to the chat, write them in markdown code quotes and I might add them 
I might type without spaces, punctuation and use shorthand and often make typos. please just tell me what you think i typed before proceeding to process my input. please repeat what i wrote word for word before working on my request.
don't start streamlit apps for me, I'll do that myself
also don't show me the commands for starting streamlit apps unprompted since Aider then asks me if I want to run it each time
when i add a task.md to the chat please do the tasks and note what you did

when removing or moving files, use git rm and git mv
Reasoning streaming:
response = completion(
    model="deepseek/deepseek-reasoner",
    messages=messages,
    stream=True
)

# Print the streaming reasoning tokens
for chunk in response:
    if chunk.choices[0].delta.reasoning_content:
        print(chunk.choices[0].delta.reasoning_content, end='')

Use many asserts so we can recognize issues with our mental model early
LLMs I use with Aider/DSPy/LiteLLM:
deepseek/deepseek-reasoner
deepseek/deepseek-chat
openrouter/google/gemini-2.0-flash-001
openrouter/deepseek/deepseek-r1
openrouter/deepseek/deepseek-r1-distill-qwen-32b
openrouter/deepseek/deepseek-chat
gemini/gemini-2.0-flash-exp

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

When running docker, please use the --quiet flag so the interactive content doesn't flood the context window 



