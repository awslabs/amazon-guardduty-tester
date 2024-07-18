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

import random
import string
import socket
from aws_lambda_powertools.utilities.typing import LambdaContext

def lambda_handler(event: dict, context: LambdaContext) -> int:
    payload = ''.join(random.choice(string.ascii_uppercase) for _ in range(1024))
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(bytes(payload, "utf-8"), (event['ip'], event['port']))
    return 0 