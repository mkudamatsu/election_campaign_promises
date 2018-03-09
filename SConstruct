# Comments are copy-and-pasted from 
# http://zacharytessler.com/2015/03/05/data-workflows-with-scons/
# https://github.com/gslab-econ/ra-manual/wiki/SCons

import os
env = Environment(ENV = {'PATH' : os.environ['PATH']}, IMPLICIT_COMMAND_DEPENDENCIES = 0)
# The Environment() call sets up a build environment that you can use to set various build options.
# ENV = {'PATH' : os.environ['PATH']} gives SCons access to the PATH environment variable.
# IMPLICIT_COMMAND_DEPENDENCIES = 0 tells SCons to not track the executables of any commands used, which will be different across machines.

env.Decider('MD5-timestamp')
# By default, SCons uses MD5 hashes of file contents to determine whether an input file has changed. When working with even moderately sized data files, computing these hashes on every build can take a very long time. The MD5-timestamp option instructs SCons to first check file timestamps, and only compute the MD5 hash if the timestamp has changed, to confirm that file is actually different. This can speed things up dramatically.

Export('env')
# This makes env available to code in all your SConscript files. Note that the objects to export are passed as strings.

env.Command(
	target = '#build_temp/smd_year_winner_voteshare_margin.dta', 
	source = [
        '#input/data_asahi-todai/data/nameid_year_all.csv', 
        '#input/data_japanese-elections/data/lower_house_results.csv',
        '#code_build/smd_year_winner_voteshare_margin.do'
              ],
	action = 'StataMP -e code_build/smd_year_winner_voteshare_margin.do && mv smd_year_winner_voteshare_margin.log log'
    )
# In the source and target paths, the "#" identifies a path as relative to the top-level SConstruct file, which is useful if you want all your build outputs in one place, regardless of where the SConscript file is.
