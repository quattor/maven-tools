.PHONY: all
INCLUDES:=ncm-$(cmp)/config.mk

TOP=$(shell pwd)

GITREPOS=ncm-components-grid
SVN_SOURCE=https://quattor.svn.sourceforge.net/svnroot/quattor/trunk/ncm-components/lcg-2/ncm-$(cmp)
QBTPATH=/scratch/jouvin/quattor/core/ncm-components/quattor-build-tools
MVNCMD=/exp/si/jouvin/tools/apache-maven-3.0.4/bin/mvn

CHDIR_SHELL := $(SHELL)
define chdir
   $(eval _D=$(firstword $(1) $(@D)))
   $(info $(MAKE): cd $(_D)) $(eval SHELL = cd $(_D); $(CHDIR_SHELL))
endef

all: $(GITREPOS)/ncm-$(cmp)

# COMP, VERSION, DESC, auth and email come from the included file
$(cmp): ncm-$(cmp)
	$(eval include $(INCLUDES))
	$(eval auth=$(shell echo "${AUTHOR}"|sed 's/ <.*//'))
	$(eval email=$(shell echo "${AUTHOR}"|sed 's/.*<\(.*\)>/\1/'))
	@echo auth=$(auth)
	@echo email=$(email)
	@echo make cmd=$(MAKE)
	sh archetype.sh "$(COMP)" "$(VERSION)" "$(DESCR)" "$(auth)" "$(email)" "$(MVNCMD)"

$(GITREPOS)/ncm-$(cmp): $(cmp)
	$(call chdir,$(GITREPOS))
	git remote add $(cmp) -t $(cmp) ../ncm-$(cmp)
	git fetch $(cmp)
	git checkout -b $(cmp) $(cmp)/$(cmp)
	git checkout -b tmp
	cp -r ../$(cmp) ./ncm-$(cmp)
	git add ncm-$(cmp)
	git commit -m 'Skeleton added'
	git filter-branch -f --tree-filter "$(TOP)/../filter.sh $(cmp) $(QBTPATH)" $(cmp)
	git checkout $(cmp)
	cd ncm-$(cmp); $(MVNCMD) test
	git checkout -B master
        # Merge should be fast forward
	git merge --ff-only $(cmp)
	git branch -D tmp
	sed -i "/<modules>/i<module>ncm-$(cmp)</module>" pom.xml
	git add pom.xml
	git commit -m "Integrate ncm-$(cmp) into Git+Maven" pom.xml
	@echo "After validating the migrated component, push it to GitHub and make it readonly on SourceForge SVN"

ncm-$(cmp):
	git svn clone $(SVN_SOURCE)
	git --git-dir=ncm-$(cmp)/.git --work-tree=ncm-$(cmp) checkout -b $(cmp)

