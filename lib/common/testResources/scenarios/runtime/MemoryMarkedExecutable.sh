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

echo '#include<stdio.h>
#include<stdlib.h>
#include<unistd.h>
#include<sys/mman.h>

void mprotectHeapExample (void){
   printf("heap example page is now executable");
}

int main() {
    long pageSize = sysconf(_SC_PAGE_SIZE);
    void* address;

    // mprotect usage for stack memory
    int x = 0;
    void* y = (void*)&x;
    // find start address of the page
    address = (unsigned long)y - ((unsigned long)y % pageSize);
    mprotect(address, pageSize, PROT_WRITE | PROT_EXEC);

    // mprotect usage for heap memory
    void *func = (void*)mprotectHeapExample;
    // find start address of the page
    address = (unsigned long)func - ((unsigned long)func % pageSize);
    mprotect(address, pageSize, PROT_WRITE | PROT_EXEC);

    return 0;
}' > mprotect.c

gcc mprotect.c -o MprotectExecuted
./MprotectExecuted
rm MprotectExecuted
rm mprotect.c