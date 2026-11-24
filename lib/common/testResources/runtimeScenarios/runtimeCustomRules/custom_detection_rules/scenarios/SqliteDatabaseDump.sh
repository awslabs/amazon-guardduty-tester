#!/bin/sh
#Copyright 2024 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#  
#  Licensed under the Apache License, Version 2.0 (the "License").
#  You may not use this file except in compliance with the License.
#  A copy of the License is located at
#  
#      http://www.apache.org/licenses/LICENSE-2.0
#  
#  or in the "license" file accompanying this file. This file is distributed 
#  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either 
#  express or implied. See the License for the specific language governing 
#  permissions and limitations under the License.
#
# Benign trigger for runtime custom detection rule SqliteDatabaseDump
# Finding type: Discovery:Runtime/SuspiciousCommand
#
# Strategy: the harness installs sqlite; this creates a throwaway database with
# one row, then runs the REAL `sqlite3 <db> .dump` to serialize it. process.name is
# the genuine 'sqlite3' (LIKE 'sqlite%') and the cmd_line contains ` .dump`,
# matching the rule's RE2. Only a disposable temp db is touched.
set -eu

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/benign-sqlite-dump.XXXXXX")"
db="$WORKDIR/throwaway.db"
echo "[cdr] SqliteDatabaseDump: creating throwaway db and running real 'sqlite3 .dump'"
sqlite3 "$db" 'CREATE TABLE t(x); INSERT INTO t VALUES(1);'
sqlite3 "$db" .dump > "$WORKDIR/dump.sql" 2>/dev/null
echo "[cdr] SqliteDatabaseDump: done"
