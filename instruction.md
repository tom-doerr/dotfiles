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
Make scripts executable
Add docstrings or comments only to explain the why 
When you see comments or docstrings that are not necessary remove them.
Use type hints when possible.

Use descriptive, meaningful names for variables, functions, and classes

Group related code together
Use consistent indentation (typically 2 or 4 spaces)
Add spacing between logical sections

Handle potential errors explicitly
Validate input data
Return meaningful error messages

Use consistent formatting
Avoid deep nesting of conditionals

## Common Anti-Patterns to Avoid

1. God Classes: Classes that do too much
2. Feature Envy: Methods that use more features of other classes than their own
3. Long Parameter Lists: Methods with too many parameters
4. Tight Coupling: Classes that know too much about each other
5. Premature Optimization: Making code complex for theoretical performance gains

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

Use pytest for writing tests

To add files to the chat, write them in markdown code quotes and I might add them 
