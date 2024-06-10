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

echo '#include <sys/uio.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

int main(int argc, char **argv) {


    pid_t child = fork();
    if(child == 0) {
        execvp("/bin/ls", NULL);
    }

    pid_t pid = child;

    void *remotePtr = 0x5567fd9922a0;
    size_t bufferLength = 128;

    struct iovec local[1];
    local[0].iov_base = calloc(bufferLength, sizeof(char));
    local[0].iov_len = bufferLength;

    struct iovec remote[1];
    remote[0].iov_base = remotePtr;
    remote[0].iov_len = bufferLength;

    ssize_t nread = process_vm_readv(pid, local, 2, remote, 1, 0);
    if (nread < 0) {
        printf(" * Failed process_vm_read\n", nread);
    }

    ssize_t nwrite = process_vm_writev(pid, local, 1, remote, 2, 0);
    if (nread < 0) {
        printf(" * Failed process_vm_write\n", nread);
    }
    return 0;
}' > vmRwTest.c

gcc vmRwTest.c -o vmRwTest -w

./vmRwTest

rm vmRwTest.c
rm vmRwTest