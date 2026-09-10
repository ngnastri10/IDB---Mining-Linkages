"""
Project-wide config - everyone working on this repo needs their own copy
of this file, since it just points at where YOUR local Data/Results/
Working folders live. That's a different path for everyone, which is
exactly why this file isn't shared through git - see SETUP below.

SETUP (one-time, first thing you do after cloning this repo):
    1. Copy this file and rename the copy to "config.py" (same folder,
       right here at the top of the repo).
    2. Open config.py and change PROJECT_ROOT below to the folder on YOUR
       computer that contains your "Data", "Results", and "Working"
       folders.
    3. That's it. config.py is listed in .gitignore, so your local path
       never gets pushed, and you'll never overwrite anyone else's.

Every pull/build script in this repo should read PROJECT_ROOT from
config.py to know where to save or find data. Nothing else in this repo
should ever have someone's personal file path typed directly into it.
"""

# Change this to the folder that contains YOUR "Data", "Results", and
# "Working" folders (i.e. the folder "Code" itself is sitting inside).
# Example, from Nico's machine:
#   PROJECT_ROOT = r"C:\Users\ngnas\OneDrive\Desktop\PhD Documents\Publications\IDB - Mining"
PROJECT_ROOT = r"PUT_YOUR_OWN_PATH_HERE"
