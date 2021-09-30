NAME	= mqtt-topic-grapher
SPEC	= $(NAME).spec
VERSION	= $(shell sed -e '/Version:/!d' -e 's/[^0-9.]*\([0-9.]*\).*/\1/' $(SPEC))
MANIFEST= MANIFEST
SRCS	= $(shell cat $(MANIFEST))
AUX	= $(SPEC) Makefile
DISTDIR	= $(NAME)-$(VERSION)

dist:	$(SRCS) $(AUX)
	pwd
	@echo "Prepare"
	-rm -rf $(DISTDIR)
	@echo "Creating folder $(DISTDIR)"
	mkdir $(DISTDIR)
	@echo "Hardlinking files for tarball"
	ln $(AUX) $(DISTDIR)
	ln $(MANIFEST) $(DISTDIR)
	for F in $(SRCS); do D=`dirname $$F`; mkdir -p $(DISTDIR)/$$D; ln --target-directory=$(DISTDIR)/$$D $$F; done
	@echo "Creating tarball $(DISTDIR).tar.gz"
	tar chzfv $(DISTDIR).tar.gz $(DISTDIR)
	@echo "Cleaning up..."
	-rm -rf $(DISTDIR)
	@echo "Finished!"

$(DISTDIR).tar.gz:	dist

rpm:	$(DISTDIR).tar.gz
	rpmbuild -ta $(DISTDIR).tar.gz
