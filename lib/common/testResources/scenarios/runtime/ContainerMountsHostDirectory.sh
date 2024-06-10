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
EXEC_FILENAME="$DATE_STRING-mountTest"

echo '
#include <stdio.h>
#include <sys/mount.h>

int main()
{
   if (mount("/etc/", "/tmp/", "tempfs-test", 0, NULL) != 0) perror("mount"); //mount() fails with "No such device", but triggers event required for finding

   return 0;
}' > mountTest.c

gcc mountTest.c -o $EXEC_FILENAME

./$EXEC_FILENAME
rm $EXEC_FILENAME
rm mountTest.c