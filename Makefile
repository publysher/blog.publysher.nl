DEST?=_site

.PHONY:	all
all:	site css

.PHONY:	clean
clean:
	rm -rf $(DEST)


.PHONY:	css
css:	
	mkdir -p $(DEST)/css/font-awesome/font/
	lessc -x less/style.less > $(DEST)/css/style.css
	cp less/font-awesome/font/* $(DEST)/css/font-awesome/font/

.PHONY:	site
site:
	jekyll build -s blog -d $(DEST)

.PHONY:	serve
serve:	css
	jekyll serve -s blog -d $(DEST) 
