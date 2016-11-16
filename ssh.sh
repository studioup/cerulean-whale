#! /usr/bin/env bash
#
# Simple script to create a new s3 account and associed credentials.
# Use the aws utility.

set -e

doctl compute ssh replace_with_droplet_id --ssh-key-path replace_with_ssh_private_key_path