#!/bin/sh

exec ssh -i ${SSH_KEY_FILE} "$@"
