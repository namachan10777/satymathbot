#!/bin/sh

chown -R satymathbot:satymathbot /var/run/satymathbot
exec /usr/bin/sudo -u satymathbot /usr/local/bin/satymathbot $@
