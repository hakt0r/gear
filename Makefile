
run:
	coffee gear.coffee daemon -D 2>&1

cached:
	node ${HOME}/.config/gear/cache/gear.js daemon -D

release:
	node ${HOME}/.config/gear/cache/gear.js daemon

release-cui:
	node ${HOME}/.config/gear/cache/gear.js daemon --cui

install:
	coffee gear.coffee install 2>&1

debug:
	coffee --nodejs debug gear.coffee daemon -D 2>&1

debug-inspector:
	coffee --nodejs debug gear.coffee daemon -D 2>&1
