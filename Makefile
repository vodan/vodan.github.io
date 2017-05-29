TOC_GENERATOR=${PWD}/bin/gh-md-toc
FILES=$(filter-out index.md,$(wildcard *.md))

define template
# My Personal website\nThis site shall hold multiple informations I want to share or more or less I
want to remember for later. This site is under continues construction.\n
endef

toc:
	echo '$(strip $(template))'> index.md
	$(TOC_GENERATOR) --depth=1 $(FILES) >> index.md
