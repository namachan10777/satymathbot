#!/bin/sh

chown -R satymathbot:satymathbot /var/run/satymathbot
exec /usr/local/bin/satymathbot $@
