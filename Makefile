PROJECT = $(notdir $(shell pwd))
ERLC_OPTS = +debug_info +warn_export_all +warn_export_vars +warn_shadow_vars +warn_obsolete_guard

CUR_DIR = $(shell pwd)

GEAS_RELEASES = R15B R15B01 R15B02 R15B03 R15B03-1 R16B R16B01 R16B02
relinfo = rm -rf .geas && mkdir -p .geas && cd .geas && kerl install $(1) && bin/erl -noshell -pa ../ebin -s geas relinfo $(1) $(2) -s init stop && cd $(CUR_DIR)

include erlang.mk

clean:: 
	-@find . -type f -name \*~ -delete


relinfos:
	$(foreach rel, $(GEAS_RELEASES), $(call relinfo, $(rel), "$(CUR_DIR)/priv/relinfos" )) 

