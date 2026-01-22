# Makefile for cs conversion using reposurgeon
#
# Steps to using this:
# 1. Make sure reposurgeon and repotool are on your $PATH.
# 2. (Skip this step if you're starting from a stream file.) For svn, set
#    REMOTE_URL to point at the remote repository you want to convert;
#    you can use either an svn: URL, an rsync: URL, or a p4: URL for this.
#    If the repository is already in a DVCS such as hg or git,
#    set REMOTE_URL to either the normal cloning URL (starting with hg://,
#    git://, etc.) or to the path of a local clone.
# 3. For cvs, set CVS_HOST to the repo hostname and CVS_MODULE to the module,
#    then uncomment the line that builds REMOTE_URL 
#    Note: for CVS hosts other than Sourceforge or Savannah you will need to 
#    include the path to the CVS modules directory after the hostname.
# 4. Set any required read options, such as --user-ignores
#    by setting READ_OPTIONS.
# 5. Optionally, replace the default value of DUMPFILTER with a
#    command or pipeline that actually filters the dump rather than
#    just copying it through.  The most usual reason to do this is
#    that your Subversion repository is multiproject and you want to
#    strip out one subtree for conversion with repocutter sift and pop
#    commands.  Note that if you ever did copies across project
#    subtrees this simple stripout will not work - you are in deep
#    trouble and should find an expert to advise you
# 6. Run 'make stubmap' to create a stub author map.
# 7. Run 'make' to build a converted repository.
#
# For a production-quality conversion you will need to edit the map
# file and the lift script.  During the process you can set EXTRAS to
# name extra metadata such as a comments message-box that the final.
# conversion depends on.
#
# Afterwards, you can use the *compare productions to check your work.
#

EXTRAS = 
CS_REMOTE_URL = svn://svn.code.sf.net/p/crystal/code
CEL_REMOTE_URL = svn://svn.code.sf.net/p/cel/code/
READ_OPTIONS =
#CHECKOUT_OPTIONS = --ignore-externals
DUMPFILTER = cat
VERBOSITY = "set progress"
REPOSURGEON = reposurgeon
REPOCUTTER = repocutter
LOGFILE = conversion.log

.PHONY: local-clobber remote-clobber gitk gc compare clean stubmap

default: cs-git

# Build a local mirror of remote repositories
cs-mirror:
	repotool mirror $(CS_REMOTE_URL) cs-mirror

cel-mirror:
	repotool mirror $(CEL_REMOTE_URL) cel-mirror

# Export the original sources without filtering
cs.svn: cs-mirror
	(cd cs-mirror/ >/dev/null; repotool export) >cs.svn

cel.svn: cel-mirror
	(cd cel-mirror/ >/dev/null; repotool export) >cel.svn

%-stubmap: cel.svn
	$(REPOSURGEON) $(VERBOSITY) 'read $(READ_OPTIONS) <$*.svn' 'authors write >$*-authors.map'

# Create a initial authors map
stubmap: cs-stubmap cel-stubmap
	sort -u cs-authors.map cel-authors.map > authors.map

cslibs.filter.svn:
	repocutter sift '^CSlibs'<cs.svn | repocutter pathrename '^CSlibs/migrated' 'CSlibs' | repocutter -r 28212:28213 deselect | repocutter pop > cslibs.filter.svn

csextra.filter.svn:
	repocutter sift '^CSExtra'<cs.svn | repocutter pathrename '^CSExtra/migrated' 'CSExtra' '^CSExtra/branches/soc/editor' 'CSExtra/branches/soc' | repocutter pop > csextra.filter.svn

%-git: %.filter.svn %.lift cs.opts base.lift cs.map $(EXTRAS)
	$(REPOSURGEON) $(VERBOSITY) 'logfile $(LOGFILE)' 'script cs.opts' "read $(READ_OPTIONS) <$*.filter.svn" 'authors read <authors.map' 'sourcetype svn' 'prefer git' 'script base.lift' 'script $*.lift' 'rebuild $*-git'

clean:
	rm -rf *.svn *-authors.map

## Build the repository from the stream dump
#cs-git: cs.svn cs.opts cs.lift cs.map $(EXTRAS)
#	$(REPOSURGEON) $(VERBOSITY) 'logfile $(LOGFILE)' 'script cs.opts' "read $(READ_OPTIONS) <cs.svn" 'authors read <cs.map' 'sourcetype svn' 'prefer git' 'script cs.lift' 'legacy write >cs.fo' 'rebuild cs-git'
#
## Build a stream dump from the local mirror
#cs.svn: cs-mirror
#	(cd cs-mirror/ >/dev/null; repotool export) | $(DUMPFILTER) >cs.svn
#
## Build a local mirror of the remote repository
#cs-mirror:
#	repotool mirror $(REMOTE_URL) cs-mirror
#
## Make a local checkout of the source mirror for inspection
#%-checkout: %-mirror
#	cd %-mirror >/dev/null; repotool checkout $(CHECKOUT_OPTIONS) $(PWD)/%-checkout
#
## Force rebuild of stream from the local mirror on the next make
#local-clobber: clean
#	rm -fr cs.fi cs-git
#
## Force full rebuild from the remote repo on the next make.
#remote-clobber: local-clobber
#	rm -fr cs.svn *-mirror *-checkout
#
## Get the (empty) state of the author mapping from the first-stage stream
#stubmap: cs.svn
#	$(REPOSURGEON) $(VERBOSITY) "read $(READ_OPTIONS) <cs.svn" 'authors write >cs.map'
#
## Compare the histories of the unconverted and converted repositories at head
## and all tags.
#headcompare: cs-mirror cs-git
#	repotool compare cs-mirror cs-git
#tagscompare: cs-mirror cs-git
#	repotool compare-tags cs-mirror cs-git
#branchescompare: cs-mirror cs-git
#	repotool compare-branches cs-mirror cs-git
#allcompare: cs-mirror cs-git
#	repotool compare-all cs-mirror cs-git
#
## General cleanup and utility
#clean:
#	rm -fr *~ .rs* cs-conversion.tar.gz *.svn *.fi *.fo
#
##
## The following productions are git-specific
##
#
## Browse the generated git repository
#gitk: cs-git
#	cd cs-git; gitk --all
#
## Run a garbage-collect on the generated git repository.  Import doesn't.
## This repack call is the active part of gc --aggressive.  This call is
## tuned for very large repositories.
#gc: cs-git
#	cd cs-git; time git -c pack.threads=1 repack -AdF --window=1250 --depth=250
