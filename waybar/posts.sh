#!/bin/bash
count=$(grep -c repo_name /home/tom/git/x_twitter_production/saved_posts.json 2>/dev/null || echo 0)
echo "PQ $count    "
