#!/bin/sh
sc create $1 binPath= "$(echo -n "$2" | base64 -d)"
