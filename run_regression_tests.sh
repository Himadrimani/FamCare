#!/bin/bash
set -e
mkdir -p DerivedData/ModuleCache
swiftc -module-cache-path DerivedData/ModuleCache HomeScreenTests/RewardLifecycleRegressionTests.swift -lsqlite3 -o DerivedData/test_suite_runner
./DerivedData/test_suite_runner
