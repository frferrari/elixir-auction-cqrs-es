#!/bin/bash

mongo -u eventide -p pastaga --authenticationDatabase andycot << EOF
use andycot
db.auction_events.drop()
db.user_events.drop()
EOF

