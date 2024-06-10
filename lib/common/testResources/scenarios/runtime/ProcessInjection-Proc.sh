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

sleep 15 &
PID=$!
DATE_STRING=$(date +%s)
EXEC_FILENAME="$DATE_STRING-proctest"

echo '#include <fstream>
#include <iostream>
#include <sys/mman.h>
/* Write @len bytes at @ptr to @addr in this address space using
 * /proc/self/mem.
 */
void memwrite(void *addr, char *ptr, size_t len) {
  //std::ofstream ff("/proc/self/mem");
  std::ofstream ff("/proc/'$PID'/mem");
  ff.seekp(reinterpret_cast<size_t>(addr));
  ff.write(ptr, len);
  ff.flush();
}

int main(int argc, char **argv) {
  // Map an unwritable page. (read-only)
  auto mymap =
      (int *)mmap(NULL, 0x9000,
                  PROT_READ, // <<<<<<<<<<<<<<<<<<<<< READ ONLY <<<<<<<<
                  MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);

  if (mymap == MAP_FAILED) {
    std::cout << "FAILED\n";
    return 1;
  }

  std::cout << "Allocated PROT_READ only memory: " << mymap << "\n";

  // Try to write to the unwritable page.
  memwrite(mymap, "\x40\x41\x41\x41", 4);
  std::cout << "did mymap[0] = 0x41414140 via proc self mem..";
  std::cout << "mymap[0] = 0x" << std::hex << mymap[0] << "\n";

  // Try to write to the text segment (executable code) of libc.
  auto getchar_ptr = (char *)getchar;
  memwrite(getchar_ptr, "\xcc", 1);

  // Run the libc function whose code we modified. If the write worked,
  // we will get a SIGTRAP when the 0xcc executes.

}' > procinject.cpp


gcc procinject.cpp -o $EXEC_FILENAME -w -lstdc++

./$EXEC_FILENAME

rm $EXEC_FILENAME
rm procinject.cpp
