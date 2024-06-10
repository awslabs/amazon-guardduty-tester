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

echo '#include <sys/ptrace.h>
#include <sys/wait.h>
#include <sys/user.h>
#include <syscall.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char* argv[]) {
    pid_t child;
    long OR_EAX;
    child = fork();
    if(child == 0) {
    ptrace(PTRACE_TRACEME, 0, NULL, NULL);
    execvp("/bin/ls", NULL);
    } else {
        wait(NULL);
        ptrace(PTRACE_PEEKUSER, child, 4 * OR_EAX, NULL);
        printf("system call %s from pid %d\n", OR_EAX, child);
        ptrace(PTRACE_DETACH, child, NULL, NULL);
    }
    return 0;
}' > ptrace.c

gcc ptrace.c -o ptrace -w
./ptrace

rm ptrace.c
rm ptrace