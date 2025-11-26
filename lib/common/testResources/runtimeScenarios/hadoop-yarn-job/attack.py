#!/usr/bin/env python3
import inspect
import sys
import os
sys.path.append("/home/ssm-user/py_tester")
sys.path.append("../../")

import signal
import argparse
import subprocess
import time
from types import FrameType
from typing import Optional
from settings_manager import SettingsManager

def main():
    settings_module_path = os.path.dirname(inspect.getfile(SettingsManager))
    current_dir = os.getcwd()
    os.chdir(settings_module_path)
    args = argparse.Namespace()
    args.finding = None
    args.test_resources = ['ec2', 'ecs-ec2', 'ecs-fargate', 'eks']
    args.runtime = ['only']
    args.tactics = []
    args.log_source = ['runtime-monitoring']
    args.yes = False

    settings = SettingsManager()
    print("Configuring AWS account for runtime testing...")
    settings.set_test_settings(args)
    print("Sleeping for 30 secs...")
    time.sleep(30)

    os.chdir(current_dir)
    subprocess.run([f'./files/run_attack_remotely.sh'])
    print("Waiting for 30 secs...")
    time.sleep(30)
    settings.reset_settings()

if __name__ == '__main__':
    main()
