.PHONY: all clean

COMMON_JAVASCRIPT=../../common/javascript
S2_JAVASCRIPT=../../s2/javascript
WIKIWYG_ST=../../wikiwyg/javascript
WIKIWYG_PATH=../../wikiwyg/javascript
MINIFY=perl -MJavaScript::Minifier::XS -0777 -e 'print JavaScript::Minifier::XS::minify(scalar <>);'
#MINIFY=cat

S3_FILE=socialtext-s3.js
S3_FILE_MINI=socialtext-s3-mini.js
S3_FILE_GZIP=$(S3_FILE).gz

ST_EDITOR_FILE=$(WIKIWYG_ST)/socialtext-editor.js
EDITOR_FILE=socialtext-editor.js
EDITOR_FILE_MINI=socialtext-editor-mini.js
EDITOR_FILE_GZIP=socialtext-editor.js.gz

ST_EDITOR_LIGHT_FILE=$(WIKIWYG_ST)/socialtext-editor-light.js
EDITOR_LIGHT_FILE=socialtext-editor-light.js
EDITOR_LIGHT_FILE_MINI=socialtext-editor-light-mini.js
EDITOR_LIGHT_FILE_GZIP=socialtext-editor-light.js.gz

EDITOR_LIGHT_FILES= \
		jquery-plugin.js \
		lookahead.js \
		jquery.selectOverlap.js \
		Class.js \
		loc.js \
		$(ST_EDITOR_LIGHT_FILE) \

ALL_EDITOR_FILES:=$(shell find $(WIKIWYG_ST) $(COMMON_JAVASCRIPT) -type f | grep -v .svn | grep -v editor.js | grep -v editor-light.js)
ALL_JEMPLATE_PLUGINS:=$(shell find JemplatePlugin -name \*.js)

S3_SOURCE_FILES= \
		timestamp.js \
		info.js \
		Debug.js \
		$(COMMON_JAVASCRIPT)/jquery-1.2.6.js \
		Class.js \
		lightbox.js \
		jquery-patch.js \
		jquery-plugin.js \
		jquery.tablesorter.js \
		jquery.selectOverlap.js \
		Jemplate.js \
		$(ALL_JEMPLATE_PLUGINS) \
		loc.js \
		cookie.js \
		lookahead.js \
		pageview.js \
		email.js \
		search.js \
		s3.js \
		people-avatar.js \

LIGHTBOX_TEMPLATES=$(wildcard lightbox/*.tt2)
LIGHTBOX_OUTPUT=$(LIGHTBOX_TEMPLATES:lightbox/%.tt2=lightbox-%.js)
LIGHTBOX_OUTPUT_GZIPS=$(LIGHTBOX_OUTPUT:%=%.gz)
PLUGIN_LIGHTBOXES=$(wildcard ../../../plugin/*/share/javascript/lightbox-*.js)

all: \
    $(LIGHTBOX_OUTPUT_GZIPS) \
    $(LIGHTBOX_OUTPUT) \
    timestamp.js \
    $(S3_FILE_GZIP) \
    $(EDITOR_FILE_GZIP) \
    $(EDITOR_LIGHT_FILE_GZIP) \
    Selection.htc \

clean:
	rm -f \
	    info.js \
	    timestamp.js \
	    Jemplate.js \
	    $(LIGHTBOX_OUTPUT) \
	    $(LIGHTBOX_OUTPUT_GZIPS) \
	    $(S3_FILE) \
	    $(S3_FILE_MINI) \
	    $(S3_FILE_GZIP) \
	    $(EDITOR_FILE) \
	    $(EDITOR_FILE_MINI) \
	    $(EDITOR_FILE_GZIP) \
	    $(EDITOR_LIGHT_FILE) \
	    $(EDITOR_LIGHT_FILE_MINI) \
	    $(EDITOR_LIGHT_FILE_GZIP) \
	    build-semaphore \
	    Selection.htc \

.SUFFIXES: .js -mini.js .js.gz

.js-mini.js:
	$(MINIFY) $< > $@

$(PLUGIN_LIGHTBOXES):
	# Do nothing. But this avoids us messing up plugin lightboxes in the
	# folowing section

lightbox-%.js: st-lightbox.js lightbox/%.tt2 lightbox/%.js
	jemplate --compile $(@:lightbox-%.js=lightbox/%.tt2) > $@; \
	for js in st-lightbox.js $(@:lightbox-%.js=lightbox/%.js); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

$(EDITOR_FILE): lightbox-attachment.js $(ST_EDITOR_FILE)
	rm -f $@;
	cat lightbox-attachment.js $(ST_EDITOR_FILE) >> $@

$(EDITOR_LIGHT_FILE): $(EDITOR_LIGHT_FILES)
	rm -f $@;
	for js in $(EDITOR_LIGHT_FILES) ; do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

$(EDITOR_FILE_MINI): $(EDITOR_FILE)
	$(MINIFY) $< > $@

$(EDITOR_LIGHT_FILE_MINI): $(EDITOR_LIGHT_FILE)
	$(MINIFY) $< > $@

-mini.js.js.gz:
	gzip -c $< > $@

Jemplate.js:
	jemplate --runtime=jquery > $@

$(S3_FILE): $(S3_SOURCE_FILES) Makefile
	rm -f $@;
	for js in $(S3_SOURCE_FILES); do \
	    (echo "// BEGIN $$js"; cat $$js | perl -pe 's/\r//g') >> $@; \
	done

$(ST_EDITOR_FILE): $(ALL_EDITOR_FILES)
	make -C $(WIKIWYG_ST) all

$(ST_EDITOR_LIGHT_FILE): $(ALL_EDITOR_FILES)
	make -C $(WIKIWYG_ST) all

info.js: ../info.yaml
	perl -MYAML -MTemplate -e \
	    'Template->new->process("template/$@", YAML::LoadFile("$<"))' > $@

timestamp.js: $(ST_EDITOR_FILE) $(S3_SOURCE_FILES:timestamp.js%=%) $(LIGHTBOX_OUTPUT) $(PLUGIN_LIGHTBOXES)
	echo 'var Socialtext = Socialtext || {};' > $@
	perl -le 'print "Socialtext.make_time = \"" . time . "\";"' >> $@

Selection.htc:
	cp -f $(WIKIWYG_PATH)/lib/Selection.htc $@

