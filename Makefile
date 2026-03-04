PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

SCRIPT := arch-purge.sh
TARGET := arch-purge

.PHONY: all install uninstall help

all: help

help:
	@echo "Available targets:"
	@echo "  make install   - Install $(TARGET) to $(BINDIR)"
	@echo "  make uninstall - Remove $(TARGET) from $(BINDIR)"

install:
	@echo "Installing $(TARGET) to $(DESTDIR)$(BINDIR)..."
	install -d "$(DESTDIR)$(BINDIR)"
	install -m 755 "$(SCRIPT)" "$(DESTDIR)$(BINDIR)/$(TARGET)"
	@echo "Installed $(TARGET) to $(DESTDIR)$(BINDIR)/$(TARGET)"

uninstall:
	@echo "Removing $(DESTDIR)$(BINDIR)/$(TARGET)..."
	rm -f "$(DESTDIR)$(BINDIR)/$(TARGET)"
	@echo "Removed $(DESTDIR)$(BINDIR)/$(TARGET)"

